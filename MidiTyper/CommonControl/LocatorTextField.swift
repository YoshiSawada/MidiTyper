//
//  LocatorTextField.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/24.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocatorTextField: NSTextField { //NSTextFieldDelegate
    
    enum FieldID {
        case BarField
        case BeatField
        case ClockField
        case Nobody
    }

    //var shouldResignFocus: Bool = true
    let nc = NotificationCenter.default
    var locator: LocatorViewController?
    var whoAmI: FieldID = .Nobody

    
    override var acceptsFirstResponder: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func awakeFromNib() {
        nc.addObserver(forName: ntDidLoadLocationTextField, object: nil, queue: nil, using: observer)

        // delegate = self
    }
   
//    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
//        textObject.selectAll(self)
//        //shouldResignFocus = false
//        return true
//    }
    
//    override func textDidEndEditing(_ notification: Notification) {
//        //shouldResignFocus = true
//    }
    
    func observer(notice: Notification) -> Void {
        switch notice.name {
        case ntDidLoadLocationTextField:
            locator = notice.object as? LocatorViewController
            
            if self == locator?.barNumberField { whoAmI = .BarField }
            if self == locator?.beatNumberField { whoAmI = .BeatField }
            if self == locator?.clockNumberField { whoAmI = .ClockField }
            //delegate = locator as LocatorViewController?
        default:
            return
        }
    }
    
//    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
//        fieldEditor.selectAll(self)
//        return true
//    }
    
//    override func keyDown(with event: NSEvent) {
//        if event.keyCode > 0 {
//            let str = String(format: "key code is: %x", event.keyCode)
//            print(str)
//            
//            switch event.keyCode {
//            case 82...92: // 0 to 9
//                stringValue.append(event.characters!)
//            case 51: // delete key
//                stringValue = String(stringValue.dropLast())
//            case 71: // clear
//                stringValue.removeAll()
//            case 76, 36: // enter key. get the values in location fields
//                locator?.locate()
//            default:
//                // I'm setting delegate self.
//                // (delegate as! LocatorViewController).keyDown(with: event)
//                //superview?.keyDown(with: event)
//                return
//            }
//
//        }
//    }
    
    override func mouseDown(with event: NSEvent) {
            locator?.parentWC?.window?.makeFirstResponder(self)
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        return true
    }
    
    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        // Don't validate if it has a charactor other than a number
        let iter = textObject.string.makeIterator()
        for c in iter {
            if c < "0" || c > "9" {
                // set the field to default
                if whoAmI == .ClockField {
                    textObject.string = "0"
                } else {
                    textObject.string = "1"
                }
                return false
            }
        }
        return true
    }

    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        if responder == locator {
            return true
        }
        return false
    }


}
