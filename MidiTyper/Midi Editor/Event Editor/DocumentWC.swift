//
//  DocumentWC.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/09.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class DocumentWC: NSWindowController, NSWindowDelegate {
    
    static var storyboardId: String? {
        return "Document Window Controller"
    }
    
    static var windowFrameAutosaveName: NSWindow.FrameAutosaveName {
        return NSWindow.FrameAutosaveName.init(rawValue: "Event Editor Window Frame Position")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    
        let nc = NotificationCenter.default
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        window?.setFrameUsingName(DocumentWC.windowFrameAutosaveName)
//        let defaults = UserDefaults.standard
//        let frame = defaults.value(forKey: "Event Editor Window Frame Position")
        
        nc.post(name: ntDocWinconLoaded, object: self)
//        guard frame != nil else {
//            return
//        }
//        window?.setFrame(frame! as! NSRect, display: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: DocumentWC.windowFrameAutosaveName)
    }
}
