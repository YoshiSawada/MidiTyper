//
//  objCBridge.h
//  MyFirstMidi
//
//  Created by Yoshi Sawada on 2017/05/07.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

#ifndef objCMIDIBridge_h
#define objCMIDIBridge_h
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#include <mach/mach.h>
#include <mach/mach_time.h>


#endif /* objCBridge_h */




@interface objCMIDIBridge : NSObject
{
    char    *pktBuffer;
    MIDIPacketList  *pktList;
    MIDIPacket  *pkt;
    int     bufferSize;
    NSString *name;
    MIDIClientRef midiRefSelf;
    MIDIPortRef midiRefOutputPort;
    MIDIEndpointRef destination;
    MIDIEndpointRef source;
    struct mach_timebase_info machTimeBase;
    UInt64 ticksPerQuarter;
    Float64 tempo;
    Float64 nanoRatio;
    uint64_t nanoPerTick;
    uint64_t    startTime;
    Boolean running;
    Boolean dataSet;
}

-(objCMIDIBridge *)init;
-(objCMIDIBridge *)initWithBufferSize: (UInt32) buffersize;
-(void)dealloc;
-(NSString *)getName:(MIDIObjectRef)midiObj;
-(OSStatus)ysCreateClient;
-(OSStatus)ysCreateOutputPort;
-(void)setDestination: (MIDIEndpointRef) dest;
-(void)setTempo: (Float64) t;
-(void)setTicksPerQuarter: (UInt64) tick;
-(uint64_t)start;
-(uint64_t)stop;
-(uint64_t)getElapsedTicks;
-(Float64)getNanoRatio;
-(MIDIPacket *)midiPacketInit;
-(MIDIPacket *)setEvent: (int)size data:(UInt8 *)data EventTime:(uint64_t)eventtime;
-(void)send;
-(void)sendNote: (UInt8) ch : (UInt8) note : (UInt8) vel : (uint64_t) eventtime : (uint64_t) gatetime;
-(uint64_t)ticksToMach : (uint64_t) ticks;
-(UInt32)makeDelta : (UInt32) val;
-(UInt32)delta2real : (UInt32) val;
-(void)ysReceiveNotification:(void *)notifyRefcon;

@end
