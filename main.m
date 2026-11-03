#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraView : NSView
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) NSTextField *statusLabel;
@end

@implementation CameraView

- (void)layout {
    [super layout];
    self.previewLayer.frame = self.bounds;
}

- (void)setPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    if (_previewLayer) {
        [_previewLayer removeFromSuperlayer];
    }
    _previewLayer = previewLayer;
    if (_previewLayer) {
        _previewLayer.frame = self.bounds;
        [self.layer addSublayer:_previewLayer];
    }
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
    [self.window setContentMinSize:NSMakeSize(200, 150)];
    [self.window center];

    self.cameraView = [[CameraView alloc] initWithFrame:self.window.contentView.bounds];
    self.cameraView.wantsLayer = YES;
    self.cameraView.layer.backgroundColor = [NSColor blackColor].CGColor;
    self.window.contentView = self.cameraView;

    [self setupMenu];
    [self setupAppIcon];
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

- (void)setupAppIcon {
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
    if (!iconPath) {
        NSArray *candidates = @[@"AppIcon.icns", @"Icons/AppIcon.png"];
        for (NSString *cand in candidates) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:cand]) {
                iconPath = cand;
                break;
            }
        }
    }
    if (iconPath) {
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (icon) {
            [NSApp setApplicationIconImage:icon];
        }
    }
}

- (void)startCamera {
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

    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    AVCaptureConnection *conn = previewLayer.connection;
    if (conn.supportsVideoMirroring) {
        conn.automaticallyAdjustsVideoMirroring = NO;
        conn.videoMirrored = YES;
    }

    self.cameraView.previewLayer = previewLayer;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.session startRunning];
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [self.session stopRunning];
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
