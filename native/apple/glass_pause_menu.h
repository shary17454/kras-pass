#import <UIKit/UIKit.h>

@interface KrasGlassPauseMenu : UIViewController
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *labels;
@property(nonatomic) BOOL allowsRestart;
@property(nonatomic) BOOL rightToLeft;
@property(nonatomic, copy) void (^completion)(NSString *);
- (void)navigate:(NSInteger)direction activate:(BOOL)activate;
@end
