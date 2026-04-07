#import "CJAppDelegate.h"

#import "CJEventServer.h"
#import "CJOverlayView.h"

static uint16_t const CJDefaultPort = 47653;
static CGFloat const CJOverlayWidth = 220.0;
static CGFloat const CJOverlayHeight = 320.0;
static NSString * const CJOverlayOffsetXDefaultsKey = @"ClawJumpOverlayOffsetX";
static NSString * const CJOverlayOffsetYDefaultsKey = @"ClawJumpOverlayOffsetY";

@interface CJAppDelegate () <CJEventServerDelegate>

@property (nonatomic, strong) NSWindow *overlayWindow;
@property (nonatomic, strong) CJOverlayView *overlayView;
@property (nonatomic, strong) CJEventServer *eventServer;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *lastStopTimestampBySession;
@property (nonatomic, copy) NSString *lastKnownTerminalSourceApp;
@property (nonatomic, copy) NSString *lastKnownTerminalBundleIdentifier;
@property (nonatomic, copy) NSString *lastKnownWorkingDirectory;
@property (nonatomic, copy) NSString *lastKnownTerminalTTY;
@property (nonatomic, copy) NSString *lastKnownTerminalSessionId;
@property (nonatomic, copy) NSString *displayedTerminalSourceApp;
@property (nonatomic, copy) NSString *displayedTerminalBundleIdentifier;
@property (nonatomic, copy) NSString *displayedWorkingDirectory;
@property (nonatomic, copy) NSString *displayedTerminalTTY;
@property (nonatomic, copy) NSString *displayedTerminalSessionId;
@property (nonatomic, assign) CGFloat overlayOffsetX;
@property (nonatomic, assign) CGFloat overlayOffsetY;
@property (nonatomic, assign) BOOL hasPersistedOverlayOffset;

@end

@implementation CJAppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastStopTimestampBySession = [NSMutableDictionary dictionary];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        if ([defaults objectForKey:CJOverlayOffsetXDefaultsKey] != nil &&
            [defaults objectForKey:CJOverlayOffsetYDefaultsKey] != nil) {
            _overlayOffsetX = [defaults doubleForKey:CJOverlayOffsetXDefaultsKey];
            _overlayOffsetY = [defaults doubleForKey:CJOverlayOffsetYDefaultsKey];
            _hasPersistedOverlayOffset = YES;
        }
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    NSApplication.sharedApplication.activationPolicy = NSApplicationActivationPolicyAccessory;

    [self installOverlayWindow];
    [self installStatusItem];

    self.eventServer = [[CJEventServer alloc] initWithPort:CJDefaultPort];
    self.eventServer.delegate = self;

    NSError *error = nil;
    if (![self.eventServer startWithError:&error]) {
        NSLog(@"Failed to start Claw Jump agent: %@", error.localizedDescription);
        [NSApp terminate:nil];
        return;
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(repositionOverlayWindow)
                                               name:NSApplicationDidChangeScreenParametersNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(overlayWindowDidMove:)
                                               name:NSWindowDidMoveNotification
                                             object:self.overlayWindow];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.eventServer stop];
}

- (void)eventServer:(CJEventServer *)server didReceiveEvent:(NSDictionary *)event {
    (void)server;

    NSString *eventName = event[@"event"];
    if (![eventName isKindOfClass:NSString.class]) {
        return;
    }

    if ([eventName isEqualToString:@"reset"]) {
        [self.overlayView resetToIdle];
        return;
    }

    if (([eventName isEqualToString:@"stop"] ||
         [eventName isEqualToString:@"notification"] ||
         [eventName isEqualToString:@"test"]) &&
        [self shouldDisplayEvent:event]) {
        [self cacheTerminalContextFromEvent:event];
        [self cacheDisplayedFocusContextFromEvent:event];
        NSString *message = [self displayMessageForEvent:event];
        NSString *terminalTTY = [event[@"terminalTTY"] isKindOfClass:NSString.class] ? event[@"terminalTTY"] : @"<none>";
        NSLog(@"Claw Jump received %@ event: %@ (tty=%@)", eventName, message, terminalTTY);
        [self repositionOverlayWindow];
        [self.overlayWindow orderFrontRegardless];
        [self.overlayView playJumpWithMessage:message];
    }
}

- (void)installOverlayWindow {
    self.overlayView = [[CJOverlayView alloc] initWithFrame:NSMakeRect(0, 0, CJOverlayWidth, CJOverlayHeight)];

    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, CJOverlayWidth, CJOverlayHeight)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.backgroundColor = NSColor.clearColor;
    window.opaque = NO;
    window.hasShadow = NO;
    window.level = NSStatusWindowLevel;
    window.ignoresMouseEvents = NO;
    window.hidesOnDeactivate = NO;
    window.collectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary |
        NSWindowCollectionBehaviorStationary |
        NSWindowCollectionBehaviorIgnoresCycle;
    window.contentView = self.overlayView;
    self.overlayWindow = window;

    __weak typeof(self) weakSelf = self;
    self.overlayView.onActivateRequested = ^{
        [weakSelf focusClaudeTerminal];
    };

    [self repositionOverlayWindow];
    [self.overlayWindow orderFrontRegardless];
}

- (void)installStatusItem {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"CJ";
    self.statusItem.button.toolTip = @"Claw Jump";

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Claw Jump"];
    [menu addItemWithTitle:@"Test Jump" action:@selector(testJump) keyEquivalent:@"t"];
    [menu addItemWithTitle:@"Focus Claude Terminal" action:@selector(focusClaudeTerminal) keyEquivalent:@"f"];
    [menu addItemWithTitle:@"Reset" action:@selector(resetOverlay) keyEquivalent:@"r"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit Claw Jump" action:@selector(quitApp) keyEquivalent:@"q"];
    self.statusItem.menu = menu;
}

- (void)repositionOverlayWindow {
    NSScreen *screen = self.overlayWindow.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (!screen) {
        return;
    }

    [self.overlayWindow setFrameOrigin:[self overlayOriginForScreen:screen]];
}

- (void)overlayWindowDidMove:(NSNotification *)notification {
    (void)notification;

    NSScreen *screen = self.overlayWindow.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (!screen) {
        return;
    }

    NSPoint defaultOrigin = [self defaultOverlayOriginForScreen:screen];
    NSPoint currentOrigin = self.overlayWindow.frame.origin;
    self.overlayOffsetX = currentOrigin.x - defaultOrigin.x;
    self.overlayOffsetY = currentOrigin.y - defaultOrigin.y;
    self.hasPersistedOverlayOffset = YES;

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:self.overlayOffsetX forKey:CJOverlayOffsetXDefaultsKey];
    [defaults setDouble:self.overlayOffsetY forKey:CJOverlayOffsetYDefaultsKey];
}

- (NSPoint)defaultOverlayOriginForScreen:(NSScreen *)screen {
    NSRect visibleFrame = screen.visibleFrame;
    CGFloat originX = NSMaxX(visibleFrame) - CJOverlayWidth - 24.0;
    CGFloat originY = NSMinY(visibleFrame) + 6.0;
    return NSMakePoint(originX, originY);
}

- (NSPoint)overlayOriginForScreen:(NSScreen *)screen {
    NSRect visibleFrame = screen.visibleFrame;
    NSPoint origin = [self defaultOverlayOriginForScreen:screen];
    if (self.hasPersistedOverlayOffset) {
        origin.x += self.overlayOffsetX;
        origin.y += self.overlayOffsetY;
    }

    CGFloat minX = NSMinX(visibleFrame);
    CGFloat maxX = NSMaxX(visibleFrame) - CJOverlayWidth;
    CGFloat minY = NSMinY(visibleFrame);
    CGFloat maxY = NSMaxY(visibleFrame) - CJOverlayHeight;

    origin.x = MIN(MAX(origin.x, minX), maxX);
    origin.y = MIN(MAX(origin.y, minY), maxY);
    return origin;
}

- (BOOL)shouldDisplayEvent:(NSDictionary *)event {
    NSString *sessionId = [event[@"sessionId"] isKindOfClass:NSString.class] ? event[@"sessionId"] : nil;
    NSString *eventName = event[@"event"];
    if (sessionId.length == 0) {
        return YES;
    }

    NSTimeInterval cooldown = [eventName isEqualToString:@"notification"] ? 2.0 : 8.0;
    NSDate *now = NSDate.date;
    NSString *cooldownKey = [NSString stringWithFormat:@"%@:%@", eventName ?: @"event", sessionId];
    NSDate *lastTimestamp = self.lastStopTimestampBySession[cooldownKey];
    if (lastTimestamp && [now timeIntervalSinceDate:lastTimestamp] < cooldown) {
        return NO;
    }

    self.lastStopTimestampBySession[cooldownKey] = now;
    return YES;
}

- (NSString *)displayMessageForEvent:(NSDictionary *)event {
    NSString *eventName = [event[@"event"] isKindOfClass:NSString.class] ? event[@"event"] : @"";
    NSString *message = [event[@"message"] isKindOfClass:NSString.class] ? event[@"message"] : nil;
    NSString *cwd = [event[@"cwd"] isKindOfClass:NSString.class] ? event[@"cwd"] : nil;

    if ([eventName isEqualToString:@"notification"] && message.length > 0) {
        return [self shortenedMessage:message maxLength:56];
    }

    if ([eventName isEqualToString:@"test"]) {
        return @"Test jump";
    }

    if (cwd.length > 0) {
        return [self shortenedMessage:[NSString stringWithFormat:@"Claude finished in %@", cwd] maxLength:56];
    }

    return @"Claude Code is ready";
}

- (void)cacheTerminalContextFromEvent:(NSDictionary *)event {
    NSString *sourceApp = [event[@"sourceApp"] isKindOfClass:NSString.class] ? event[@"sourceApp"] : nil;
    NSString *cwd = [event[@"cwd"] isKindOfClass:NSString.class] ? event[@"cwd"] : nil;
    NSString *terminalTTY = [event[@"terminalTTY"] isKindOfClass:NSString.class] ? event[@"terminalTTY"] : nil;
    NSString *terminalSessionId = [event[@"terminalSessionId"] isKindOfClass:NSString.class] ? event[@"terminalSessionId"] : nil;

    if (sourceApp.length > 0) {
        self.lastKnownTerminalSourceApp = sourceApp;
        NSString *bundleIdentifier = [self bundleIdentifierForTerminalSourceApp:sourceApp];
        if (bundleIdentifier.length > 0) {
            self.lastKnownTerminalBundleIdentifier = bundleIdentifier;
        }
    }

    if (cwd.length > 0) {
        self.lastKnownWorkingDirectory = cwd;
    }

    if (terminalTTY.length > 0) {
        self.lastKnownTerminalTTY = terminalTTY;
    }

    if (terminalSessionId.length > 0) {
        self.lastKnownTerminalSessionId = terminalSessionId;
    }
}

- (void)cacheDisplayedFocusContextFromEvent:(NSDictionary *)event {
    NSString *sourceApp = [event[@"sourceApp"] isKindOfClass:NSString.class] ? event[@"sourceApp"] : nil;
    NSString *cwd = [event[@"cwd"] isKindOfClass:NSString.class] ? event[@"cwd"] : nil;
    NSString *terminalTTY = [event[@"terminalTTY"] isKindOfClass:NSString.class] ? event[@"terminalTTY"] : nil;
    NSString *terminalSessionId = [event[@"terminalSessionId"] isKindOfClass:NSString.class] ? event[@"terminalSessionId"] : nil;

    self.displayedTerminalSourceApp = sourceApp;
    self.displayedWorkingDirectory = cwd;
    self.displayedTerminalTTY = terminalTTY;
    self.displayedTerminalSessionId = terminalSessionId;
    self.displayedTerminalBundleIdentifier = [self bundleIdentifierForTerminalSourceApp:sourceApp];
}

- (NSString *)bundleIdentifierForTerminalSourceApp:(NSString *)sourceApp {
    NSString *lowercased = sourceApp.lowercaseString;
    if ([lowercased containsString:@"iterm"]) {
        return @"com.googlecode.iterm2";
    }
    if ([lowercased containsString:@"apple_terminal"] || [lowercased isEqualToString:@"terminal"]) {
        return @"com.apple.Terminal";
    }
    if ([lowercased containsString:@"wezterm"]) {
        return @"com.github.wez.wezterm";
    }
    if ([lowercased containsString:@"warp"]) {
        return @"dev.warp.Warp-Stable";
    }
    if ([lowercased containsString:@"ghostty"]) {
        return @"com.mitchellh.ghostty";
    }
    if ([lowercased containsString:@"kitty"]) {
        return @"net.kovidgoyal.kitty";
    }
    if ([lowercased containsString:@"vscode"]) {
        return @"com.microsoft.VSCode";
    }
    if ([lowercased containsString:@"cursor"]) {
        return @"com.todesktop.230313mzl4w4u92";
    }
    return nil;
}

- (BOOL)activateRunningApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    NSArray<NSRunningApplication *> *runningApps =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    NSRunningApplication *application = runningApps.firstObject;
    if (!application) {
        return NO;
    }

    return [application activateWithOptions:NSApplicationActivateAllWindows];
}

- (BOOL)launchApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    NSURL *applicationURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleIdentifier];
    if (!applicationURL) {
        return NO;
    }

    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:applicationURL configuration:configuration completionHandler:nil];
    return YES;
}

- (BOOL)activateViaAppleScriptForTerminalSourceApp:(NSString *)sourceApp {
    if (sourceApp.length == 0) {
        return NO;
    }

    NSString *lowercased = sourceApp.lowercaseString;
    NSString *applicationName = nil;
    if ([lowercased containsString:@"iterm"]) {
        applicationName = @"iTerm";
    } else if ([lowercased containsString:@"apple_terminal"] || [lowercased isEqualToString:@"terminal"]) {
        applicationName = @"Terminal";
    } else if ([lowercased containsString:@"wezterm"]) {
        applicationName = @"WezTerm";
    } else if ([lowercased containsString:@"warp"]) {
        applicationName = @"Warp";
    } else if ([lowercased containsString:@"ghostty"]) {
        applicationName = @"Ghostty";
    } else if ([lowercased containsString:@"kitty"]) {
        applicationName = @"kitty";
    }

    if (applicationName.length == 0) {
        return NO;
    }

    NSString *scriptSource = [NSString stringWithFormat:@"tell application \"%@\" to activate", applicationName];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorInfo = nil;
    [script executeAndReturnError:&errorInfo];
    return errorInfo == nil;
}

- (BOOL)activateSpecificTerminalSessionIfPossible {
    if (self.displayedTerminalTTY.length == 0 || self.displayedTerminalSourceApp.length == 0) {
        return NO;
    }

    NSString *lowercased = self.displayedTerminalSourceApp.lowercaseString;
    if ([lowercased containsString:@"iterm"]) {
        return [self activateITermSessionWithTTY:self.displayedTerminalTTY];
    }

    if ([lowercased containsString:@"apple_terminal"] || [lowercased isEqualToString:@"terminal"]) {
        return [self activateTerminalTabWithTTY:self.displayedTerminalTTY];
    }

    return NO;
}

- (BOOL)activateITermSessionWithTTY:(NSString *)tty {
    NSString *escapedTTY = [tty stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSArray<NSString *> *applicationNames = @[@"iTerm", @"iTerm2"];
    for (NSString *applicationName in applicationNames) {
        NSString *scriptSource =
            [NSString stringWithFormat:
             @"tell application \"%@\"\n"
             @"  repeat with theWindow in windows\n"
             @"    repeat with theTab in tabs of theWindow\n"
             @"      repeat with theSession in sessions of theTab\n"
             @"        if tty of theSession is \"%@\" then\n"
             @"          tell application \"%@\" to activate\n"
             @"          tell theWindow to set current tab to theTab\n"
             @"          tell theWindow to set index to 1\n"
             @"          select theSession\n"
             @"          return true\n"
             @"        end if\n"
             @"      end repeat\n"
             @"    end repeat\n"
             @"  end repeat\n"
             @"end tell\n"
             @"return false",
             applicationName,
             escapedTTY,
             applicationName];
        if ([self executeAppleScriptBoolean:scriptSource]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)activateTerminalTabWithTTY:(NSString *)tty {
    NSString *escapedTTY = [tty stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *scriptSource =
        [NSString stringWithFormat:
         @"tell application \"Terminal\"\n"
         @"  repeat with theWindow in windows\n"
         @"    repeat with theTab in tabs of theWindow\n"
         @"      if tty of theTab is \"%@\" then\n"
         @"        activate\n"
         @"        set selected tab of theWindow to theTab\n"
         @"        set index of theWindow to 1\n"
         @"        return true\n"
         @"      end if\n"
         @"    end repeat\n"
         @"  end repeat\n"
         @"end tell\n"
         @"return false",
         escapedTTY];
    return [self executeAppleScriptBoolean:scriptSource];
}

- (BOOL)executeAppleScriptBoolean:(NSString *)scriptSource {
    if (scriptSource.length == 0) {
        return NO;
    }

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *result = [script executeAndReturnError:&errorInfo];
    if (errorInfo != nil || result == nil) {
        return NO;
    }

    if (result.descriptorType == typeBoolean) {
        return result.booleanValue;
    }

    NSString *stringValue = result.stringValue.lowercaseString;
    return [stringValue isEqualToString:@"true"];
}

- (NSString *)shortenedMessage:(NSString *)message maxLength:(NSUInteger)maxLength {
    if (message.length <= maxLength) {
        return message;
    }

    NSUInteger suffixLength = 3;
    if (maxLength <= suffixLength) {
        return [message substringToIndex:maxLength];
    }

    return [[message substringToIndex:maxLength - suffixLength] stringByAppendingString:@"..."];
}

- (void)testJump {
    [self repositionOverlayWindow];
    [self.overlayWindow orderFrontRegardless];
    [self.overlayView playJumpWithMessage:@"Test jump"];
}

- (void)resetOverlay {
    [self.overlayView resetToIdle];
}

- (void)focusClaudeTerminal {
    [self.overlayView resetToIdle];
    NSLog(@"Claw Jump focus requested: sourceApp=%@ tty=%@ cwd=%@",
          self.displayedTerminalSourceApp ?: @"<none>",
          self.displayedTerminalTTY ?: @"<none>",
          self.displayedWorkingDirectory ?: @"<none>");

    BOOL focused = NO;

    focused = [self activateSpecificTerminalSessionIfPossible];

    if (!focused && self.displayedTerminalBundleIdentifier.length > 0) {
        focused = [self activateRunningApplicationWithBundleIdentifier:self.displayedTerminalBundleIdentifier];
        if (!focused) {
            focused = [self launchApplicationWithBundleIdentifier:self.displayedTerminalBundleIdentifier];
        }
    }

    if (!focused && self.displayedTerminalSourceApp.length > 0) {
        NSString *bundleIdentifier = [self bundleIdentifierForTerminalSourceApp:self.displayedTerminalSourceApp];
        if (bundleIdentifier.length > 0) {
            focused = [self activateRunningApplicationWithBundleIdentifier:bundleIdentifier];
            if (!focused) {
                focused = [self launchApplicationWithBundleIdentifier:bundleIdentifier];
            }
        }
    }

    if (!focused && self.displayedTerminalSourceApp.length > 0) {
        focused = [self activateViaAppleScriptForTerminalSourceApp:self.displayedTerminalSourceApp];
    }

    if (!focused && self.displayedWorkingDirectory.length > 0) {
        NSURL *directoryURL = [NSURL fileURLWithPath:self.displayedWorkingDirectory isDirectory:YES];
        focused = [NSWorkspace.sharedWorkspace openURL:directoryURL];
    }

    if (!focused) {
        NSLog(@"Claw Jump could not find a tracked terminal to focus.");
    }
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end
