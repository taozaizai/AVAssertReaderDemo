//
//  KGPreviewPlayer.h
//  PreviewPlayer
//
//  Created by 赵桃园 on 2019/5/30.
//  Copyright © 2019年 赵桃园. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, KGPreviewPlayerStatus) {
    KGPreviewPlayerStatusNotInited = 0,
    KGPreviewPlayerStatusPlaying,
    KGPreviewPlayerStatusPause,
    KGPreviewPlayerStatusEnd,
    KGPreviewPlayerStatusFail
};

@class KGPreviewPlayer;

@protocol KGPreviewPlayerDelegate  <NSObject>

- (void)prepareResourceFinish:(KGPreviewPlayer *)player;

@end

@interface KGPreviewPlayer : NSObject

@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CMTime currentPlayTime;
@property (nonatomic, assign) KGPreviewPlayerStatus status;
@property (nonatomic, weak) id<KGPreviewPlayerDelegate> delegate;

- (instancetype)initWithVideoFileUrl:(NSURL *)fileUrl renderLayer:(CALayer *)renderLayer;
- (void)prepareForPlay;
- (void)play;
- (void)pause;
- (void)seekTime:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
