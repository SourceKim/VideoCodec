////  EncodeMp4ToH264ViewController.m
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/18.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "EncodeMp4ToH264ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "SKVideoEncoder.h"

@interface EncodeMp4ToH264ViewController ()

@property (nonatomic, strong) AVAsset * asset;

@property (nonatomic, strong) AVAssetReader * assetReader;

@property (nonatomic, strong) AVAssetReaderOutput * videoOutput;

@property (nonatomic, strong) SKVideoEncoder * encoder;

@end

@implementation EncodeMp4ToH264ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 配置 MP4 文件
    _asset = [self loadAsset: @"1561122035537077.mp4"];
    
    // 配置 Asset Reader
    AVAssetTrack *videoTrack = [_asset tracksWithMediaType: AVMediaTypeVideo].firstObject;
    _assetReader = [self createAssetReader: _asset];
    _videoOutput = [self setupAssetReaderOutput: videoTrack];
    
    // 初始化 Encoder
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Encoded_MP4_H264_File"];
    _encoder = [[SKVideoEncoder alloc] initWithOptions:(SKVideoEncoderOptions) {
        .width = 480,
        .height = 960,
        .outputPath = file,
    }];
    
    // Asset Reader 开始读取
    [self startAssetReading];
    
    // 从 Asset Reader 中读取 （直到读到的 SampleBuffer 为 NULL）
    while (1) {
        CMSampleBufferRef sampleBuffer = [_videoOutput copyNextSampleBuffer];
        
        if (sampleBuffer == NULL) { // 读取完毕
            [self stopAssetReading];
            NSLog(@"Finish reading from asset");
            break;
        }
        
        // 编码
        [_encoder encode: sampleBuffer];
    }
    
    NSLog(@"Encode MP4 Finished, file path: %@", file);
}

#pragma mark - Load asset

- (AVAsset *)loadAsset: (NSString *)fileName {
    NSURL *mp4Url = [[NSBundle mainBundle] URLForResource: fileName withExtension: nil];
    return [AVAsset assetWithURL: mp4Url];
}

#pragma mark - Setup asset reader

- (AVAssetReader *)createAssetReader: (AVAsset *)asset {
    NSError *err;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset: asset error: &err];
    
    NSAssert(assetReader != nil, @"error: %@", err);
    
    return assetReader;
}

- (AVAssetReaderTrackOutput *)setupAssetReaderOutput: (AVAssetTrack *)track {
    
    NSDictionary *outputSettings = @{(id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput
                                             assetReaderTrackOutputWithTrack: track
                                             outputSettings: outputSettings];
    
    if ([_assetReader canAddOutput: output]) {
        [_assetReader addOutput: output];
    } else {
        NSLog(@"Can't add output");
    }
    
    return output;
}

- (void)startAssetReading {
    if (![_assetReader startReading]) {
        NSLog(@"Can't start reading asset");
    }
}

- (void)stopAssetReading {
    [_assetReader cancelReading];
}

@end
