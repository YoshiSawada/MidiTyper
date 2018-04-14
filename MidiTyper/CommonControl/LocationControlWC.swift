//
//  CommonControlWindowController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/04.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocationControlWC: NSWindowController {

    static var storyboardId: String? {
        return "LocationControlWC"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.autorecalculatesKeyViewLoop = true
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    override func keyDown(with event: NSEvent) {
        let str = String(format: "Locator WinCon receives keydown %2x", event.keyCode)
        print(str)
        contentViewController?.keyDown(with: event)
    }

}
