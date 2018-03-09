//
//  LocatorViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/06.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocatorViewController: NSViewController {

    var docCon: NSDocumentController?
    var currentDoc: MidiData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        let dc = NotificationCenter.default
        
        dc.addObserver(forName:ntDocumentOpened, object:nil, queue:nil, using:locatorObserver)
        // Do view setup here.
    }
    
    func locatorObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntDocumentOpened:
            currentDoc = notf.object as? MidiData
        default:
            print("Locator notification observer reached the default; nothing to write here at the moment")
        }
    }
    
    @IBAction func stopAction(_ sender: Any) {
    }
    
    @IBAction func playAction(_ sender: Any) {
        //currentDoc = self.keyWindow()
        currentDoc?.play(sender)
    }
    
    @IBAction func toggleAction(_ sender: Any) {
        //let doc = docCon?.currentDocument as? MidiData
        
        currentDoc?.toggle(sender)
    }
    
    @IBAction func rewindAction(_ sender: Any) {
    }
    
    func keyWindow() -> MidiData? {
        for doc in (docCon?.documents)! {
            if doc.windowControllers[0].window?.isKeyWindow == true {
                return (doc as! MidiData)
            }
        }
        return nil
    }
}
