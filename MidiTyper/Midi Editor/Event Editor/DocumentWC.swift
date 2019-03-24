//
//  DocumentWC.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/09.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class DocumentWC: NSWindowController, NSWindowDelegate {
    
    let del = NSApplication.shared.delegate as? AppDelegate
    
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
        
        // debug 2019/3/23
        // doc = document as? MidiData
        // this doesn't succeed. Thus I set it in AppDelegate

        
        nc.post(name: ntDocWinconLoaded, object: self)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if document != nil {
            del?.curDocChanged(To: self)
        }
    }
    
    func keyDownHook(with event: NSEvent) {
        let vc = window?.contentViewController as? ViewController
        vc?.keyDownHook(with: event)
    }
    
    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: DocumentWC.windowFrameAutosaveName)
    }
}
