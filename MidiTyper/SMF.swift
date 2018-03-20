//
//  SMF.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/01.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

// I didn't put the code in this file into MidiData class
// as it's too big and I don't want to have a class being too big.

import Foundation

// Supporting functions for MidiData
//  Parsing Standard Midi File
//

var noteOnTable: Array<MidiEvent> = Array<MidiEvent>()


func openSMF(owner: MidiData, from url: URL) throws {
    
    // var SMF: UnsafeMutableRawPointer
    var headerLength: Int
    var trackStartPtr: Int
    var err = ysError(source: "SMF.swift", line: 22, type: ysError.errorID.noSMFHeader)
    
    let fpin = fopen(url.path, "r")
    
    if fpin == nil {
        throw NSError(domain: NSOSStatusErrorDomain, code: afpObjectNotFound, userInfo: nil)
    }
    
    fseek(fpin, 0, SEEK_END)
    let length = ftell(fpin)
    fseek(fpin, 0, SEEK_SET)
    owner.SMF = UnsafeMutableRawPointer.allocate(bytes: length, alignedTo: 4)
    if owner.SMF == nil {
        err.line = 37; err.type = ysError.errorID.readFile
        throw err
    }
    
    // owner.SMF can be !
    fread(owner.SMF, 1, length, fpin)
    fclose(fpin)
    
    // Check Midi header
    if checkSMFHeader(smfPtr: owner.SMF!, header: MidiData.MThd, fileOffset: 0) == false {
            let headerError = ysError(source: "SMF.swift", line: 48, type: ysError.errorID.noSMFHeader)
            throw headerError
    }
    owner.curPtr = 4
    // read header length
    var ui32: UInt32
    var ui16: UInt16
    var smfNumOfTrack: Int
    
    ui32 = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt32.self)
    ui32 = CFSwapInt32(ui32)
    headerLength = Int(ui32)
    
    owner.curPtr = 8

    if headerLength < 6 {
        err.line = 55; err.type = ysError.errorID.noSMFHeader
        throw err
    }

    // read SMF format
    var formatType: UInt16
    
    formatType = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt16.self)
    formatType = CFSwapInt16(formatType)
    if formatType == 2 {
        err.line = 68; err.type = ysError.errorID.notSupportedFormat
        throw err
    } else if formatType != 0 && formatType != 1 {
        err.line = 68; err.type = ysError.errorID.notSupportedFormat
        throw err
    }

    owner.curPtr = 10
    
    // read number of tracks
    ui16 = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt16.self)
    ui16 = CFSwapInt16(ui16)
    smfNumOfTrack = Int(ui16)
    if smfNumOfTrack == 0 {
        err.line = 83 ; err.type = ysError.errorID.noContents
        throw err
    }
    // read ticksPerQuarter
    owner.curPtr = 12
    ui16 = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt16.self)
    owner.ticksPerQuarter = CFSwapInt16(ui16)

    owner.curPtr = 14
    
    // if there's any other header in the future, process it
    if owner.curPtr < headerLength + 8 {
        owner.curPtr = headerLength + 8
    }
    
    trackStartPtr = owner.curPtr  // set the pointer to the begening of the first track data

    // start reading the track(s)
    //
    // As we've got ticksPerQuarter, initialize monitor center
    let tq:Int = Int(owner.ticksPerQuarter!)

    if owner.monitor == nil {
        owner.monitor = MonitorCenter(ticksPerQuarter: tq, nanoRatio: (owner.del?.objMidi.getNanoRatio())!)
        if owner.monitor == nil {
            err.line = 110; err.type = ysError.errorID.midiInterface
            throw err
        }
    }
    owner.monitor!.isTempoInitialized = false
    owner.monitor!.isTimeSigInitialized = false
    owner.curElapsedTick = 0
    owner.nextMeasNum = 0
    owner.monitor!.resetTempoMap()

    /*
     Read through tempo and time sig and so force first with skipping regular events
     2nd: making a sequency of midi events. Sequence here is a temporary array to keep events.
     3rd: making bars and moving events from sequence to bars
     2017/9/1 again I changed the order of 2nd and 3rd process flipped.
    */
    try readCommonTrack(owner: owner)
    // if it fails, it will throw.
    
    try owner.makeBarSeq()
    
    var buf = owner.SMF!.advanced(by: trackStartPtr)
    
    if owner.tracks == nil {
        owner.tracks = Array<Track>()
    } else {
        owner.tracks!.removeAll()
    }

    // loop to read tracks to the end
    
    var seqWithCh:intermedSeqWithChannel?

    for _ in 0..<Int(smfNumOfTrack) {
        let (seq, entireTracklen, prefixCh) = readTrack(trackPtr: buf)
        if seq == nil {
            err.line = 144
            throw err
        }
        
        seqWithCh = nil
        if seq!.count > 0 {
            if prefixCh != nil {
                seqWithCh = intermedSeqWithChannel.init(isPrefixCh:true, channel:prefixCh!, eventSequence: seq!)
            } else {
                seqWithCh = intermedSeqWithChannel.init(isPrefixCh: false, channel: 0, eventSequence: seq!)
            }
            
            owner.eventSeqs.append(seqWithCh!.copy() as! intermedSeqWithChannel)
        }
        buf = buf.advanced(by: entireTracklen!)
    }

    // Putting Midi events in intermediate tracks(seqs) to bars
    for i in 0..<owner.eventSeqs.count {
        owner.track = Track()
        let seq = owner.eventSeqs[i].eventSequence
        
        for j in 0..<seq.count { // loop number of event times
            let ev:MidiEvent? = seq[j]
            let meas:Int? = owner.barSeqTemplate.findBar(tick: Int(ev!.eventTick), Expandable: true)
            if owner.track == nil || meas == nil {
                err.line = 175
                Swift.print("either track or meas = nil in oepnWithUrl function")
                throw err
            }
            
            var bar:Bar?
            var ix:Int? // index
            
            if ev != nil {
                // check if bar to which the event should belong exist or not
                // if no bar exist
                if owner.track == nil {
                    err.line = 187
                    throw err
                }
                if owner.track!.bars == nil {
                    bar = owner.barSeqTemplate.bars![meas!]
                    owner.track!.bars!.append(bar!.copy() as! Bar)
                    ix = 0   // I know index for the bar of interest is zero
                } else {    // bar exit(s). Then, is any of them the bar the event should belong to?
                    ix = owner.track!.index(forMeas: meas!)
                    // if false, make bar. If yes, get access the existing bar in the track
                    if ix == nil {
                        bar = owner.barSeqTemplate.bars![meas!]
                        if bar == nil {
                            Swift.print("faled to retreive bar from barSeqTemplate for meas=\(meas!)")
                            err.line = 201
                            throw err
                        }
                        owner.track!.bars!.append(bar!.copy() as! Bar)
                        ix = owner.track!.index(forMeas: meas!)
                        if ix == nil {
                            Swift.print("failed to get index for meas = \(meas!) in track")
                            err.line = 208
                            throw err
                        }
                    }
                }
                let t = owner.track!.bars![ix!].add(event: ev!.copy() as! MidiEvent, abs2rel: true)
                if t == nil {
                    Swift.print("relative tick is converted to out of range = \(String(describing: t))")
                    err.line = 216
                    throw err
                }
            }
        }
        if seq.count > 0 {
            // set prefix channel if we have
            if owner.eventSeqs[i].isPrefixCh == true {
                owner.track!.playChannel = owner.eventSeqs[i].channel
            } else {
                owner.track!.playChannel = nil
            }
            // debug.
            // trying to do this in addressing bug that I have duplicated track sequency over different tracks.
            // When verified, I don't have to use trcopied.
            // I can directly give copy() of Track in the param to append
            // let trcopied: Track = owner.track!.copy() as! Track
            owner.tracks!.append(owner.track!.copy() as! Track)
        }
    }

    // debug at this point I have wrong data. 2018/3/18
    if owner.tracks != nil {
        owner.numOfTracks = owner.tracks!.count
    } else {
        owner.numOfTracks = 0
    }
    
    owner.eventSeqs.removeAll()     // delete eventSeqs buffer

    owner.SMF!.deallocate(bytes: length, alignedTo: 1)    // don't know if alignedTo: 1 is OK

    // Prepare track map (matrix) to play
    if makeTrackTable(MidiData: owner) == false {
        err.line = 244
        throw err
    }

    // send notification to delegate that the data is ready to play
    owner.nc.post(name: ntPlayable, object: owner)
    
    // congratulations. Success in reading SMF, I hope...
}


// MARK: Private functions
//

// Checking header
private func checkSMFHeader(smfPtr: UnsafeMutableRawPointer, header h:[Int8], fileOffset offset: Int) -> Bool {
    var pass:Bool = true
    var c: Int8
    
    for i in 0...3 {
        c = (smfPtr.load(fromByteOffset: i + offset, as: Int8.self))
        if h[i] != c {
            pass = false
            break
        }
    }
    return pass
}

private func readCommonTrack (owner: MidiData) throws {
    
    var ui8: Array<UInt8> = Array<UInt8>.init(repeating: 0, count: 4)
    
    var err = ysError(source: "SMF.swift", line: 150, type: ysError.errorID.SMFParse)
    
    if checkSMFHeader(smfPtr: owner.SMF!, header: MidiData.MTrk, fileOffset: owner.curPtr)  == false {
        err.line = 156
        throw err
    }

    owner.curPtr += 4
    
    if owner.commonTrackSeq != nil { // cleanup the array
        if owner.commonTrackSeq!.count > 0 {
            owner.commonTrackSeq?.removeAll()
        }
    } else {
        owner.commonTrackSeq = Array<MetaEvent>()
    }
    // later on commonTrackSeq can be associated with !
    
    partialLoadFromSMF(smfPtr: owner.SMF!, offset: owner.curPtr, numOfByte: 4, buffer: &ui8)
    let ui32:UInt32? = convArrayOf4Uint8ToUInt32(&ui8)
    if ui32 == nil {
        // something wrong
        err.line = 170
        throw err
    }
    
    owner.curPtr += 4
    
    let tracklen = Int(ui32!)
    var readLen: Int = 0
    
    var delta: Int32
    var deltaWidth: Int
    var metaEvt: MetaEvent
    var metaLen: Int
    owner.curElapsedTick = 0
    var eot: Bool = false
    
    while (readLen < tracklen) && (eot == false) {
        (delta, deltaWidth) = makeRawDelta4byte(smfPtr: owner.SMF!, startOfDelta: owner.curPtr)
        owner.curPtr += deltaWidth
        readLen += deltaWidth
        owner.curElapsedTick = owner.curElapsedTick + Int(delta)
        
        let mStatus = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt8.self)
        owner.curPtr += 1
        readLen += 1
        
        if mStatus == 0xff { // meta event
            // call func to parse meta event
            (metaEvt, metaLen) = readMetaEvent(MidiData: owner, offset: owner.curPtr, eventTick:owner.curElapsedTick) as! (MetaEvent, Int)
            owner.curPtr += metaLen
            readLen += metaLen
            owner.commonTrackSeq!.append(metaEvt)
            if metaEvt.metaTag == 0x2f {
                // end of track
                eot = true
            }
        }  else if mStatus > 0x7f { // skip other data as we're reading common track data
            switch mStatus { // working on this 2017/8/27
            case 0x80...0x8f:
                owner.curPtr += 2
                readLen += 2
            case 0x90...0x9f:
                owner.curPtr += 2
                readLen += 2
            case 0xa0...0xaf:
                // polyphonic after tourch. Followed by note number and depth
                owner.curPtr += 2
                readLen += 2
            case 0xb0...0xbf:   // control change and mode messages
                owner.curPtr += 2
                readLen += 2
            case 0xc0...0xcf:   // program change
                owner.curPtr += 1
                readLen += 1
            case 0xd0...0xdf:   // channel pressure/after tough
                owner.curPtr += 1
                readLen += 1
            case 0xe0...0xef:   // pitch bend
                owner.curPtr += 2
                readLen += 2
            case 0xf0:
                let len = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt8.self)
                owner.curPtr += Int(len) + 1 // length of sysex and the length byte
                readLen += Int(len) + 1
            case 0xf7: // special format defined only in SMF to send big sysex following the 1st packe of it
                let len = owner.SMF!.load(fromByteOffset: owner.curPtr, as: UInt8.self)
                owner.curPtr += Int(len) + 1 // add length byte itself
                readLen += Int(len) + 1
            default:    // never be here because we have if mStatus > 0x7f statement before we get here
                owner.curPtr += 1
                readLen += 1
            }
            // skip event
            // Let's make skip function. I need to put switch to handle all types of midi event
            Swift.print("Midi status: \(mStatus)")
        } else { // then it should be running status
            owner.curPtr += 1
            readLen += 1
            Swift.print("running status? : \(mStatus)")
        }
    }
}

private func partialLoadFromSMF (smfPtr: UnsafeMutableRawPointer, offset ofs: Int, numOfByte n: Int, buffer buf:inout [UInt8]) {
    for i in 0..<n {
        buf[i] = smfPtr.load(fromByteOffset: ofs + i, as: UInt8.self)
    }
    
}

internal func convArrayOf4Uint8ToUInt32 (_ p:inout [UInt8]) -> UInt32 {
    var val:UInt32
    
    val = UInt32(p[0])*0x1000000 + UInt32(p[1])*0x10000 + UInt32(p[2])*0x100 + UInt32(p[3])
    
    return val
}

private func makeRawDelta4byte (smfPtr: UnsafeMutableRawPointer, startOfDelta ofs: Int) -> (val: Int32, width: Int) {

    /* This function takes offset in SMF file to read delta at the point. It returns two values in the tupple. 1st value will be 4 byte width of delta. Note it's not going to be interpreted to the actual value. It will be delta expression as it is. The second value in return will be the width of delta expression.
     To convert SMF formated delta to actual delta value, use the function in objMIDIBridge. */

    var buf:[UInt8] = [0,0,0,0]
    var i32: Int32
    var intermed: Int32
    
    partialLoadFromSMF(smfPtr: smfPtr, offset: ofs, numOfByte: 4, buffer: &buf)
    
    if buf[0] <= 0x7f {
        return (Int32(buf[0]), 1)
    }
    if buf[1] <= 0x7f {
        intermed = Int32(buf[0] & 0x7f) << 7
        i32 = intermed + Int32(buf[1])
        return (i32, 2)
    }
    if buf[2] <= 0x7f {
        intermed = Int32(buf[0] & 0x7f) << 14
        i32 = intermed
        intermed = Int32(buf[1] & 0x7f) << 7
        i32 += intermed + Int32(buf[2])
        return (i32, 3)
    }
    // else
    intermed = Int32(buf[0] & 0x7f) << 21
    i32 = intermed
    intermed = Int32(buf[1] & 0x7f) << 14
    i32 += intermed
    intermed = Int32(buf[2] & 0x7f) << 7
    i32 += intermed + Int32(buf[3])
    return (i32, 4)
}

private func readMetaEvent (MidiData owner:MidiData, offset ofs:Int, eventTick et:Int) -> (me: MetaEvent?, advance: Int) {
    let metaEvt = MetaEvent()
    var ad: Int
    
    metaEvt.metaTag = owner.SMF!.load(fromByteOffset: ofs, as: UInt8.self)
    metaEvt.eventTick = et
    let metalen = owner.SMF!.load(fromByteOffset: ofs + 1, as: UInt8.self)
    
    switch metaEvt.metaTag {
    case tagTempo: // tempo
        partialLoadFromSMF(smfPtr: owner.SMF!, offset: ofs + 2, numOfByte: Int(metalen), buffer: &(metaEvt.data))
        
        var nanoPerTick: __uint64_t = owner.metaTempoToNanoPerQuarter (metaEvent: metaEvt)!
        
        nanoPerTick = nanoPerTick / __uint64_t(owner.monitor!.ticksPerQuarter)
        
        owner.monitor!.addTempoMapElement(eventTick: metaEvt.eventTick, nanoPerTick: nanoPerTick)
        owner.monitor!.isTempoInitialized = true
        
        ad = Int(metalen) + 2
    case tagTimeSignature: // Time signature
        partialLoadFromSMF(smfPtr: owner.SMF!, offset: ofs + 2, numOfByte: 4, buffer: &(metaEvt.data))
        ad = 6  // 1(metatag) + 1(len itself) + len 4 = 6
        
        owner.monitor!.curTimeSig["num"] = Int(metaEvt.data[0])
        owner.monitor!.curTimeSig["denom"] = Int(metaEvt.data[1])
        owner.monitor!.isTimeSigInitialized = true
        
        let bar = Bar.init(measNum: owner.nextMeasNum, startTick: owner.curElapsedTick, numerator: owner.monitor!.curTimeSig["num"]!, denominator: owner.monitor!.curTimeSig["denom"]!, ticksPerQuarter: Int(owner.ticksPerQuarter!))
        owner.barSeqTemplate.bars?.append(bar)
        
        owner.nextMeasNum = owner.nextMeasNum + 1
        
    case tagKey: // Key
        partialLoadFromSMF(smfPtr: owner.SMF!, offset: ofs + 2, numOfByte: Int(metalen), buffer: &(metaEvt.data))
        ad = Int(metalen) + 2
        
    case tagEndOfTrack: // end of track
        partialLoadFromSMF(smfPtr: owner.SMF!, offset: ofs + 2, numOfByte: Int(metalen), buffer: &(metaEvt.data))
        ad = Int(metalen) + 2
        
    default:    // skipping event
        partialLoadFromSMF(smfPtr: owner.SMF!, offset: ofs + 2, numOfByte: Int(metalen), buffer: &(metaEvt.data))
        ad = Int(metalen) + 2
    }
    
    return (metaEvt, ad)
}


// read one track and make event sequence
//  parameter: SMF pointer
//  returns: array of MidiEvent

internal func readTrack(trackPtr tr:UnsafeRawPointer) -> (seq:Array<MidiEvent>?, entireTracklen: Int?, prefixCh:UInt8?) {
    
    var track:Array<MidiEvent>? = []
    var buf:[UInt8] = [0,0,0,0]
    var bValue:Bool
    var readLen: UInt32 = 0
    var deltaWidth: Int
    var delta:Int32
    var elapsedTick: Int32
    var midiEvt:MidiEvent?
    //let midiEvt:MidiEvent = MidiEvent()
    var runningStatus:UInt8 = 0
    let headerLength = 4 // header + track length
    let Ofs2TrackContext:UInt32 = 8
    var prefixCh:UInt8? = nil
    
    
    bValue = isSMFHeader(ofType: MidiData.MTrk, atSeqPointer: tr)
    if bValue == false {
        track = nil
        return (track, nil, nil)
    }
    
    buf = load4UInt8FromUnalignedBuffer(ptr: tr.advanced(by: headerLength))
    
    let tracklen = convArrayOf4Uint8ToUInt32(&buf)
    elapsedTick = 0
    
    noteOnTable.removeAll()
        
    while readLen < tracklen {
        // read delta
        buf = load4UInt8FromUnalignedBuffer(ptr: tr.advanced(by: Int(readLen + Ofs2TrackContext)))
        (delta, deltaWidth) = interpretDeltaLength(of4byte: buf)
        readLen += UInt32(deltaWidth)
        elapsedTick += delta
        
        // interpret event
        buf = load4UInt8FromUnalignedBuffer(ptr: tr.advanced(by: Int(Ofs2TrackContext + readLen)))
        
        if buf[0] < 0x80 { // running status
            buf[2] = buf[1]
            buf[1] = buf[0]
            buf[0] = runningStatus
            readLen -= 1    // adjust read count
        }
        
        switch buf[0] {
            
        case 0x80...0x8f: // note off
            let idx:Int? = noteOnTable.index(where: {$0.eventStatus & 0x0f == buf[0] & 0x0f && $0.note == buf[1]})
            // we must have correspoinding note on
            if idx != nil {
                // write gate time of the note on
                noteOnTable[idx!].gateTime = elapsedTick - noteOnTable[idx!].eventTick
                // add midiEvent to the track
                let evt = noteOnTable[idx!]
                track?.append(evt)
                noteOnTable.remove(at: idx!)
            }
            runningStatus = buf[0]
            readLen += UInt32(3)
            
        case 0x90...0x9f: // note on
            // gate time zero is place holder. It'll be valid when we have note off corresponding to
            // this note on event
            if buf[2] == 0 { // velocity zero = note off
                let idx:Int? = noteOnTable.index(where: {$0.eventStatus == buf[0] && $0.note == buf[1]})
                if idx == nil {
                    print("note on associated with the note off doesn't exit status = \(buf[0]) note = \(buf[1])")
                } else {
                    noteOnTable[idx!].gateTime = elapsedTick - noteOnTable[idx!].eventTick
                    track?.append(noteOnTable[idx!])
                    noteOnTable.remove(at: idx!)
                }
            } else {    // note on
                midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: buf[2], gateTime: 0)
                if midiEvt == nil { return (nil, nil, nil) }
                //midiEvt.setEvent(tick: elapsedTick, midiStatus: buf[0], value1: buf[1], value2: buf[2], gateTime: 0)
                noteOnTable.append(midiEvt!)
            }
            // do not put the event in track yet till we find note off in pair
            runningStatus = buf[0]
            readLen += UInt32(3)
            
        case 0xa0...0xaf:
            // polyphonic pressure followed by note number and depth
            // we can handle control change in the same way
            //midiEvt.setEvent(tick: elapsedTick, midiStatus: buf[0], value1: buf[1], value2: buf[2], gateTime: 0)
            midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: buf[2], gateTime: 0)
            if midiEvt == nil { return (nil, nil, nil) }
            track?.append(midiEvt!)
            runningStatus = buf[0]
            readLen += UInt32(3)
            
        case 0xb0...0xbf:
            // control change
            //midiEvt.setEvent(tick: elapsedTick, midiStatus: buf[0], value1: buf[1], value2: buf[2], gateTime: 0)
            midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: buf[2], gateTime: 0)
            if midiEvt == nil { return (nil, nil, nil) }
            track?.append(midiEvt!)
            runningStatus = buf[0]
            readLen += UInt32(3)
            
        case 0xc0...0xcf:
            // program change
            midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: 0, gateTime: 0)
            if midiEvt == nil { return (nil, nil, nil) }
            track?.append(midiEvt!)
            runningStatus = buf[0]
            readLen += UInt32(2)
            
        case 0xd0...0xdf:
            // channel pressure
            //midiEvt.setEvent(tick: elapsedTick, midiStatus: buf[0], value1: buf[1], value2: 0, gateTime: 0)
            midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: 0, gateTime: 0)
            if midiEvt == nil { return (nil, nil, nil) }

            track?.append(midiEvt!)
            runningStatus = buf[0]
            readLen += UInt32(2)
            
        case 0xe0...0xef:
            // pitch bend
            //midiEvt.setEvent(tick: elapsedTick, midiStatus: buf[0], value1: buf[1], value2: buf[2], gateTime: 0)
            midiEvt = MidiEvent(tick: elapsedTick, midiStatus: buf[0], note: buf[1], vel: buf[2], gateTime: 0)
            if midiEvt == nil { return (nil, nil, nil) }

            track?.append(midiEvt!)
            runningStatus = buf[0]
            readLen += UInt32(3)
            
        case 0xf0: // system exclusive. Just skip it
            let piece = tr.advanced(by: Int(readLen + Ofs2TrackContext))
            for i in 0...tracklen - readLen {
                let onebyte = piece.load(fromByteOffset: Int(i), as: UInt8.self)
                if onebyte == 0xf7 {
                    readLen += i
                    break
                }
                if i >= tracklen - readLen {
                    print("cannot find 0xF7 for 0xF0 where I searched \(i) bytes")
                }
            }
            
            piece.deallocate(bytes: Int(tracklen - readLen), alignedTo: 1)
            
        case 0xff: // meta event
            // interpret MIDI channel prefix at least
            if buf[1] == tagMIDIChannelPrefix {
                prefixCh = buf[3]
            }
            readLen += UInt32(buf[2] + 3)   // need to add status, meta tag and meta length too
            
        case 0xf1...0xf7:
            readLen += 1
            
        default:  // running status should be handled before switch clause. code should not be here
            print("sometihng wrong in reading SMF. Cannot interpret the event status at file offset = \(readLen)")
            let sortedTrack:Array<MidiEvent>? = nil
            return (sortedTrack, nil, nil)
        }
    }
    
    // sort the track in the order of eventTick
    if track != nil {
        if track!.count >= 2 {
            let sortedTrack = track?.sorted(by: {$0.eventTick < $1.eventTick})
            return (sortedTrack, Int(tracklen) + 8, prefixCh)
        }
    }
    
    return (track, Int(tracklen) + 8, prefixCh)
}

internal func isSMFHeader(ofType header:[Int8], atSeqPointer seqptr: UnsafeRawPointer) -> Bool {
    
    var pass:Bool = true
    
    for i in 0...3 {
        let c = seqptr.load(fromByteOffset: i, as: Int8.self)
        if header[i] != c {
            pass = false
            break
        }
    }
    return pass
}

internal func load4UInt8FromUnalignedBuffer(ptr:UnsafeRawPointer) -> [UInt8] {
    var fourbyte:[UInt8] = [0,0,0,0]
    
    for i in 0...3 {
        fourbyte[i] = ptr.load(fromByteOffset: i, as: UInt8.self)
    }
    
    return fourbyte
}

internal func interpretDeltaLength (of4byte fb:[UInt8]) -> (val: Int32, width: Int) {
    
    var i32: Int32
    var intermed: Int32
    
    if fb[0] <= 0x7f {
        return (Int32(fb[0]), 1)
    }
    if fb[1] <= 0x7f {
        intermed = Int32(fb[0] & 0x7f) << 7
        i32 = intermed + Int32(fb[1])
        return (i32, 2)
    }
    if fb[2] <= 0x7f {
        intermed = Int32(fb[0] & 0x7f) << 14
        i32 = intermed
        intermed = Int32(fb[1] & 0x7f) << 7
        i32 += intermed + Int32(fb[2])
        return (i32, 3)
    }
    // else
    intermed = Int32(fb[0] & 0x7f) << 21
    i32 = intermed
    intermed = Int32(fb[1] & 0x7f) << 14
    i32 += intermed
    intermed = Int32(fb[2] & 0x7f) << 7
    i32 += intermed + Int32(fb[3])
    return (i32, 4)
}
