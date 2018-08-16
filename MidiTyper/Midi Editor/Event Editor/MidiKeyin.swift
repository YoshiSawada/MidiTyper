//
//  MidiKeyin.swift
//  PlayPersistentStore
//
//  Created by Yoshi Sawada on 2018/07/08.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class MIDITypedInObject: NSObject {
    var isEnterKey: Bool
    var typedString: [String:String]
    var midiEvent: MidiEvent?
    
    override init() {
        isEnterKey = false
        typedString = Dictionary(dictionaryLiteral: ("Note", ""), ("Vel", ""), ("GateTime", ""), ("StepTiem", ""))
        midiEvent = nil
    }
}

class MidiKeyin: NSObject {
    
    var octav: Int
    var gateTime: Int
    var stepTime: Int
    var velocity: Int
    var lastNoteName: String
    var lastStepName: String
    var curNote: Int
    var curStep: Int
    var lastStep: Int   // used for dot process
    var slurFlag: Bool
    let ticksPerQuarter = 480 // assuming this
    var keyAssignTable: [keyAssign]
    var typedData: MIDITypedInObject
    var nc: NotificationCenter?

    let defaultKeyAssignTable:[keyAssign] = [
        keyAssign(position: 1, action: "C", keyLabel: "1", code: 83),
        keyAssign(position: 2, action: "C#", keyLabel: "2", code: 84),
        keyAssign(position: 3, action: "D", keyLabel: "3", code: 85),
        keyAssign(position: 4, action: "D#", keyLabel: "4", code: 86),
        keyAssign(position: 5, action: "E", keyLabel: "5", code: 87),
        keyAssign(position: 6, action: "F", keyLabel: "6", code: 88),
        keyAssign(position: 7, action: "F#", keyLabel: "7", code: 89),
        keyAssign(position: 8, action: "G", keyLabel: "8", code: 91),
        keyAssign(position: 9, action: "G#", keyLabel: "9", code: 92),
        keyAssign(position: 10, action: "A", keyLabel: "clear", code: 71),
        keyAssign(position: 11, action: "A#", keyLabel: "=", code: 81),
        keyAssign(position: 12, action: "B", keyLabel: "/", code: 75),
        keyAssign(position: 13, action: "32th", keyLabel: "F15", code: 113),
        keyAssign(position: 14, action: "16th", keyLabel: "0", code: 82),
        keyAssign(position: 15, action: "8th", keyLabel: ".", code: 65),
        keyAssign(position: 16, action: "Quarter", keyLabel: "pagedown", code: 121),
        keyAssign(position: 17, action: "half", keyLabel: "pageup", code: 116),
        keyAssign(position: 18, action: "whole", keyLabel: "del->", code: 117),
        keyAssign(position: 19, action: "chord", keyLabel: "F16", code: 106),
        keyAssign(position: 20, action: "triplet", keyLabel: "F17", code: 64),
        keyAssign(position: 21, action: "dot", keyLabel: "F18", code: 79),
        keyAssign(position: 22, action: "slur", keyLabel: "F19", code: 80),
        keyAssign(position: 23, action: "+", keyLabel: "+", code: 69),
        keyAssign(position: 24, action: "-", keyLabel: "-", code: 78),
        keyAssign(position: 25, action: "enter", keyLabel: "enter", code: 76)
    ]
    
    let notenames: [String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    let noteKeyRange = Range<Int>(1...12)
    let stepKeyRange = Range<Int>(13...22)
    let octavKeyRange = Range<Int>(23...24)

    override init() {
        octav = 3
        gateTime = 384
        stepTime = 480
        velocity = 80
        lastNoteName = ""
        lastStepName = "16th"
        curNote = 60
        curStep = 120
        lastStep = 120
        slurFlag = false
        keyAssignTable = defaultKeyAssignTable
        typedData = MIDITypedInObject()
        nc = NotificationCenter.default
        super.init()
    }
    
    init(with kat: [keyAssign]) {
        octav = 3
        gateTime = 384
        stepTime = 480
        keyAssignTable = kat
        velocity = 80
        lastNoteName = ""
        lastStepName = ""
        curNote = 0
        curStep = 0
        lastStep = 0
        slurFlag = false
        typedData = MIDITypedInObject()
        super.init()
    }
    
    func keyIn(event: NSEvent) -> MIDITypedInObject {

        for ks in keyAssignTable {
            if ks.keycode == event.keyCode {
                // buffering key
                
                let shift = event.modifierFlags.contains(NSEvent.ModifierFlags.shift)
                
                switch ks.position {
                case noteKeyRange:
                    subNote(note: ks.action, shift: shift)
                    typedData.isEnterKey = false
                case stepKeyRange:
                    subStep(step: ks.action, shift: shift)
                    typedData.isEnterKey = false
                case octavKeyRange:
                    subOctav(keyLabel: ks.action)
                    typedData.isEnterKey = false
                default:
                    if ks.action == "enter" {
                        // validate the data
                        
                        // do enter process
                        typedData.isEnterKey = true
                        // create midi event
                        typedData.midiEvent = MidiEvent.init()
                        typedData.midiEvent?.setEvent(tick: 0, midiStatus: 0x90, value1: UInt8(curNote), value2: UInt8(velocity), gateTime: Int32(gateTime))
                        
                        // reset parameters in key in buffer
                        gateTime = 0
                        stepTime = 0
                        curNote = 0
                        lastNoteName = ""
                        
                        print("do enter process")
                    }
                } // closure of switch
            } // closure of if ks.keycode == keycode
        } // closure of for ks
        
        stringValue()
        
        return typedData
    }
    
    private func subNote(note: String, shift: Bool) -> Void {
        
        var note4monitor: MidiEvent?

        // if shift key is pressed, increase octav for this key in
        var aOctav: Int
        
        // The same key is pressed in a row
        if note == lastNoteName {
            // update Int value and String value
            // put curNote and lastNoteName
            if shift == true {
                if curNote >= 12 {
                    curNote -= 12
                }
            } else {
                if curNote <= 127 - 12 {
                    curNote += 12
                }
            }
            aOctav  = curNote / 12 - 2
            lastNoteName = note
            
            // post MidiNoteKeyIn notification so I can send Midi note for monitor
            note4monitor = MidiEvent.init(tick: 0, midiStatus: UInt8(0x90), note: UInt8(curNote), vel: UInt8(velocity), gateTime: Int32(gateTime))
            nc?.post(name: ntMidiNoteKeyIn, object: note4monitor)
            
            return
        }
        
        // not the same note
        
        if shift == true {
            if octav > -2 {
                aOctav = octav - 1
            } else {
                aOctav = octav
            }
        } else {
            aOctav = octav
        }
        
        switch note {
        case "C":
            curNote = 24 + aOctav * 12
        case "C#":
            curNote = 25 + aOctav * 12
        case "D":
            curNote = 26 + aOctav * 12
        case "D#":
            curNote = 27 + aOctav * 12
        case "E":
            curNote = 28 + aOctav * 12
        case "F":
            curNote = 29 + aOctav * 12
        case "F#":
            curNote = 30 + aOctav * 12
        case "G":
            curNote = 31 + aOctav * 12
        case "G#":
            curNote = 32 + aOctav * 12
        case "A":
            curNote = 33 + aOctav * 12
        case "A#":
            curNote = 34 + aOctav * 12
        case "B":
            curNote = 35 + aOctav * 12
        default:
            // debug
            print("unexpected note name")
            return
        }

        // post MidiNoteKeyIn notification so I can send Midi note for monitor
        note4monitor = MidiEvent.init(tick: 0, midiStatus: UInt8(0x90), note: UInt8(curNote), vel: UInt8(velocity), gateTime: Int32(gateTime))
        nc?.post(name: ntMidiNoteKeyIn, object: note4monitor)

        lastNoteName = note
    }
    
    private func subStep(step: String, shift: Bool) -> Void {
        // if the same key is typed repeatedly
        
        var st: Int
        
        switch step {
        case "32th":
            st = ticksPerQuarter / 8    //60
        case "16th":
            st = ticksPerQuarter / 4
        case "8th":
            st = ticksPerQuarter / 2
        case "Quarter":
            st = ticksPerQuarter
        case "half":
            st = ticksPerQuarter * 2
        case "whole":
            st = ticksPerQuarter * 4 // this may not be right
                        // depending on the time signature
        case "dot":
            st = lastStep / 2
        case "slur":
            slurFlag = true
            return
        default:
            // debug
            st = 0
            print("some step time related key")
        }
        
        lastStep = st
        
        // if slur key
        if slurFlag == true {
            stepTime += st
            slurFlag = false
            return
        }
        
        // if the step key is repeated
        if step == lastStepName {
            stepTime += st
            return
        }
        
        stepTime = st
        gateTime = stepTime / 10 * 9    // 90% of steptime
    }
    
    private func subOctav(keyLabel: String) -> Void {
        if keyLabel == "+" {
            octav = octav >= 8 ? 8 : octav + 1
        } else {    // it must be minus '-'
            octav = octav <= -2 ? -2 : octav - 1
        }
    }
    
    func stringValue() -> Void { // create String in dictionary
        let aNote = curNote % 12
        let aOctav = curNote / 12 - 2
        
        guard  curNote >= 0 && curNote <= 127 else {
            print("something wrong in stringValue in MidiKeyin")
            typedData.midiEvent = nil
            return
        }
        
        var noteStr = notenames[aNote]
        noteStr = noteStr + String(aOctav)
        
        // make step time string
        var stepstr: String
        
        switch stepTime {
        case 480:
            stepstr = "Quarter"
        case 240:
            stepstr = "8th"
        case 120:
            stepstr = "16th"
        case 960:
            stepstr = "half"
        case 1920:
            stepstr = "whole"
        default:
            stepstr = String(stepTime)
        }
        typedData.typedString["Note"] = noteStr
        typedData.typedString["Vel"] = String(velocity)
        typedData.typedString["GateTime"] = String(gateTime)
        typedData.typedString["StepTime"] = stepstr
        
        return
    }
}
