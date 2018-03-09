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
class MidiEvent: NSObject, NSCoding {
    var eventTick: Int32 = 0
    var eventStatus: UInt8 = 0
    var note: UInt8 = 0  // note number
    var vel: UInt8 = 0  // velocity
    var gateTime: Int32 = 0   // for note event only
    
    override init() {
        super.init()
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
        let byteData = Data.init(bytes: [eventStatus, note, vel])
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
}

class intermedSeqWithChannel {
    let isPrefixCh:Bool
    let channel: UInt8
    let eventSequence:Array<MidiEvent>
    
    init(isPrefixCh isCh:Bool, channel ch:UInt8, eventSequence seq:Array<MidiEvent> ) {
        channel = ch
        eventSequence = seq
        isPrefixCh = isCh
    }
}

class MetaEvent: NSObject, NSCoding {
    var metaTag: UInt8
    var eventTick: Int
    var data:[UInt8]
    
    override init() {
        metaTag = 0
        eventTick = 0
        data = Array<UInt8>.init(repeatElement(0, count: 128))
        
        super.init()
    }
    
    init(metaTag: UInt8, eventTick: Int, data: [UInt8]) {
        self.metaTag = metaTag
        self.eventTick = eventTick
        self.data = data
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let metaTag = aDecoder.decodeObject(forKey: "metaTag") as? UInt8 else { return nil }
        
        let eventTick = aDecoder.decodeInteger(forKey: "eventTick")
        guard let data = aDecoder.decodeObject(forKey: "data") as? [UInt8] else { return nil }
        
        self.init(metaTag: metaTag, eventTick: eventTick, data: data)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(metaTag, forKey: "metaTag")
        aCoder.encode(eventTick, forKey: "eventTick")
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
    
    func canIGetIn(elapsedTick et:Int) -> String {
        if et >= startTick && et < nextBarTick {
            return "in"
        } else if et < startTick {
            return "before"
        }
        return "after"
    }
    
    func rel2abs(indexOfEvent i: Int) -> Int {
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
}

class Track: NSObject, NSCoding {
    
    var bars: Array<Bar>?
    var curPos: Int
    var play:Bool
    var dirty:Bool  // shows the order of bars may not be aligned
    var lhIndexPtr, rhIndexPtr:Int
    var playChannel:UInt8?
    
    override init() {
        bars = Array<Bar>()
        curPos = 0
        play = true
        dirty = false
        lhIndexPtr = 0
        rhIndexPtr = 0
        playChannel = 0
    }
    
    init(pc: UInt8, barsArray: [Bar] ) {
        curPos = 0
        play = true
        dirty = false
        lhIndexPtr = 0
        rhIndexPtr = 0
        
        self.playChannel = pc
        self.bars = barsArray
        
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
        let i = bars!.index(where: {$0.measNum == meas})
        return i
    }
    
    // if Expandable == true then adding bar(s) by copying the last bar as the template
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
}

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

    // static declarations
    static var MThd:[Int8] = [ 0x4d, 0x54, 0x68, 0x64 ]
    static var MTrk:[Int8] = [ 0x4d, 0x54, 0x72, 0x6b ]
    
    // vars for SMF
    var curPtr: Int = 0
    var headerLength: Int?
    var formatType: UInt16?
    var numOfTracks: Int
    var ticksPerQuarter: UInt16?
    var trackStartPtr: Int?
    
    
    // class vars
    //var refNum: Int = 0 // ID for this instance. Given from app delegate
    
    var SMF: UnsafeMutableRawPointer?
    var barSeqTemplate: Track = Track()
    var commonTrackSeq: Array<MetaEvent>? = []
    var tracks:Array<Track>?
    
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
    
    
    let del = NSApplication.shared.delegate as! AppDelegate
    let nc = NotificationCenter.default

    override init() {
        curElapsedTick = 0
        nextMeasNum = 0
        numOfTracks = 0
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class var autosavesInPlace: Bool {
        return false
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
        windowController.window?.makeKeyAndOrderFront(self)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
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
        case "mid":
            do {
                try openSMF(owner: self, from: url)
                // debug
                makeWindowControllers()
                showWindows()
                
                let nc = NotificationCenter.default
                nc.post(name: ntDocumentOpened, object: self)
            } catch {
                let t = type(of: error)
                if t == ysError.self {
                    let err = error as! ysError
                    Swift.print("Source = \(err.source), Line = \(err.line), type = \(err.type)")
                }
            }
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: unknownFormatErr, userInfo: nil)
        }
        Swift.print("Succeed to read SMF")
    }
    
    func play(_ sender: Any)  {
        if monitor == nil { return }
        if monitor?.beforePlayback(midiIF:del.objMidi, barseqtemp:barSeqTemplate, tracks:tracks!) == false {
            del.displayAlert("failed to start the sequence")
            return
        }
        // monitor!.isPlayable must be called after .beforePlayback
        // because some data must be set up beforehand
        if monitor!.isPlayable == false { return }
        
        // reset playPtrIndex in all tracks
        // this loop of code may not be necessary as long as time window
        // to retrieve array of midiRawEvents without overlapped.
        monitor?.playEntry()
        nc.post(name: ntPlaying, object: self)
    }
    
    func toggle(_ sender: Any) {
        if monitor?.playing == true {
            monitor?.stop()
            nc.post(name: ntStopped, object: self)
            return
        }
        // song play reached the end. Start it oever again
        if monitor?.didReachEnd == true && monitor?.isPlayable == true {
            play(sender)
            return
        }
        // song stopped somewhere in it. continue play
        if monitor?.didStop == true && monitor?.isPlayable == true {
            monitor?.playingThread()
            nc.post(name: ntPlaying, object: self)
        }
    }
    
    
    override open class var readableTypes: [String] {
        return ["com.ysawada.MidiTyper", "mid", "MIDI audio"]
    }

    // MARK: Midi Process functions
    //
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
        
        var err = ysError(source: "MidiData", line: 500, type: ysError.errorID.SMFParse)
        
        if commonTrackSeq == nil || monitor == nil {
            err.line = 503
            throw err
        }
        
        if (commonTrackSeq?.count)! < 1 {
            err.line = 508
            throw err
        }
        
        if monitor!.isTimeSigInitialized == false {
            err.line = 513
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

} // end of MidiData class



