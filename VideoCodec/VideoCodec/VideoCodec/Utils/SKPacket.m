//
//  SKPacket.m
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "SKPacket.h"

@implementation SKPacket

- (instancetype)initWithSize: (NSInteger)size
{
    self = [super init];
    if (self) {
        _size = size;
        _buffer = malloc(size);
    }
    return self;
}

- (void)dealloc
{
    free(self.buffer);
}

@end
