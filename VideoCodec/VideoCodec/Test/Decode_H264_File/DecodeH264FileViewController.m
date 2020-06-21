//
//  DecodeH264FileViewController.m
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "DecodeH264FileViewController.h"

#import "SKVideoFileReader.h"

#import "SKVideoDecoder.h"

@interface DecodeH264FileViewController ()<SKVideoDecoderDelegate>

@end

@implementation DecodeH264FileViewController {
    
    SKVideoFileReader *_fileReader;
    
    SKVideoDecoder *_decoder;
    
    UIImageView *_imgv;
    
    NSMutableArray<UIImage *> *_imgs;
    
    CADisplayLink *_dis;
    
    int _decodedFrameCount;
    int _playFrameIndex;
    
    CIContext *_ctx;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _imgs = [NSMutableArray array];
    _decodedFrameCount = 0;
    _ctx = [CIContext context];
    
    _imgv = [[UIImageView alloc] initWithFrame: self.view.bounds];
    [self.view addSubview: _imgv];
    _imgv.contentMode = UIViewContentModeScaleAspectFit;
    
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Encoded_MP4_H264_File"];
    NSLog(@"Reading file stream: %@", file);
    
    // 构造 H264 文件读取器
    _fileReader = [[SKVideoFileReader alloc] initWithH264File: file];
    
    // 构造 H264 解码器
    _decoder = [SKVideoDecoder new];
    _decoder.delegate = self;
    
    // 子线程读取 & 解码
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        // 循环从 H264 文件中读取 packet（内部以 startCode 分割）
        SKPacket *currentPacket = [self->_fileReader nextPacket];
        while (currentPacket != nil) {
            [self->_decoder decode: currentPacket]; // 1. 解码
            currentPacket = [self->_fileReader nextPacket]; // 2. 读取下一个 packet
        }
        
        NSLog(@"Decode finished");
        
        // 读取结束，返回主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_playFrameIndex = 0;
            self->_dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(play)];
            [self->_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
        });
    });
    
    
}

#pragma mark - SKVideoDecoderDelegate 解码回调

- (void)onBufferDecoded:(SKVideoDecoder *)decoder buffer:(CVPixelBufferRef)buffer {
    
    _decodedFrameCount++;
    
    NSLog(@"Did decode frame, current count: %d", _decodedFrameCount);
    
    if (buffer) {
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer: buffer];
        CGRect rect = CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer));
        CGImageRef cgImage = [_ctx createCGImage: ciImage fromRect: rect];
        // 注意：从 AVAssetReader 中读取出来的 naturalSize 是宽高相反的，所以要加入 orientation
        UIImage *img = [UIImage imageWithCGImage: cgImage scale: 0 orientation: UIImageOrientationRight];
        [_imgs addObject: img];
    }
}

#pragma mark - 播放

- (void)play {
    if (_playFrameIndex >= _imgs.count) {
        [_dis invalidate];
        _dis = nil;
        return;
    }
    _imgv.image = _imgs[_playFrameIndex];
    _playFrameIndex++;
}

@end
