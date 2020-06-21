////  SKVideoEncoder.m
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/18.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "SKVideoEncoder.h"

#import <VideoToolbox/VideoToolbox.h>

@implementation SKVideoEncoder {
    int32_t _width, _height;
    
    VTCompressionSessionRef _session;
    
    uint _frameCnt;
    
    NSString *_outFilePath;
    
    NSFileHandle *_outFile;
}

- (instancetype)initWithOptions: (SKVideoEncoderOptions)options
{
    self = [super init];
    if (self) {
        
        [self config: options];
        
        _session = [self createSession];
        
        [self setupSession: _session];
        
        [self prepareSession: _session];
        
        _frameCnt = 0;
    }
    return self;
}

- (void)teardown {
    [self teardown_videoToolBox];
    
    [_outFile closeFile];
    _outFile = nil;
}

- (void)teardown_videoToolBox {
    VTCompressionSessionCompleteFrames(_session, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_session);
    CFRelease(_session);
    _session = NULL;
}

- (void)config: (SKVideoEncoderOptions)options {
    
    _width = options.width;
    _height = options.height;
    
    _outFilePath = options.outputPath;
    
    [[NSFileManager defaultManager] createFileAtPath: _outFilePath contents: nil attributes: nil];
    _outFile = [NSFileHandle fileHandleForWritingAtPath: _outFilePath];
}

- (VTCompressionSessionRef)createSession {
    
    VTCompressionSessionRef session;
    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 _width,
                                                 _height,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 encodeCallback,
                                                 (__bridge void *)self,
                                                 &session);
    
    if (status != noErr) {
        NSLog(@"Session create failed, errcode: %d", status);
        return NULL;
    }
    
    return session;
}

- (void)setupSession: (VTCompressionSessionRef)session {
    
    OSStatus status;
    
    // 最大帧延迟，提升该值可以减少编码压力（会丢弃帧）
    int32_t maxFrameDelay = 3;
    CFNumberRef cfMaxFrameDelay = CFNumberCreate(NULL, kCFNumberSInt32Type, &maxFrameDelay);
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxFrameDelayCount, cfMaxFrameDelay);
    if (status != noErr) {
        NSLog(@"Set max frame delay failed, errcode: %d", status);
    }
    
    // 帧率 （FPS）
    int32_t frameRate = 60;
    CFNumberRef cfFrameRate = CFNumberCreate(NULL, kCFNumberSInt32Type, &frameRate);
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, cfFrameRate);
    if (status != noErr) {
        NSLog(@"Set frame rate failed, errcode: %d", status);
    }
    
    // 两个 I 帧的最大帧时间间隔（单位：秒）
    int32_t maxKeyframeDuration = 1;
    CFNumberRef cfMaxKeyframeDuration = CFNumberCreate(NULL, kCFNumberSInt32Type, &maxKeyframeDuration);
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, cfMaxKeyframeDuration);
    if (status != noErr) {
        NSLog(@"Set max I frame interval failed, errcode: %d", status);
    }
    
    // 两个 I 帧的最大帧间隔（GOP）
    int32_t GOP = 8;
    CFNumberRef cfGOP = CFNumberCreate(NULL, kCFNumberSInt32Type, &GOP);
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, cfGOP);
    if (status != noErr) {
        NSLog(@"Set GOP failed, errcode: %d", status);
    }
    
    // 码率（单位：byte。此处是平均码率，实际可能会超出或者小于该值）
    int32_t bitrate = _width * _height * 3 * 4;
    CFNumberRef cfBitrate = CFNumberCreate(NULL, kCFNumberSInt32Type, &bitrate);
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, cfBitrate);
    if (status != noErr) {
        NSLog(@"Set bitrate failed, errcode: %d", status);
    }
    
    // 实时编码 （实时编码的效果会比非实时差一点）
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (status != noErr) {
        NSLog(@"Set real time encoding failed, errcode: %d", status);
    }
    
    // 帧重新排序（编码 B 帧必须要重新排序才可以，会导致编码的顺序和显示的顺序不同）
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    if (status != noErr) {
        NSLog(@"Set frame reordering failed, errcode: %d", status);
    }
    
    // 编码的比特流配置文件和级别
    status = VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    if (status != noErr) {
        NSLog(@"Set Profile & Level failed, errcode: %d", status);
    }
}

- (void)prepareSession: (VTCompressionSessionRef)session {
    
    OSStatus status = VTCompressionSessionPrepareToEncodeFrames(session);
    
    if (status != noErr) {
        NSLog(@"Session prepare failed, errcode: %d", status);
        return;
    }
}

- (void)encode: (CMSampleBufferRef)sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime presentationTimeStamp = CMTimeMake(_frameCnt, 1);
    _frameCnt++;
    CMTime duration = CMSampleBufferGetOutputDuration(sampleBuffer);
    
    OSStatus status = VTCompressionSessionEncodeFrame(_session,
                                                      imageBuffer,
                                                      presentationTimeStamp,
                                                      duration,
                                                      NULL,
                                                      imageBuffer,
                                                      NULL);
    
    if (status != noErr) {
        NSLog(@"Encode sample buffer with id (%d) failed, errcode: %d", _frameCnt, status);
    }
}

void encodeCallback(void * CM_NULLABLE outputCallbackRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTEncodeInfoFlags infoFlags,
                    CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    
    SKVideoEncoder *encoder = (__bridge SKVideoEncoder *)outputCallbackRefCon;
    NSFileHandle *outFile = encoder->_outFile;
    
    NSLog(@"Start Encoding a frame...");
    
    if (status != noErr) {
        NSLog(@"Encode callback of frame (%d) failed, errcode: %d", encoder->_frameCnt, status);
        return;
    }
    
    if (infoFlags == kVTEncodeInfo_FrameDropped) {
        NSLog(@"Encode callback, but frame dropped");
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"Encode callback, but block data is not ready");
        return;
    }
    
    // 判断是否是关键帧 （通过判断是否「依赖于其他帧」）
    bool isKeyFrame = false;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachments != NULL) {
        CFDictionaryRef attachment = CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyFrame = (dependsOnOthers == kCFBooleanFalse);
    }
    
    // Start Code, SPS & PPS 在编码之后，写入数据的最开头都需要使用 0001 去分割
    static const char startCode[] = "\x00\x00\x00\x01";
    static size_t startCodeLen = sizeof(startCode) - 1; // 去除末尾 '\0'
    NSData *startCodeData = [NSData dataWithBytes: startCode length: startCodeLen];
    
    // 编码 SPS PPS
    if (isKeyFrame) {
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        const uint8_t *sps, *pps;
        size_t spsLen, ppsLen;
        size_t spsParamCount, ppsParamCount;
        int spsNALUnitHeaderLengthOut, ppsNALUnitHeaderLengthOut;
        
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &sps, &spsLen, &spsParamCount, &spsNALUnitHeaderLengthOut);
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &pps, &ppsLen, &ppsParamCount, &ppsNALUnitHeaderLengthOut);
        
        NSData *spsData = [NSData dataWithBytes: sps length: spsLen];
        NSData *ppsData = [NSData dataWithBytes: pps length: ppsLen];
        
        [outFile writeData: startCodeData];
        [outFile writeData: spsData];
        [outFile writeData: startCodeData];
        [outFile writeData: ppsData];
    }
    
    // 编码 NALUs
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t len, totalLen;
    char *dataPtr;
    
    CMBlockBufferGetDataPointer(blockBuffer, 0, &len, &totalLen, &dataPtr);
    
    size_t bufferOffset = 0;
    static const int kAVCCHeaderLen = 4; // NALU 的前 4 个字节，是该 NALU 的长度
    
        // 循环读取 NALU
    while (bufferOffset < totalLen - kAVCCHeaderLen) {
        
        // 1. 读取开头 4 个字节，这里记录着本 NALU 的长度 （注意，NALU 长度硬性规定为 Big-Endian）
        uint32_t NALULen = 0;
        memcpy(&NALULen, dataPtr + bufferOffset, kAVCCHeaderLen);
        NALULen = CFSwapInt32BigToHost(NALULen); // 从 Big-Endian 转为系统的字节序（iOS 是 Little-Endian）
        
        // 2. 写入文件 （0001 + NALU）
        NSData *naluData = [NSData dataWithBytes: dataPtr + bufferOffset + kAVCCHeaderLen
                                          length: NALULen];
        
        [outFile writeData: startCodeData];
        [outFile writeData: naluData];
        
        // 3. 调整 Offset，继续读取下一个
        bufferOffset += kAVCCHeaderLen + NALULen;
    }
    
}

@end
