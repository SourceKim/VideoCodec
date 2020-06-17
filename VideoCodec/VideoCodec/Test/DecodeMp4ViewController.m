////  DecodeMp4ViewController.m
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/17.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "DecodeMp4ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "SKVideoCodec.h"

@interface DecodeMp4ViewController ()

@property (nonatomic, strong) AVAsset * asset;

@property (nonatomic, strong) AVAssetReader * assetReader;

@property (nonatomic, strong) AVAssetReaderOutput * videoOutput;

@property (nonatomic, strong) SKVideoCodec * decoder;

@property (nonatomic, strong) AVSampleBufferDisplayLayer * displayLayer;

@end

@implementation DecodeMp4ViewController {
    
    dispatch_queue_t _displayQueue;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _asset = [self loadAsset: @"1561122035537077.mp4"];
    
    AVAssetTrack *videoTrack = [_asset tracksWithMediaType: AVMediaTypeVideo].firstObject;
    
    _assetReader = [self createAssetReader: _asset];
    
    _videoOutput = [self setupAssetReaderOutput: videoTrack];
    
    [self startAssetReading];
    
    _decoder = [SKVideoCodec new];
    [_decoder createDecodeSession: videoTrack];
    
    _displayQueue = dispatch_queue_create(0, 0);
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupDisplayLayer];
    
    __weak typeof(self) weakSelf = self;
    _decoder.decodeCallback = ^(CVImageBufferRef  _Nonnull imageBuffer,
                                CMTime presentationTimeStamp,
                                CMTime presentationDuration) {
        
        CMSampleTimingInfo timeInfo = {
            .duration = presentationDuration,
            .presentationTimeStamp = presentationTimeStamp,
            .decodeTimeStamp = kCMTimeInvalid
        };
        
        CMVideoFormatDescriptionRef videoDesc = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &videoDesc);
        
        CMSampleBufferRef sampleBuffer = NULL;
        OSStatus status = CMSampleBufferCreateForImageBuffer(NULL, imageBuffer, true, NULL, NULL, videoDesc, &timeInfo, &sampleBuffer);
        
        if (sampleBuffer != NULL) {
            __strong typeof(self) strongSelf = weakSelf;
            if ([strongSelf->_displayLayer isReadyForMoreMediaData]) {
                [strongSelf->_displayLayer enqueueSampleBuffer: sampleBuffer];
            } else {
                NSLog(@"Layer is not ready");
            }
        } else {
            NSLog(@"Fail to convert decoded buffer to CMSampleBuffer");
        }
    };
    
    [_displayLayer requestMediaDataWhenReadyOnQueue: _displayQueue usingBlock:^{
        
    }];
    
    while (1) {
        
        CMSampleBufferRef sampleBuffer = [_videoOutput copyNextSampleBuffer];
        
        [_decoder decode: sampleBuffer];
        
        CMSampleBufferInvalidate(sampleBuffer);
        
        if (sampleBuffer == nil) {
            break;
        }
        
        CFRelease(sampleBuffer);
    }
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
    
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput
                                             assetReaderTrackOutputWithTrack: track
                                             outputSettings: nil];
    
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

#pragma mark - Setup Display Layer

- (void)setupDisplayLayer {
    
    CGRect vBounds = self.view.bounds;
    
    _displayLayer = [AVSampleBufferDisplayLayer new];
    _displayLayer.frame = vBounds;
    _displayLayer.position = CGPointMake(CGRectGetMidX(vBounds), CGRectGetMidY(vBounds));
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.opaque = true;
    [self.view.layer addSublayer: _displayLayer];
}

@end
