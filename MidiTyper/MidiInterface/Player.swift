//
//  Player.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/10/04.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Foundation
import Cocoa

var trackTable: Array<TrackMap>?
let DeferNanoTime:__uint64_t = 50000000 // 50msec
let PlayTimeWindow:__uint64_t = 100000000   // 100msec
let PlayingThreadInterval: TimeInterval = 0.025 // double in sec, 25ms

enum PlayEngineStatus {
    case NotReady
    case ReadyToPlay
    case Playing
    case Pause
    case Finished
}

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

struct PlayHead {
    var relMach: __uint64_t
    var absMach: __uint64_t
    var nextTick: Int?
    
    init() {
        relMach = 0
        absMach = 0
        nextTick = 0
    }
}

class MonitorCenter {
    // declarations
    let nc = NotificationCenter.default
    var objMidi:objCMIDIBridge? = nil
    var isTempoInitialized: Bool {
        get {
            if tempoMapSeq.count > 0 {
                return true
            } else {
                return false
            }
        }
    }
    var isTimeSigInitialized: Bool = false
    var curTimeSig: Dictionary<String, Int> = ["num":4, "denom":2]
    var isOrderOfBarDirty: Bool = false
    let nanoRatio: Double
    // let ticksPerQuarter: Int
    var tempoMapSeq:Array<TempoMap> = Array<TempoMap>()
    var isTempoMapDirty = false
    var midiEventQueue:Array<midiRawEvent> = Array<midiRawEvent>()
    var noteOffQueue:Array<midiRawEvent> = Array<midiRawEvent>()
    var barSeqTemplate: Track = Track()
    var isBarSeqTemplateInitialized = false
    var lhBar, rhBar: Int
//    var nanoAtStart: __uint64_t = 0
//    var nanoNextTime: __uint64_t = 0
//    var nanoPlayhead: __uint64_t = 0
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
    // status monitor
    var playing: Bool = false
    var didStop: Bool = false
    var didReachEnd: Bool = false
    var status: PlayEngineStatus
    
    // main data to play
    var tracksForPlay:Array<Track>?
    
    // midi data with machtime
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
    
    var playhead: PlayHead
    
    var isPlayingTimeLocked: Bool
    let del: AppDelegate?
    private var curIndexInTempoMap:Int = 0
    
    //MARK:  Monitor Center Functions
    //init (ticksPerQuarter tq: Int, nanoRatio nr: Double) {
    init(midiIF:objCMIDIBridge) {
        objMidi = midiIF
        //ticksPerQuarter = tq
        nanoRatio = objMidi!.getNanoRatio()
        lhBar = 0
        rhBar = 0
        status = PlayEngineStatus.NotReady
        midiEventQueue.reserveCapacity(64)
        noteOffQueue.reserveCapacity(64)
        isPlayingTimeLocked = false
        del = NSApplication.shared.delegate as? AppDelegate
        playhead = PlayHead()
    }
    
    // MARK: Locator control

    func toggle(_ sender: Any) {
        switch status {
        case PlayEngineStatus.ReadyToPlay:
            startEntry()
        case PlayEngineStatus.Playing:
            do {
                try stop()
            } catch {
                del?.errorHandle(err: error as! ysError)
            }
        case PlayEngineStatus.Pause:
            contPlay()
        case PlayEngineStatus.Finished:
            do {
                try rewind()
            } catch { del?.errorHandle(err: error as! ysError) }
            
            playingThread()
        default:
            return
        }
    }
    
    // To play, call functions in the order of, prepare2Play and startEntry()
    // startEntry calls setAndGo() and then call playingThread.
    // Then it repeats calling queue2Play.
    // In calling queue2Play repeatedly, set lhmt to the value of nanoNextTime
    // to make sure no event will be missed to play
    
    // beforePlayback configures pointers and prepare to play. This function doesn't setup any
    // realtime timer. Timers and counters are set in setAndGo that is called from playEntry
    func prepare2Play(barseqtemp:Track, tracks:Array<Track>) -> Bool {
        // error checks should be done here instead of doing so every time in
        // queue2play or playingthread
        barSeqTemplate = barseqtemp
        tracksForPlay = tracks

        if tracksForPlay!.count == 0 {
            return false
        }

        // objMidi = midiIF
        barSeqTemplate = barseqtemp
        isBarSeqTemplateInitialized = true
        playhead.absMach = 0
        playhead.relMach = 0
        playhead.nextTick = 0
        // rewind()
        return true
    }
    
    func startEntry() {
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

        playingThread()
    }

    func stop() throws {
        // flush out note off event right now
        
        
        switch status {
        case PlayEngineStatus.Playing:
            if noteOffQueue.count == 0 {
                return
            }
            try flushNoteOff()
            self.playing = false
            self.didStop = true
            status = PlayEngineStatus.Pause
            nc.post(name: ntStopped, object: self)
        default:
            return
        }
    } // end of stop function
    
    func rewind() throws {
        switch status {
        case PlayEngineStatus.Playing:
              try stop()
//            lhBar = 0
//            rhBar = 0
//            for tr in tracksForPlay! {
//                tr.lhIndexPtr = 0
//                tr.rhIndexPtr = 0
//            }
            status = PlayEngineStatus.ReadyToPlay
            playhead.relMach = 0
            playhead.absMach = 0
            playhead.nextTick = 0
            // debug 4/14 no need
            //nanoPlayhead = 0
        case PlayEngineStatus.Pause, PlayEngineStatus.Finished:
//            lhBar = 0
//            rhBar = 0
//            for tr in tracksForPlay! {
//                tr.lhIndexPtr = 0
//                tr.rhIndexPtr = 0
//            }
            status = PlayEngineStatus.ReadyToPlay
            playhead.relMach = 0
            playhead.absMach = 0
            playhead.nextTick = 0
            // debug 4/14 no need
            //nanoPlayhead = 0
        default:    // if not ready
            return
        }
    }
    
    func contPlay() -> Void {
        playhead.absMach = mach_absolute_time() + DeferNanoTime
        // debug 4/14 no need
        //nanoAtStart = nanoNextTime - nanoPlayhead
        playingThread()
    }
    
    // take song position pointer value, set the location,
    //  and return elapsed tick from the start
    func locate(byF2H songPointer: Int) throws -> (meas: Int?, beat: Int?, tick: Int?) {
        let elapsedMidiClock = songPointer * 6
        
        guard let ticksPerQuater: Int = getTicksPerQuarter() else {
            return (nil, nil, nil)
        }
        
        let ticksPerMidiclock = ticksPerQuater / 24
        if ticksPerMidiclock < 1 {
            print("The song has too coarse ticks per quarter to locate by song position pointer")
            return (nil, nil, nil)
        }
        
        let elapsedTicks = elapsedMidiClock * ticksPerMidiclock
        
        // locate to elapsedTicks
        guard let aMachtime = machTime(byTick: elapsedTicks, min: nil) else {
            return (nil, nil, nil)
        }
        
        // find what bar, beat and clock
        guard let measnum = barSeqTemplate.findBar(tick: elapsedTicks, Expandable: false) else {
            return (nil, nil, nil)
        }
        
        guard let barindex = barSeqTemplate.index(forMeas: measnum) else {
            return (nil, nil, nil)
        }
        let bar = barSeqTemplate.bars![barindex]
        
        let tickStartOfBar = bar.startTick
        var offsetTicksInBar = elapsedTicks - tickStartOfBar
        if offsetTicksInBar == 0 {
            // it's sharp begininng of the bar
            return (meas: measnum, beat: 0, tick: 0)
        }
        let denom = 2 << bar.timeSig["denom"]!
        let beat = offsetTicksInBar / (getTicksPerQuarter()! * 4 / denom)
        offsetTicksInBar = offsetTicksInBar % (getTicksPerQuarter()! * 4 / denom)
        
        try flushNoteOff()
        
        playhead.relMach = aMachtime
        playhead.absMach = mach_absolute_time() + DeferNanoTime
        playhead.nextTick = getTick(byMachtime: aMachtime)!
        // debug 4/14 no need
        // nanoAtStart = nanoAtStart - nanoPlayhead

        return (meas: measnum, beat: beat, tick: offsetTicksInBar)
    }
    
    
    // Take bar number and beat number and locate to it. Return elapsedTick value
    func locate(byBar: Int, beat: Int, clock: Int) throws -> Int? {
        
        var elapsedTick: Int
        let nc = NotificationCenter.default
        
        if byBar == 0 || beat == 0 {
            nc.post(name: ntInvalidLocation, object: String("bar or beat is = 0"))
            return nil
        }
        
        if barSeqTemplate.bars == nil {
            return nil
        }
        
        if (barSeqTemplate.bars?.count)! < byBar {
            // debug
            print("specified bar is out of range")
            return nil
        }
        
        guard let bar = barSeqTemplate.bars?[byBar - 1] else {
            return nil
        }
        elapsedTick = bar.startTick
        
        guard let beatTick = getTicksPerQuarter() else {
            return nil
        }
        
        var factor: Double
        factor = Double(1 << bar.timeSig["denom"]!)
        factor = 4 / factor

        elapsedTick += beatTick * (beat-1) * Int(factor)
        elapsedTick += clock
        
        guard let machtime = machTime(byTick: elapsedTick, min: nil) else {
            return nil
        }
        
        try flushNoteOff()
        playhead.relMach = machtime
        playhead.absMach = mach_absolute_time() + DeferNanoTime
        playhead.nextTick = getTick(byMachtime: machtime)!

        return elapsedTick
    }

    
    // MARK: Private functions and thread
    
    // this function is supposed to be called from play()
    //  Setting up nanoAtStart, nanoNextTime
    //  Checking tracksForPlay and trackTable
    private func setAndGo() -> Array<midiRawEvent>? {
        if self.isPlayable == false {
            print("isPlayable == false")
            return nil
        }
        playhead.absMach = mach_absolute_time() + DeferNanoTime
        playhead.relMach = 0
        playhead.nextTick = 0
        // debug 4/14 no need
        //nanoNextTime = nanoAtStart
        
        let eventqueue = self.queue2Play()
        
        didReachEnd = false
        return eventqueue
    }
    
    // Machtime should be given in absolute base. That way we can share the time window in synch.
    //
    private func queue2Play() -> Array<midiRawEvent>? {   // return events array

        guard playhead.nextTick != nil else {
            return nil
        }
        
        let now = mach_absolute_time()
        if playhead.absMach > now {
            if playhead.absMach - now > PlayTimeWindow { // if we are too fast, 100ms ahead,skip one time slot
                return nil
            }
        }
        let lhRelmach = playhead.relMach
        var rhRelmach:__uint64_t
        
        if now > playhead.absMach { // behind the time, catch up..
            rhRelmach = lhRelmach + PlayTimeWindow + (now - playhead.absMach)
        } else if playhead.absMach - now > PlayTimeWindow { // or if we're running a bit ahead
            rhRelmach = lhRelmach + PlayTimeWindow/2 // Narrower the time window down to half the time window
        } else {
            rhRelmach = lhRelmach + PlayTimeWindow
        }
        
        let lhTick = playhead.nextTick!
        let rhTick = getTick(byMachtime: rhRelmach)
        
        midiEventQueue.removeAll(keepingCapacity: true)
        // find lhbar and rhbar
        //
        //
        let lhbar = barSeqTemplate.findBar(tick: lhTick, Expandable: false)
        var rhbar = barSeqTemplate.findBar(tick: rhTick, Expandable: false)
        
        if lhbar == nil && rhbar == nil {
            self.playing = false
            status = PlayEngineStatus.Finished
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
                    let tick = tracksForPlay![i].bars![ix].rel2abstick(indexOfEvent: k)
                    if (tick >= lhTick) && (tick < rhTick!) {
                        // push the event to midi playback stack
                        //
                        if (ev.eventStatus & UInt8(0x90)) == UInt8(0x90) {
                            // prepare note off event first
                            // tick has the running value from the beggining of the song
                            
                            let noteOffTick = tick + Int(ev.gateTime)
                            let noteOffMachtime = self.machTime(byTick: noteOffTick, min: lhRelmach)! - lhRelmach + playhead.absMach
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
                        let machtime = self.machTime(byTick: elaptick, min: lhRelmach)! - lhRelmach + playhead.absMach
                        
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
            if noteOffQueue[j].machtime >= playhead.absMach && noteOffQueue[j].machtime < playhead.absMach + (rhRelmach - lhRelmach) {
                midiEventQueue.append(noteOffQueue[j])
                noteOffQueue[j].mark = true
            } else {
                noteOffQueue[j].mark = false
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
        
        // debug
         print("lhbar:\(String(describing: lhbar)) rhbar:\(String(describing: rhbar))")
        
        // for midiEv in playbackqueue {
        //
        //  print(String(format: "st:%2x note:%2x vel:%2x", midiEv.data[0], midiEv.data[1], midiEv.data[2]))
        // }
        
        // update playhead
        playhead.absMach = rhRelmach - lhRelmach + playhead.absMach
        playhead.relMach = rhRelmach
        playhead.nextTick = rhTick
        return playbackqueue
    }   // end of queue2Play
    
    func playingThread() {
        // spawn thread
        playing = true
        didStop = false

        status = PlayEngineStatus.Playing
        nc.post(name: ntPlaying, object: self)

        DispatchQueue.global(qos: .userInitiated).async {
            var i:Int = 0   // debug
            var j:Int = 0   // debug
            
            repeat {
                self.isPlayingTimeLocked = true
                
                let now = mach_absolute_time()
                if self.playhead.absMach < now {
                    // this point may be the entry of contine play
                    let behind = now - self.playhead.absMach + 50000000
                    // self.playhead.absMach = now + 50000000  // add 50ms margin
                    self.playhead.absMach += behind
                    print("\(behind)nano:behind")
                }
                if self.playhead.absMach - now < PlayTimeWindow {
                    let evQueue = self.queue2Play()
                    if evQueue != nil {
                        _ = self.objMidi?.midiPacketInit()
                        if evQueue!.count > 0 {
                            for ev in evQueue! {
                                // debug
                                // print(String(format: "in thread, %2x, %2x, %2x", ev.data[0],ev.data[1],ev.data[2]))
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
                
                self.isPlayingTimeLocked = false
                Thread.sleep(forTimeInterval: PlayingThreadInterval)
                
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
    
    func flushNoteOff() throws {
        if status != .Playing {
            return
        }
        
        var i = 0
        while isPlayingTimeLocked == true {
            Thread.sleep(forTimeInterval: PlayingThreadInterval/2)
            if i > 5 {
                let err = ysError(source: "Player.swift", line: 702, type: .timeoutForSemaphor)
                throw err
            }
            i += 1
        }
        // flush note off
        let i64 = playhead.absMach + 5000000   // send note offs 5ms later than
        // the last event on queue
        let d:Double = Double(i64) * nanoRatio
        let miditime:__uint64_t = __uint64_t(d)
        
        _ = self.objMidi?.midiPacketInit()
        for event in noteOffQueue {
            var ev = event
            _ = objMidi?.setEvent(Int32(event.size), data: &ev.data, eventTime: miditime)
        }
        objMidi?.send()
    } // end of fulushNoteOff() function

    //MARK: Sub functions
    //
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
    
    func getTicksPerQuarter() -> Int? {
        // Get ticksPerQuarter from barSeqTemplate
        if barSeqTemplate.bars == nil { return nil }
        if barSeqTemplate.bars!.count == 0 { return nil }
        
        let bar = barSeqTemplate.bars![0]
        let barlen = bar.barLen
        var factor: Double
        factor = Double(1
            << bar.timeSig["denom"]!)
        factor = factor / 4
        
        let d = Double(barlen / bar.timeSig["num"]!) * factor
        let ticksPerQuarter = Int(d)
        
        return ticksPerQuarter
    }
    
    // Take elapsed tick value
    // and return offset machtime from the start of the song
    // Note: due to the rounding error in converting from double to __uint64_t,
    // it sometimes generate smaller value than expected.
    // That is a problem where, for instance, I expect the machtime corresponding
    // to the begining of the bar or lhRelmach in queue2play because the event may miss
    // To prevent the problem, I have min parameter so it won't be smaller than it.
    func machTime(byTick tick: Int, min: __uint64_t?) -> __uint64_t? {
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
                        return machTime(byTick: tick, min:min)
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
        var mt = __uint64_t(scaled)
        if min != nil {
            mt = mt < min! ? min! : mt
        }

        return mt
    } // end of machTime
    
    func tempo(atTick tick: Int, ticksPerQ tpq: Int) -> Double? {
        guard tempoMapSeq.count > 0 else {
            return nil
        }
        if curIndexInTempoMap > tempoMapSeq.count - 1 {
            curIndexInTempoMap = 0
        }
        
        let indexBeforeProcess = curIndexInTempoMap
        var hitIndex: Int?
        var ipoint: Int = 0
        
        for i in curIndexInTempoMap..<tempoMapSeq.count {
            ipoint = i
            hitIndex = nil
            
            if tempoMapSeq[i].beginTick > tick {
                if i == indexBeforeProcess {
                    // curIndexInTempoMap is beyond the point of interest
                    curIndexInTempoMap = 0
                    return tempo(atTick: tick, ticksPerQ: tpq)
                }
                hitIndex = i - 1
                curIndexInTempoMap = hitIndex!
                break
            } else if tempoMapSeq[i].beginTick == tick {
                hitIndex = i
                curIndexInTempoMap = hitIndex!
                break
            }
        }
        if hitIndex == nil && ipoint == tempoMapSeq.count-1 {
            // if I have no more tempo change beyond the tick, then
            // apply the last tempo
            let tmp = tempoMapSeq[ipoint].getTempo(ticksPerQuarter: tpq)
            return tmp
        }
        guard hitIndex != nil else {
            return nil
        }
        return tempoMapSeq[hitIndex!].getTempo(ticksPerQuarter: tpq)
    } // end of tempo(atTick.. funcion

}   // end of class MonitorCenter

// MARK: -- functions not in a class

func makeTrackTable(MidiData md:MidiData) -> Bool {
    if trackTable != nil {
        trackTable?.removeAll()
    }
    
    let numOfBars:Int? = md.barSeqTemplate.bars?.count
    
    if numOfBars == nil {
        return false
    }
    
    
    trackTable = Array<TrackMap>()
    trackTable?.reserveCapacity(md.numOfTracks!)
    if trackTable == nil {
        return false
    }
    // setting up Bool table for track to play
    for i in 0..<md.numOfTracks! {
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


