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

@interface SKVideoDecoder : NSObject

- (CVPixelBufferRef)decode: (SKPacket *)packet;

@property (nonatomic, strong) void(^decodeCallback)(CVPixelBufferRef);

@end

NS_ASSUME_NONNULL_END
