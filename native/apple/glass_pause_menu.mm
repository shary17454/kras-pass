#import "glass_pause_menu.h"

@implementation KrasGlassPauseMenu {
    NSMutableArray<UIButton *> *_buttons;
    NSInteger _selection;
    UIVisualEffectView *_panel;
    UIScrollView *_scroll;
    UIAlertController *_restartConfirmation;
    NSInteger _confirmationSelection;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _buttons = [NSMutableArray new];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    self.view.semanticContentAttribute = self.rightToLeft
        ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;

    UIVisualEffect *effect = nil;
    if (@available(iOS 26.0, *)) effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:effect];
    _panel = panel;
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        panel.effect = nil;
        panel.backgroundColor = UIColor.secondarySystemBackgroundColor;
    }
    panel.layer.cornerRadius = 28;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.clipsToBounds = YES;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:panel];

    UIScrollView *scroll = [UIScrollView new];
    _scroll = scroll;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [panel.contentView addSubview:scroll];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    UILabel *title = [self labelForKey:@"title" style:UIFontTextStyleTitle2];
    title.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:title];
    if (self.labels[@"message"].length) [stack addArrangedSubview:[self labelForKey:@"message" style:UIFontTextStyleBody]];
    NSArray *commands = @[@"resume", @"restart", @"settings", @"quit"];
    NSArray *symbols = @[@"play.fill", @"arrow.counterclockwise", @"gearshape", @"rectangle.portrait.and.arrow.right"];
    for (NSUInteger index = 0; index < commands.count; ++index) {
        NSString *command = commands[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        if (@available(iOS 26.0, *)) {
            if (!UIAccessibilityIsReduceTransparencyEnabled()) {
                config = index == 0 ? [UIButtonConfiguration prominentGlassButtonConfiguration]
                                    : [UIButtonConfiguration glassButtonConfiguration];
            }
        }
        config.title = self.labels[command];
        config.image = [UIImage systemImageNamed:symbols[index]];
        config.imagePadding = 10;
        config.contentInsets = NSDirectionalEdgeInsetsMake(12, 16, 12, 16);
        button.configuration = config;
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.accessibilityIdentifier = [@"kras.pause." stringByAppendingString:command];
        button.enabled = ![command isEqualToString:@"restart"] || self.allowsRestart;
        __weak KrasGlassPauseMenu *weakSelf = self;
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            KrasGlassPauseMenu *menu = weakSelf;
            if (!menu) return;
            if ([command isEqualToString:@"restart"]) [menu confirmRestart];
            else [menu finish:command];
        }] forControlEvents:UIControlEventPrimaryActionTriggered];
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [stack addArrangedSubview:button];
        [_buttons addObject:button];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *width = [panel.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-48];
    width.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *height = [panel.heightAnchor constraintEqualToAnchor:stack.heightAnchor constant:32];
    height.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        width, height,
        [panel.widthAnchor constraintLessThanOrEqualToConstant:600],
        [panel.heightAnchor constraintLessThanOrEqualToAnchor:safe.heightAnchor constant:-32],
        [panel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:16],
        [scroll.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-16],
        [scroll.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:16],
        [scroll.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(transparencyChanged:)
        name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)transparencyChanged:(NSNotification *)notification {
    BOOL reduced = UIAccessibilityIsReduceTransparencyEnabled();
    if (@available(iOS 26.0, *)) {
        _panel.effect = reduced ? nil : [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
    }
    _panel.backgroundColor = reduced ? UIColor.secondarySystemBackgroundColor : UIColor.clearColor;
    for (NSUInteger index = 0; index < _buttons.count; ++index) {
        UIButton *button = _buttons[index];
        UIButtonConfiguration *previous = button.configuration;
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        if (@available(iOS 26.0, *)) {
            if (!reduced) config = index == 0 ? [UIButtonConfiguration prominentGlassButtonConfiguration]
                                             : [UIButtonConfiguration glassButtonConfiguration];
        }
        config.title = previous.title;
        config.image = previous.image;
        config.imagePadding = previous.imagePadding;
        config.contentInsets = previous.contentInsets;
        button.configuration = config;
    }
}

- (BOOL)canBecomeFirstResponder { return YES; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}
- (NSArray<UIKeyCommand *> *)keyCommands {
    return @[
        [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:0 action:@selector(previousChoice:)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:0 action:@selector(nextChoice:)],
        [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:0 action:@selector(activateChoice:)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(resumeChoice:)]];
}
- (void)previousChoice:(UIKeyCommand *)key { [self navigate:-1 activate:NO]; }
- (void)nextChoice:(UIKeyCommand *)key { [self navigate:1 activate:NO]; }
- (void)activateChoice:(UIKeyCommand *)key { [self navigate:0 activate:YES]; }
- (void)resumeChoice:(UIKeyCommand *)key {
    if (_restartConfirmation) [self closeRestartConfirmation:NO];
    else [self finish:@"resume"];
}
- (void)navigate:(NSInteger)direction activate:(BOOL)activate {
    if (!direction && !activate) {
        [self resumeChoice:nil];
        return;
    }
    if (_restartConfirmation) {
        if (activate) [self closeRestartConfirmation:_confirmationSelection == 1];
        else if (direction) {
            _confirmationSelection = 1 - _confirmationSelection;
            _restartConfirmation.preferredAction = _restartConfirmation.actions[_confirmationSelection];
        }
        return;
    }
    if (self.presentedViewController || !_buttons.count) return;
    if (activate) {
        [_buttons[_selection] sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        return;
    }
    if (!direction) return;
    for (NSUInteger attempt = 0; attempt < _buttons.count; ++attempt) {
        _selection = (_selection + (direction > 0 ? 1 : -1) + _buttons.count) % _buttons.count;
        if (_buttons[_selection].enabled) break;
    }
    for (NSUInteger index = 0; index < _buttons.count; ++index) _buttons[index].highlighted = index == _selection;
    [_scroll scrollRectToVisible:[_buttons[_selection] convertRect:_buttons[_selection].bounds toView:_scroll]
        animated:!UIAccessibilityIsReduceMotionEnabled()];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _buttons[_selection]);
}

- (UILabel *)labelForKey:(NSString *)key style:(UIFontTextStyle)style {
    UILabel *label = [UILabel new];
    label.text = self.labels[key];
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = UIColor.labelColor;
    label.numberOfLines = 0;
    return label;
}

- (void)confirmRestart {
    if (!self.allowsRestart || self.presentedViewController) return;
    UIAlertController *confirmation = [UIAlertController alertControllerWithTitle:self.labels[@"restart"]
        message:self.labels[@"confirm"] preferredStyle:UIAlertControllerStyleAlert];
    __weak KrasGlassPauseMenu *weakSelf = self;
    [confirmation addAction:[UIAlertAction actionWithTitle:self.labels[@"cancel"] style:UIAlertActionStyleCancel
        handler:^(UIAlertAction *action) {
            KrasGlassPauseMenu *menu = weakSelf;
            if (menu) menu->_restartConfirmation = nil;
        }]];
    [confirmation addAction:[UIAlertAction actionWithTitle:self.labels[@"restart"] style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            KrasGlassPauseMenu *menu = weakSelf;
            if (!menu) return;
            menu->_restartConfirmation = nil;
            [menu finish:@"restart"];
        }]];
    _restartConfirmation = confirmation;
    _confirmationSelection = 0;
    [self presentViewController:confirmation animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)closeRestartConfirmation:(BOOL)restart {
    UIAlertController *confirmation = _restartConfirmation;
    if (!confirmation) return;
    _restartConfirmation = nil;
    __weak KrasGlassPauseMenu *weakSelf = self;
    [confirmation dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:^{
        if (restart) [weakSelf finish:@"restart"];
    }];
}

- (void)finish:(NSString *)command {
    void (^callback)(NSString *) = self.completion;
    if (!callback) return;
    self.completion = nil;
    [self dismissViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled() completion:^{ callback(command); }];
}
@end
