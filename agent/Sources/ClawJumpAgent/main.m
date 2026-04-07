#import <AppKit/AppKit.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <unistd.h>

#import "CJAppDelegate.h"
#import "CJOverlayView.h"

static uint16_t const CJDefaultPort = 47653;
static CGFloat const CJSnapshotWidth = 220.0;
static CGFloat const CJSnapshotHeight = 320.0;

static void PrintHelp(void) {
    printf(
        "Claw Jump Agent\n\n"
        "Usage:\n"
        "  claw-jump-agent             Start the background desktop agent\n"
        "  claw-jump-agent emit stop   Send a local stop event to the agent\n"
        "  claw-jump-agent emit reset  Send a local reset event to the agent\n"
        "  claw-jump-agent emit test   Send a local test event to the agent\n"
        "  claw-jump-agent snapshot idle <path>  Render an idle preview PNG\n"
        "  claw-jump-agent snapshot jump <path>  Render a glowing jump preview PNG\n"
    );
}

static int EmitEvent(NSString *eventName) {
    NSDictionary *payload = @{
        @"event": eventName,
        @"sourceApp": @"cli"
    };

    NSError *requestError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&requestError];
    if (!body) {
        fprintf(stderr, "Failed to encode payload: %s\n", requestError.localizedDescription.UTF8String);
        return EXIT_FAILURE;
    }

    int socketFD = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFD < 0) {
        fprintf(stderr, "Failed to create socket.\n");
        return EXIT_FAILURE;
    }

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_port = htons(CJDefaultPort);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (connect(socketFD, (struct sockaddr *)&address, sizeof(address)) != 0) {
        fprintf(stderr, "Failed to connect to the Claw Jump agent.\n");
        close(socketFD);
        return EXIT_FAILURE;
    }

    NSString *requestString = [NSString stringWithFormat:
                               @"POST /event HTTP/1.1\r\n"
                               @"Host: 127.0.0.1:%d\r\n"
                               @"Content-Type: application/json\r\n"
                               @"Content-Length: %lu\r\n"
                               @"Connection: close\r\n"
                               @"\r\n",
                               CJDefaultPort,
                               (unsigned long)body.length];
    NSMutableData *requestData = [[requestString dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [requestData appendData:body];

    ssize_t sentBytes = write(socketFD, requestData.bytes, requestData.length);
    if (sentBytes < 0 || (NSUInteger)sentBytes != requestData.length) {
        fprintf(stderr, "Failed to send the event payload.\n");
        close(socketFD);
        return EXIT_FAILURE;
    }

    char responseBuffer[512];
    ssize_t responseLength = read(socketFD, responseBuffer, sizeof(responseBuffer) - 1);
    close(socketFD);

    if (responseLength <= 0) {
        fprintf(stderr, "The agent closed the connection before replying.\n");
        return EXIT_FAILURE;
    }

    responseBuffer[responseLength] = '\0';
    NSString *responseString = [NSString stringWithUTF8String:responseBuffer];
    if (![responseString hasPrefix:@"HTTP/1.1 2"]) {
        fprintf(stderr, "The agent returned an unexpected response.\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

static int RenderSnapshot(NSString *state, NSString *outputPath) {
    if (outputPath.length == 0) {
        fprintf(stderr, "Missing output path for snapshot.\n");
        return EXIT_FAILURE;
    }

    if (!NSApplicationLoad()) {
        fprintf(stderr, "Failed to initialize AppKit for snapshot rendering.\n");
        return EXIT_FAILURE;
    }

    CJOverlayView *view = [[CJOverlayView alloc] initWithFrame:NSMakeRect(0, 0, CJSnapshotWidth, CJSnapshotHeight)];
    [view layoutSubtreeIfNeeded];

    if ([state isEqualToString:@"jump"]) {
        [view prepareJumpPreviewWithMessage:@"Claude is ready for you"];
    } else {
        [view prepareIdlePreviewWithMessage:@"Waiting for Claude Code"];
    }
    [view displayIfNeeded];

    NSInteger scale = 2;
    NSInteger pixelsWide = (NSInteger)(CJSnapshotWidth * scale);
    NSInteger pixelsHigh = (NSInteger)(CJSnapshotHeight * scale);
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:pixelsWide
                      pixelsHigh:pixelsHigh
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0];
    if (!bitmap) {
        fprintf(stderr, "Failed to allocate bitmap for snapshot.\n");
        return EXIT_FAILURE;
    }

    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:graphicsContext];
    CGContextRef context = graphicsContext.CGContext;
    CGContextClearRect(context, CGRectMake(0, 0, pixelsWide, pixelsHigh));
    CGContextScaleCTM(context, scale, scale);
    [view.layer renderInContext:context];
    [NSGraphicsContext restoreGraphicsState];

    NSData *pngData = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!pngData) {
        fprintf(stderr, "Failed to encode snapshot PNG.\n");
        return EXIT_FAILURE;
    }

    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
    NSError *directoryError = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:outputURL.URLByDeletingLastPathComponent
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&directoryError];
    if (directoryError) {
        fprintf(stderr, "Failed to create snapshot directory: %s\n", directoryError.localizedDescription.UTF8String);
        return EXIT_FAILURE;
    }

    NSError *writeError = nil;
    if (![pngData writeToURL:outputURL options:NSDataWritingAtomic error:&writeError]) {
        fprintf(stderr, "Failed to write snapshot: %s\n", writeError.localizedDescription.UTF8String);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc >= 2) {
            NSString *mode = [NSString stringWithUTF8String:argv[1]];
            if ([mode isEqualToString:@"emit"]) {
                if (argc < 3) {
                    PrintHelp();
                    return EXIT_FAILURE;
                }
                return EmitEvent([NSString stringWithUTF8String:argv[2]]);
            }

            if ([mode isEqualToString:@"snapshot"]) {
                if (argc < 4) {
                    PrintHelp();
                    return EXIT_FAILURE;
                }
                return RenderSnapshot([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]]);
            }

            if ([mode isEqualToString:@"--help"] || [mode isEqualToString:@"-h"] || [mode isEqualToString:@"help"]) {
                PrintHelp();
                return EXIT_SUCCESS;
            }
        }

        NSApplication *application = NSApplication.sharedApplication;
        CJAppDelegate *delegate = [CJAppDelegate new];
        application.delegate = delegate;
        [application run];
    }

    return EXIT_SUCCESS;
}
