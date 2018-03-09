//
//  Player.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/10/04.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Foundation

var trackTable: Array<TrackMap>?
let DeferNanoTime:__uint64_t = 50000000 // 50msec
let PlayTimeWindow:__uint64_t = 500000000   // 500msec

class TrackMap {
    var trackIndex:Int = 0
    var index = [Int]()     // subscription index for bar within track seq
    var hasBar = [Bool]()
    
    init(trackIndex:Int, barLength:Int) {
        self.trackIndex = trackIndex
        index.reserveCapacity(barLength)
        hasBar.reserveCapacity(barLength)
        for _ in 0..<barLength {
            self.index.append(0)
            self.hasBar.append(false)
        }
    }
    
    func setElement(meas:Int, index:Int, hasBar:Bool) {
        self.index[meas] = index
        self.hasBar[meas] = hasBar
    }
}

class MonitorCenter {
    // declarations
    let nc = NotificationCenter.default
    var objMidi:objCMIDIBridge? = nil
    var isTempoInitialized: Bool = false
    var isTimeSigInitialized: Bool = false
    var curTimeSig: Dictionary<String, Int> = ["num":4, "denom":2]
    var isOrderOfBarDirty: Bool = false
    let nanoRatio: Double
    let ticksPerQuarter: Int
    var tempoMapSeq:Array<TempoMap> = Array<TempoMap>()
    var isTempoMapDirty = false
    var midiEventQueue:Array<midiRawEvent> = Array<midiRawEvent>()
    var noteOffQueue:Array<midiRawEvent> = Array<midiRawEvent>()
    var barSeqTemplate: Track = Track()
    var isBarSeqTemplateInitialized = false
    var lhBar, rhBar: Int
    var nanoAtStart:__uint64_t = 0
    var nanoNextTime:__uint64_t = 0
    var isPlayable: Bool {
        get {
            if tracksForPlay == nil { return false }
            if tempoMapSeq.count == 0 { return false }
            if isTempoInitialized == false { return false }
            if isTimeSigInitialized == false { return false }
            if objMidi == nil { return false }
            if barSeqTemplate.bars == nil { return false }
            if isBarSeqTemplateInitialized == false { return false }
            if trackTable == nil { return false
            } else if trackTable!.count == 0 { return false }

            return true
        }
    }
    var playing: Bool = false
    var didStop: Bool = false
    var didReachEnd: Bool = false
    var tracksForPlay:Array<Track>?
    
    
    struct midiRawEvent {
        let size:Int
        var data:[UInt8] = [0, 0, 0, 0]
        let machtime:__uint64_t
        var mark:Bool
        
        init(size:Int, data:[UInt8], machtime:__uint64_t) {
            self.size = size
            for i in 0..<size {
                self.data[i] = data[i]
            }
            self.machtime = machtime
            self.mark = false
        }
    }
    
    private var curIndexInTempoMap:Int = 0
    
    //  Monitor Center Functions   ------------------------------------
    init (ticksPerQuarter tq: Int, nanoRatio nr: Double) {
        ticksPerQuarter = tq
        nanoRatio = nr
        lhBar = 0
        rhBar = 0
        midiEventQueue.reserveCapacity(64)
        noteOffQueue.reserveCapacity(64)
    }
    
    // To play, call functions in the order of, beforePlayback and playEntry()
    // start() will be called from play()
    // repeat calling queue2Play.
    // In calling queue2Play repeatedly, set lhmt to the value of nanoNextTime
    // to make sure no event will be missed to play
    
    func beforePlayback(midiIF:objCMIDIBridge, barseqtemp:Track, tracks:Array<Track>) -> Bool {
        // error checks should be done here instead of doing so every time in
        // queue2play or playingthread
        barSeqTemplate = barseqtemp
        tracksForPlay = tracks

        if tracksForPlay!.count == 0 {
            return false
        }

        objMidi = midiIF
        barSeqTemplate = barseqtemp
        tracksForPlay = tracks
        noteOffQueue.removeAll(keepingCapacity: true)
        midiEventQueue.removeAll(keepingCapacity: true)
        lhBar = 0
        rhBar = 0
        isBarSeqTemplateInitialized = true
        for i in 0..<tracksForPlay!.count {
            tracksForPlay![i].lhIndexPtr = 0
            tracksForPlay![i].rhIndexPtr = 0
        }
        return true
    }
    
    // this function is supposed to be called from play()
    //  Setting up nanoAtStart, nanoNextTime
    //  Checking tracksForPlay and trackTable
    private func setAndGo() -> Array<midiRawEvent>? {
        if self.isPlayable == false {
            print("isPlayable == false")
            return nil
        }
        nanoAtStart = mach_absolute_time() + DeferNanoTime
        nanoNextTime = nanoAtStart
        
        let eventqueue = self.queue2Play()

        didReachEnd = false
        return eventqueue
    }
    
    func playEntry() {
        _ = objMidi?.midiPacketInit()
        let eventqueue = self.setAndGo()
        if eventqueue == nil {
            // debug
            print("eventqueue from start returns nil")
            return
        }
        for event in eventqueue! {
            var ev = event
            // debug: check to see if the byte order is correct in &ev.data
            _ = objMidi?.setEvent(Int32(event.size), data: &ev.data, eventTime: event.machtime)
        }
        objMidi?.send()
        
        // call playing thread and continue to play
        //  Maybe I should put some adaptive playback algorithm to synchronize is time
        playingThread()
    }
    
    
    // Machtime should be given in absolute base. That way we can share the time window in synch.
    //
    private func queue2Play() -> Array<midiRawEvent>? {   // return events array

        // lhMachtime and rhMachtime must be converted to relative time to the start of song in this function
        let now = mach_absolute_time()
        if nanoNextTime > now {
            if nanoNextTime - now > 750000000 { // if we are too fast, skip one time slot
                return nil
            }
        }
        let lhmach = nanoNextTime - nanoAtStart
        var rhmach:__uint64_t
        
        if now > nanoNextTime { // behind the time, catch up..
            rhmach = lhmach + PlayTimeWindow + (now - nanoNextTime)
        } else if nanoNextTime - now > 1000000000 { // or if we're running a bit ahead
            rhmach = lhmach + 250000000 // Narrower the time window down to 0.25ms
        } else {
            rhmach = lhmach + PlayTimeWindow
        }
        nanoNextTime = rhmach + nanoAtStart // convert it to abslute time
        
        let lhTick = getTick(byMachtime: lhmach)
        let rhTick = getTick(byMachtime: rhmach)
        
        midiEventQueue.removeAll(keepingCapacity: true)
        // find lhbar and rhbar
        //
        //
        let lhbar = barSeqTemplate.findBar(tick: lhTick, Expandable: false)
        var rhbar = barSeqTemplate.findBar(tick: rhTick, Expandable: false)
        
        if lhbar == nil && rhbar == nil {
            self.playing = false
            return nil  // considered no more data
        }
        if rhbar == nil {
            rhbar = lhbar!  // nearly end of the song
        }

        for i in 0..<tracksForPlay!.count {
            if tracksForPlay![i].play == false {
                continue
            }
            for j in lhbar!...rhbar! {
                if trackTable![i].hasBar[j] == false {
                    continue
                }
                let ix = trackTable![i].index[j]
                // explore event in the time window
                if tracksForPlay![i].bars![ix].events.count == 0 {
                    continue
                }
                
                for k in 0..<tracksForPlay![i].bars![ix].events.count {
                    let ev = tracksForPlay![i].bars![ix].events[k]
                    let tick = tracksForPlay![i].bars![ix].rel2abs(indexOfEvent: k)
                    if (tick >= lhTick!) && (tick < rhTick!) {
                        // push the event to midi playback stack
                        
                        if (ev.eventStatus & UInt8(0x90)) == UInt8(0x90) {
                            // prepare note off event first
                            // tick has abs value
                            let noteOffTick = tick + Int(ev.gateTime)
                            let noteOffMachtime = self.machTime(byTick: noteOffTick)! + nanoAtStart
                            var stat = ev.eventStatus
                            // adjust midi channel if I have channel prefix
                            if tracksForPlay![i].playChannel != nil {
                                stat = stat & 0xf0
                                stat = stat | tracksForPlay![i].playChannel!
                            }
                            stat = stat & UInt8(0x0f)
                            stat = UInt8(0x80) | stat
                            // assemble midi data context
                            let data:[UInt8] = [stat, ev.note, UInt8(0)]
                            let noteOff:midiRawEvent = midiRawEvent.init(size:3, data:data, machtime: noteOffMachtime)
                            noteOffQueue.append(noteOff)    // don't forget reorder later
                        }
                        // put midi event in queue
                        
                        // create another array of midiRawEvent.
                        // combine note on and note off in the array and return it so
                        // the play thread can play the elements in it.
                        // this way, I can solve the access confliction between threads
                        let datasize:Int
                        var data:[UInt8]
                        switch ev.eventStatus {
                        case 0x90...0xbf:
                            datasize = 3
                            data = [ev.eventStatus, ev.note, ev.vel]
                        case 0xc0...0xdf:
                            datasize = 2
                            data = [ev.eventStatus, ev.note]
                        case 0xe0...0xef:
                            datasize = 3
                            data = [ev.eventStatus, ev.note, ev.vel]
                        default:
                            // this is not actually note but the length of data
                            // not supported at this time
                            //datasize = Int(ev.note)+2
                            datasize = 3
                            data = [ev.eventStatus, ev.note, ev.vel]
                            // debug
                            print("status > 0xf0. this should not happen")
                        }
                        let elaptick = tracksForPlay![i].bars![ix].startTick + Int(ev.eventTick)
                        let machtime = self.machTime(byTick: elaptick)! + nanoAtStart
                        
                        // adjust channel if I have channel prefix
                        // assuming all data are channel voice messages
                        if tracksForPlay![i].playChannel != nil {
                            data[0] = data[0] & 0xf0    // mask channel
                            data[0] = data[0] | tracksForPlay![i].playChannel!
                        }
                        let midiev = midiRawEvent.init(size: datasize, data: data, machtime: machtime)
                        midiEventQueue.append(midiev)
                    }// closure of tick timewindow
                } // closure of k loop
            }// closure of j loop
            // merge noteoffqueue into midiEventQueue, and sort it
        } // closure of i loop

        for j in 0..<noteOffQueue.count {
            if (noteOffQueue[j].machtime >= lhmach + nanoAtStart) && (noteOffQueue[j].machtime < nanoNextTime) {
                midiEventQueue.append(noteOffQueue[j])
                noteOffQueue[j].mark = true
            }
        }
        // clean up used note off event queue
            // need to change. iterate index won't work
        var cleanedNoteOffQueue = Array<midiRawEvent>()
        cleanedNoteOffQueue.reserveCapacity(64)
        for ev in noteOffQueue {
            if ev.mark == false {
                cleanedNoteOffQueue.append(ev)
            }
        }
        noteOffQueue = cleanedNoteOffQueue
        // sort midi event queue and make final midi raw event queue
        let playbackqueue = midiEventQueue.sorted(by: {$0.machtime < $1.machtime})
        
        return playbackqueue
    }   // end of queue2Play
    
    func playingThread() {
        // spawn thread
        playing = true
        didStop = false

        DispatchQueue.global(qos: .userInitiated).async {
            var i:Int = 0   // debug
            var j:Int = 0   // debug
            
            repeat {
                let now = mach_absolute_time()
                if self.nanoNextTime < now {
                    // this point may be the entry of contine play
                    let behind = now - self.nanoNextTime + 50000000
                    self.nanoNextTime = now + 50000000  // add 50ms margin
                    self.nanoAtStart = self.nanoAtStart + behind
                    print("\(behind)nano:behind")
                }
                if self.nanoNextTime - now < 500000000 {
                    let evQueue = self.queue2Play()
                    if evQueue != nil {
                        _ = self.objMidi?.midiPacketInit()
                        if evQueue!.count > 0 {
                            for ev in evQueue! {
                                var vev = ev
                                _ = self.objMidi?.setEvent(Int32(ev.size), data: &vev.data, eventTime: ev.machtime)
                            }
                            self.objMidi?.send() // sending notes
                        }
                    }
                }
                // debug start
                i += 1
                if i == 39 {
                    j = j + 1
                    print("thread is playing \(j) sec")
                    i = 0
                }   // debug end
                
                Thread.sleep(forTimeInterval: 0.025)
            } while self.playing == true

            DispatchQueue.main.async {
                print("thread finished")
                if self.didStop == false { // if isStopped == false then
                            // the song should have reached the end
                    self.didReachEnd = true
                    self.nc.post(name: ntEndReached, object: self)
                }
                
            }

        }   // end of the thread
        

    }   // end of playingThread
    
    func stop() {
        // flush out note off event right now
        
        self.playing = false
        self.didStop = true
        
        if noteOffQueue.count == 0 {
            return
        }
        
        let i64 = nanoNextTime + 10000000   // send note offs 10ms later than
                                        // the last event on queue
        let d:Double = Double(i64) * nanoRatio
        let miditime:__uint64_t = __uint64_t(d)
        
        _ = self.objMidi?.midiPacketInit()
        for event in noteOffQueue {
            var ev = event
            // debug: check to see if the byte order is correct in &ev.data
            
            _ = objMidi?.setEvent(Int32(event.size), data: &ev.data, eventTime: miditime)
        }
        objMidi?.send()

    } // end of stop function

    
    func getTick(byMachtime mt:__uint64_t) -> Int? {
        if tempoMapSeq.count == 0 {
            return nil
        }
        for i in 0..<tempoMapSeq.count {
            if tempoMapSeq[i].beginNanoTime > mt {
                if i == 0 {
                    return nil
                }
                let ofsNano = mt - tempoMapSeq[i-1].beginNanoTime
                let ofsTick = ofsNano / tempoMapSeq[i-1].nanoPerTick
                return tempoMapSeq[i-1].beginTick + Int(ofsTick)
            }
        }
        // if I reach here then I should apply the last element in tempoMapSeq
        let ofsNano = mt - tempoMapSeq.last!.beginNanoTime
        let ofsTick = ofsNano / tempoMapSeq.last!.nanoPerTick
        return tempoMapSeq.last!.beginTick + Int(ofsTick)
    }
    
    func resetTempoMap () {
        if tempoMapSeq.count > 0 {
            tempoMapSeq.removeAll()
        }
    }
    
    // This function is called by openUrl and creation of tempo data along with
    // resetTempoMap()
    func addTempoMapElement(eventTick tick:Int, nanoPerTick npt:__uint64_t) {
        let beginNanoTime:__uint64_t
        if tempoMapSeq.count == 0 {
            beginNanoTime = 0
        } else {
            let sectionTicks:__uint64_t = __uint64_t(tick - (tempoMapSeq.last?.beginTick)!) // tick count between this tempo and previous tempo
            let elapsedNanoTime = (tempoMapSeq.last?.nanoPerTick)! * sectionTicks
            beginNanoTime = (tempoMapSeq.last?.beginNanoTime)! + elapsedNanoTime
        }
        let tm = TempoMap(beginTick:tick, beginNanoTime:beginNanoTime, nanoPerTick:npt)
        tempoMapSeq.append(tm)
    }   // end of addTempoMapElement
    
    func reorderTempMapSeq() {
        if isTempoMapDirty == false {
            return
        }
        let map = tempoMapSeq.sorted(by: {$0.beginNanoTime < $1.beginNanoTime})
        tempoMapSeq = map
    }
    
    func machTime(byTick tick: Int) -> __uint64_t? {
        if tempoMapSeq.count == 0 {
            return nil
        }
        
        var hit:Int = 0
        var macht:__uint64_t
        
        if curIndexInTempoMap > tempoMapSeq.count - 1 {
            curIndexInTempoMap = 0
        }
        
        for i in curIndexInTempoMap..<tempoMapSeq.count {
            if tick <= tempoMapSeq[i].beginTick {
                if i > 0 {
                    if curIndexInTempoMap == i {
                        // Given tick is before the tick in previous event.
                        // reset curIndexTempoMap and call itself again
                        curIndexInTempoMap = 0
                        return machTime(byTick: tick)
                    }
                    hit = i - 1
                    break
                } else { // if index == 0
                    // tick count in tempoMapSeq[0] should not be greater than 0
                    if tempoMapSeq[0].beginTick < 0 {
                        return nil
                    }
                }
            } else {
                if i == tempoMapSeq.count - 1 {
                    // Did search till the end. The last tempo should apply
                    hit = i
                }
            }
        }
        
        let sectionTick = tick - tempoMapSeq[hit].beginTick
        macht = tempoMapSeq[hit].beginNanoTime + __uint64_t(sectionTick) * tempoMapSeq[hit].nanoPerTick
        let scaled:Double = Double(macht) * nanoRatio
        curIndexInTempoMap = hit
        return __uint64_t(scaled)
    } // end of machTime

}   // end of class MonitorCenter


func makeTrackTable(MidiData md:MidiData) -> Bool {
    if trackTable != nil {
        trackTable?.removeAll()
    }
    
    let numOfBars:Int? = md.barSeqTemplate.bars?.count
    
    if numOfBars == nil {
        return false
    }
    
    
    trackTable = Array<TrackMap>()
    trackTable?.reserveCapacity(md.numOfTracks)
    if trackTable == nil {
        return false
    }
    // setting up Bool table for track to play
    for i in 0..<md.numOfTracks {
        let trackMap = TrackMap(trackIndex: i, barLength: numOfBars!)
        for b in 0..<numOfBars! {
            let m = md.tracks![i].index(forMeas: b)
            if m == nil {
                trackMap.setElement(meas: b, index: 0, hasBar: false)
            } else {
                trackMap.setElement(meas: b, index: m!, hasBar: true)
            }
        }
        trackTable!.append(trackMap)
    }
    let sortedTrackTable = trackTable!.sorted(by: {$0.trackIndex < $1.trackIndex})
    trackTable = sortedTrackTable
    
    
    return true
}   // end of makeTrackTable


