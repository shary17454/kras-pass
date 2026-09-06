#import <AuthenticationServices/AuthenticationServices.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <atomic>

using namespace godot;

@interface KrasAppleAuthorization : NSObject <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>
@property(nonatomic, strong) ASAuthorizationController *controller;
@property(nonatomic, strong) KrasAppleAuthorization *retained;
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, copy) void (^completion)(NSString *, NSString *, NSString *);
@end

@implementation KrasAppleAuthorization
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller {
    return self.window;
}
- (void)finish:(NSString *)token code:(NSString *)code error:(NSString *)error {
    void (^callback)(NSString *, NSString *, NSString *) = self.completion;
    self.completion = nil;
    self.controller = nil;
    if (callback) callback(token, code, error);
    self.retained = nil;
}
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization {
    if (![authorization.credential isKindOfClass:ASAuthorizationAppleIDCredential.class]) {
        [self finish:nil code:nil error:@"failed"];
        return;
    }
    ASAuthorizationAppleIDCredential *credential = (ASAuthorizationAppleIDCredential *)authorization.credential;
    NSString *token = [[NSString alloc] initWithData:credential.identityToken encoding:NSUTF8StringEncoding];
    NSString *code = [[NSString alloc] initWithData:credential.authorizationCode encoding:NSUTF8StringEncoding];
    [self finish:token code:code error:token.length ? nil : @"failed"];
}
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error {
    [self finish:nil code:nil error:(error.code == ASAuthorizationErrorCanceled ? @"cancelled" : @"failed")];
}
@end

class KrasAppleBridge : public RefCounted {
    GDCLASS(KrasAppleBridge, RefCounted);
    std::atomic_bool busy{false};
    static NSDictionary *query(const String &profile) {
        NSString *account = [NSString stringWithUTF8String:profile.utf8().get_data()];
        return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                 (__bridge id)kSecAttrService: @"com.shary.kraspass.account",
                 (__bridge id)kSecAttrAccount: account};
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("sign_in", "nonce"), &KrasAppleBridge::sign_in);
        ClassDB::bind_method(D_METHOD("save_session", "profile", "token"), &KrasAppleBridge::save_session);
        ClassDB::bind_method(D_METHOD("load_session", "profile"), &KrasAppleBridge::load_session);
        ClassDB::bind_method(D_METHOD("clear_session", "profile"), &KrasAppleBridge::clear_session);
        ADD_SIGNAL(MethodInfo("identity_received", PropertyInfo(Variant::STRING, "token"), PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "error")));
    }
public:
    void sign_in(String nonce) {
        if (nonce.length() != 43 || busy.exchange(true)) {
            call_deferred("emit_signal", "identity_received", "", "", "failed");
            return;
        }
        Ref<KrasAppleBridge> keep(this);
        NSString *value = [NSString stringWithUTF8String:nonce.utf8().get_data()];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) window = candidate;
            }
            if (!window) {
                keep->busy = false;
                keep->call_deferred("emit_signal", "identity_received", "", "", "failed");
                return;
            }
            KrasAppleAuthorization *login = [KrasAppleAuthorization new];
            login.retained = login;
            login.window = window;
            login.completion = ^(NSString *token, NSString *code, NSString *error) {
                keep->busy = false;
                keep->call_deferred("emit_signal", "identity_received",
                    String(token ? token.UTF8String : ""), String(code ? code.UTF8String : ""), String(error ? error.UTF8String : ""));
            };
            ASAuthorizationAppleIDRequest *request = [[ASAuthorizationAppleIDProvider new] createRequest];
            request.requestedScopes = @[ASAuthorizationScopeEmail];
            request.nonce = value;
            login.controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
            login.controller.delegate = login;
            login.controller.presentationContextProvider = login;
            [login.controller performRequests];
        });
    }
    bool save_session(String profile, String token) {
        if (token.length() != 43) return false;
        NSData *data = [[NSString stringWithUTF8String:token.utf8().get_data()] dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *attributes = @{(__bridge id)kSecValueData: data,
            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
        OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query(profile), (__bridge CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            NSMutableDictionary *item = [query(profile) mutableCopy];
            [item addEntriesFromDictionary:attributes];
            status = SecItemAdd((__bridge CFDictionaryRef)item, nil);
        }
        return status == errSecSuccess;
    }
    String load_session(String profile) {
        NSMutableDictionary *item = [query(profile) mutableCopy];
        item[(__bridge id)kSecReturnData] = @YES;
        CFTypeRef output = nullptr;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)item, &output) != errSecSuccess) return "";
        NSData *data = CFBridgingRelease(output);
        NSString *token = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return String(token ? token.UTF8String : "");
    }
    void clear_session(String profile) { SecItemDelete((__bridge CFDictionaryRef)query(profile)); }
};

void initialize_kras_apple(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<KrasAppleBridge>();
}
extern "C" GDExtensionBool GDE_EXPORT kras_apple_init(GDExtensionInterfaceGetProcAddress get_proc,
    GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize_kras_apple);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
