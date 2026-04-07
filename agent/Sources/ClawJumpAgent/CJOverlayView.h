#import <AppKit/AppKit.h>

typedef void (^CJOverlayActivateHandler)(void);

@interface CJOverlayView : NSView

@property (nonatomic, copy) CJOverlayActivateHandler onActivateRequested;

- (void)playJumpWithMessage:(NSString *)message;
- (void)resetToIdle;
- (void)prepareIdlePreviewWithMessage:(NSString *)message;
- (void)prepareJumpPreviewWithMessage:(NSString *)message;

@end
