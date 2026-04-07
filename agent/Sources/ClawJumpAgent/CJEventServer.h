#import <Foundation/Foundation.h>

@class CJEventServer;

@protocol CJEventServerDelegate <NSObject>
- (void)eventServer:(CJEventServer *)server didReceiveEvent:(NSDictionary *)event;
@end

@interface CJEventServer : NSObject

@property (nonatomic, weak) id<CJEventServerDelegate> delegate;
@property (nonatomic, readonly) uint16_t port;

- (instancetype)initWithPort:(uint16_t)port NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)startWithError:(NSError * _Nullable * _Nullable)error;
- (void)stop;

@end
