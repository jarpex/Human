#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraView : NSView
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) NSTextField *statusLabel;
@end

@implementation CameraView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
    }
    return self;
}

- (CALayer *)makeBackingLayer {
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layer];
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    layer.backgroundColor = [NSColor blackColor].CGColor;
    return layer;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (void)showStatus:(NSString *)text {
    if (!self.statusLabel) {
        self.statusLabel = [NSTextField labelWithString:text];
        self.statusLabel.alignment = NSTextAlignmentCenter;
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
        self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.statusLabel];
        [NSLayoutConstraint activateConstraints:@[
            [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    } else {
        self.statusLabel.stringValue = text;
    }
}

- (void)hideStatus {
    [self.statusLabel removeFromSuperview];
    self.statusLabel = nil;
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) CameraView *cameraView;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *currentDevice;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    NSRect frame = NSMakeRect(0, 0, 480, 360);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"👩🏻 Human";
    self.window.level = NSFloatingWindowLevel;
    self.window.delegate = self;
    [self.window setReleasedWhenClosed:NO];
    [self.window setMovableByWindowBackground:YES];
    [self.window setContentMinSize:NSMakeSize(200, 150)];
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary;
    [self.window center];

    self.cameraView = [[CameraView alloc] initWithFrame:self.window.contentView.bounds];
    self.window.contentView = self.cameraView;

    [self setupMenu];
    [self startCamera];

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)setupMenu {
    NSMenu *menubar = [NSMenu new];
    NSMenuItem *appMenuItem = [NSMenuItem new];
    [menubar addItem:appMenuItem];
    NSMenu *appMenu = [NSMenu new];
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"]];
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit Human" action:@selector(terminate:) keyEquivalent:@"q"]];
    appMenuItem.submenu = appMenu;
    NSApp.mainMenu = menubar;
}

- (void)startCamera {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceWasConnected:)
                                                 name:AVCaptureDeviceWasConnectedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceWasDisconnected:)
                                                 name:AVCaptureDeviceWasDisconnectedNotification
                                               object:nil];

    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
            [self setupCaptureSession];
            break;
        case AVAuthorizationStatusNotDetermined: {
            [self.cameraView showStatus:@"Requesting camera access..."];
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [self setupCaptureSession];
                    } else {
                        [self.cameraView showStatus:@"Camera access denied"];
                    }
                });
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            [self.cameraView showStatus:@"Camera access restricted. Enable in System Settings."];
            break;
    }
}

- (void)setupCaptureSession {
    [self.cameraView hideStatus];

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:@[
                AVCaptureDeviceTypeBuiltInWideAngleCamera,
                AVCaptureDeviceTypeExternal
            ]
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionUnspecified];
        device = discovery.devices.firstObject;
    }

    if (!device) {
        [self.cameraView showStatus:@"No camera found"];
        return;
    }

    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        [self.cameraView showStatus:@"Unable to access camera"];
        return;
    }

    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }

    self.currentDevice = device;

    self.cameraView.previewLayer.session = self.session;

    AVCaptureConnection *conn = self.cameraView.previewLayer.connection;
    if (conn.supportsVideoMirroring) {
        conn.automaticallyAdjustsVideoMirroring = NO;
        conn.videoMirrored = YES;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.session startRunning];
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)deviceWasDisconnected:(NSNotification *)notification {
    AVCaptureDevice *disconnectedDevice = notification.object;
    if (!self.currentDevice || ![disconnectedDevice isEqual:self.currentDevice]) {
        return;
    }

    if (self.session) {
        AVCaptureSession *oldSession = self.session;
        self.session = nil;
        self.currentDevice = nil;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [oldSession stopRunning];
        });
    }
}

- (void)deviceWasConnected:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.session || !self.session.isRunning) {
            [self setupCaptureSession];
        }
    });
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.session) {
        AVCaptureSession *session = self.session;
        self.session = nil;
        self.currentDevice = nil;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [session stopRunning];
        });
    }
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
