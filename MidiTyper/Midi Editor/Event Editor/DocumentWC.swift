//
//  DocumentWC.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/09.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class DocumentWC: NSWindowController {
    
    static var storyboardId: String? {
        return "Document Window Controller"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        // debug
        let nib = windowNibName?.rawValue
        print("window nib name: \(nib ?? "not available")")
    }
}
