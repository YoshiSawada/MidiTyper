//
//  setupWindowController.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/12/26.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class setupWindowController: NSWindowController, NSWindowDelegate {

    var keyAssignVC: KeyAssignViewController?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let dc = NotificationCenter.default
        dc.addObserver(forName: ntKeyAssignTableLoaded, object: nil, queue: nil, using: myObserver)
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        window?.delegate = self
        window?.preventsApplicationTerminationWhenModal = false
        dc.post(name: ntSetupWindowLoaded, object: self)
    }
    
    static var storyboardId: String? {
        return "Set up Window Controller"
    }


    func windowWillClose(_ notification: Notification) {
        print(notification.name.rawValue)
    }
    
    func windowWillMove(_ notification: Notification) {
        print("received windowWillMove notification")
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        var res: Bool = true
        
        if keyAssignVC != nil {
            if keyAssignVC?.isTableDirty == true {
                let al = NSAlert.init()
                
                al.messageText = "Are you sure?"
                al.informativeText = "Key Assign Table was updated. If you wans to save it before leave, press save."
                al.addButton(withTitle: "Save")
                al.addButton(withTitle: "Back")
                al.addButton(withTitle: "Dismiss window anyway")
                al.alertStyle = NSAlert.Style.warning
                let modalresponse = al.runModal()
                
//                al.beginSheetModal(for: self.window!, completionHandler:  { (modalresponse) -> Void in
                switch modalresponse {
                case NSApplication.ModalResponse.alertFirstButtonReturn:
                    self.keyAssignVC?.saveKeyAssign()
                case NSApplication.ModalResponse.alertSecondButtonReturn:
                    res = false
                default:
                    res = true
                }
//
//                })
            }
        }
        return res
    }
    
    func myObserver(ntf: Notification) -> Void {
        if ntf.name == ntKeyAssignTableLoaded {
            keyAssignVC = ntf.object as? KeyAssignViewController
            if keyAssignVC != nil {
                keyAssignVC?.parentWin = self.window
                let b = self.window?.standardWindowButton(NSWindow.ButtonType.closeButton)
                if b != nil {
                    b?.isEnabled = true
                }
            }
        }
        
    }
}
