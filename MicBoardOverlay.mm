#import "MicBoardOverlay.h"
#import <UIKit/UIKit.h>

@interface MicBoardOverlay ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) NSArray<NSString*> *soundPaths;
@property (nonatomic, strong) NSArray<NSString*> *soundNames;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) UIButton *dragHandle;
@end

@implementation MicBoardOverlay

+ (void)showOverlay {
    static MicBoardOverlay *instance = nil;
    if (instance) return;
    instance = [[MicBoardOverlay alloc] init];
    [instance setupOverlay];
}

- (void)setupOverlay {
    // Create always-on-top window
    self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 100;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.userInteractionEnabled = YES;
    self.overlayWindow.hidden = NO;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                self.overlayWindow.windowScene = (UIWindowScene*)scene;
                break;
            }
        }
    }
    
    self.overlayWindow.rootViewController = self;
    [self.overlayWindow makeKeyAndVisible];
    self.isEnabled = YES;
    self.isExpanded = NO;
    
    // Load sounds from Documents/MicBoard/
    NSString *soundDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/MicBoard/Sounds"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:soundDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSArray *files = [fm contentsOfDirectoryAtPath:soundDir error:nil];
    NSMutableArray *paths = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];
    
    for (NSString *file in files) {
        if ([file hasSuffix:@".mp3"] || [file hasSuffix:@".wav"] || [file hasSuffix:@".m4a"]) {
            [paths addObject:[soundDir stringByAppendingPathComponent:file]];
            NSString *name = [file stringByDeletingPathExtension];
            if (name.length > 10) name = [name substringToIndex:10];
            [names addObject:name];
        }
    }
    
    // Add default sounds if none found
    if (paths.count == 0) {
        [names addObjectsFromArray:@[@"Bruh", @"Oof", @"Wow", @"Lol", @"GG"]];
        [paths addObjectsFromArray:@[@"", @"", @"", @"", @""]]; // placeholders
    }
    
    self.soundPaths = paths;
    self.soundNames = names;
    
    [self buildUI];
}

- (void)buildUI {
    // Floating pill button
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.frame = CGRectMake(20, 200, 52, 52);
    self.toggleButton.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.95];
    self.toggleButton.layer.cornerRadius = 26;
    self.toggleButton.layer.shadowColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.5].CGColor;
    self.toggleButton.layer.shadowOffset = CGSizeZero;
    self.toggleButton.layer.shadowRadius = 8;
    self.toggleButton.layer.shadowOpacity = 1;
    [self.toggleButton setTitle:@"🎵" forState:UIControlStateNormal];
    self.toggleButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [self.toggleButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    
    // Make draggable
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.toggleButton addGestureRecognizer:pan];
    
    [self.view addSubview:self.toggleButton];
    
    // Sound panel
    CGFloat panelW = 280;
    CGFloat panelH = 400;
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(80, 180, panelW, panelH)];
    self.panel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:0.97];
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.3].CGColor;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.panel.layer.shadowOffset = CGSizeMake(0, 8);
    self.panel.layer.shadowRadius = 20;
    self.panel.layer.shadowOpacity = 0.6;
    self.panel.hidden = YES;
    self.panel.alpha = 0;
    [self.view addSubview:self.panel];
    
    // Panel header
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, panelW, 44)];
    header.text = @"  MicBoard";
    header.textColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:1];
    header.font = [UIFont boldSystemFontOfSize:16];
    header.backgroundColor = [UIColor colorWithRed:0 green:0.3 blue:0.15 alpha:0.5];
    [self.panel addSubview:header];
    
    // Enable toggle
    UISwitch *enableSwitch = [[UISwitch alloc] init];
    enableSwitch.frame = CGRectMake(panelW - 60, 10, 0, 0);
    enableSwitch.on = YES;
    enableSwitch.onTintColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:1];
    [enableSwitch addTarget:self action:@selector(toggleEnabled:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:enableSwitch];
    
    // Stop button
    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    stopBtn.frame = CGRectMake(12, 52, panelW - 24, 32);
    stopBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.2 alpha:0.8];
    stopBtn.layer.cornerRadius = 8;
    [stopBtn setTitle:@"■  STOP SOUND" forState:UIControlStateNormal];
    stopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [stopBtn addTarget:self action:@selector(stopSound) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:stopBtn];
    
    // Volume slider
    UILabel *volLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 90, 60, 20)];
    volLabel.text = @"Volume";
    volLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    volLabel.font = [UIFont systemFontOfSize:11];
    [self.panel addSubview:volLabel];
    
    UISlider *volSlider = [[UISlider alloc] initWithFrame:CGRectMake(70, 90, panelW - 84, 20)];
    volSlider.minimumValue = 0;
    volSlider.maximumValue = 1;
    volSlider.value = 0.8;
    volSlider.minimumTrackTintColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:1];
    volSlider.tag = 999;
    [self.panel addSubview:volSlider];
    
    // Sound buttons grid
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 118, panelW, panelH - 118)];
    scroll.showsVerticalScrollIndicator = NO;
    [self.panel addSubview:scroll];
    
    int cols = 2;
    CGFloat btnW = (panelW - 30) / cols;
    CGFloat btnH = 50;
    CGFloat gap = 8;
    
    for (int i = 0; i < self.soundNames.count; i++) {
        int col = i % cols;
        int row = i / cols;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(10 + col * (btnW + gap), 8 + row * (btnH + gap), btnW, btnH);
        btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.15 blue:0.12 alpha:1];
        btn.layer.cornerRadius = 10;
        btn.layer.borderColor = [UIColor colorWithRed:0 green:0.6 blue:0.3 alpha:0.4].CGColor;
        btn.layer.borderWidth = 1;
        btn.tag = i;
        
        [btn setTitle:self.soundNames[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        btn.titleLabel.numberOfLines = 2;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        [btn setTitleColor:[UIColor colorWithWhite:0.9 alpha:1] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(playSound:) forControlEvents:UIControlEventTouchUpInside];
        
        // Press animation
        [btn addTarget:self action:@selector(btnDown:) forControlEvents:UIControlEventTouchDown];
        [btn addTarget:self action:@selector(btnUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        
        [scroll addSubview:btn];
    }
    
    int rows = (int)ceil((double)self.soundNames.count / cols);
    scroll.contentSize = CGSizeMake(panelW, rows * (btnH + gap) + 16);
    
    // Add sounds instruction if empty
    if (self.soundPaths.count == 0 || [self.soundPaths[0] isEqualToString:@""]) {
        UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, scroll.contentSize.height - 40, panelW - 24, 36)];
        hint.text = @"Add .mp3/.wav files to\n~/Documents/MicBoard/Sounds/";
        hint.textColor = [UIColor colorWithWhite:0.4 alpha:1];
        hint.font = [UIFont systemFontOfSize:10];
        hint.numberOfLines = 2;
        hint.textAlignment = NSTextAlignmentCenter;
        [scroll addSubview:hint];
    }
}

- (void)playSound:(UIButton*)sender {
    int idx = (int)sender.tag;
    if (idx >= self.soundPaths.count) return;
    NSString *path = self.soundPaths[idx];
    if (path.length == 0) return;
    
    UISlider *vol = (UISlider*)[self.panel viewWithTag:999];
    float volume = vol ? vol.value : 0.8;
    
    MicBoardPlaySound(path, volume);
    
    // Flash green
    [UIView animateWithDuration:0.1 animations:^{
        sender.backgroundColor = [UIColor colorWithRed:0 green:0.6 blue:0.3 alpha:1];
    } completion:^(BOOL done){
        [UIView animateWithDuration:0.2 animations:^{
            sender.backgroundColor = [UIColor colorWithRed:0.1 green:0.15 blue:0.12 alpha:1];
        }];
    }];
}

- (void)stopSound { MicBoardStopSound(); }

- (void)toggleEnabled:(UISwitch*)sw {
    MicBoardSetEnabled(sw.on);
    self.toggleButton.backgroundColor = sw.on ? 
        [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.95] :
        [UIColor colorWithWhite:0.4 alpha:0.9];
}

- (void)btnDown:(UIButton*)btn {
    [UIView animateWithDuration:0.08 animations:^{ btn.transform = CGAffineTransformMakeScale(0.93, 0.93); }];
}
- (void)btnUp:(UIButton*)btn {
    [UIView animateWithDuration:0.12 animations:^{ btn.transform = CGAffineTransformIdentity; }];
}

- (void)togglePanel {
    self.isExpanded = !self.isExpanded;
    if (self.isExpanded) {
        self.panel.hidden = NO;
        CGRect btnFrame = self.toggleButton.frame;
        self.panel.frame = CGRectMake(btnFrame.origin.x + 60, btnFrame.origin.y - 20, 280, 400);
        // Keep on screen
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        if (self.panel.frame.origin.x + 280 > screenW - 10)
            self.panel.frame = CGRectMake(screenW - 290, self.panel.frame.origin.y, 280, 400);
        if (self.panel.frame.origin.y + 400 > screenH - 20)
            self.panel.frame = CGRectMake(self.panel.frame.origin.x, screenH - 420, 280, 400);
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:0 animations:^{
            self.panel.alpha = 1;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{ self.panel.alpha = 0; } 
                         completion:^(BOOL d){ self.panel.hidden = YES; }];
    }
}

- (void)handleDrag:(UIPanGestureRecognizer*)pan {
    CGPoint delta = [pan translationInView:self.view];
    CGRect f = self.toggleButton.frame;
    f.origin.x = MAX(0, MIN(f.origin.x + delta.x, [UIScreen mainScreen].bounds.size.width - f.size.width));
    f.origin.y = MAX(50, MIN(f.origin.y + delta.y, [UIScreen mainScreen].bounds.size.height - 100));
    self.toggleButton.frame = f;
    [pan setTranslation:CGPointZero inView:self.view];
}

@end
