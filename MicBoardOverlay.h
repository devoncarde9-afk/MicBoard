#import <UIKit/UIKit.h>

@interface MicBoardOverlay : UIViewController
+ (void)showOverlay;
@end

extern void MicBoardPlaySound(NSString *filePath, float volume);
extern void MicBoardStopSound();
extern void MicBoardSetEnabled(BOOL enabled);
