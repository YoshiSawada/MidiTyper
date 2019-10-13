//
//  Document.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/02/20.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

// MARK: struct, enum etc.
//

// static declarations
let MThd:[UInt8] = [ 0x4d, 0x54, 0x68, 0x64 ]
let MTrk:[UInt8] = [ 0x4d, 0x54, 0x72, 0x6b ]

class MidiEvent: NSObject, NSCoding {
    var eventTick: Int32 = 0
    var eventStatus: UInt8 = 0
    var note: UInt8 = 0  // note number
    var vel: UInt8 = 0  // velocity
    var gateTime: Int32 = 0   // for note event only
    
    override init() {
        super.init()
    }
    
    override func copy() -> Any {
        let clone = MidiEvent(tick: eventTick, midiStatus: eventStatus, note: note, vel:vel, gateTime: gateTime)
        return clone
    }
    
    init(tick t:Int32, midiStatus ms:UInt8, note n:UInt8, vel v:UInt8, gateTime gt: Int32) {
        super.init()
        self.eventTick = t
        self.eventStatus = ms
        self.note = n
        self.vel = v
        self.gateTime = gt
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let eventTick: Int32 = aDecoder.decodeInt32(forKey: "eventTick")
        
        guard let byteData: Data = aDecoder.decodeObject(forKey: "byteData") as? Data else { return nil }
        let eventStatus = byteData[0]
        let note = byteData[1]
        let vel = byteData[2]
        
        let gateTime = aDecoder.decodeInt32(forKey: "gateTime")
        
        self.init(tick: eventTick, midiStatus: eventStatus, note: note, vel: vel, gateTime: gateTime)
    }
    
    func encode(with aCoder: NSCoder) {
        let byteData = Data.init([eventStatus, note, vel])
        aCoder.encode(eventTick, forKey: "eventTick")
        aCoder.encode(byteData, forKey: "byteData")
        aCoder.encode(gateTime, forKey: "gateTime")
    }
    
    func setEvent(tick t: Int32, midiStatus ms:UInt8, value1 v1:UInt8, value2 v2:UInt8, gateTime gt:Int32) {
        self.eventTick = t
        self.eventStatus = ms
        self.note = v1
        self.vel = v2
        self.gateTime = gt
    }
    
    func stringValue() -> (String, String, String)? {
        if eventStatus & 0x90 == 0 {
            // event is not a note. In the future this may change so it will show control changes and others
            return nil
        }
        if vel == 0 || gateTime == 0 {
            return nil
        }
        
        var octav: Int
        
        if note >= 24 {
            // octav in +
            octav = Int(note - 24) / 12
        } else {
            if Int(note) % 12 > 0 {
                octav = ((24 - Int(note)) / 12 + 1) * -1
            } else {
                octav = (24 - Int(note)) / 12 * -1
            }
        }
        
        var noteSymbol: String
        
        switch Int(note) % 12 {
        case 0:
            noteSymbol = "C"
        case 1:
            noteSymbol = "C#"
        case 2:
            noteSymbol = "D"
        case 3:
            noteSymbol = "D#"
        case 4:
            noteSymbol = "E"
        case 5:
            noteSymbol = "F"
        case 6:
            noteSymbol = "F#"
        case 7:
            noteSymbol = "G"
        case 8:
            noteSymbol = "G#"
        case 9:
            noteSymbol = "A"
        case 10:
            noteSymbol = "A#"
        default:
            noteSymbol = "B"
        }
        let notationStr = noteSymbol + String(octav)
        let velocityStr = String(vel)
        let gtStr = String(gateTime)
        
        return (notationStr, velocityStr, gtStr)
    }
}

class intermedSeqWithChannel: NSObject {
    var isPrefixCh:Bool
    var channel: UInt8
    var eventSequence:Array<MidiEvent>
    
    override init() {
        isPrefixCh = false
        channel = 0
        eventSequence = Array<MidiEvent>()
    }
    
    init(isPrefixCh isCh:Bool, channel ch:UInt8, eventSequence seq:Array<MidiEvent> ) {
        channel = ch
        eventSequence = seq
        isPrefixCh = isCh
    }
    
    override func copy() -> Any {
        let clone = intermedSeqWithChannel()
        clone.isPrefixCh = isPrefixCh
        clone.channel = channel
        
        for ev in eventSequence {
            clone.eventSequence.append(ev.copy() as! MidiEvent)
        }
        
        return clone
    }
}

class MetaEvent: NSObject, NSCoding {
    var metaTag: UInt8
    var eventTick: Int  // running / elapsed tick
    var metaLen: Int
    var data:[UInt8]
    
    override init() {
        metaTag = 0
        eventTick = 0
        metaLen = 0
        data = Array<UInt8>()
        
        super.init()
    }
    
    init(metaTag: UInt8, eventTick: Int, len:Int, data: [UInt8]) {
        self.metaTag = metaTag
        self.eventTick = eventTick
        self.metaLen = len
        self.data = Array<UInt8>.init()
        for i in 0..<metaLen {
            self.data.append(data[i])
        }
        super.init()
    }
    
    override func copy() -> Any {
        let clone = MetaEvent(metaTag: metaTag, eventTick: eventTick, len: metaLen, data: data)
        return clone
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let metaTag = aDecoder.decodeObject(forKey: "metaTag") as? UInt8 else { return nil }
        
        let eventTick = aDecoder.decodeInteger(forKey: "eventTick")
        let len = aDecoder.decodeInteger(forKey: "metaLen")
        guard let data = aDecoder.decodeObject(forKey: "data") as? [UInt8] else { return nil }
        
        self.init(metaTag: metaTag, eventTick: eventTick, len: len, data: data)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(metaTag, forKey: "metaTag")
        aCoder.encode(eventTick, forKey: "eventTick")
        aCoder.encode(metaLen,forKey: "metaLen")
        aCoder.encode(data, forKey: "data")
    }
}

class Bar: NSObject, NSCoding {
    var measNum: Int
    var timeSig:[String:Int]
    var startTick: Int
    var barLen:Int
    var nextBarTick: Int
    //var events:[MidiEvent]?
    var events:Array<MidiEvent> = Array<MidiEvent>()
    //var metaEvents:[MetaEvent]?
    var metaEvents:Array<MetaEvent> = Array<MetaEvent>()
    
    
    override init() {
        measNum = 0
        timeSig = ["num": 4, "denom":2] // standard MIDI file format. denom is power of 2, in that, for instance, 2 denotes 4
        startTick = 0
        barLen = 0
        nextBarTick = 0
        //events = Array<MidiEvent>()
        //metaEvents = Array<MetaEvent>()
        super.init()
    }
    
    init(measNum mn:Int, startTick st:Int, numerator num:Int, denominator denom:Int, ticksPerQuarter tq:Int) {
        // self.init()
        measNum = mn
        timeSig = ["num":num, "denom":denom]
        startTick = st
        barLen = (tq * 4) >> timeSig["denom"]!
        barLen *= timeSig["num"]!
        nextBarTick = startTick + barLen
        super.init()
    }
    
    init(measNum: Int, timeSig: [String : Int], startTick: Int, barLen: Int, nextBarTick: Int, events: [MidiEvent], metaEvents: [MetaEvent]) {
        self.measNum = measNum
        self.timeSig = timeSig
        self.startTick = startTick
        self.barLen = barLen
        self.nextBarTick = nextBarTick
        self.events = events
        self.metaEvents = metaEvents
        
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let measNum = aDecoder.decodeInteger(forKey: "measNum")
        guard let timeSig = aDecoder.decodeObject(forKey: "timeSig") as? [String : Int] else { return nil }
        let startTick = aDecoder.decodeInteger(forKey: "startTick")
        let barLen = aDecoder.decodeInteger(forKey: "barLen")
        let nextBarTick = aDecoder.decodeInteger(forKey: "nextBarTick")
        guard let events = aDecoder.decodeObject(forKey: "events") as? [MidiEvent] else { return nil }
        guard let metaEvents = aDecoder.decodeObject(forKey: "metaEvents") as? [MetaEvent] else { return nil }
        self.init(measNum: measNum, timeSig: timeSig, startTick: startTick, barLen: barLen, nextBarTick: nextBarTick, events: events, metaEvents: metaEvents)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(measNum, forKey: "measNum")
        aCoder.encode(timeSig, forKey: "timeSig")
        aCoder.encode(startTick, forKey: "startTick")
        aCoder.encode(barLen, forKey: "barLen")
        aCoder.encode(nextBarTick, forKey: "nextBarTick")
        aCoder.encode(events, forKey: "events")
        aCoder.encode(metaEvents, forKey: "metaEvents")
    }
    
    //func copy(with zone: NSZone? = nil) -> Any {
    override func copy() -> Any {
        let clone = Bar()
        clone.measNum = measNum
        clone.startTick = startTick
        clone.timeSig = timeSig
        clone.barLen = barLen
        clone.nextBarTick = nextBarTick
        for me in events {
            clone.events.append(me.copy() as! MidiEvent)
        }
        for metaev in metaEvents {
            clone.metaEvents.append(metaev.copy() as! MetaEvent)
        }
        
        return clone
    }
    
    func canIGetIn(elapsedTick et:Int) -> String {
        if et >= startTick && et < nextBarTick {
            return "in"
        } else if et < startTick {
            return "before"
        }
        return "after"
    }
    
    func rel2abstick(indexOfEvent i: Int) -> Int {
        if (events.count) < i - 1 {
            return 0
        }
        return Int(events[i].eventTick) + startTick
    }
    
    func add(event ev:MidiEvent, abs2rel sw:Bool) -> Int? {
        var e:MidiEvent
        e = ev
        
        if sw == true {
            // convert event tick in absolute to relative
            if self.canIGetIn(elapsedTick: Int(e.eventTick)) == "in" {
                e.eventTick = e.eventTick - Int32(self.startTick)
            } else {
                return nil
            }
        } else {
            if e.eventTick < self.startTick || e.eventTick >= self.nextBarTick {
                return nil
            }
        }
        self.events.append(e)
        return Int(e.eventTick)
    }
    
    func beatAndTick(fromAbsTick atick: Int) -> (beat: Int?, tick: Int?) {
        if timeSig["num"] == nil || timeSig["denom"] == nil {
            return (nil, nil)
        }
        let rel = atick - self.startTick
        let ticksPerBeat = self.barLen / self.timeSig["num"]!
        let beat = rel / ticksPerBeat
        if beat >= timeSig["num"]! {
            return (nil, nil)
        }
        let tick = rel - (beat * ticksPerBeat)
        
        return (beat, tick)
    }
    
    func beatAndTick(fromRelTick rtick: Int) -> (beat: Int?, tick: Int?) {
        if timeSig["num"] == nil || timeSig["denom"] == nil {
            return (nil, nil)
        }
        let ticksPerBeat = barLen / timeSig["num"]!
        let beat = rtick / ticksPerBeat
        if beat >= timeSig["num"]! {
            return (nil, nil)
        }
        let tick = rtick - ticksPerBeat * beat
        return (beat, tick)
    }
    
    func relTick(fromBeat beat: Int, andTick tick: Int) -> Int? {
        var relTick: Int
        
        if timeSig["num"] == nil {
            return nil
        }
        
        let ticksPerBeat = barLen / timeSig["num"]!
        relTick = ticksPerBeat * beat + tick
        return relTick
    }
    
    func timeSigIn2Int() -> (num: Int, denom: Int) {
        if timeSig["num"] == nil || timeSig["denom"] == nil {
            return (4, 2)
        }
        return (timeSig["num"]!, timeSig["denom"]!)
    }
    
    func sort() {
        if events.count <= 1 { return }
        
        let reorderedEvents:Array<MidiEvent>? = self.events.sorted(by: { $0.eventTick < $1.eventTick })
        if reorderedEvents != nil {
            events = reorderedEvents!
        }
    }
}

class Track: NSObject, NSCoding {
    
    var bars: Array<Bar>?
    var curPos: Int
    var play:Bool
    var dirty:Bool  // shows the order of bars may not be aligned
    var lhIndexPtr, rhIndexPtr:Int
    var playChannel:UInt8?
    var serializedTrack: UnsafeMutableRawPointer
    let defaultSerialzedTrackSize: Int = 1024
    let dataSizeIncrement: Int = 1024
    var serializedTrackSize: Int    // Not include 8 bytes header
    var smfTrackSize: UInt32 { // UInt32 track size for SMF in swapped byte order
        get {
            return CFSwapInt32(UInt32(serializedTrackSize))
        }
    }
    private var curMemSize: Int
    private var offset: Int // later it may also be used to know the size

    
    override init() {
        bars = Array<Bar>()
        curPos = 0
        play = true
        dirty = false
        lhIndexPtr = 0
        rhIndexPtr = 0
        playChannel = 0
        serializedTrack = UnsafeMutableRawPointer.allocate(byteCount: defaultSerialzedTrackSize, alignment: 1)
        curMemSize = defaultSerialzedTrackSize
        offset = 0
        serializedTrackSize = 0
        super.init()
    }
    
    init(pc: UInt8, barsArray: [Bar] ) {
        curPos = 0
        play = true
        dirty = false
        lhIndexPtr = 0
        rhIndexPtr = 0
        
        self.playChannel = pc
        self.bars = barsArray
        serializedTrack = UnsafeMutableRawPointer.allocate(byteCount: defaultSerialzedTrackSize, alignment: 1)

        curMemSize = defaultSerialzedTrackSize
        offset = 0
        serializedTrackSize = 0

        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let bars = aDecoder.decodeObject(forKey: "bars") as? [Bar] else { return nil }
        let pc = aDecoder.decodeObject(forKey: "playChannel") as! UInt8
        self.init(pc: pc, barsArray: bars)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(bars, forKey: "bars")
        aCoder.encode(playChannel, forKey: "playChannel")
    }
    
    override func copy() -> Any {
        let clone = Track()
        clone.curPos = curPos
        clone.play = play
        clone.dirty = dirty
        clone.lhIndexPtr = lhIndexPtr
        clone.rhIndexPtr = rhIndexPtr
        clone.playChannel = playChannel
        
        if bars != nil {
            for bar in bars! {
                clone.bars?.append(bar.copy() as! Bar)
            }
        }

        return clone
    }
    
    func sort () {
        let reordered:Array<Bar>? = self.bars?.sorted(by: {$0.measNum < $1.measNum})
        if reordered != nil {
            bars = reordered
            dirty = false
        }
    }
    
    func index(forMeas meas:Int) -> Int? {
        if bars == nil {
            return nil
        }
        let i = bars!.firstIndex(where: {$0.measNum == meas})
        return i
    }
    
    // if Expandable == true then adding bar(s) by copying the last bar as the template
    // return value is index
    func findBar (tick absTick:Int?, Expandable exp:Bool) -> Int? {
        if bars == nil || absTick == nil {
            return nil
        }
        let reply = bars![curPos].canIGetIn(elapsedTick: absTick!)
        
        switch reply {
        case "in":
            return curPos
        case "after":
            for i in curPos..<bars!.count {
                if bars![i].canIGetIn(elapsedTick: absTick!) == "in" {
                    curPos = i
                    return i
                }
            }
            if exp == false { // If Expandable is false, then return
                return nil  // no more bar
            }
            // given tick is beyond the bars in template
            repeat {
                let i = bars!.count
                let lastBar = bars![i-1]
                // var bar = Bar()
                let bar = Bar()
                bar.measNum = lastBar.measNum + 1
                bar.timeSig = lastBar.timeSig
                bar.startTick = lastBar.nextBarTick
                bar.nextBarTick = lastBar.nextBarTick+lastBar.barLen
                bar.barLen = lastBar.barLen
                bars?.append(bar)
            } while absTick! >= (bars?.last?.nextBarTick)!
            if bars == nil {
                return nil
            }
            curPos = (bars?.last?.measNum)!
            return bars!.last?.measNum
            
        case "before":
            var i:Int = curPos
            while i >= 0 {
                if bars![i].canIGetIn(elapsedTick: absTick!) == "in" {
                    curPos = i
                    return i
                }
                i -= 1
            }
            // otherwise something wrong
            return nil
        default:
            return nil
        }
    }
    
    func ticksForMeas(zeroBaseMeas meas:Int, Expandable ext: Bool) -> Int? {
        if bars == nil {
            bars = Array<Bar>()
        }
        if meas < bars!.count {
            return bars![meas].startTick
        } else if ext == true {
            // make new empty bars
            if bars!.count == 0 {
                return nil
            }
            
            repeat {
                let i = bars!.count
                let lastBar = bars![i-1]
                // var bar = Bar()
                let bar = Bar()
                bar.measNum = lastBar.measNum + 1
                bar.timeSig = lastBar.timeSig
                bar.startTick = lastBar.nextBarTick
                bar.nextBarTick = lastBar.nextBarTick+lastBar.barLen
                bar.barLen = lastBar.barLen
                bars?.append(bar)
            } while bars!.count <= meas
            
            return bars![meas].startTick
        }
        return nil
    }
    
    func makeTrackChunk(del: AppDelegate) -> Void {
        // note off array
        var prevTick: UInt32 = 0
        offset = 0
        
        struct noteOff {
            var tick: UInt32
            var channel: UInt8
            var note: UInt8
            var used: Bool
            
            init(tick: UInt32, ch: UInt8, note: UInt8) {
                self.tick = tick
                self.channel = ch
                self.note = note
                self.used = false
            }
        }
        
        var noteOffArray: [noteOff] = Array<noteOff>.init()
        
        if bars == nil {
            return
        }
        
        // put track chunk label
        for i in 0...3 {
            serializedTrack.storeBytes(of: MTrk[i], toByteOffset: offset, as: UInt8.self)
            offset += 1
        }
        
        // skip the tracksize field now
        offset += 4
        
        // write playback channel
        var chMeta: [UInt8] = [0x0, 0xff, 0x20, 0x01, 0x00]
        chMeta[4] = playChannel ?? 0
        for i in 0...4 {
            serializedTrack.storeBytes(of: chMeta[i], toByteOffset: offset, as: UInt8.self)
            offset += 1
        }
        
        var noteonTick: UInt32
        
        // debug
        var cntBarLoop = 0
        
        for bar in bars! {
            let barBeginTick: UInt32 = UInt32(bar.startTick)
            for ev in bar.events {
                
                // debug
                cntBarLoop += 1
                
                noteonTick = barBeginTick + UInt32(ev.eventTick)
                
                // see if any note off should come before the note on
                for i in 0..<noteOffArray.count {
                    let nf = noteOffArray[i]
                    if nf.tick <= noteonTick {
                        // add the note off first
                        let delta = nf.tick - prevTick
                        let (deltastream, c) = del.makeDelta(tick: delta)
                        verifyMemorySize(del: del, need: c+3)
                        for j in 0...c-1 {
                            serializedTrack.storeBytes(of: deltastream[j], toByteOffset: offset, as: UInt8.self)
                            offset += 1
                        }
                        prevTick = nf.tick
                            // flag it to mark it to delete
                        // I must access to noteOffArray[i] directly
                        // rather than nf as I change the value inside.
                        noteOffArray[i].used = true
                        
                        // add note off in serialized memory
                        serializedTrack.storeBytes(of: nf.channel | 0x80, toByteOffset: offset, as: UInt8.self)
                        offset += 1
                        serializedTrack.storeBytes(of: nf.note, toByteOffset: offset, as: UInt8.self)
                        offset += 1
                        serializedTrack.storeBytes(of: 0, toByteOffset: offset, as: UInt8.self)
                        offset += 1
                    }
                } // end of noteoff array loop
                
                // delete marked noteoff
                    // start from the last subscript number to zero
                    // as we delete element as we go
                var remainToCheck = noteOffArray.count
                if remainToCheck > 0 {
                    remainToCheck = remainToCheck - 1 // convert it to subscript val
                    
                    while remainToCheck >= 0 {
                        if noteOffArray[remainToCheck].used == true {
                            noteOffArray.remove(at: remainToCheck)
                        }
                        remainToCheck = remainToCheck - 1
                    }
                }
                
                // put note off in array
                let noteoff = noteOff.init(tick: noteonTick+UInt32(ev.gateTime), ch: ev.eventStatus & 0x0f, note: ev.note)
                noteOffArray.append(noteoff)
                noteOffArray = noteOffArray.sorted(by: {$0.tick < $1.tick})
                
                // make delta value for note on
                let delta = noteonTick - prevTick
                let (deltaStream, c) = del.makeDelta(tick: delta)
                verifyMemorySize(del: del, need: c+3)
                for i in 0...c-1 {
                    serializedTrack.storeBytes(of: deltaStream[i], toByteOffset: offset, as: UInt8.self)
                    offset += 1
                }
                prevTick = noteonTick
                
                // add note on to serialized memory
                serializedTrack.storeBytes(of: ev.eventStatus | 0x80, toByteOffset: offset, as: UInt8.self)
                offset += 1
                serializedTrack.storeBytes(of: ev.note, toByteOffset: offset, as: UInt8.self)
                offset += 1
                serializedTrack.storeBytes(of: ev.vel, toByteOffset: offset, as: UInt8.self)
                offset += 1

            } // end of events loop
            // add note off if there's any
            noteOffInBar: for j in 0..<noteOffArray.count {
                let noff = noteOffArray[j]
                if noff.tick < bar.nextBarTick {
                    let delta = noff.tick - prevTick
                    let (deltastream, c) = del.makeDelta(tick: delta)
                    verifyMemorySize(del: del, need: c+3)
                    for i in 0...c-1 {
                        serializedTrack.storeBytes(of: deltastream[i], toByteOffset: offset, as: UInt8.self)
                        offset += 1
                    }
                    prevTick = noff.tick
                    // add note off event in serialezed memory
                    serializedTrack.storeBytes(of: noff.channel | 0x80, toByteOffset: offset, as: UInt8.self)
                    offset += 1
                    serializedTrack.storeBytes(of: noff.note, toByteOffset: offset, as: UInt8.self)
                    offset += 1
                    serializedTrack.storeBytes(of: 0, toByteOffset: offset, as: UInt8.self)
                    offset += 1
                    // mark it that it be used
                    noteOffArray[j].used = true
                }
                else {
                    break noteOffInBar
                }

            }   // end of loop to add the rest of note offs if any

            // delete used noteoff in stack
            let noteOffArrayCount = noteOffArray.count
            // we cannot write for k in 0..<noteOffArray.count
            // as we remove items in the array in the loop
            for k in 0..<noteOffArrayCount {
                let subsc = noteOffArrayCount - k - 1
                if noteOffArray[subsc].used == true {
                    noteOffArray.remove(at: subsc)
                }
            } // end of loop to delete used note off
            
        } // end of loop for bar
        
        // write end of track meta event
        let endOfTrack: [UInt8] = [0xff, 0x2f, 0x00]
        verifyMemorySize(del: del, need: 3)
        for i in 0...2 {
            serializedTrack.storeBytes(of: endOfTrack[i], toByteOffset: offset, as: UInt8.self)
            offset += 1
        }
        
        // write track chunk size
        var ui32: UInt32
        ui32 = UInt32(offset)
        serializedTrackSize = Int(ui32)
        ui32 = ui32 - 8 // less header size
        ui32 = CFSwapInt32(ui32)
        
        serializedTrack.storeBytes(of: ui32, toByteOffset: 4, as: UInt32.self)
        
    } // end of function make SMF track chunk
    
    func deinitialize() -> Void {
        serializedTrack.deallocate()
    }
    
    private func verifyMemorySize(del: AppDelegate, need: Int) -> Void {
        if offset + need > curMemSize {
            serializedTrack = del.expandRawPointerMemory(srcPtr: serializedTrack, srcSize: curMemSize, newSize: curMemSize+dataSizeIncrement)
            curMemSize += dataSizeIncrement
        }
    }
} // end of Track

let tagSequenceNumber:UInt8 = 0
let tagTextEvent:UInt8 = 1
let tagCopyRight:UInt8 = 2
let tagTrackName:UInt8 = 3
let tagInstrumentName:UInt8 = 4
let tagLyrics:UInt8 = 5
let tagMarker:UInt8 = 6
let tagCuePoint:UInt8 = 7
let tagMIDIChannelPrefix:UInt8 = 0x20
let tagEndOfTrack:UInt8 = 0x2f
let tagTempo:UInt8 = 0x51
let tagSmpteOffset:UInt8 = 0x54
let tagTimeSignature:UInt8 = 0x58
let tagKey:UInt8 = 0x59
let tagProprietaryEvent:UInt8 = 0x7f

struct SongLocation {
    // all are zero based
    var meas: Int
    var beat: Int
    var tick: Int
    var relTick: Int
    var absTick: Int
    
    init() {
        meas = 0
        beat = 0
        tick = 0
        relTick = 0
        absTick = 0
    }
}

// MARK: Supplemental class
//

struct TempoMap {
    var beginTick: Int
    var beginNanoTime: __uint64_t   // nano time. Yes, really...
    var nanoPerTick: __uint64_t
    
    init() {
        beginTick = 0
        beginNanoTime = 0
        nanoPerTick = 1041667   // initialize it to tempo 120
    }
    
    init(beginTick bt:Int, beginNanoTime bnt: __uint64_t, nanoPerTick npt: __uint64_t) {
        beginTick = bt
        // tempo = tmp
        beginNanoTime = bnt
        nanoPerTick = npt
    }
    
    func getTempo(ticksPerQuarter tpq:Int) -> Double {
        let nanoPerQuarter:Double = Double(tpq) * Double(nanoPerTick)
        return 1000000000 * 60 / nanoPerQuarter
    }
}

// MARK: class MidiData
//

class MidiData: NSDocument {

    enum MidiDataError: Error {
        case InitializeError(String)
    }
    
    // vars for SMF
    var curPtr: Int = 0
    var headerLength: Int?
    var formatType: UInt16?
    var numOfTracks: Int? {
        get {
            return tracks?.count
        }
    }
    var ticksPerQuarter: UInt16?    // essential information only given by original file at given time.
    var trackStartPtr: Int?
    var title: String?
    
    var smfWholeChunk: SMFBuffer
    
    
    // class vars
    //var refNum: Int = 0 // ID for this instance. Given from app delegate
    
    var SMF: UnsafeMutableRawPointer?
    var barSeqTemplate: Track = Track()
    var commonTrackSeq: Array<MetaEvent>? = []
    var tracks: Array<Track>?
    var isNew: Bool
    var isRemapNeed: Bool
    
    // intermediate data
    var eventSeqs: Array<intermedSeqWithChannel> = [] // array of track of event seq
    var track:Track?
    
    // seq vars
    var curElapsedTick: Int
    var nextMeasNum: Int
    var monitor: MonitorCenter?
    var isAnydata : Bool {
        get {
            if commonTrackSeq == nil {
                return false
            }
            if commonTrackSeq!.count < 1 {
                return false
            }
            return true
        }
    }
    
    
    let del: AppDelegate?
    let nc = NotificationCenter.default
    var viewCon: ViewController?

    // MARK: MidiData Functions
    
    override init() {
        isNew = true
        curElapsedTick = 0
        nextMeasNum = 0
        //  numOfTracks = 1
        tracks = Array<Track>()
        
        // initialize tracks
        let aBar = Bar.init(measNum: 0, startTick: 0, numerator: 4, denominator: 2, ticksPerQuarter: 480)
        
        let aTrack = Track()
        aTrack.bars?.append(aBar)
        tracks?.append(aTrack)
        ticksPerQuarter = 480
        
        // initialize commonTrackSeq (collection of meta event)
        var aData: [UInt8] = Array<UInt8>.init(repeating: 0, count: 4)
        
            // tempo 120 -> 500k microsec per quarter note
        aData[0] = 0x07
        aData[1] = 0xa1
        aData[2] = 0x20
        let metaTempo = MetaEvent.init(metaTag: tagTempo, eventTick: 0, len: 3, data: aData)
        
            // time sig 4/4
        aData[0] = 4
        aData[1] = 2
        aData[2] = 0x18
        aData[3] = 0x08
        let metaTimeSig = MetaEvent.init(metaTag: tagTimeSignature, eventTick: 0, len: 4, data: aData)
        
            // Midi channel prefix
        aData[0] = 0x0
        let metaChannel = MetaEvent.init(metaTag: tagMIDIChannelPrefix, eventTick: 0, len: 1, data: aData)
        
            // End of Track
        aData[0] = 0
        let metaEnd = MetaEvent.init(metaTag: tagEndOfTrack, eventTick: 1920, len: 1, data: aData)
        
        commonTrackSeq?.append(metaTempo)
        commonTrackSeq?.append(metaTimeSig)
        commonTrackSeq?.append(metaChannel)
        commonTrackSeq?.append(metaEnd)
        
        // initialize barseqTemplate
            // if possible, barSeqTemplate should be made in the function
            // of makeBarSeq(). But I cannot call class function in init()
            // Thus I'm initializing barSeqTemplate manually.
        barSeqTemplate.bars?.append(aBar.copy() as! Bar)
        
        del = NSApplication.shared.delegate as? AppDelegate
        if del != nil {
            monitor = MonitorCenter(midiIF: del!.objMidi)
        }
        
        smfWholeChunk = SMFBuffer.init(memSize: 1024, incSize: 1024)
        isRemapNeed = false
        
        super.init()
        // Add your subclass-specific initialization here.
        let ret = buildTempoMap()
        if ret == false {
            Swift.print("MidiData cannot initialize the tempomap")
        }
        nc.post(name: ntUntitledDocumentCreated, object: self)
    }
    
    convenience init(type: MidiData) throws {
        self.init()
        if numOfTracks == nil {
            throw MidiDataError.InitializeError("Error in creating untitled Midi Data")
        }
    }
    

    override class var autosavesInPlace: Bool {
        return false
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(ticksPerQuarter, forKey: "ticksPerQuarter")
    }
    
    func deinitialize() -> Void {
        smfWholeChunk.deinitialize()
        if tracks == nil {
            return
        }
        
        for tr in tracks! {
            tr.deinitialize()
        }
    }
    
    
    func buildTempoMap() -> Bool {
        if commonTrackSeq?.count == 0 {
            return false
        }
        
        var nanoPerTick: __uint64_t
        
        monitor!.resetTempoMap()
        
        for meta in commonTrackSeq! {
            switch meta.metaTag {
            case tagTempo:
                nanoPerTick = metaTempoToNanoPerQuarter (metaEvent: meta)!
                nanoPerTick = nanoPerTick/480
                
                monitor!.addTempoMapElement(eventTick: meta.eventTick, nanoPerTick: nanoPerTick)
            default:
                continue
            }
        }
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        self.addWindowController(windowController)
        
        // setup MidiEventEditor
        // get main ViewController
        viewCon = windowController.window?.contentViewController as? ViewController
        if viewCon == nil {
            del?.displayAlert("Cannot instantiate MidiEvent View")
        }

        windowController.window?.makeKeyAndOrderFront(self)
        
        let nc = NotificationCenter.default
        nc.post(name: ntDocumentViewDidPrepared, object: self)
    }
    
    func makeEventEditor() throws -> Void {
        do {
            try viewCon!.loadSong(midiData: self)
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

        if typeName == "com.ysawada.MidiTyper" {
            if numOfTracks ?? 0 > 0 {
                entrySerializedToSmf()
                let aData = Data.init(bytes: smfWholeChunk.bufPointer, count: smfWholeChunk.endPoint)
                return aData
            }
        }

        
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
//        Swift.print("given typeName = \(typeName)")
//        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
//        data.copyBytes(to: ptr, count: 4)
//        Swift.print("SMF header = \(ptr)")
        
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        switch typeName {
        case "mid", "MIDI audio":
            do {
                try openSMF(owner: self, from: url)
                if monitor?.prepare2Play(barseqtemp: barSeqTemplate, tracks: tracks!) == false {
                    del?.displayAlert("prepare2Play failed")
                }

                title = url.lastPathComponent

                // isNew must be placed before makeWindowControllers
                // because makeWindowsControllers invokes notification
                // to a function where it sees if isNew is set
                isNew = false
                
                makeWindowControllers()

                do {
                    try makeEventEditor()
                }
                
                showWindows()

                let nc = NotificationCenter.default
                nc.post(name: ntDocumentOpened, object: self)
            }
            
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: unknownFormatErr, userInfo: nil)
        }
        Swift.print("Succeed to read SMF")
    }
    
    func entrySerializedToSmf() -> Void {
        
        guard tracks != nil else {
            del?.displayAlert("No Trackdata")
            return
        }
        
        // clean up the memory if necessary
        if smfWholeChunk.endPoint != 0 {
            smfWholeChunk.deinitialize()
            smfWholeChunk = SMFBuffer.init()
        }
        
        for tr in tracks! {
            if tr.serializedTrackSize != 0 {
                tr.serializedTrack.deallocate()
                tr.serializedTrack = UnsafeMutableRawPointer.allocate(byteCount: tr.defaultSerialzedTrackSize, alignment: 1)
            }
        }
        
        // Make the main header
        smfWholeChunk.append(array: MThd)
        // header size
        smfWholeChunk.swapAndWrite4ByteInt(at: 4, data: UInt32(6))
        // SMF format type 1
        smfWholeChunk.swapAndWrite2ByteInt(at: 8, data: UInt16(1))
        // number of tracks
        let ntrks = (numOfTracks ?? 0) + 1
        smfWholeChunk.swapAndWrite2ByteInt(at: 10, data: UInt16(ntrks))
        // ticksPerQuarter
        smfWholeChunk.swapAndWrite2ByteInt(at: 12, data: ticksPerQuarter ?? UInt16(480))
        _ = smfWholeChunk.seek(pos: 14)
        
        // make 1st track
        let metaTrack = makeMetaEventTrackChunk(owner: self)
        smfWholeChunk.append(chunk: metaTrack)
        
        // append midi event tracks here
        // cnt is added to debug
        var cnt: Int = 0
        
        for tr in tracks! {
            // smfWholeChunk.appen(tr.serializedTrack)
            tr.makeTrackChunk(del: del!)
            smfWholeChunk.append(buffer: tr.serializedTrack, size: tr.serializedTrackSize)
            
            // debug
            cnt += 1
        }
        
    }
    
    // MARK: playing functions
    
    func start(_ sender: Any)  {
        if monitor == nil { return }
// Block below moved to read(..) in MidiData
        //        if monitor?.prepare2Play(barseqtemp:barSeqTemplate, tracks:tracks!) == false {
//            del?.displayAlert("failed to start the sequence")
//            return
//        }
        // monitor!.isPlayable must be called after .prepare2Play
        // because some data must be set up beforehand
        if monitor!.isPlayable == false { return }
        
        monitor?.startEntry()
    }
    
    func stop() {
        do {
            try monitor?.stop()
        } catch {
            del?.errorHandle(err: error as! ysError)
        }
    }
    
    func rewind() {
        do {
            try monitor?.rewind()
        } catch { del?.errorHandle(err: error as! ysError) }
    }
    
    func toggle(_ sender: Any) {
        monitor?.toggle(self)
    }
    
    func locate(bar: Int, beat: Int, clock: Int) throws {
        if monitor == nil {
            let nc = NotificationCenter.default
            let str = String("Midi Interface doesn't seem to be valid")
            nc.post(name: ntInvalidLocation, object: str)
        }

        let result = try monitor?.locate(byBar: bar, beat: beat, clock: clock)
        
        if result == nil {
            let nc = NotificationCenter.default
            nc.post(name: ntInvalidLocation, object: String("Specified location is not valid"))
        }
    }
    
    override open class var readableTypes: [String] {
        return ["com.ysawada.MidiTyper", "mid", "MIDI audio"]
    }

    // MARK: Midi Process functions
    //
    
    // Call this function in zero based values
    func advance(by: Int, meas: Int, beat: Int, tick: Int) -> SongLocation? {
        var newLoc = SongLocation.init()
        let bar: Bar?
        
        // get the template bar of current location
        let ix = barSeqTemplate.index(forMeas: meas)
        if ix == nil {
            bar = barTemplate(forZerobaseMeas: meas)
        } else {
            bar = barSeqTemplate.bars![ix!]
        }
        if bar == nil {
            return nil
        }
        
        let tickPerBeat = bar!.barLen / bar!.timeSig["num"]!
        let relTick = tickPerBeat * beat + tick + by    // tick of new location
        
        if relTick < bar!.barLen {  // new location is in the current bar
            newLoc.meas = meas
            var bt, tk: Int
            
            (bt, tk) = bar!.beatAndTick(fromRelTick: relTick) as! (Int, Int)
            newLoc.beat = bt
            newLoc.tick = tk
            newLoc.absTick = bar!.startTick + relTick
            newLoc.relTick = relTick
        } else { // new location goes beyond the current bar
            let absTick = bar!.startTick + relTick
            let newIndex = barSeqTemplate.findBar(tick: absTick, Expandable: true)
            if newIndex == nil { return nil }
            let newBarTemp = barSeqTemplate.bars![newIndex!]
            newLoc.meas = newBarTemp.measNum

            let newRelTick = absTick - newBarTemp.startTick
            (newLoc.beat, newLoc.tick) = newBarTemp.beatAndTick(fromRelTick: newRelTick) as! (Int, Int)
            newLoc.absTick = absTick
            newLoc.relTick = newRelTick
        }
        
        return newLoc
    }
    
    
    internal func metaTempoToNanoPerQuarter (metaEvent meta: MetaEvent?) -> __uint64_t? {
        // meta tempo denotes microsec per quarter
        //
        
        if meta == nil {
            return nil
        }
        if meta!.metaTag != tagTempo {
            return nil
        }
        
        var nanosecPerquarter = __uint64_t(meta!.data[0]) * 0x10000 + __uint64_t(meta!.data[1]) * 0x100 + __uint64_t(meta!.data[2])
        // nanosecPerquarter is microsecPerquarter at this point yet
        nanosecPerquarter *= 1000  // make it nanosec
        
        return nanosecPerquarter
    }
    
    internal func makeBarSeq () throws {
        
        var err = ysError(source: "MidiData", line: 746, type: ysError.errorID.SMFParse)
        
        if commonTrackSeq == nil || monitor == nil {
            err.line = 749
            throw err
        }
        
        if (commonTrackSeq?.count)! < 1 {
            err.line = 754
            throw err
        }
                
        var meta: MetaEvent?
        var it = commonTrackSeq!.makeIterator()
        var done: Bool = false
        var timeSigs = Array<Dictionary<String, Int>>.init(repeating: ["num":4, "denom":2], count: 2) // a pair of bucket to read and write time sig
        var curTick: Int = 0
        var measCount: Int = 0
        var endOfTrack: Int = 0
        var n: Int = 0  // subscript to write in timeSigs
        var m: Int = 1  // reading subcript for timeSigs
        var timeSigCount: Int = 0
        var tsToBeUsed:Dictionary<String, Int>?
        
        // erase track
        barSeqTemplate.bars?.removeAll()
        endOfTrack = (commonTrackSeq?.last?.eventTick)!
        
        curElapsedTick = 0
        // going through commonTrackSeq
        point1: while done == false {
            
            // make two consecutive time sig in time line
            meta = it.next()
            if meta == nil {
                done = true
            }
            if meta?.metaTag != tagTimeSignature {
                if meta?.metaTag == tagEndOfTrack {
                    done = true
                    curElapsedTick = endOfTrack
                    // time sig that should be used is the other one from [n]
                    m = n
                    tsToBeUsed = ["num": (timeSigs[m]["num"])!, "denom": (timeSigs[m]["denom"])!]
                    _ = createBars(fromTick: curTick, TotTick: endOfTrack, startMeas: measCount, timesig: tsToBeUsed)
                }
                continue point1
            }
            // now the meta is time signature
            curElapsedTick = (meta?.eventTick)!
            
            if (curElapsedTick > curTick) {
                timeSigCount += 1
                if timeSigCount > 1 {
                    if n == 0 {
                        n += 1  // push index
                        //continue point1
                        m = 0   // pop index to be used when encounter with the end of track
                    } else {
                        n = 0
                        m = 1
                    }
                }
                timeSigs[n] = ["num": Int((meta?.data[0])!), "denom": Int((meta?.data[1])!)]
            } else { // curElapsedTick == curTick, which means another time sig at the same tick count
                // except we have always the same values between them when we have the first time sig
                if timeSigCount == 0 {
                    timeSigCount = 1
                }
                timeSigs[n] = ["num": Int((meta?.data[0])!), "denom": Int((meta?.data[1])!)]
                // if this is the case, continue reading the next time sig or EoT without making bars
                continue point1
            }
            
            
            if timeSigCount < 2 {
                continue point1
            }
            
            // we have had two time signatures.
            
            // at this point we have two filled timesig, which should be the only one
            // make bars between the pair of time sig then continue reading next time sig
            // meta event is all read, make bars to that point and finish the loop
            // Bar creation may better be sub function.
            
            tsToBeUsed = timeSigs[m]
            
            let res = createBars(fromTick: curTick, TotTick: curElapsedTick, startMeas: measCount, timesig: tsToBeUsed)
            measCount = res.reachedMeas
            curTick = (barSeqTemplate.bars?[measCount - 1].nextBarTick)!
            
        }
    } // end of makeBarSeq()
    
    private func createBars(fromTick fromt: Int, TotTick tot: Int, startMeas sm: Int, timesig ts:Dictionary<String, Int>?) -> (ret:Bool, reachedMeas:Int) {
        var traveled: Int = 0
        var curMeas: Int = sm
        
        if ts == nil {
            return (ret:false, reachedMeas:0)
        }
        
        if fromt > tot {
            return (ret:false, reachedMeas:0)
        }
        
        while (fromt + traveled) < tot {
            let bar = Bar.init(measNum: curMeas, startTick: fromt + traveled, numerator: (ts?["num"]!)!, denominator: (ts?["denom"]!)!, ticksPerQuarter: Int(ticksPerQuarter!))
            barSeqTemplate.bars?.append(bar)
            traveled += bar.barLen
            curMeas += 1
        }
        return (ret:true, reachedMeas:curMeas) // place holder
    }
    
    // Return a copy of bar template for meas(zero base).
    // It will create bar template if necessary
    func barTemplate(forZerobaseMeas meas: Int) -> Bar? {
        let x = barSeqTemplate.index(forMeas: meas)
        if x != nil { // bar template exists. Return the copy of it
            return barSeqTemplate.bars![x!].copy() as? Bar
        }
        // based on the time sig of the last bar, extend the length
        // of the song and make bar template.
        let lastBar = barSeqTemplate.bars?.last
        let lastMeas = lastBar?.measNum
        if lastMeas == nil { return nil }
        // make new bars from last Meas to the specified meas
        var startTick4Bar = lastBar!.nextBarTick
        for i in lastMeas! + 1...meas {
            let bar = Bar.init(measNum: i, startTick: startTick4Bar, numerator: lastBar!.timeSig["num"]!, denominator: lastBar!.timeSig["denom"]!, ticksPerQuarter: Int(ticksPerQuarter!))
            barSeqTemplate.bars!.append(bar.copy() as! Bar)
            startTick4Bar = bar.nextBarTick
        }
        
        isRemapNeed = true
        
        return barSeqTemplate.bars!.last!.copy() as? Bar
        // Before playback the song. I have to update TrackTable in play.swift
    }
    
    func willEndEditing() {
        // rebuild commonTrackSeq
        
        if isRemapNeed == false {
            _ = monitor!.prepare2Play(barseqtemp: barSeqTemplate, tracks: tracks!)
            _ = monitor!.isPlayable
            return
        }

        var error = ysError.init(source: "MidiData", line: 1400, type: ysError.errorID.RebuildingCommonTrackSeq)
        
        // First remove time signature and tempo currently in existing commonTrackSeq
        if commonTrackSeq == nil {
            error.line = 1404
            del!.errorHandle(err: error)
            return
        }

        // rebuild commonTrackSeq. First I will create a temp array
        // Then I'll replace commonTrackSeq with the temp one.
        // and sort them
        
        var tmpCommonSeq = Array<MetaEvent>()
        
        for meta in commonTrackSeq! {
            if meta.metaTag == tagTempo {
                continue
            }
            if meta.metaTag == tagTimeSignature {
                continue
            }
            tmpCommonSeq.append(meta.copy() as! MetaEvent)
        }
        
        if monitor == nil {
            error.line = 1430
            del!.errorHandle(err: error)
            return
        }
        if barSeqTemplate.bars == nil {
            error.line = 1435
            del!.errorHandle(err: error)
            return
        }
        // Midi data has to have initial tempo and time signature in the first
        // two event.
        // Unless we have those, we can not convert time domain from
        // bar, beat, clock to elapsed tick
        
        // We must read through Time Signature first and then tempo
        var latchedTS = (0, 0)
        var data:[UInt8] = [4, 2, 24, 8]
        
        for bar in barSeqTemplate.bars! {
            if bar.measNum == 0 {
                latchedTS = bar.timeSigIn2Int()
                // add time sig meta event to commonTrackSeq
                data[0] = UInt8(latchedTS.0)
                data[1] = UInt8(latchedTS.1)
                let ts = MetaEvent.init(metaTag: tagTimeSignature, eventTick: 0, len: 4, data: data)
                tmpCommonSeq.append(ts)
                continue
            }
            if bar.timeSigIn2Int() != latchedTS {
                let (n, d) = bar.timeSigIn2Int()
                data[0] = UInt8(n)
                data[1] = UInt8(d)
                let ts = MetaEvent.init(metaTag: tagTimeSignature, eventTick: bar.startTick, len: 4, data: data)
                tmpCommonSeq.append(ts)
                latchedTS = bar.timeSigIn2Int()
            }
        }
        
        // read through tempo
        
        for t in monitor!.tempoMapSeq {
            let npt: __uint64_t = t.nanoPerTick
            let npq = npt * UInt64(ticksPerQuarter!)
            let microsecPerQuarter = npq / 1000
            
            // convert UInt64 to UInt32 and then to array of UInt8
            var i32_1: UInt32 = UInt32(microsecPerQuarter)

            i32_1 = i32_1 & 0x00ffffff
            var i32_2 = i32_1 >> 16
            
            data[0] = UInt8(i32_2)
            
            i32_2 = i32_1 >> 8
            i32_2 = i32_2 & 0x000000ff
            data[1] = UInt8(i32_2)
            
            i32_2 = i32_1 & 0x000000ff
            data[2] = UInt8(i32_2)
            
            // put it into meta event
            let meta = MetaEvent.init(metaTag: tagTempo, eventTick: t.beginTick, len: 3, data: data)
            tmpCommonSeq.append(meta.copy() as! MetaEvent)
            
        }
        // start writing here
        // sort meta event seq
            // not sure if this will work out...
        commonTrackSeq = tmpCommonSeq.sorted(by: {
            if $0.eventTick <= $1.eventTick {
                return true
            } else {
                return false
            }
         } )
        
        // it is not necessary to call buildTempoMap because
        // TSTViewController rebuild tempomap every time the user changes
        // tempo
//        if buildTempoMap() == false {
//            error.line = 1519
//            del!.errorHandle(err: error)
//            return
//        }
        
        if makeTrackTable(MidiData: self) == false {
            error.line = 1532
            del!.errorHandle(err: error)
            return
        }
        
        isRemapNeed = false
        if monitor!.prepare2Play(barseqtemp: barSeqTemplate, tracks: tracks!) == false {
            error.line = 1534
            del!.errorHandle(err: error)
            return
        }
        _ = monitor!.isPlayable
    }


} // end of MidiData class



