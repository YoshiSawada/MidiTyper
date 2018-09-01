//
//  EscapeTextField.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/08/25.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class EscapeTextField: NSTextField {
    
    var resign: Bool = true

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func resignFirstResponder() -> Bool {
        return resign
    }
    
}
