//
//  SKVideoDecoder.m
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "SKVideoDecoder.h"

#import <VideoToolbox/VideoToolbox.h>
#import <CoreImage/CoreImage.h>

#define SK_H264_FRAME_TYPE_I 0x05
#define SK_H264_FRAME_TYPE_BP 0x01
#define SK_H264_FRAME_TYPE_SPS 0x07
#define SK_H264_FRAME_TYPE_PPS 0x08
#define SK_H264_FRAME_TYPE_SEI 0x06

#define START_CODE_LEN 4

@implementation SKVideoDecoder {
    
    VTDecompressionSessionRef _session;
    CFDictionaryRef _outputBufferAttributes;
    VTDecompressionOutputCallbackRecord _callbackRecord;
    CMFormatDescriptionRef _currentFormatDesc;
    
    uint8_t *_sps, *_pps;
    size_t _spsLen, _ppsLen;
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        _outputBufferAttributes = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        _callbackRecord = (VTDecompressionOutputCallbackRecord) {
            .decompressionOutputCallback = decodeCallback,
            .decompressionOutputRefCon = (__bridge void *)self,
        };
        
    }
    return self;
}

- (void)decode: (SKPacket *)packet {
    
    uint8_t *buffer = packet.buffer;
    NSInteger bufferLen = packet.size;
    
    int frameType = buffer[START_CODE_LEN - 1 + 1] & 0x1F; // Start Code 之后的第一位就是 NALU 的类型
    
    NSLog(@"frame type - %d", frameType);
    
    uint32_t nalSize = (uint32_t)(bufferLen - 4);
    uint32_t *pNalSize = (uint32_t *)buffer;
    *pNalSize = CFSwapInt32HostToBig(nalSize);
    
    switch (frameType) {
        case SK_H264_FRAME_TYPE_I:
            [self checkSession];
            [self decodeFrame: packet];
            break;
            
        case SK_H264_FRAME_TYPE_BP:
            [self checkSession];
            [self decodeFrame: packet];
            break;
            
        case SK_H264_FRAME_TYPE_SPS:
            _spsLen = bufferLen - START_CODE_LEN;
            _sps = malloc(_spsLen);
            memcpy(_sps, buffer + START_CODE_LEN, _spsLen);
            break;
            
        case SK_H264_FRAME_TYPE_PPS:
            _ppsLen = bufferLen - START_CODE_LEN;
            _pps = malloc(_ppsLen);
            memcpy(_pps, buffer + START_CODE_LEN, _ppsLen);
            break;
            
        case SK_H264_FRAME_TYPE_SEI:

            break;
            
        default:
            
            break;
    }

}

- (void)checkSession {
    
    OSStatus status;
    
    const uint8_t *parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSizePointers[2] = { _spsLen, _ppsLen };
    
    CMFormatDescriptionRef formatDesc;
    status = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,
                                                                 2,
                                                                 parameterSetPointers,
                                                                 parameterSizePointers,
                                                                 START_CODE_LEN,
                                                                 &formatDesc);
    
    // 如果 session 不存在或者 formatDesc 更新了，则直接用 formatDesc 创建
    if (_session == NULL || !CMFormatDescriptionEqual(formatDesc, _currentFormatDesc)) {
        
        status = VTDecompressionSessionCreate(NULL,
                                              formatDesc,
                                              NULL,
                                              _outputBufferAttributes,
                                              &_callbackRecord,
                                              &_session);
        
        _currentFormatDesc = formatDesc;
    }
}

-(void)decodeFrame: (SKPacket *)packet {
    
    if (!_session) {
        NSLog(@"No session");
        return;
    }
    
    OSStatus status;
    
    // 1. 构造 Block Buffer （SKPacket -> CMBlockBufferRef）
    CMBlockBufferRef blockBuffer = NULL;
    CMBlockBufferFlags blockFlags = 0;
    status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                (void*)packet.buffer, // data
                                                packet.size, // block length
                                                kCFAllocatorNull, // **Important! can't be Null**
                                                NULL,
                                                0, // Offset
                                                packet.size, // data length
                                                blockFlags,
                                                &blockBuffer);
    
    if (status != kCMBlockBufferNoErr || blockBuffer == NULL) {
        NSLog(@"Create block buffer failed, status: %d", status);
        CFRelease(blockBuffer);
        return;
    }
    
    // 2. 构造 Sample Buffer （CMBlockBufferRef -> CMSampleBufferRef）
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = { packet.size };
    status = CMSampleBufferCreateReady(NULL,
                                       blockBuffer,
                                       _currentFormatDesc,
                                       1, // Sample num
                                       0,
                                       NULL,
                                       1,
                                       sampleSizeArray,
                                       &sampleBuffer);
    
    if (status != kCMBlockBufferNoErr || sampleBuffer == NULL) {
        NSLog(@"Create sample buffer failed, status: %d", status);
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);
        return;
    }
    
    // 3. 解码成 Pixel Buffer （CMSampleBuffer -> CVPixelBufferRef，在回调中返回）
    VTDecodeFrameFlags frameFlags = 0; // 默认是同步回调
    VTDecodeInfoFlags outFlags = 0; // 输出的 flags
    status = VTDecompressionSessionDecodeFrame(_session,
                                               sampleBuffer,
                                               frameFlags,
                                               NULL,
                                               &outFlags);
    
    if (status != noErr || sampleBuffer == NULL) {
        NSLog(@"Decode sample buffer failed, status: %d", status);
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);
        return;
    }
    
    // 4. 内存释放
    CFRelease(blockBuffer);
    CFRelease(sampleBuffer);
}

#pragma mark - 解码的回调
void decodeCallback(void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp,
                    CMTime presentationDuration) {
    
    NSLog(@"decode callback");
    
    SKVideoDecoder *decoder = (__bridge SKVideoDecoder *)decompressionOutputRefCon;
    
    if (decoder.delegate && [decoder.delegate respondsToSelector: @selector(onBufferDecoded:buffer:)]) {
        [decoder.delegate onBufferDecoded: decoder buffer: imageBuffer];
    }
}

@end
