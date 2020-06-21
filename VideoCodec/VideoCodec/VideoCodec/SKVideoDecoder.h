//
//  SKVideoDecoder.h
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SKPacket.h"

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SKVideoDecoder;

@protocol SKVideoDecoderDelegate <NSObject>

- (void)onBufferDecoded: (SKVideoDecoder *)decoder buffer: (CVPixelBufferRef)buffer;

@end

@interface SKVideoDecoder : NSObject

@property (nonatomic, weak) id<SKVideoDecoderDelegate> delegate;

- (void)decode: (SKPacket *)packet;

@end

NS_ASSUME_NONNULL_END
