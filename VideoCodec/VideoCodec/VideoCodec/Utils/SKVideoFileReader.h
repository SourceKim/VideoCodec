//
//  SKVideoFileReader.h
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SKPacket.h"

NS_ASSUME_NONNULL_BEGIN

@interface SKVideoFileReader : NSObject

- (instancetype)initWithH264File: (NSString *)file;

- (SKPacket*)nextPacket;

@end

NS_ASSUME_NONNULL_END
