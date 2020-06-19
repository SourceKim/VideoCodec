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

@interface DecodeH264FileViewController ()

@end

@implementation DecodeH264FileViewController {
    
    SKVideoFileReader *_fileReader;
    
    SKVideoDecoder *_decoder;
    
    UIImageView *_imgv;
    
    NSMutableArray<UIImage *> *_imgs;
    
    CADisplayLink *_dis;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _imgv = [[UIImageView alloc] initWithFrame: self.view.bounds];
    [self.view addSubview: _imgv];
    _imgv.contentMode = UIViewContentModeScaleAspectFit;
    
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Encoded_MP4_H264_File"];
    
    NSLog(@"reading file stream: %@", file);
    
    _fileReader = [[SKVideoFileReader alloc] initWithH264File: file];
    
    _decoder = [SKVideoDecoder new];
    
    _imgs = [NSMutableArray array];
    _decoder.decodeCallback = ^(CVPixelBufferRef buffer) {
        CVPixelBufferRef decodedBuffer = buffer;
        if (decodedBuffer) {
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer: decodedBuffer];
            CIContext *temporaryContext = [CIContext contextWithOptions:nil];
            CGImageRef videoImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(decodedBuffer), CVPixelBufferGetHeight(decodedBuffer))];
            UIImage *img = [UIImage imageWithCGImage: videoImage];
            [_imgs addObject: img];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                _imgv.image = img;
//            });
            
            //            NSLog(@"image: %zu, %zu", CGImageGetWidth(videoImage), CGImageGetHeight(videoImage));
        }
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        SKPacket *currentPacket = [_fileReader nextPacket];
            while (currentPacket != nil) {
                
                CVPixelBufferRef decodedBuffer = [_decoder decode: currentPacket];
                NSLog(@"cont: %d", _imgs.count);
                if (_imgs.count == 50) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(play)];
                        [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
                    });

                    break;
                }
                
                currentPacket = [_fileReader nextPacket];
            }
    });
    

}

static int idx = 0;
- (void)play {
    
    if (idx >= _imgs.count) {
        [_dis invalidate];
        _dis = nil;
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _imgv.image = _imgs[idx];
        idx++;
    });

    
    
}

@end
