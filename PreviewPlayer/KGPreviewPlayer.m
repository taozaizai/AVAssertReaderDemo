//
//  KGPreviewPlayer.m
//  PreviewPlayer
//
//  Created by 赵桃园 on 2019/5/30.
//  Copyright © 2019年 赵桃园. All rights reserved.
//

#import "KGPreviewPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface KGPreviewPlayer () {
    CGImageRef _cgimage;
}
@property (nonatomic, strong) NSURL *fileUrl;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;

@property (nonatomic, strong) CALayer *previewLayer;
@property (nonatomic, strong) CALayer *containerLayer;

@property (nonatomic, strong) NSTimer *decodeTimer;
@property (nonatomic, strong) NSConditionLock *clock;

@end

@implementation KGPreviewPlayer

- (instancetype)initWithVideoFileUrl:(NSURL *)fileUrl renderLayer:(CALayer *)renderLayer {
    if (self = [super init]) {
        _fileUrl = fileUrl;
        _containerLayer = renderLayer;
        _containerLayer.backgroundColor = [UIColor blackColor].CGColor;
        _status = KGPreviewPlayerStatusNotInited;
        _currentPlayTime = kCMTimeZero;
        _duration = kCMTimeZero;
        _clock = [[NSConditionLock alloc] initWithCondition:100];
    }
    return self;
}

- (void)prepareForPlay {
    AVURLAsset *vas = [AVURLAsset URLAssetWithURL:self.fileUrl options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@(YES)}];
    AVAssetReader *videoReader = [AVAssetReader assetReaderWithAsset:vas error:nil];
    AVAssetTrack *videoTrack = [vas tracksWithMediaType:AVMediaTypeVideo].firstObject;
    
    CGSize videoSize = videoTrack.naturalSize;
    CGSize containerSize = self.containerLayer.bounds.size;
    CGSize renderSize;
    //计算渲染层的大小
    if (videoSize.width/videoSize.height > containerSize.width/containerSize.height) {
        //以宽度为准
        renderSize = CGSizeMake(containerSize.width, containerSize.width*videoSize.height/videoSize.width);
        
    } else {
        //以高度为准
        renderSize = CGSizeMake(containerSize.height*videoSize.width/videoSize.height, containerSize.height);
        
    }
    
    
    CALayer *renderLayer = [CALayer layer];
    renderLayer.frame = CGRectMake((containerSize.width-renderSize.width)*0.5, (containerSize.height - renderSize.height)*0.5, renderSize.width, renderSize.height);
    [self.containerLayer addSublayer:renderLayer];
    self.previewLayer = renderLayer;
    
    NSMutableDictionary *outPutSetting = [NSMutableDictionary dictionary];
    [outPutSetting setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput *outPut = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outPutSetting];
    [videoReader addOutput:outPut];
    outPut.supportsRandomAccess = YES;
    self.reader = videoReader;
    self.asset = vas;
    self.output = outPut;
    
    CGFloat frameDuration = CMTimeGetSeconds(videoTrack.minFrameDuration);
    self.duration = self.asset.duration;
    CMTimeShow(self.asset.duration);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTimer *timer = [NSTimer timerWithTimeInterval:frameDuration target:self selector:@selector(readNextFrame) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
        self.decodeTimer = timer;
        [timer fire];
    });
    [self.delegate prepareResourceFinish:self];
}

- (void)play {
    switch (_status) {
        case KGPreviewPlayerStatusNotInited:
            [self startDecode];
            break;
        case KGPreviewPlayerStatusPause:
            self.status = KGPreviewPlayerStatusPlaying;
            [self.decodeTimer setFireDate:[NSDate distantPast]];
            break;
        case KGPreviewPlayerStatusPlaying:
            return;
            break;
        case KGPreviewPlayerStatusEnd:
        case KGPreviewPlayerStatusFail:
            self.status = KGPreviewPlayerStatusPlaying;
            [self seekTime:kCMTimeZero];
            break;
        default:
            break;
    }
}

- (void)pause {
    self.status = KGPreviewPlayerStatusPause;
    //停止计时器,即停止了解码操作
    [self.decodeTimer setFireDate:[NSDate distantFuture]];
}

- (void)seekTime:(CMTime)time {
    if (self.status == KGPreviewPlayerStatusEnd) {
        CMTimeRange range = CMTimeRangeMake(time, CMTimeSubtract(self.asset.duration, time));
        NSValue *value = [NSValue valueWithCMTimeRange:range];
        [self.output resetForReadingTimeRanges:@[value]];
    } else {
        [self.decodeTimer setFireDate:[NSDate distantPast]];
        [self.reader cancelReading];
        if (self.status != KGPreviewPlayerStatusPause) {
            [self.clock lockWhenCondition:100];
        }
        _currentPlayTime = time;
        [self reConfigReader];
        [self startDecode];
    }
}

- (void)reConfigReader {
    AVAssetReader *videoReader = [AVAssetReader assetReaderWithAsset:self.asset error:nil];
    AVAssetTrack *videoTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    NSMutableDictionary *outPutSetting = [NSMutableDictionary dictionary];
    [outPutSetting setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput *outPut = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outPutSetting];
    [videoReader addOutput:outPut];
    outPut.supportsRandomAccess = YES;
    videoReader.timeRange = CMTimeRangeMake(_currentPlayTime, CMTimeSubtract(self.duration, _currentPlayTime));
    self.reader = videoReader;
    self.output = outPut;
    
}

#pragma mark - Private methods

- (void)startDecode {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.reader startReading];
        self.status = KGPreviewPlayerStatusPlaying;
    });
}

- (void)readNextFrame {
    if (self.status != KGPreviewPlayerStatusPlaying) {
        return;
    }
    if (self.reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBuffer = [self.output copyNextSampleBuffer];
        if (sampleBuffer != NULL) {
            [self decodeSamleBufferToCgimage:sampleBuffer];
            CFRelease(sampleBuffer);
            [self displayImage];
        } else {
            return;
        }
    } else {
        if (self.reader.status == AVAssetReaderStatusCompleted) {
            self.status = KGPreviewPlayerStatusEnd;
        } else if (self.reader.status == AVAssetReaderStatusCancelled) {
            self.status = KGPreviewPlayerStatusFail;
        } else {
            self.status = KGPreviewPlayerStatusFail;
        }
        NSLog(@"结束");
        [self.clock unlockWithCondition:100];
    }
}

- (void)displayImage {
    if (_cgimage != NULL) {
        _previewLayer.contents = (__bridge id)_cgimage;
        CGImageRelease(_cgimage);
        _cgimage = NULL;
    }
}

- (void)decodeSamleBufferToCgimage:(CMSampleBufferRef)sampleBuffer {
    _currentPlayTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    CMTimeShow(_currentPlayTime);
    CVImageBufferRef cvimagebuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(cvimagebuffer, 0);
    void *baseAddre = CVPixelBufferGetBaseAddress(cvimagebuffer);
    size_t cvwidth = CVPixelBufferGetWidth(cvimagebuffer);
    size_t cvheight = CVPixelBufferGetHeight(cvimagebuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(cvimagebuffer);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddre, cvwidth, cvheight, 8, bytesPerRow, space, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef resImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(cvimagebuffer, 0);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    _cgimage = resImage;
}

@end
