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

- (CVPixelBufferRef)decode: (SKPacket *)packet {
    
    uint8_t *buffer = packet.buffer;
    NSInteger bufferLen = packet.size;
    
    int frameType = buffer[START_CODE_LEN - 1 + 1] & 0x1F; // Start Code 之后的第一位就是 NALU 的类型
    
    NSLog(@"frame type - %d", frameType);
    
    uint32_t nalSize = (uint32_t)(bufferLen - 4);
    uint32_t *pNalSize = (uint32_t *)buffer;
    *pNalSize = CFSwapInt32HostToBig(nalSize);
    
    CVPixelBufferRef decodedBuffer = NULL;
    switch (frameType) {
        case SK_H264_FRAME_TYPE_I:
            [self checkSession];
            decodedBuffer = [self decodeFrame: packet];
            break;
            
        case SK_H264_FRAME_TYPE_BP:
            [self checkSession];
            decodedBuffer = [self decodeFrame: packet];
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
    
    return decodedBuffer;
    
//    if (decodedBuffer) {
//        CIImage *ciImage = [CIImage imageWithCVPixelBuffer: decodedBuffer];
//        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
//        CGImageRef videoImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(decodedBuffer), CVPixelBufferGetHeight(decodedBuffer))];
//        NSLog(@"image: %zu, %zu", CGImageGetWidth(videoImage), CGImageGetHeight(videoImage));
//    }

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

-(CVPixelBufferRef)decodeFrame: (SKPacket *)packet {
    
    if (!_session) {
        NSLog(@"No session");
        return NULL;
    }
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)packet.buffer, packet.size,
                                                          kCFAllocatorNull,
                                                          NULL, 0, packet.size,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = { packet.size };
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _currentFormatDesc,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            // 默认是同步操作。
            // 调用didDecompress，返回后再回调
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_session,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    
    return outputPixelBuffer;
}


void decodeCallback(
                    void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp,
                    CMTime presentationDuration) {
    
    NSLog(@"decode callback");
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    CVPixelBufferRetain(imageBuffer);
    
    ((__bridge SKVideoDecoder *)decompressionOutputRefCon).decodeCallback(imageBuffer);
    
//    if (imageBuffer) {
//        CIImage *ciImage = [CIImage imageWithCVPixelBuffer: imageBuffer];
//        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
//        CGImageRef videoImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
//        NSLog(@"image: %zu, %zu", CGImageGetWidth(videoImage), CGImageGetHeight(videoImage));
//    }
}

@end
