//
//  KeyAssignTextField.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/12/03.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class KeyAssignTextField: NSTextField {

    var selected: Bool = false
    var posInTable = (0, 0) // tupple
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        if selected == true {
            var r = self.frame
            // debug adjusting enclosing box
            r.origin.y = 0
            let color:NSColor = NSColor.blue
            let drect = CGRect(x: r.origin.x, y: r.origin.y, width: r.width, height: r.height)
            let bpath: NSBezierPath = NSBezierPath(rect: drect)

            color.set()
            bpath.lineWidth = 2
            bpath.stroke()
        }
    }

    
    override func keyDown(with event: NSEvent) {
        print("keyCode in textfield = \(event.keyCode), char = \(String(describing: event.characters))")
    }
    
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        if responder == self {
            return true
        }
        return false
    }
    
}
