////  SKVideoEncoder.h
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/18.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct SKVideoEncoderOptions {

    int32_t width;
    int32_t height;
    
    NSString *outputPath;
    
}SKVideoEncoderOptions;

@interface SKVideoEncoder : NSObject

- (instancetype)initWithOptions: (SKVideoEncoderOptions)options;

- (void)encode: (CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
