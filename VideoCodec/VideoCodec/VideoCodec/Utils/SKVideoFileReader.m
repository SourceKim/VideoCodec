//
//  SKVideoFileReader.m
//  VideoCodec
//
//  Created by 苏金劲 on 2020/6/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "SKVideoFileReader.h"

#define MAX_BUFFER_LEN 1024 * 1024

const uint8_t KStartCode[4] = {0, 0, 0, 1};

@implementation SKVideoFileReader {
    
    uint8_t *_tmpBuffer;
    
    NSInputStream *_fileStream;
    
    /// 文件流的当前偏移值
    NSInteger _currentOffset;
}

- (instancetype)initWithH264File: (NSString *)file
{
    self = [super init];
    if (self) {
        
        _tmpBuffer = malloc(MAX_BUFFER_LEN);
        
        _fileStream = [NSInputStream inputStreamWithFileAtPath: file];
        
        [_fileStream open];
        
        _currentOffset = 0;
    }
    return self;
}

//- (void)nextPacket {
//
//    if ([_fileStream hasBytesAvailable]) {
//        NSInteger byteCount = [_fileStream read: _tmpBuffer maxLength:<#(NSUInteger)#>]
//    }
//}

- (SKPacket*)nextPacket
{
    if(_currentOffset < MAX_BUFFER_LEN && _fileStream.hasBytesAvailable) {
//        NSLog(@"_currentOffset a: %ld", (long)_currentOffset);
        NSInteger readBytes = [_fileStream read: _tmpBuffer + _currentOffset maxLength: MAX_BUFFER_LEN - _currentOffset];
        _currentOffset += readBytes;
        
//        NSLog(@"read bytes count: %ld", (long)readBytes);
//        NSLog(@"_currentOffset: %ld", (long)_currentOffset);
    }
    
    if(memcmp(_tmpBuffer, KStartCode, 4) != 0) {
        return nil;
    }
    
    if(_currentOffset >= 5) {
        uint8_t *bufferBegin = _tmpBuffer + 4;
        uint8_t *bufferEnd = _tmpBuffer + _currentOffset;
        while(bufferBegin != bufferEnd) {
            if(*bufferBegin == 0x01) {
                if(memcmp(bufferBegin - 3, KStartCode, 4) == 0) {
                    NSInteger packetSize = bufferBegin - _tmpBuffer - 3;
//                    NSLog(@"packetSize: %ld", (long)packetSize);
                    SKPacket *vp = [[SKPacket alloc] initWithSize:packetSize];
                    memcpy(vp.buffer, _tmpBuffer, packetSize);
                    
                    memmove(_tmpBuffer, _tmpBuffer + packetSize, _currentOffset - packetSize);
                    _currentOffset -= packetSize;
                    
//                    NSLog(@"km - %d, %d, %d, %d", vp.buffer[0], vp.buffer[1], vp.buffer[2], vp.buffer[3]); // 都是 0001
                    
                    return vp;
                }
            }
            ++bufferBegin;
        }
    }

    return nil;
}

@end
