//
//  LocatorTextField.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/24.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocatorTextField: NSTextField {

    override var acceptsFirstResponder: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
   
    override func keyDown(with event: NSEvent) {
        if event.keyCode > 0 {
            let str = String(format: "key code is: %x", event.keyCode)
            print(str)
            
            switch event.keyCode {
            case 82...92: // 0 to 9
                stringValue.append(event.characters!)
            case 51: // delete key
                stringValue = String(stringValue.dropLast())
            case 71: // clear
                stringValue.removeAll()
            default:
                super.keyDown(with: event)
            }

        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        return true
    }


}
