//
//  LocatorViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/03/06.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class LocatorViewController: NSViewController, NSTextFieldDelegate, NSWindowDelegate {

    enum FieldID {
        case BarField
        case BeatField
        case ClockField
        case Nobody
    }

    override var acceptsFirstResponder: Bool { return true }
    var curFocus: FieldID = .Nobody
    var docCon: NSDocumentController?
    var currentDoc: MidiData?
    var parentWC: LocationControlWC?
    let del: AppDelegate? = NSApplication.shared.delegate as? AppDelegate

    
    @IBOutlet weak var messageTextField: LocatorTextField!
    @IBOutlet weak var barNumberField: LocatorTextField!
    @IBOutlet weak var beatNumberField: LocatorTextField!
    @IBOutlet weak var clockNumberField: LocatorTextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        let dc = NotificationCenter.default
        
        dc.addObserver(forName:ntDocumentOpened, object:nil, queue:nil, using:locatorObserver)
        dc.addObserver(forName: ntInvalidLocation, object: nil, queue: nil, using: locatorObserver)
        // Do view setup here.
        // debug: try masking itself from being delegate. See if it makes any difference
//        barNumberField.delegate = self as NSTextFieldDelegate
//        beatNumberField.delegate = self as NSTextFieldDelegate
//        clockNumberField.delegate = self as NSTextFieldDelegate
        
        barNumberField.doubleValue = 1
        barNumberField.nextKeyView = beatNumberField
        
        beatNumberField.doubleValue = 1
        beatNumberField.nextKeyView = clockNumberField
        clockNumberField.doubleValue = 0
        clockNumberField.nextKeyView = barNumberField
        
        // make bar field FirstResponder
        // But window is not available at the point of viewDidLoad. Defer this process later.
        // view.window?.makeFirstResponder(barNumberField)

        dc.post(name: ntDidLoadLocationTextField, object: self)
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
        
        var curField: LocatorTextField?
        
        switch parentWC?.window?.firstResponder {
        case barNumberField:
            curFocus = .BarField
            curField = barNumberField
        case beatNumberField:
            curFocus = .BeatField
            curField = beatNumberField
        case clockNumberField:
            curFocus = .ClockField
            curField = clockNumberField
        default:
            curFocus = .Nobody
            curField = nil
        }
        
        // debug
        print("In field: \(curFocus) with key: \(event.keyCode)")

        switch event.keyCode {
        case 48:    // tabkey
            if event.modifierFlags.contains(.shift) {
                let resp: LocatorTextField?
                switch curFocus {
                case .BarField:
                    resp = clockNumberField
                case .BeatField:
                    resp = barNumberField
                case .ClockField:
                    resp = beatNumberField
                default:
                    resp = nil
                }
                parentWC?.window?.makeFirstResponder(resp)
                resp?.selectText(self)
            } else {
                let resp: LocatorTextField?
                switch curFocus {
                case .BarField:
                    resp = beatNumberField
                case .BeatField:
                    resp = clockNumberField
                case .ClockField:
                    resp = barNumberField
                default:
                    resp = nil
                }
                parentWC?.window?.makeFirstResponder(resp)
                resp?.selectText(self)
            }
        case 49:    // space bar
            toggleAction(self)
        case 82...92: // 0 to 9
            curField?.stringValue.append(event.characters!)
        case 65:    // period
            return
        case 51: // delete key
            if curField != nil {
                curField!.stringValue = String(curField!.stringValue.dropLast())
            }
        case 71: // clear
            curField?.stringValue.removeAll()
        case 76, 36: // enter key. get the values in location fields
            locate()
        default:
            // super.keyDown(with: event)
            return
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
        barNumberField.selectText(sender)
        //locate()
    }
    
    @IBAction func beatFieldAction(_ sender: Any) {
        if validateLocatorFields() == false { return }
        beatNumberField.selectText(sender)
        //locate()
    }
    
    @IBAction func clockFieldAction(_ sender: Any) {
        if validateLocatorFields() == false { return }
        clockNumberField.selectText(sender)
        //locate()
    }
    
    func locate() -> Void {
        var bar, beat, clock: Int
        
        // debug
        print("locate is called in LocatorViewController")
        
        let dbar = barNumberField.doubleValue
        let dbeat = beatNumberField.doubleValue
        let dclock = clockNumberField.doubleValue
        
        if dbar == 0 {
            barNumberField.doubleValue = 1
        }
        
        if dbeat == 0 {
            beatNumberField.doubleValue = 1
        }

        bar = Int(dbar)
        beat = Int(dbeat)
        clock = Int(dclock)
        
        do {
            try currentDoc?.locate(bar: bar, beat: beat, clock: clock)
        } catch {
            del?.displayAlert("Could not find time slot in semaphor in locator function")
        }
    } // end of locate function
    
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
        let mes = String("some value(s) is invalid")

        if barNumberField.doubleValue < 1 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        if beatNumberField.doubleValue < 1 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        if clockNumberField.doubleValue < 0 {
            nc.post(name: ntInvalidLocation, object: mes)
            return false
        }
        return true

    }
}
