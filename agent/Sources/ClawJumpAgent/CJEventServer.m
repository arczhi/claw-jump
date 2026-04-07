#import "CJEventServer.h"

#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <unistd.h>

@interface CJEventServer ()

@property (nonatomic, assign) int listenSocket;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong) dispatch_source_t acceptSource;

@end

@implementation CJEventServer

- (instancetype)initWithPort:(uint16_t)port {
    self = [super init];
    if (self) {
        _port = port;
        _listenSocket = -1;
        _serverQueue = dispatch_queue_create("com.clawjump.agent.server", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (BOOL)startWithError:(NSError * _Nullable __autoreleasing *)error {
    int socketFD = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFD < 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return NO;
    }

    int reuse = 1;
    setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    int currentFlags = fcntl(socketFD, F_GETFL, 0);
    fcntl(socketFD, F_SETFL, currentFlags | O_NONBLOCK);

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_port = htons(self.port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(socketFD, (struct sockaddr *)&address, sizeof(address)) < 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        close(socketFD);
        return NO;
    }

    if (listen(socketFD, 16) < 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        close(socketFD);
        return NO;
    }

    self.listenSocket = socketFD;

    dispatch_source_t acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)socketFD, 0, self.serverQueue);
    self.acceptSource = acceptSource;

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(acceptSource, ^{
        [weakSelf acceptPendingConnections];
    });
    dispatch_source_set_cancel_handler(acceptSource, ^{
        if (weakSelf.listenSocket >= 0) {
            close(weakSelf.listenSocket);
            weakSelf.listenSocket = -1;
        }
    });

    dispatch_resume(acceptSource);
    return YES;
}

- (void)stop {
    if (self.acceptSource) {
        dispatch_source_cancel(self.acceptSource);
        self.acceptSource = nil;
    } else if (self.listenSocket >= 0) {
        close(self.listenSocket);
        self.listenSocket = -1;
    }
}

- (void)acceptPendingConnections {
    while (YES) {
        int clientFD = accept(self.listenSocket, NULL, NULL);
        if (clientFD < 0) {
            if (errno == EWOULDBLOCK || errno == EAGAIN) {
                break;
            }
            return;
        }

        dispatch_async(self.serverQueue, ^{
            [self handleClient:clientFD];
        });
    }
}

- (void)handleClient:(int)clientFD {
    @autoreleasepool {
        NSMutableData *requestData = [NSMutableData data];
        NSMutableData *bodyData = nil;
        NSString *requestLine = @"";
        NSUInteger expectedBodyLength = 0;

        char buffer[4096];
        ssize_t bytesRead = 0;

        while ((bytesRead = read(clientFD, buffer, sizeof(buffer))) > 0) {
            [requestData appendBytes:buffer length:(NSUInteger)bytesRead];

            NSRange separatorRange = [requestData rangeOfData:[NSData dataWithBytes:"\r\n\r\n" length:4]
                                                      options:0
                                                        range:NSMakeRange(0, requestData.length)];
            if (separatorRange.location == NSNotFound) {
                continue;
            }

            NSData *headerData = [requestData subdataWithRange:NSMakeRange(0, separatorRange.location)];
            NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
            NSArray<NSString *> *lines = [headerString componentsSeparatedByString:@"\r\n"];
            requestLine = lines.firstObject ?: @"";

            for (NSString *line in lines) {
                NSString *lower = line.lowercaseString;
                if ([lower hasPrefix:@"content-length:"]) {
                    NSString *value = [[line componentsSeparatedByString:@":"] lastObject];
                    expectedBodyLength = (NSUInteger)value.integerValue;
                    break;
                }
            }

            NSUInteger bodyOffset = separatorRange.location + separatorRange.length;
            NSUInteger availableBodyLength = requestData.length - bodyOffset;
            if (availableBodyLength >= expectedBodyLength) {
                bodyData = [[requestData subdataWithRange:NSMakeRange(bodyOffset, expectedBodyLength)] mutableCopy];
                break;
            }
        }

        if ([requestLine hasPrefix:@"GET /healthz"]) {
            [self respondWithStatus:@"200 OK" body:@"{\"ok\":true}" toClient:clientFD];
            close(clientFD);
            return;
        }

        if (bodyData.length == 0 || ![requestLine hasPrefix:@"POST /event"]) {
            [self respondWithStatus:@"404 Not Found" body:@"{\"error\":\"not_found\"}" toClient:clientFD];
            close(clientFD);
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&jsonError];
        if (![payload isKindOfClass:NSDictionary.class] || jsonError) {
            [self respondWithStatus:@"400 Bad Request" body:@"{\"error\":\"invalid_json\"}" toClient:clientFD];
            close(clientFD);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate eventServer:self didReceiveEvent:payload];
        });

        [self respondWithStatus:@"202 Accepted" body:@"{\"accepted\":true}" toClient:clientFD];
        close(clientFD);
    }
}

- (void)respondWithStatus:(NSString *)status body:(NSString *)body toClient:(int)clientFD {
    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *response = [NSString stringWithFormat:
                          @"HTTP/1.1 %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n%@",
                          status,
                          (unsigned long)bodyData.length,
                          body];
    NSData *responseData = [response dataUsingEncoding:NSUTF8StringEncoding];
    write(clientFD, responseData.bytes, responseData.length);
}

@end
