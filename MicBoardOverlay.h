#import <UIKit/UIKit.h>

@interface MicBoardOverlay : UIViewController
+ (void)showOverlay;
@end

#ifdef __cplusplus
extern "C" {
#endif

void MicBoardPlaySound(NSString *filePath, float volume);
void MicBoardStopSound(void);
void MicBoardSetEnabled(BOOL enabled);

#ifdef __cplusplus
}
#endif
