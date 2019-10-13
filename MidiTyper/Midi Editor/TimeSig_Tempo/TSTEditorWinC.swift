//
//  TSTEditorWinC.swift
//  MidiTyper
//  Time Signature & Tempo map editor window controller
//
//  Created by Yoshi Sawada on 2018/05/02.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class TSTEditorWinC: NSWindowController {
    
    static var storyboardId: String? {
        return "TimeSig and TempoEditor Win Con"
        //return "something"
    }
    
    override func windowDidLoad() {
        let nc = NotificationCenter.default
        super.windowDidLoad()
    
        nc.post(name: ntDidTSTWinConLoaded, object: self)
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    
    func myKey(with event:NSEvent) {
        let cv:TSTViewController? = window?.contentViewController as? TSTViewController
        cv?.myKey(with: event)
    }
        
}
