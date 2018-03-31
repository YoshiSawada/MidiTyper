//
//  objCMIDIBridge.m
//  MyFirstMidi
//
//  Created by Yoshi Sawada on 2017/04/30.
//  Copyright © 2017 Yoshi Sawada. All rights reserved.
//


#import "objCMIDIBridge.h"

const UInt32 kDelta2byteLimit = 0x3fff;
const UInt32 kDelta3byteLimit = 0x1fffff;

@implementation objCMIDIBridge


-(objCMIDIBridge *)init {
    Float64 f;
    
    self = [super init];
    source = 0;
    destination = 0;
    mach_timebase_info(&machTimeBase);
    tempo = 120.0;
    ticksPerQuarter = 480;
    f = 60 / tempo / ticksPerQuarter;
    nanoPerTick = f * 1000000000;    // above line generates overflow error if I directly use nano
    nanoRatio = machTimeBase.numer / machTimeBase.denom;
    startTime = 0;
    running = false;
    pktBuffer = malloc(1024);
    bufferSize = 1024;
    dataSet = false;

    return self;
}

-(objCMIDIBridge *)initWithBufferSize:(UInt32)buffersize {
    self = [super init];
    source = 0;
    destination = 0;
    mach_timebase_info(&machTimeBase);
    tempo = 120.0;
    ticksPerQuarter = 480;
    nanoPerTick = 1000000000 / tempo / ticksPerQuarter;
    nanoRatio = machTimeBase.numer / machTimeBase.denom;
    startTime = 0;
    running = false;
    pktBuffer = malloc(buffersize);
    bufferSize = buffersize;
    dataSet = false;

    return self;
}

-(void)dealloc {
    if (pktBuffer) {
        free(pktBuffer);
    }
}

-(NSString *)getName : (MIDIObjectRef)midiObj {
    CFStringRef cfstr;

    MIDIObjectGetStringProperty(midiObj, kMIDIPropertyName, &cfstr);
    name = [NSString alloc];
    name = (NSString *)CFBridgingRelease(cfstr);

    return name;
}

-(OSStatus)ysCreateClient {
    OSStatus stat;
    
    stat = MIDIClientCreate(CFSTR("MIDITyper"), NULL, 0, &midiRefSelf);
    return stat;
}

-(OSStatus)ysCreateOutputPort {
    OSStatus stat;
    stat = MIDIOutputPortCreate(midiRefSelf, CFSTR("MIDITyperOutputPort"), &midiRefOutputPort);

    return stat;
}

-(void)setDestination: (MIDIEndpointRef) dest {
    destination = dest;
}

-(void)setTicksPerQuarter:(UInt64) tick {
    ticksPerQuarter = tick;
    nanoPerTick = 1000000000 / tempo / ticksPerQuarter;
}

-(void)setTempo:(Float64) t {
    tempo = t;
    nanoPerTick = 1000000000 / tempo / ticksPerQuarter;
}

-(uint64_t)start {    
    startTime = mach_absolute_time();
    running = true;
    
    // debug
    NSLog(@"start time = %llu", startTime);

    return startTime;
}

-(uint64_t)stop {
    running = false;
    startTime = 0;
    return mach_absolute_time();
}

-(uint64)getElapsedTicks {
    uint64_t now;
    uint64 elapsedTicks;
    
    if (running == false) {
        return 0;
    }
    now = mach_absolute_time();
    elapsedTicks = (now - startTime) * nanoRatio / nanoPerTick;
    
    return elapsedTicks;
}

-(Float64)getNanoRatio {
    return nanoRatio;
}

-(MIDIPacket *)midiPacketInit {
    pktList = (MIDIPacketList *)pktBuffer;
    pkt = MIDIPacketListInit((MIDIPacketList *)pktBuffer);
    return pkt;
}

-(MIDIPacket *)setEvent: (int)size data:(UInt8 [])data EventTime:(uint64_t)eventMachtime {
    
    UInt8 bucket[256];
    int i;
    
    for (i = 0 ; i < size ; ++i) {
        bucket[i] = data[i];
    }
    
    pkt = MIDIPacketListAdd(pktList, bufferSize, pkt, eventMachtime, size, bucket);
    // (const Byte *)&
    
    dataSet = true;
    return pkt;
}

-(void)send {
    if(dataSet == false)
        return;
    MIDISend(midiRefOutputPort, destination, pktList);
    dataSet = false;
}

// obsolute: don't use it for future program. Use setEvent() and then send() instead
-(void)sendNote: (UInt8) ch : (UInt8) note : (UInt8) vel : (uint64_t) eventtime : (uint64_t) gatetime { // time is given in the unit of ticks
    UInt8 noteOn[4];
    UInt8 noteOff[4];
    uint64_t onTime, offTime;
    
    // if note running then send notification or throw error
    
    noteOn[0] = 0x90 + ch;
    noteOn[1] = note;
    noteOn[2] = vel;
    
    noteOff[0] = 0x80 + ch;
    noteOff[1] = note;
    noteOff[2] = 0;
    
    onTime = [self ticksToMach:eventtime] + startTime;
    offTime = onTime + [self ticksToMach:gatetime];
    
    pktList = (MIDIPacketList *)pktBuffer;
    
    pkt = MIDIPacketListInit((MIDIPacketList *)pktBuffer);
    // The last parameter may necessarily be (const byte *). Not sure if I can assign local memory to it.
        // assemble packet of note on
    
    pkt = MIDIPacketListAdd(pktList, bufferSize, pkt, onTime, 3, (const Byte *)&noteOn);
        // assemble packet of note off
    pkt = MIDIPacketListAdd(pktList, bufferSize, pkt, offTime, 3, (const Byte *)&noteOff);
    
    MIDISend(midiRefOutputPort, destination, pktList);
    // debug
    NSLog(@"ontime = %llu offtime = %llu", onTime, offTime);
   
}

-(uint64_t)ticksToMach : (uint64_t) ticks {
    uint64_t t;
    
    t = ticks * nanoPerTick;
    t = t / nanoRatio;
    
    return t;
}

-(UInt32)makeDelta : (UInt32) val { // making delta value for standard MIDI file
    UInt32 delta, b1, b2;
    
    if (val <= 0x7f) { // 1 byte length delta value
        return val;
    }
    if (val <= kDelta2byteLimit) { // 2 byte length delta value
        delta = val >> 7;
        delta = 0x80 | delta;
        delta = delta << 8;
        delta = delta + (val & 0x7f);
        return delta;
    }
    if (val <= kDelta3byteLimit) { // 3 byte length delta value
        // make msb
        delta = val >> 14;
        delta = 0x80 | delta;
        delta = delta << 16;
        b1 = val >> 7;
        b1 = b1 & 0x7f;
        b1 = 0x80 | b1;
        b1 = b1 << 8;
        delta = delta + b1 + (val & 0x7f);
        return delta;
    }
    // 4 byte length delta value
        // make msb
    delta = val >> 21;
    delta = 0x80 | delta;
    delta = delta << 24;
        // make 2nd msb
    b2 = val >> 14;
    b2 = b2 & 0x7f;
    b2 = b2 | 0x80;
    b2 = b2 << 16;
        // make 3rd msb (2nd lsb)
    b1 = val >> 7;
    b1 = b1 & 0x7f;
    b1 = b1 | 0x80;
    b1 = b1 << 8;
    delta = delta + b2 + b1 + (val & 0x7f);
    return delta;
}

-(UInt32)delta2real : (UInt32) val {
    UInt32 b1, b2, b3, act;
    
    if(val <= 0x7f) {
        return val;
    }
    if (val <= 0xffff) { // if 2 byte length of delta
        val = val & 0x7f7f;
        b1 = val >> 8;
        act = (b1 << 7) + (val & 0x7f);
        return act;
    }
    if (val <= 0xffffff) { // if 3 byte length of delta
        val = val & 0x7f7f7f;
        b2 = val >> 16;
        b2 = b2 << 14;
        b1 = val >> 8;
        b1 = b1 & 0x7f;
        b1 = b1 << 7;
        act = b2 + b1 + (val & 0x7f);
        return act;
    }
    // 4 byte length of delta
    val = val & 0x7f7f7f7f;
    b3 = val >> 24;
    b3 = b3 << 21;
    b2 = val >> 16;
    b2 = b2 & 0x7f;
    b2 = b2 << 14;
    b1 = val >> 8;
    b1 = b1 & 0x7f;
    b1 = b1 << 7;
    act = b3 + b2 + b1 + (val & 0x7f);
    return act;
}

-(void)ysReceiveNotification:(void *)notifyRefcon {
    NSLog(@"MIDI Change notification Received");
}

@end

// fundtion to return NSString from CFStringRef

