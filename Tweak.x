#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import "MicBoardOverlay.h"

static AVAudioEngine *_engine = nil;
static AVAudioPlayerNode *_soundPlayer = nil;
static AVAudioMixerNode *_mixer = nil;
static BOOL _micBoardEnabled = YES;

%hook AVAudioSession

- (BOOL)setCategory:(NSString *)category 
        withOptions:(AVAudioSessionCategoryOptions)options 
              error:(NSError **)outError {
    AVAudioSessionCategoryOptions newOptions = options | 
        AVAudioSessionCategoryOptionMixWithOthers |
        AVAudioSessionCategoryOptionDefaultToSpeaker;
    return %orig(category, newOptions, outError);
}

- (BOOL)setCategory:(NSString *)category 
               mode:(NSString *)mode 
            options:(AVAudioSessionCategoryOptions)options 
              error:(NSError **)outError {
    AVAudioSessionCategoryOptions newOptions = options |
        AVAudioSessionCategoryOptionMixWithOthers;
    return %orig(category, mode, newOptions, outError);
}

%end

%hook AVAudioEngine

- (void)prepare {
    %orig;
    if (!_micBoardEnabled) return;
    @try {
        AVAudioInputNode *inputNode = self.inputNode;
        AVAudioFormat *format = [inputNode outputFormatForBus:0];
        @try { [inputNode removeTapOnBus:0]; } @catch(NSException *e) {}
        [inputNode installTapOnBus:0 bufferSize:4096 format:format 
            block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {}];
    } @catch(NSException *e) {
        NSLog(@"[MicBoard] tap error: %@", e);
    }
}

%end

static void InitMicBoardEngine() {
    if (_engine) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            _engine = [[AVAudioEngine alloc] init];
            _soundPlayer = [[AVAudioPlayerNode alloc] init];
            _mixer = _engine.mainMixerNode;
            [_engine attachNode:_soundPlayer];
            AVAudioFormat *format = [[AVAudioFormat alloc] 
                initStandardFormatWithSampleRate:44100 channels:1];
            [_engine connect:_soundPlayer to:_mixer format:format];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                withOptions:AVAudioSessionCategoryOptionMixWithOthers |
                            AVAudioSessionCategoryOptionAllowBluetooth |
                            AVAudioSessionCategoryOptionDefaultToSpeaker
                error:nil];
            NSError *error = nil;
            [_engine startAndReturnError:&error];
            if (!error) [_soundPlayer play];
        } @catch(NSException *e) {
            NSLog(@"[MicBoard] engine error: %@", e);
        }
    });
}

void MicBoardPlaySound(NSString *filePath, float volume) {
    if (!_micBoardEnabled || !_engine) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            NSURL *url = [NSURL fileURLWithPath:filePath];
            NSError *error = nil;
            AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:url error:&error];
            if (error || !audioFile) return;
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] 
                initWithPCMFormat:audioFile.processingFormat
                    frameCapacity:(AVAudioFrameCount)audioFile.length];
            [audioFile readIntoBuffer:buffer error:&error];
            if (error) return;
            _soundPlayer.volume = volume;
            [_soundPlayer stop];
            [_soundPlayer play];
            [_soundPlayer scheduleBuffer:buffer completionHandler:nil];
        } @catch(NSException *e) {
            NSLog(@"[MicBoard] play error: %@", e);
        }
    });
}

void MicBoardStopSound() {
    if (_soundPlayer) [_soundPlayer stop];
    if (_soundPlayer) [_soundPlayer play];
}

void MicBoardSetEnabled(BOOL enabled) {
    _micBoardEnabled = enabled;
    if (!enabled) MicBoardStopSound();
}

%ctor {
    NSLog(@"[MicBoard] loaded!");
    InitMicBoardEngine();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        [MicBoardOverlay showOverlay];
    });
}
