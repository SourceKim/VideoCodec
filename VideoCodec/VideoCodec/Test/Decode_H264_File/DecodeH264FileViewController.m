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
    
    _decoder.decodeCallback = ^(CVPixelBufferRef buffer) {
        CVPixelBufferRef decodedBuffer = buffer;
        if (decodedBuffer) {
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer: decodedBuffer];
            CIContext *temporaryContext = [CIContext contextWithOptions:nil];
            CGImageRef videoImage = [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(decodedBuffer), CVPixelBufferGetHeight(decodedBuffer))];
            UIImage *img = [UIImage imageWithCGImage: videoImage];
            dispatch_async(dispatch_get_main_queue(), ^{
                _imgv.image = img;
            });
            
            //            NSLog(@"image: %zu, %zu", CGImageGetWidth(videoImage), CGImageGetHeight(videoImage));
        }
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        SKPacket *currentPacket = [_fileReader nextPacket];
            while (currentPacket != nil) {
                
                CVPixelBufferRef decodedBuffer = [_decoder decode: currentPacket];
                

                
                currentPacket = [_fileReader nextPacket];
            }
    });
    

    
}

@end
