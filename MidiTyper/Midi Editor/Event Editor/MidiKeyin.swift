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
    var isRest: Bool
    var isNoteType: Bool
    var typedString: [String:String]
    var midiEvent: MidiEvent
    
    override init() {
        isEnterKey = false
        isRest = true
        isNoteType = false
        typedString = Dictionary(dictionaryLiteral: ("Note", ""), ("Vel", ""), ("GateTime", ""), ("StepTime", ""))
        midiEvent = MidiEvent.init()
        midiEvent.eventStatus = UInt8(0x90)
        midiEvent.vel = UInt8(80)   // place holder
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
    let gateTimeRatioMultipleOf10 = 9
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
        keyAssign(position: 25, action: "enter", keyLabel: "enter", code: 76),
        keyAssign(position: 26, action: "enter2", keyLabel: "enter2", code: 36)
    ]
    
    let notenames: [String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    let noteKeyRange = Range<Int>(1...12)
    let stepKeyRange = Range<Int>(13...22)
    let octavKeyRange = Range<Int>(23...24)
    let enterKeyRange = Range<Int>(25...26)
    
    // MARK: Functions

    override init() {
        octav = 3
        gateTime = 108  // place holder
        stepTime = 0
        velocity = 80
        lastNoteName = "Rest"
        lastStepName = ""
        curStep = 120
        lastStep = 120
        curNote = 0
        slurFlag = false
        keyAssignTable = defaultKeyAssignTable
        typedData = MIDITypedInObject()
        nc = NotificationCenter.default
        super.init()
    }
    
    init(with kat: [keyAssign]) {
        octav = 3
        gateTime = 108  // place holder
        stepTime = 0
        keyAssignTable = kat
        velocity = 80
        lastNoteName = "Rest"
        lastStepName = ""
        curStep = 0
        curNote = 0
        lastStep = 0
        slurFlag = false
        typedData = MIDITypedInObject()
        super.init()
    }
    
    func set(MidiEvent mev: MidiEvent) {
        typedData.midiEvent = mev.copy() as! MidiEvent
        
        curNote = Int(typedData.midiEvent.note)
        velocity = Int(typedData.midiEvent.vel)
        gateTime = Int(typedData.midiEvent.gateTime)
        stepTime = 0
        
        // set string value for mev
        stringValue()
    }
    
    func keyIn(event: NSEvent) -> MIDITypedInObject {

        // If this instance is not in note typing mode, then simply return
        if typedData.isNoteType == true {
            typingNote(event: event)
        }
        
        // See if it's enter key
        let enterKey1 = keyAssignTable.firstIndex(where: { $0.action == "enter" } )
        let enterKey2 = keyAssignTable.firstIndex(where: { $0.action == "enter2" } )
        if enterKey1 == nil || enterKey2 == nil {
            // enter key is not defined
            typedData.midiEvent.eventStatus = 0
            return typedData
        }
        if event.keyCode == keyAssignTable[enterKey1!].keycode || event.keyCode == keyAssignTable[enterKey2!].keycode {
            typedData.isEnterKey = true
        }

        return typedData
    }
    
    func resetTypedData() -> Void {
        // reset parameters in key in buffer
        //  this must be done after inserting the midi event to song
        gateTime = 0
        stepTime = 0
        curNote = 0
        lastNoteName = ""
        lastNoteName = "Rest"
        typedData.isRest = true
    }
    
    func setMidiEvent(fromTextField note:String, vel:String, gt: String) -> Bool {
        let c = note.first
        if c == nil { return false}
        
        var pass: Bool = false
        if c! >= Character("a") && c! <= Character("g") {
            pass = true
        }
        if pass == false {
            if c! >= Character("A") && c! <= Character("G") {
                pass = true
            }
        }
        
        // check the 2nd character
        let ix = note.index(note.startIndex, offsetBy: 1, limitedBy: note.endIndex)
        if ix == nil { return false }
        let c2 = note[ix!]
        let isSharp = c2 == "#" ? true : false
        
        var noteofs: Int?
        
        switch(c!) {
        case "C", "c":
            noteofs = 0
            if isSharp {
                noteofs = noteofs! + 1
            }
        case "D", "d":
            noteofs = 2
            if isSharp {
                noteofs = noteofs! + 1
            }

        case "E", "e":
            noteofs = 4

        case "F", "f":
            noteofs = 5
            if isSharp {
                noteofs = noteofs! + 1
            }

        case "G", "g":
            noteofs = 7
            if isSharp {
                noteofs = noteofs! + 1
            }

        case "A", "a":
            noteofs = 9
            if isSharp {
                noteofs = noteofs! + 1
            }

        case "B", "b":
            noteofs = 11
        default:
            noteofs = nil
        }
        
        if noteofs == nil { return false }
        
        // see octav value
        var octav: Int?
        if isSharp {
            // get the 3rd character
            let index = note.index(note.startIndex, offsetBy: 2, limitedBy: note.endIndex)
            if index == nil { return false }
            let c3 = note[index!]
            octav = Int(String(c3))
            if octav == nil { return false }
        } else {
            octav = Int(String(c2))
            if octav == nil { return false }
        }

        let notevalue = (octav! + 2) * 12 + noteofs!
        if notevalue < 0 || notevalue > 127 { return false }
        
        typedData.midiEvent.eventStatus = UInt8(0x90)  // for now ignore channel
        typedData.midiEvent.note = UInt8(notevalue)

        // let's look at the velocity
        let velvalue = Int(vel)
        if velvalue == nil { return false }
        if velvalue! < 0 || velvalue! > 127 { return false }
        
        // let's look at the gate time
        let gtvalue = Int(gt)
        if gtvalue == nil { return false }
        if gtvalue! < 0 { return false }
        
        typedData.midiEvent.vel = UInt8(velvalue!)
        typedData.midiEvent.gateTime = Int32(gtvalue!)
        typedData.isRest = false
        typedData.isNoteType = true
        
        return true
    }
    
    func stringValue() -> Void { // create String in dictionary
        let aNote = curNote % 12
        let aOctav = curNote / 12 - 2
        
        guard  curNote >= 0 && curNote <= 127 else {
            print("something wrong in stringValue in MidiKeyin")
            typedData.midiEvent.note = UInt8(0)
            return
        }
        
        var noteStr = notenames[aNote]
        noteStr = typedData.isRest ? "Rest" : noteStr + String(aOctav)
        
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
    
    func dataFromStringField() -> MidiData? {
        
        return nil
    }

    
    // MARK: Private functions
    //
    
    private func typingNote(event: NSEvent) {
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
                    print("non note is typed")
                    return
                } // closure of switch

                typedData.midiEvent.note = UInt8(curNote)
                typedData.midiEvent.vel = UInt8(velocity)
                typedData.midiEvent.gateTime = Int32(gateTime)
            } // closure of if ks.keycode == keycode
        } // closure of for ks
    }
    
    // set the notenumber in curNote and set the notename to the container
    private func subNote(note: String, shift: Bool) -> Void {
        
        var note4monitor: MidiEvent?

        // if shift key is pressed, increase octav for this key in
        var aOctav: Int
        
        lastStepName = ""   // this is necessary to make my input method work.
        
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
            
            typedData.typedString["Note"] = note + String(aOctav)
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
        //  send out midi note event to midi interface only when note key is pressed.
        note4monitor = MidiEvent.init(tick: 0, midiStatus: UInt8(0x90), note: UInt8(curNote), vel: UInt8(velocity), gateTime: Int32(gateTime))
        nc?.post(name: ntMidiNoteKeyIn, object: note4monitor)

        lastNoteName = note
        typedData.isRest = false
        typedData.typedString["Note"] = note + String(aOctav)

    }
    
    private func subStep(step: String, shift: Bool) -> Void {
        // if the same key is typed repeatedly
        
        var st: Int
        
        lastNoteName = ""   // this is necessary to make my input method work
        
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
            st = lastStep / 2 * 3
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
        } else {
            stepTime = st
        }
        
        gateTime = stepTime / 10 * gateTimeRatioMultipleOf10
        
        lastStepName = step
        typedData.typedString["StepTime"] = String(stepTime)
        typedData.typedString["GateTime"] = String(gateTime)

    }
    
    private func subOctav(keyLabel: String) -> Void {
        if keyLabel == "+" {
            octav = octav >= 8 ? 8 : octav + 1
        } else {    // it must be minus '-'
            octav = octav <= -2 ? -2 : octav - 1
        }
    }
    
}
