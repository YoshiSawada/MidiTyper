//
//  OnelineMidi.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/04/25.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa


// definition and template to show an event on MIDI editor
class OnelineMidi: NSObject {
    var barObj: Bar?
    var meas: String
    var beat: String
    var clock: String
    var event: String
    var note: String
    var vel: String
    var gatetime: String
    var midiEv: MidiEvent?
    
    let noteDic = Dictionary(dictionaryLiteral: (0,"C"), (1, "C#"), (2,"D"), (3,"D#"), (4,"E"), (5,"F"), (6,"F#"), (7,"G"), (8,"G#"), (9,"A"), (10,"A#"), (11,"B"))
    
    override init() {
        meas = "1"
        beat = "***"
        clock = "***"
        event = "Bar"
        note = "***"
        vel = "***"
        gatetime = "***"
    }
    
    init(bar:Bar, ev: MidiEvent) {
        barObj = bar
        meas = String.init(bar.measNum + 1)
        let ticksPerBeat = bar.barLen / bar.timeSig["num"]!
        let ibeat = Int(ev.eventTick) / ticksPerBeat
        beat = String(ibeat+1)
        clock = String(Int(ev.eventTick) - (ticksPerBeat * ibeat))
        switch ev.eventStatus & 0xf0 {
        case 0x90:
            event = "Note"
        case 0xa0:
            event = "PolyPr"
        case 0xb0:
            event = "CC"
        case 0xc0:
            event = "PC"
        case 0xd0:
            event = "CP"
        case 0xe0:
            event = "PB"
        default:
            event = String(format: "%2x", ev.eventStatus)
        }
        note = String(ev.note)
        vel = String(ev.vel)
        gatetime = String(ev.gateTime)
        
        midiEv = ev.copy() as? MidiEvent

        super.init()

        // Here note is initialized with raw value first and then
        // being written with note name format, which is redundant.
        // Due to the restriction of Swift, however, I cannot call
        // a function in a class before super.init()
        // And I have to initialize subclass variables before super.init()

        if event == "Note" {
            note = notename(noteval: ev.note)
        }
    }
    
    convenience init(bar:Bar) {
        self.init()
        barObj = bar
        meas = String(bar.measNum + 1)
    }
    
    func notename(noteval: UInt8) -> String {
        var octav: Int
        
        if noteval >= 24 {
            // octav in +
            octav = Int(noteval - 24) / 12
        } else {
            if Int(noteval) % 12 > 0 {
                octav = ((24 - Int(noteval)) / 12 + 1) * -1
            } else {
                octav = (24 - Int(noteval)) / 12 * -1
            }
        }

        let mod = noteval % 12
        let note = noteDic[Int(mod)]! + String(octav)
        return note
    }
}
