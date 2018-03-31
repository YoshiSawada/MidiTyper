//
//  LocatorViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/06.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocatorViewController: NSViewController, NSTextFieldDelegate, NSWindowDelegate {

    override var acceptsFirstResponder: Bool { return true }
    var docCon: NSDocumentController?
    var currentDoc: MidiData?
    
    @IBOutlet weak var messageTextField: NSTextField!
    @IBOutlet weak var barNumberField: NSTextField!
    @IBOutlet weak var beatNumberField: NSTextField!
    @IBOutlet weak var clockNumberField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        let dc = NotificationCenter.default
        
        dc.addObserver(forName:ntDocumentOpened, object:nil, queue:nil, using:locatorObserver)
        dc.addObserver(forName: ntInvalidLocation, object: nil, queue: nil, using: locatorObserver)
        // Do view setup here.
        barNumberField.delegate = self as NSTextFieldDelegate
    }

    func locatorObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntDocumentOpened:
            currentDoc = notf.object as? MidiData
        case ntInvalidLocation:
            // show message in the message field on the locator
            let str:String? = notf.object as? String
            if str != nil {
                messageTextField.stringValue = str!
            }
        default:
            print("Locator notification observer reached the default; nothing to write here at the moment")
        }
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49:    // space bar
            toggleAction(self)
        case 76, 36: // enter key. get the values in location fields
            locate()
        default:
            super.keyDown(with: event)
            // rewind, start and pause will be handled by key equivalent set in Storyboard.
        }
    }
    
    @IBAction func stopAction(_ sender: Any) {
        currentDoc?.stop()
        currentDoc?.rewind()
    }
    
    @IBAction func startAction(_ sender: Any) {
        //currentDoc = self.keyWindow()
        currentDoc?.start(sender)
    }
    
    @IBAction func toggleAction(_ sender: Any) {
        //let doc = docCon?.currentDocument as? MidiData
        
        currentDoc?.toggle(sender)
    }
    
    @IBAction func rewindAction(_ sender: Any) {
        currentDoc?.rewind()
    }
    
    @IBAction func barFieldAction(_ sender: Any) {
        if validateLocatorFields() == false { return }
        locate()
    }
    
    @IBAction func beatFieldAction(_ sender: Any) {
        if validateLocatorFields() == false { return }
        locate()
    }
    
    @IBAction func clockFieldAction(_ sender: Any) {
        if validateLocatorFields() == false { return }
        locate()
    }
    
    func locate() -> Void {
        var bar, beat, clock: Int
        
        let dbar = barNumberField.doubleValue
        let dbeat = beatNumberField.doubleValue
        let dclock = clockNumberField.doubleValue
        
        if dbar == 0 || dbeat == 0 || dclock == 0 {
            messageTextField.stringValue = "Location number cannot be 0. They should be 1 base"
            return
        }

        bar = Int(dbar)
        beat = Int(dbeat)
        clock = Int(dclock)
        
        currentDoc?.locate(bar: bar, beat: beat, clock: clock)
    }
    
    func keyWindow() -> MidiData? {
        for doc in (docCon?.documents)! {
            if doc.windowControllers[0].window?.isKeyWindow == true {
                return (doc as! MidiData)
            }
        }
        return nil
    }
    
    // setting up to get key down event
    //

    override func becomeFirstResponder() -> Bool {
        // debug
        print("Location controller view become first responder")
        return true
    }

    override func resignFirstResponder() -> Bool {
        return true
    }
    
    // MARK: Private function

    // I changed the function of this.
    // It was to check if all the 3 fieled are set to valid number.
    // But the function set any invalid field to 1 now.
    private func validateLocatorFields() -> Bool {
        let nc = NotificationCenter.default
        let mes = String("some value(s) is smaller than 1. Type in 1-based value")

        if barNumberField.doubleValue < 1 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        if beatNumberField.doubleValue == 1 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        if clockNumberField.doubleValue == 1 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        return true

    }
}
