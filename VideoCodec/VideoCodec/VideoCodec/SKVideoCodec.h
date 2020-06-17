////  SKVideoCodec.h
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/17.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SKVideoDecodeCallback)(
CVImageBufferRef imageBuffer,
CMTime presentationTimeStamp,
CMTime presentationDuration);

@interface SKVideoCodec : NSObject

/// 根据 Track 创建 Decode Session，用来做解码使用
/// @param track 资源的轨道
- (void)createDecodeSession: (AVAssetTrack *)track;

- (void)decode: (CMSampleBufferRef)sampleBuffer;

@property (nonatomic, strong) SKVideoDecodeCallback decodeCallback;

@end

NS_ASSUME_NONNULL_END
