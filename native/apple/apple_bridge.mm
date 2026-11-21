#import <AuthenticationServices/AuthenticationServices.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import "glass_pause_menu.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <atomic>
#include <algorithm>
#include <cmath>

using namespace godot;

static bool kras_finite_rect(CGRect rect) {
    return std::isfinite(rect.origin.x) && std::isfinite(rect.origin.y) &&
        std::isfinite(rect.size.width) && std::isfinite(rect.size.height) &&
        rect.size.width >= 0 && rect.size.height >= 0;
}

static bool kras_normalize_rect(CGRect rect, CGRect bounds, Rect2 &result) {
    if (!kras_finite_rect(bounds) || bounds.size.width <= 0 || bounds.size.height <= 0 ||
        !kras_finite_rect(rect)) return false;
    const CGFloat left = std::max(CGRectGetMinX(rect), CGRectGetMinX(bounds));
    const CGFloat top = std::max(CGRectGetMinY(rect), CGRectGetMinY(bounds));
    const CGFloat right = std::min(CGRectGetMaxX(rect), CGRectGetMaxX(bounds));
    const CGFloat bottom = std::min(CGRectGetMaxY(rect), CGRectGetMaxY(bounds));
    // Keep zero-width/height division lines; CGRectIsEmpty would discard them.
    if (right < left || bottom < top) return false;
    result = Rect2((left - bounds.origin.x) / bounds.size.width,
        (top - bounds.origin.y) / bounds.size.height,
        (right - left) / bounds.size.width, (bottom - top) / bounds.size.height);
    return true;
}

static TypedArray<Rect2> kras_reserved_rects(UIView *view, CGRect bounds, UIViewReservedRegionKind *kind)
    API_AVAILABLE(ios(27.1)) {
    TypedArray<Rect2> result;
    // UIViewReservedRegion.h: frame is in this view's coordinates, INCLUDING margins.
    for (UIViewReservedRegion *region in [view reservedRegionsOfKind:kind options:UIViewReservedRegionQueryOptionsNone]) {
        if (!region.isActive) continue;
        Rect2 normalized;
        if (kras_normalize_rect(region.frame, bounds, normalized)) result.append(normalized);
    }
    return result;
}

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
    std::atomic<int64_t> menu_session{-1};
    __strong KrasGlassPauseMenu *menu = nil;
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
        ClassDB::bind_method(D_METHOD("supports_glass_menu"), &KrasAppleBridge::supports_glass_menu);
        ClassDB::bind_method(D_METHOD("present_glass_menu", "labels", "session", "rtl", "allows_restart"), &KrasAppleBridge::present_glass_menu);
        ClassDB::bind_method(D_METHOD("dismiss_glass_menu"), &KrasAppleBridge::dismiss_glass_menu);
        ClassDB::bind_method(D_METHOD("navigate_glass_menu", "session", "direction", "activate"), &KrasAppleBridge::navigate_glass_menu);
        ClassDB::bind_method(D_METHOD("request_viewport_metrics"), &KrasAppleBridge::request_viewport_metrics);
        ClassDB::bind_method(D_METHOD("_deliver_viewport_metrics", "metrics", "keep"), &KrasAppleBridge::deliver_viewport_metrics);
        ADD_SIGNAL(MethodInfo("viewport_metrics_received", PropertyInfo(Variant::DICTIONARY, "metrics")));
        ADD_SIGNAL(MethodInfo("menu_action", PropertyInfo(Variant::INT, "session"), PropertyInfo(Variant::STRING, "action")));
        ADD_SIGNAL(MethodInfo("identity_received", PropertyInfo(Variant::STRING, "token"), PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "error")));
    }
    void deliver_viewport_metrics(Dictionary metrics, Ref<KrasAppleBridge> keep) {
        if (keep.ptr() == this) emit_signal("viewport_metrics_received", metrics);
    }
public:
    // One deferred response per request; no subscription, controller hooks, or UIKit on the caller's thread.
    // Rect2s use physical top-left axes in [0, 1], relative to the game root view's bounds.
    // valid=false means no attached foreground game view / usable bounds; ignore that sample.
    void request_viewport_metrics() {
        Ref<KrasAppleBridge> keep(this);
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary metrics;
            metrics["valid"] = false;
            metrics["safe_rect"] = Rect2();
            metrics["occlusions"] = TypedArray<Rect2>();
            metrics["divisions"] = TypedArray<Rect2>();
            UIWindow *window = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) window = candidate;
            }
            // Read the game root, not a presented native sheet, screen, or guessed child view.
            UIView *view = window.rootViewController.viewIfLoaded;
            if (view && view.window == window) {
                const CGRect bounds = view.bounds;
                Rect2 safe_rect;
                if (kras_normalize_rect(UIEdgeInsetsInsetRect(bounds, view.safeAreaInsets), bounds, safe_rect) &&
                    safe_rect.size.x > 0 && safe_rect.size.y > 0) {
                    metrics["valid"] = true;
                    metrics["safe_rect"] = safe_rect;
                    if (@available(iOS 27.1, *)) {
                        metrics["occlusions"] = kras_reserved_rects(view, bounds, [UIViewReservedRegionKind occlusionRegionKind]);
                        metrics["divisions"] = kras_reserved_rects(view, bounds, [UIViewReservedRegionKind divisionRegionKind]);
                    }
                }
            }
            // The queued Variant holds keep until delivery, not only until this UIKit block ends.
            keep->call_deferred("_deliver_viewport_metrics", metrics, keep);
        });
    }
    bool supports_glass_menu() const {
        if (@available(iOS 26.0, *)) return true;
        return false;
    }
    void present_glass_menu(Dictionary labels, int64_t session, bool rtl, bool allows_restart) {
        NSMutableDictionary *texts = [NSMutableDictionary new];
        for (NSString *key in @[@"title", @"message", @"resume", @"restart", @"settings", @"quit", @"confirm", @"cancel"]) {
            String field(key.UTF8String);
            Variant value = labels.get(field, "");
            if (value.get_type() != Variant::STRING || String(value).length() > 2000) {
                call_deferred("emit_signal", "menu_action", session, "unavailable");
                return;
            }
            texts[key] = [NSString stringWithUTF8String:String(value).utf8().get_data()];
        }
        menu_session = session;
        Ref<KrasAppleBridge> keep(this);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (keep->menu_session != session) return;
            UIWindow *window = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) window = candidate;
            }
            UIViewController *root = window.rootViewController;
            if (!keep->supports_glass_menu() || !root || root.presentedViewController || keep->menu) {
                keep->call_deferred("emit_signal", "menu_action", session, "unavailable");
                return;
            }
            KrasGlassPauseMenu *sheet = [KrasGlassPauseMenu new];
            sheet.labels = texts;
            sheet.rightToLeft = rtl;
            sheet.allowsRestart = allows_restart;
            sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
            sheet.modalInPresentation = YES;
            sheet.completion = ^(NSString *action) {
                keep->menu = nil;
                if (keep->menu_session == session) keep->call_deferred("emit_signal", "menu_action", session, String(action.UTF8String));
            };
            keep->menu = sheet;
            [root presentViewController:sheet animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
        });
    }
    void dismiss_glass_menu() {
        menu_session = -1;
        Ref<KrasAppleBridge> keep(this);
        dispatch_async(dispatch_get_main_queue(), ^{
            keep->menu.completion = nil;
            [keep->menu dismissViewControllerAnimated:NO completion:nil];
            keep->menu = nil;
        });
    }
    void navigate_glass_menu(int64_t session, int64_t direction, bool activate) {
        Ref<KrasAppleBridge> keep(this);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (keep->menu_session == session) [keep->menu navigate:direction activate:activate];
        });
    }
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
