//
//  SKPacket.h
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKPacket : NSObject

@property (nonatomic, assign) uint8_t * buffer;

@property (nonatomic, assign) NSInteger size;

- (instancetype)initWithSize: (NSInteger)size;

@end

NS_ASSUME_NONNULL_END
