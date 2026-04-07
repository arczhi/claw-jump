#import "CJOverlayView.h"

#import <QuartzCore/QuartzCore.h>

@interface CJOverlayView ()

@property (nonatomic, strong) CALayer *shadowLayer;
@property (nonatomic, strong) CALayer *auraLayer;
@property (nonatomic, strong) CALayer *pulseRingLayer;
@property (nonatomic, strong) CALayer *pedestalLayer;
@property (nonatomic, strong) CALayer *pedestalFaceLayer;
@property (nonatomic, strong) CALayer *pedestalGlowLayer;
@property (nonatomic, strong) CALayer *pedestalButtonLayer;
@property (nonatomic, strong) CALayer *usbLayer;
@property (nonatomic, strong) CALayer *mascotContainer;
@property (nonatomic, strong) CALayer *mascotBodyLayer;
@property (nonatomic, strong) CALayer *leftTabLayer;
@property (nonatomic, strong) CALayer *rightTabLayer;
@property (nonatomic, strong) NSArray<CALayer *> *legLayers;
@property (nonatomic, strong) NSArray<CALayer *> *eyeLayers;
@property (nonatomic, strong) CATextLayer *messageLayer;
@property (nonatomic, strong) CALayer *messageBackgroundLayer;
@property (nonatomic, assign) NSPoint dragStartMouseLocation;
@property (nonatomic, assign) NSPoint dragStartWindowOrigin;
@property (nonatomic, assign) BOOL didDragWindow;

@end

@implementation CJOverlayView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.clearColor.CGColor;

    _shadowLayer = [CALayer layer];
    _shadowLayer.backgroundColor = [[NSColor colorWithWhite:0 alpha:0.18] CGColor];
    _shadowLayer.cornerRadius = 8;
    [self.layer addSublayer:_shadowLayer];

    _pedestalLayer = [CALayer layer];
    _pedestalLayer.backgroundColor = [[NSColor colorWithRed:0.57 green:0.59 blue:0.62 alpha:1] CGColor];
    _pedestalLayer.cornerRadius = 13;
    _pedestalLayer.shadowColor = NSColor.blackColor.CGColor;
    _pedestalLayer.shadowOpacity = 0.16;
    _pedestalLayer.shadowRadius = 16;
    _pedestalLayer.shadowOffset = CGSizeMake(0, 12);
    [self.layer addSublayer:_pedestalLayer];

    _pedestalFaceLayer = [CALayer layer];
    _pedestalFaceLayer.backgroundColor = [[NSColor colorWithRed:0.79 green:0.81 blue:0.84 alpha:0.2] CGColor];
    _pedestalFaceLayer.cornerRadius = 13;
    [_pedestalLayer addSublayer:_pedestalFaceLayer];

    _pedestalGlowLayer = [CALayer layer];
    _pedestalGlowLayer.backgroundColor = [[NSColor colorWithRed:0.96 green:0.52 blue:0.16 alpha:0.0] CGColor];
    _pedestalGlowLayer.cornerRadius = 4;
    _pedestalGlowLayer.opacity = 0;
    [_pedestalLayer addSublayer:_pedestalGlowLayer];

    _pedestalButtonLayer = [CALayer layer];
    _pedestalButtonLayer.backgroundColor = [[NSColor colorWithRed:0.71 green:0.73 blue:0.75 alpha:1] CGColor];
    _pedestalButtonLayer.cornerRadius = 7;
    _pedestalButtonLayer.borderColor = [[NSColor colorWithWhite:1 alpha:0.36] CGColor];
    _pedestalButtonLayer.borderWidth = 1;
    [_pedestalLayer addSublayer:_pedestalButtonLayer];

    _usbLayer = [CALayer layer];
    _usbLayer.backgroundColor = [[NSColor colorWithRed:0.67 green:0.68 blue:0.70 alpha:1] CGColor];
    _usbLayer.cornerRadius = 3;
    [self.layer addSublayer:_usbLayer];

    CALayer *usbPlug = [CALayer layer];
    usbPlug.backgroundColor = [[NSColor colorWithRed:0.34 green:0.36 blue:0.39 alpha:1] CGColor];
    usbPlug.cornerRadius = 2;
    [_usbLayer addSublayer:usbPlug];

    _mascotContainer = [CALayer layer];
    [self.layer addSublayer:_mascotContainer];

    _auraLayer = [CALayer layer];
    _auraLayer.backgroundColor = [[NSColor colorWithRed:1.0 green:0.83 blue:0.28 alpha:0.55] CGColor];
    _auraLayer.cornerRadius = 44;
    _auraLayer.opacity = 0.0;
    _auraLayer.shadowColor = [[NSColor colorWithRed:1.0 green:0.81 blue:0.22 alpha:1.0] CGColor];
    _auraLayer.shadowOpacity = 0.95;
    _auraLayer.shadowRadius = 26;
    _auraLayer.shadowOffset = CGSizeZero;
    [_mascotContainer addSublayer:_auraLayer];

    _pulseRingLayer = [CALayer layer];
    _pulseRingLayer.borderColor = [[NSColor colorWithRed:1.0 green:0.94 blue:0.62 alpha:0.95] CGColor];
    _pulseRingLayer.borderWidth = 3.0;
    _pulseRingLayer.cornerRadius = 52;
    _pulseRingLayer.opacity = 0.0;
    [_mascotContainer addSublayer:_pulseRingLayer];

    _mascotBodyLayer = [CALayer layer];
    _mascotBodyLayer.backgroundColor = [[NSColor colorWithRed:0.70 green:0.27 blue:0.12 alpha:1] CGColor];
    _mascotBodyLayer.cornerRadius = 9;
    _mascotBodyLayer.shadowColor = NSColor.blackColor.CGColor;
    _mascotBodyLayer.shadowOpacity = 0.18;
    _mascotBodyLayer.shadowRadius = 8;
    _mascotBodyLayer.shadowOffset = CGSizeMake(0, 6);
    [_mascotContainer addSublayer:_mascotBodyLayer];

    _leftTabLayer = [CALayer layer];
    _leftTabLayer.backgroundColor = [[NSColor colorWithRed:0.61 green:0.23 blue:0.10 alpha:1] CGColor];
    _leftTabLayer.cornerRadius = 5;
    [_mascotContainer addSublayer:_leftTabLayer];

    _rightTabLayer = [CALayer layer];
    _rightTabLayer.backgroundColor = [[NSColor colorWithRed:0.61 green:0.23 blue:0.10 alpha:1] CGColor];
    _rightTabLayer.cornerRadius = 5;
    [_mascotContainer addSublayer:_rightTabLayer];

    NSMutableArray<CALayer *> *legs = [NSMutableArray array];
    for (NSInteger index = 0; index < 4; index += 1) {
        CALayer *leg = [CALayer layer];
        leg.backgroundColor = [[NSColor colorWithRed:0.66 green:0.25 blue:0.11 alpha:1] CGColor];
        leg.cornerRadius = 3;
        [_mascotContainer addSublayer:leg];
        [legs addObject:leg];
    }
    _legLayers = legs.copy;

    NSMutableArray<CALayer *> *eyes = [NSMutableArray array];
    for (NSInteger index = 0; index < 2; index += 1) {
        CALayer *eye = [CALayer layer];
        eye.backgroundColor = [[NSColor colorWithWhite:0 alpha:0.75] CGColor];
        eye.cornerRadius = 2.5;
        [_mascotContainer addSublayer:eye];
        [eyes addObject:eye];
    }
    _eyeLayers = eyes.copy;

    _messageBackgroundLayer = [CALayer layer];
    _messageBackgroundLayer.backgroundColor = [[NSColor colorWithWhite:0 alpha:0.55] CGColor];
    _messageBackgroundLayer.cornerRadius = 11;
    [self.layer addSublayer:_messageBackgroundLayer];

    _messageLayer = [CATextLayer layer];
    _messageLayer.fontSize = 11;
    _messageLayer.alignmentMode = kCAAlignmentCenter;
    _messageLayer.contentsScale = NSScreen.mainScreen.backingScaleFactor ?: 2.0;
    _messageLayer.foregroundColor = [[NSColor colorWithWhite:1 alpha:0.92] CGColor];
    _messageLayer.string = @"Waiting for Claude Code";
    [self.layer addSublayer:_messageLayer];

    usbPlug.frame = CGRectMake(0, 5, 7, 12);
}

- (BOOL)isFlipped {
    return NO;
}

- (void)layout {
    [super layout];

    CGFloat width = NSWidth(self.bounds);
    CGFloat height = NSHeight(self.bounds);
    CGFloat centerX = width / 2.0;
    CGFloat pedestalWidth = 104.0;
    CGFloat pedestalHeight = 132.0;
    CGFloat pedestalX = floor(centerX - pedestalWidth / 2.0);
    CGFloat pedestalY = 34.0;

    self.shadowLayer.frame = CGRectMake(centerX - 37.0, 28.0, 74.0, 16.0);
    self.pedestalLayer.frame = CGRectMake(pedestalX, pedestalY, pedestalWidth, pedestalHeight);
    self.pedestalFaceLayer.frame = CGRectMake(0.0, 0.0, 28.0, pedestalHeight);
    self.pedestalGlowLayer.frame = CGRectMake((pedestalWidth - 54.0) / 2.0, pedestalHeight - 6.0, 54.0, 8.0);
    self.pedestalButtonLayer.frame = CGRectMake(14.0, 14.0, 15.0, 15.0);
    self.usbLayer.frame = CGRectMake(CGRectGetMaxX(self.pedestalLayer.frame) - 4.0, pedestalY + 16.0, 18.0, 22.0);
    self.usbLayer.sublayers.firstObject.frame = CGRectMake(-5.0, 5.0, 7.0, 12.0);

    self.mascotContainer.bounds = CGRectMake(0.0, 0.0, 92.0, 78.0);
    [self updateMascotGeometry];
    [self setMascotCenterY:[self idleMascotCenterY]];

    self.messageBackgroundLayer.frame = CGRectMake(centerX - 86.0, 8.0, 172.0, 22.0);
    self.messageLayer.frame = CGRectInset(self.messageBackgroundLayer.frame, 8.0, 4.0);

    (void)height;
}

- (void)playJumpWithMessage:(NSString *)message {
    self.messageLayer.string = message.length > 0 ? message : @"Claude Code is ready";

    CGFloat startY = [self currentMascotCenterY];
    CGFloat jumpY = [self jumpMascotCenterY];
    CGFloat waitingY = [self waitingMascotCenterY];

    [self.mascotContainer removeAnimationForKey:@"jump"];
    [self.shadowLayer removeAnimationForKey:@"shadowScale"];
    [self.shadowLayer removeAnimationForKey:@"shadowOpacity"];
    [self.pedestalGlowLayer removeAnimationForKey:@"glowOpacity"];
    [self.auraLayer removeAnimationForKey:@"auraOpacity"];
    [self.auraLayer removeAnimationForKey:@"auraScale"];
    [self.pulseRingLayer removeAnimationForKey:@"ringOpacity"];
    [self.pulseRingLayer removeAnimationForKey:@"ringScale"];

    [self setMascotHighlighted:YES animated:YES];

    self.mascotContainer.position = CGPointMake(NSMidX(self.bounds), waitingY);
    self.shadowLayer.transform = CATransform3DIdentity;
    self.shadowLayer.opacity = 0.18;
    self.pedestalGlowLayer.opacity = 0.28;
    self.auraLayer.opacity = 0.26;
    self.auraLayer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0);
    self.pulseRingLayer.opacity = 0.0;
    self.pulseRingLayer.transform = CATransform3DMakeScale(1.18, 1.18, 1.0);

    CAKeyframeAnimation *jump = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
    jump.values = @[@(startY), @(jumpY), @(waitingY)];
    jump.keyTimes = @[@0.0, @0.42, @1.0];
    jump.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ];
    jump.duration = 0.82;
    [self.mascotContainer addAnimation:jump forKey:@"jump"];

    CAKeyframeAnimation *shadowScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.x"];
    shadowScale.values = @[@1.0, @0.76, @1.02];
    shadowScale.keyTimes = jump.keyTimes;
    shadowScale.duration = jump.duration;
    [self.shadowLayer addAnimation:shadowScale forKey:@"shadowScale"];

    CAKeyframeAnimation *shadowOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    shadowOpacity.values = @[@0.18, @0.08, @0.18];
    shadowOpacity.keyTimes = jump.keyTimes;
    shadowOpacity.duration = jump.duration;
    [self.shadowLayer addAnimation:shadowOpacity forKey:@"shadowOpacity"];

    CAKeyframeAnimation *glowOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    glowOpacity.values = @[@0.0, @1.0, @0.28];
    glowOpacity.keyTimes = jump.keyTimes;
    glowOpacity.duration = jump.duration;
    [self.pedestalGlowLayer addAnimation:glowOpacity forKey:@"glowOpacity"];

    CAKeyframeAnimation *auraOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    auraOpacity.values = @[@0.0, @0.95, @0.26];
    auraOpacity.keyTimes = jump.keyTimes;
    auraOpacity.duration = jump.duration;
    [self.auraLayer addAnimation:auraOpacity forKey:@"auraOpacity"];

    CAKeyframeAnimation *auraScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    auraScale.values = @[@0.78, @1.18, @1.0];
    auraScale.keyTimes = jump.keyTimes;
    auraScale.duration = jump.duration;
    [self.auraLayer addAnimation:auraScale forKey:@"auraScale"];

    CAKeyframeAnimation *ringOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    ringOpacity.values = @[@0.0, @0.82, @0.0];
    ringOpacity.keyTimes = @[@0.0, @0.38, @1.0];
    ringOpacity.duration = jump.duration;
    [self.pulseRingLayer addAnimation:ringOpacity forKey:@"ringOpacity"];

    CAKeyframeAnimation *ringScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.values = @[@0.72, @1.0, @1.34];
    ringScale.keyTimes = @[@0.0, @0.36, @1.0];
    ringScale.duration = jump.duration;
    [self.pulseRingLayer addAnimation:ringScale forKey:@"ringScale"];
}

- (void)resetToIdle {
    CGFloat startY = [self currentMascotCenterY];
    CGFloat idleY = [self idleMascotCenterY];

    self.messageLayer.string = @"Ready for the next prompt";
    self.mascotContainer.position = CGPointMake(NSMidX(self.bounds), idleY);
    self.shadowLayer.transform = CATransform3DIdentity;
    self.shadowLayer.opacity = 0.18;
    self.pedestalGlowLayer.opacity = 0.0;
    self.auraLayer.opacity = 0.0;
    self.pulseRingLayer.opacity = 0.0;
    self.auraLayer.transform = CATransform3DIdentity;
    self.pulseRingLayer.transform = CATransform3DIdentity;

    [self setMascotHighlighted:NO animated:YES];

    CABasicAnimation *settle = [CABasicAnimation animationWithKeyPath:@"position.y"];
    settle.fromValue = @(startY);
    settle.toValue = @(idleY);
    settle.duration = 0.28;
    settle.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.mascotContainer addAnimation:settle forKey:@"reset"];

    CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glow.fromValue = @(((CALayer *)self.pedestalGlowLayer.presentationLayer ?: self.pedestalGlowLayer).opacity);
    glow.toValue = @0.0;
    glow.duration = settle.duration;
    [self.pedestalGlowLayer addAnimation:glow forKey:@"resetGlow"];

    CABasicAnimation *auraFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    auraFade.fromValue = @(((CALayer *)self.auraLayer.presentationLayer ?: self.auraLayer).opacity);
    auraFade.toValue = @0.0;
    auraFade.duration = settle.duration;
    [self.auraLayer addAnimation:auraFade forKey:@"resetAura"];
}

- (void)prepareIdlePreviewWithMessage:(NSString *)message {
    [self layoutSubtreeIfNeeded];
    self.messageLayer.string = message.length > 0 ? message : @"Waiting for Claude Code";
    self.shadowLayer.transform = CATransform3DIdentity;
    self.shadowLayer.opacity = 0.18;
    self.pedestalGlowLayer.opacity = 0.0;
    self.auraLayer.opacity = 0.0;
    self.pulseRingLayer.opacity = 0.0;
    self.auraLayer.transform = CATransform3DIdentity;
    self.pulseRingLayer.transform = CATransform3DIdentity;
    [self setMascotCenterY:[self idleMascotCenterY]];
    [self setMascotHighlighted:NO animated:NO];
}

- (void)prepareJumpPreviewWithMessage:(NSString *)message {
    [self layoutSubtreeIfNeeded];
    self.messageLayer.string = message.length > 0 ? message : @"Claude finished, jump back in";
    self.shadowLayer.transform = CATransform3DMakeScale(0.78, 1.0, 1.0);
    self.shadowLayer.opacity = 0.08;
    self.pedestalGlowLayer.opacity = 0.95;
    self.auraLayer.opacity = 0.9;
    self.auraLayer.transform = CATransform3DMakeScale(1.16, 1.16, 1.0);
    self.pulseRingLayer.opacity = 0.78;
    self.pulseRingLayer.transform = CATransform3DMakeScale(1.08, 1.08, 1.0);
    [self setMascotCenterY:[self jumpMascotCenterY]];
    [self setMascotHighlighted:YES animated:NO];
}

- (void)updateMascotGeometry {
    self.auraLayer.frame = CGRectMake(4.0, -10.0, 84.0, 84.0);
    self.pulseRingLayer.frame = CGRectMake(-6.0, -20.0, 104.0, 104.0);
    self.mascotBodyLayer.frame = CGRectMake(12.0, 26.0, 68.0, 48.0);
    self.leftTabLayer.frame = CGRectMake(4.0, 34.0, 12.0, 30.0);
    self.rightTabLayer.frame = CGRectMake(76.0, 34.0, 12.0, 30.0);

    NSArray<NSNumber *> *legOffsets = @[@18.0, @34.0, @50.0, @66.0];
    [self.legLayers enumerateObjectsUsingBlock:^(CALayer * _Nonnull leg, NSUInteger index, BOOL * __unused _Nonnull stop) {
        leg.frame = CGRectMake(legOffsets[index].doubleValue, 2.0, 8.0, 24.0);
    }];

    self.eyeLayers[0].frame = CGRectMake(31.0, 50.0, 5.0, 5.0);
    self.eyeLayers[1].frame = CGRectMake(53.0, 50.0, 5.0, 5.0);
}

- (void)setMascotHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    NSColor *bodyColor = highlighted
        ? [NSColor colorWithRed:0.95 green:0.79 blue:0.28 alpha:1.0]
        : [NSColor colorWithRed:0.70 green:0.27 blue:0.12 alpha:1.0];
    NSColor *tabColor = highlighted
        ? [NSColor colorWithRed:0.92 green:0.68 blue:0.16 alpha:1.0]
        : [NSColor colorWithRed:0.61 green:0.23 blue:0.10 alpha:1.0];
    NSColor *legColor = highlighted
        ? [NSColor colorWithRed:0.96 green:0.74 blue:0.18 alpha:1.0]
        : [NSColor colorWithRed:0.66 green:0.25 blue:0.11 alpha:1.0];
    CGColorRef glowShadow = highlighted
        ? [[NSColor colorWithRed:1.0 green:0.86 blue:0.36 alpha:1.0] CGColor]
        : NSColor.blackColor.CGColor;

    [self setLayer:self.mascotBodyLayer backgroundColor:bodyColor animated:animated key:@"bodyColor"];
    [self setLayer:self.leftTabLayer backgroundColor:tabColor animated:animated key:@"leftTabColor"];
    [self setLayer:self.rightTabLayer backgroundColor:tabColor animated:animated key:@"rightTabColor"];

    for (NSUInteger index = 0; index < self.legLayers.count; index += 1) {
        CALayer *leg = self.legLayers[index];
        [self setLayer:leg backgroundColor:legColor animated:animated key:[NSString stringWithFormat:@"legColor%lu", (unsigned long)index]];
    }

    if (animated) {
        CABasicAnimation *shadowColor = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
        shadowColor.fromValue = (__bridge id _Nullable)((CALayer *)self.mascotBodyLayer.presentationLayer ?: self.mascotBodyLayer).shadowColor;
        shadowColor.toValue = (__bridge id)glowShadow;
        shadowColor.duration = 0.24;
        [self.mascotBodyLayer addAnimation:shadowColor forKey:@"bodyShadowColor"];

        CABasicAnimation *shadowOpacity = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        shadowOpacity.fromValue = @(((CALayer *)self.mascotBodyLayer.presentationLayer ?: self.mascotBodyLayer).shadowOpacity);
        shadowOpacity.toValue = highlighted ? @0.88 : @0.18;
        shadowOpacity.duration = 0.24;
        [self.mascotBodyLayer addAnimation:shadowOpacity forKey:@"bodyShadowOpacity"];
    }

    self.mascotBodyLayer.shadowColor = glowShadow;
    self.mascotBodyLayer.shadowOpacity = highlighted ? 0.88 : 0.18;
    self.mascotBodyLayer.shadowRadius = highlighted ? 18.0 : 8.0;
}

- (void)setLayer:(CALayer *)layer backgroundColor:(NSColor *)color animated:(BOOL)animated key:(NSString *)key {
    CGColorRef targetColor = color.CGColor;
    if (animated) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        animation.fromValue = (__bridge id _Nullable)((CALayer *)layer.presentationLayer ?: layer).backgroundColor;
        animation.toValue = (__bridge id)targetColor;
        animation.duration = 0.22;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [layer addAnimation:animation forKey:key];
    }
    layer.backgroundColor = targetColor;
}

- (CGFloat)idleMascotCenterY {
    return CGRectGetMaxY(self.pedestalLayer.frame) - 26.0;
}

- (CGFloat)waitingMascotCenterY {
    return CGRectGetMaxY(self.pedestalLayer.frame) + 2.0;
}

- (CGFloat)jumpMascotCenterY {
    return CGRectGetMaxY(self.pedestalLayer.frame) + 54.0;
}

- (CGFloat)currentMascotCenterY {
    CALayer *presentation = (CALayer *)self.mascotContainer.presentationLayer;
    return presentation ? presentation.position.y : self.mascotContainer.position.y;
}

- (void)setMascotCenterY:(CGFloat)centerY {
    self.mascotContainer.position = CGPointMake(NSMidX(self.bounds), centerY);
}

- (CGRect)currentMascotFrame {
    CALayer *presentation = (CALayer *)self.mascotContainer.presentationLayer;
    return presentation ? presentation.frame : self.mascotContainer.frame;
}

- (BOOL)isInteractivePoint:(NSPoint)point {
    CGRect mascotFrame = CGRectInset([self currentMascotFrame], -18.0, -18.0);
    CGRect pedestalFrame = CGRectInset(self.pedestalLayer.frame, -6.0, -4.0);
    return NSPointInRect(point, mascotFrame) || NSPointInRect(point, pedestalFrame);
}

- (NSView *)hitTest:(NSPoint)point {
    return [self isInteractivePoint:point] ? self : nil;
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (![self isInteractivePoint:point]) {
        [super mouseDown:event];
        return;
    }

    self.didDragWindow = NO;
    self.dragStartMouseLocation = NSEvent.mouseLocation;
    self.dragStartWindowOrigin = self.window.frame.origin;
}

- (void)mouseDragged:(NSEvent *)event {
    (void)event;

    if (!self.window) {
        return;
    }

    NSPoint currentMouseLocation = NSEvent.mouseLocation;
    CGFloat deltaX = currentMouseLocation.x - self.dragStartMouseLocation.x;
    CGFloat deltaY = currentMouseLocation.y - self.dragStartMouseLocation.y;
    if (fabs(deltaX) > 2.0 || fabs(deltaY) > 2.0) {
        self.didDragWindow = YES;
    }

    NSPoint newOrigin = NSMakePoint(self.dragStartWindowOrigin.x + deltaX, self.dragStartWindowOrigin.y + deltaY);
    [self.window setFrameOrigin:newOrigin];
}

- (void)mouseUp:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (!self.didDragWindow && [self isInteractivePoint:point] && self.onActivateRequested) {
        self.onActivateRequested();
        return;
    }

    [super mouseUp:event];
}

@end
