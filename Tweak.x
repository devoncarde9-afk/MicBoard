#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import "MicBoardOverlay.h"

// Global audio engine for mixing
static AVAudioEngine *_engine = nil;
static AVAudioPlayerNode *_soundPlayer = nil;
static AVAudioMixerNode *_mixer = nil;
static BOOL _micBoardEnabled = YES;
static float _soundVolume = 1.0f;
static float _micVolume = 1.0f;

// Hook AVAudioSession to intercept mic input
%hook AVAudioSession

- (BOOL)setCategory:(NSString *)category 
        withOptions:(AVAudioSessionCategoryOptions)options 
              error:(NSError **)outError {
    // Allow mixing so our audio can blend with mic
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

// Hook AVAudioEngine to tap into the mic input node
%hook AVAudioEngine

- (void)prepare {
    %orig;
    if (!_micBoardEnabled) return;
    
    @try {
        // Install tap on input node to mix our sounds in
        AVAudioInputNode *inputNode = self.inputNode;
        AVAudioFormat *format = [inputNode outputFormatForBus:0];
        
        // Remove existing tap if any
        @try { [inputNode removeTapOnBus:0]; } @catch(NSException *e) {}
        
        // Install our mixing tap
        [inputNode installTapOnBus:0 
                        bufferSize:4096 
                            format:format 
                             block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
            // This runs for every mic buffer
            // Our sound player node handles mixing automatically
            // via the engine's mixer
        }];
    } @catch(NSException *e) {
        NSLog(@"[MicBoard] tap install error: %@", e);
    }
}

%end

// Initialize our audio engine once
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
            if (error) {
                NSLog(@"[MicBoard] engine start error: %@", error);
            } else {
                NSLog(@"[MicBoard] audio engine started successfully");
                [_soundPlayer play];
            }
        } @catch(NSException *e) {
            NSLog(@"[MicBoard] engine init error: %@", e);
        }
    });
}

// Public function to play a sound file through the mic
void MicBoardPlaySound(NSString *filePath, float volume) {
    if (!_micBoardEnabled || !_engine) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            NSURL *url = [NSURL fileURLWithPath:filePath];
            NSError *error = nil;
            AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:url error:&error];
            if (error || !audioFile) {
                NSLog(@"[MicBoard] failed to load sound: %@", error);
                return;
            }
            
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] 
                initWithPCMFormat:audioFile.processingFormat
                    frameCapacity:(AVAudioFrameCount)audioFile.length];
            
            [audioFile readIntoBuffer:buffer error:&error];
            if (error) { NSLog(@"[MicBoard] read error: %@", error); return; }
            
            // Set volume on mixer
            _soundPlayer.volume = volume;
            
            // Stop current sound and play new one
            [_soundPlayer stop];
            [_soundPlayer play];
            [_soundPlayer scheduleBuffer:buffer 
                       completionHandler:^{ 
                NSLog(@"[MicBoard] sound finished"); 
            }];
            
        } @catch(NSException *e) {
            NSLog(@"[MicBoard] play error: %@", e);
        }
    });
}

void MicBoardStopSound() {
    if (_soundPlayer) [_soundPlayer stop];
    if (_soundPlayer) [_soundPlayer play]; // keep node active
}

void MicBoardSetEnabled(BOOL enabled) {
    _micBoardEnabled = enabled;
    if (!enabled) MicBoardStopSound();
}

%ctor {
    NSLog(@"[MicBoard] tweak loaded!");
    InitMicBoardEngine();
    
    // Show overlay after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        [MicBoardOverlay showOverlay];
    });
}
