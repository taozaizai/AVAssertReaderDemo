//
//  ViewController.m
//  PreviewPlayer
//
//  Created by 赵桃园 on 2019/5/30.
//  Copyright © 2019年 赵桃园. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "KGPreviewPlayer.h"

#define V_NAME @"process.mp4"

@interface ViewController () <KGPreviewPlayerDelegate> {
    BOOL _sliderHasLock;
}

@property (nonatomic, strong) KGPreviewPlayer *player;
@property (nonatomic, strong) UISlider *playSlider;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *playTimeLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CALayer *previewLayer = [CALayer layer];
    previewLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    [self.view.layer addSublayer:previewLayer];
    
    
    CGFloat itemWidth = self.view.bounds.size.width/3.0;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn addTarget:self action:@selector(restartPlay) forControlEvents:UIControlEventTouchUpInside];
    btn.backgroundColor = [UIColor blueColor];
    [btn setTitle:@"重新开始" forState:UIControlStateNormal];
    btn.layer.borderColor = [UIColor whiteColor].CGColor;
    btn.layer.borderWidth = 2;
    btn.frame = CGRectMake(0, 500, 200, 50);
    [self.view addSubview:btn];
    
    UIButton *pauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [pauseBtn addTarget:self action:@selector(pause) forControlEvents:UIControlEventTouchUpInside];
    pauseBtn.backgroundColor = [UIColor blueColor];
    [pauseBtn setTitle:@"暂停" forState:UIControlStateNormal];
    pauseBtn.frame = CGRectMake(itemWidth*1, 500, 200, 50);
    pauseBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    pauseBtn.layer.borderWidth = 2;
    [self.view addSubview:pauseBtn];
    
    
    UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [playBtn addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    playBtn.backgroundColor = [UIColor blueColor];
    [playBtn setTitle:@"播放" forState:UIControlStateNormal];
    playBtn.frame = CGRectMake(itemWidth*2, 500, 200, 50);
    playBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    playBtn.layer.borderWidth = 2;
    [self.view addSubview:playBtn];
    
    
    UISlider *slider = [[UISlider alloc] init];
    CGFloat sliderWidth = self.view.bounds.size.width - 120;
    slider.frame = CGRectMake((self.view.bounds.size.width-sliderWidth)*0.5, CGRectGetMaxY(playBtn.frame)+20, sliderWidth, 30);
    [self.view addSubview:slider];
    [slider addTarget:self action:@selector(sliderValueChanged) forControlEvents:UIControlEventTouchUpInside];
    [slider addTarget:self action:@selector(sliderLocked) forControlEvents:UIControlEventTouchDown];
    [slider addTarget:self action:@selector(sliderUnlocked) forControlEvents:UIControlEventTouchUpOutside];
    self.playSlider = slider;
    
    UILabel *durationLabel = [[UILabel alloc] init];
    durationLabel.frame = CGRectMake(CGRectGetMaxX(slider.frame)+10, CGRectGetMinY(slider.frame), 50, 30);
    durationLabel.text = @"00:00";
    durationLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:durationLabel];
    
    UILabel *playTimeLabel = [[UILabel alloc] init];
    playTimeLabel.frame = CGRectMake(CGRectGetMinX(slider.frame)-10-50, CGRectGetMinY(slider.frame), 50, 30);
    playTimeLabel.text = @"00:00";
    playTimeLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:playTimeLabel];
    
    self.durationLabel = durationLabel;
    self.playTimeLabel = playTimeLabel;
    
    NSTimer *updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (self.player.status == KGPreviewPlayerStatusPlaying) {
            [self updateTimeLabel];
        }
    }];
    [updateTimer fire];

    
    NSString *vasPath = [[NSBundle mainBundle] pathForResource:V_NAME ofType:nil];
    self.player = [[KGPreviewPlayer alloc] initWithVideoFileUrl:[NSURL fileURLWithPath:vasPath] renderLayer:previewLayer];
    self.player.delegate = self;
    [self.player prepareForPlay];
}

- (void)updateTimeLabel {
    CGFloat seconds = CMTimeGetSeconds(self.player.currentPlayTime);
    if (!_sliderHasLock) {
        self.playSlider.value = seconds;
    }
    self.playTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", ((NSInteger)seconds)/60, ((NSInteger)seconds)%60];
}

- (void)sliderValueChanged {
    NSLog(@"changed");
    CMTime seekTime = CMTimeMake(_playSlider.value*600, 600);
    [self.player seekTime:seekTime];
    _sliderHasLock = NO;
}

- (void)sliderLocked {
    _sliderHasLock = YES;
}

- (void)sliderUnlocked {
    _sliderHasLock = NO;
}

- (void)restartPlay {
    [self.player seekTime:kCMTimeZero];
}

- (void)play {
    [self.player play];
}

- (void)pause {
    [self.player pause];
}

#pragma mark - KGPreviewPlayerDelegate
- (void)prepareResourceFinish:(KGPreviewPlayer *)player {
    self.playSlider.maximumValue = CMTimeGetSeconds(player.duration);
    self.playSlider.minimumValue = 0;
    
    NSInteger seconds = CMTimeGetSeconds(self.player.duration);
    self.durationLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", seconds/60, seconds%60];
    
    [player play];
}

@end
