////  SKVideoCodec.m
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/17.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "SKVideoCodec.h"

#import <VideoToolbox/VideoToolbox.h>

@implementation SKVideoCodec {
    
    VTDecompressionSessionRef _decodeSession;
    
    CMFormatDescriptionRef _currentDesc;
}

static SKVideoCodec *ptr = nil;

- (instancetype)init
{
    self = [super init];
    if (self) {
        ptr = self;
    }
    return self;
}

/* 解码回调
 `VTDecompressionSession.h` 中 copy
 */
void decodeCallback(
                    void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp,
                    CMTime presentationDuration ) {
    
    NSLog(@"did decode - %lf - %lf", CMTimeGetSeconds(presentationTimeStamp), CMTimeGetSeconds(presentationDuration));
    
    if (ptr.decodeCallback != nil) {
        ptr.decodeCallback(imageBuffer, presentationTimeStamp, presentationDuration);
    }
}


/// 根据 Track 创建 Decode Session，用来做解码使用
/// @param track 资源的轨道
- (void)createDecodeSession: (AVAssetTrack *)track {
    
    CMFormatDescriptionRef formatDesc = (__bridge CMFormatDescriptionRef)[track.formatDescriptions firstObject];
    _currentDesc = formatDesc;
    
    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = decodeCallback, // 传入解码回调到函数指针
        .decompressionOutputRefCon = NULL
    };
    
    VTDecompressionSessionRef decodeSession;
    OSStatus status = VTDecompressionSessionCreate(NULL,
                                                   formatDesc,
                                                   NULL,
                                                   NULL,
                                                   &callback,
                                                   &decodeSession);
    
    if (decodeSession == NULL) {
        NSLog(@"Create decode session failed, status: %d", status);
    }
    
    _decodeSession = decodeSession;
}

- (void)decode: (CMSampleBufferRef)sampleBuffer {
    
    OSType type = VTDecompressionSessionDecodeFrame(_decodeSession,
                                                    sampleBuffer,
                                                    !kVTDecodeFrame_EnableAsynchronousDecompression,
                                                    NULL,
                                                    NULL);
    
    CMFormatDescriptionRef desc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(desc);
    NSLog(@"decode dim：%d, %d", dim.width, dim.height);
    
    NSLog(@"same desc：%d", CMFormatDescriptionEqual(_currentDesc, desc));
    
    NSLog(@"DecodeType: %d", type);
}

@end
