//
//  AppDelegate.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/02/20.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa


// Notification definition
let ntPlayable = Notification.Name(rawValue: "Ready to play")
let ntPlaying = Notification.Name(rawValue: "Playing")
let ntStopped = Notification.Name(rawValue: "Stopped")
let ntEndReached = Notification.Name(rawValue: "Reached the End")
let ntKeyAssignTableLoaded = Notification.Name(rawValue: "Key Assign Table is Loaded")
let ntAppLaunched = Notification.Name(rawValue: "Application Launched")
let ntDocumentOpened = Notification.Name(rawValue: "Document is opened")
let ntInvalidLocation = Notification.Name(rawValue: "Invalid locator value")
let ntDidLoadLocationTextField = Notification.Name(rawValue: "Locator Field is opened")
let ntDidTSTWinConLoaded = Notification.Name(rawValue: "TST WinCon Loaded")
let ntLocatorWinconLoaded = Notification.Name(rawValue: "Locator Wincon Loaded")
let ntDocWinconLoaded = Notification.Name(rawValue: "Document Wincon Loaded")
let ntMidiNoteKeyIn = Notification.Name(rawValue: "MidiNoteKeyIn")
let ntChangeEventMenuIssued = Notification.Name(rawValue: "ChangeEventMenuIssued")
let ntInsEventMenuIssued = Notification.Name(rawValue: "InsertEventMenuIssued")
let ntNoteTypingMenuIssued = Notification.Name(rawValue: "NoteTypingMenuIssued")

// Error definitions
//

struct ysError: Error {
    
    enum errorID {
        case createFile
        case writeDataToFile
        case findFile
        case readFile
        case noContents
        case noSMFHeader
        case notSupportedFormat
        case midiInterface
        case SMFParse
        case timeoutForSemaphor
        case typedinEvent
    }
    var source: String  // source file name
    var line: Int   // line of code
    var type: errorID
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var docCon: NSDocumentController?
    var docWincon: DocumentWC?
    var tstWC: TSTEditorWinC?
    var locWC: LocationControlWC?
    let objMidi:objCMIDIBridge = objCMIDIBridge()
    let storyboard: NSStoryboard?
    var app: NSApplication?

    var midiInterface: MidiInterface?

    @IBOutlet weak var changeMenuItem: NSMenuItem!
    @IBOutlet weak var insMenuItem: NSMenuItem!
    @IBOutlet weak var noteTypingMenuItem: NSMenuItem!
    
    
    enum WindowTag {
        case EventEditWin
        case TSTWin // time signature and tempo editor
        case LocationControllerWin
        case ConfigurationWin
    }


    override init() {
        docCon = nil
        storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        app = aNotification.object as? NSApplication
        
        docCon = NSDocumentController.shared
        if docCon == nil {
            print("shared document controller is nil !!")
        }
        // debug
        print("document count = \(docCon?.documents.count ?? -1)")
        
        // regist notifications to observe
        let dc = NotificationCenter.default

        dc.addObserver(forName:ntPlayable, object:nil, queue:nil, using:seqStateObserver)
        dc.addObserver(forName: ntPlaying, object: nil, queue: nil, using: seqStateObserver)
        dc.addObserver(forName: ntStopped, object: nil, queue: nil, using: seqStateObserver)
        dc.addObserver(forName: ntEndReached, object: nil, queue: nil, using: seqStateObserver)
        
        
        dc.addObserver(forName: ntDidTSTWinConLoaded, object: nil, queue: nil, using: appstateObserver)
        dc.addObserver(forName: ntLocatorWinconLoaded, object: nil, queue: nil, using: appstateObserver)
        dc.addObserver(forName: ntDocWinconLoaded, object: nil, queue: nil, using: appstateObserver)
        
        // scan Midi Interface
        midiInterface = MidiInterface()
        
        do {
            try midiInterface?.prepareContent()
        } catch {
            print(error)
            exit(1)
        }

        let wc = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "LocationControlWC")) as? LocationControlWC
        wc?.showWindow(self)
        if wc != nil {
            // Make barNumberFieled focused
            let barNumberField = (wc!.contentViewController as! LocatorViewController).barNumberField
            wc!.window?.makeFirstResponder(barNumberField)
            
            // make reference of LocationControlWC in LocatorViewController
            (wc!.contentViewController as! LocatorViewController).parentWC = wc!
        }
        
        
        // hook keydown in app delegete, distribute it to the front win
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
            self.keyDown(with: aEvent)
            return aEvent
        }
        
        // clean up menu items
        changeMenuItem.isEnabled = false
        insMenuItem.isEnabled = false
        noteTypingMenuItem.isEnabled = false

    }

    // Get notification for document to be closed.
    //  and disable editMenuItem and insMenuItem
    

    func seqStateObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntPlayable:    // playable but not playing
//            playMenuItem.isEnabled = true
//            stopMenuItem.isEnabled = false
//            continueMenuItem.isEnabled = false
            // debug
            print("Got playable notification")
            
            print("Document count is now = \(docCon?.documents.count ?? -1)")
        case ntPlaying:
//            playMenuItem.isEnabled = false
//            stopMenuItem.isEnabled = true
//            continueMenuItem.isEnabled = false
            // debug
            print("Got playing notification")
        case ntStopped:
//            continueMenuItem.isEnabled = true
//            stopMenuItem.isEnabled = false
//            playMenuItem.isEnabled = true
            // debug
            print("Got stopped notification")
        case ntEndReached:
            print("Got reached the end notification")
//            midiData[activeRefnum].stop(self)
//            continueMenuItem.isEnabled = false
//            stopMenuItem.isEnabled = false
        default:
            print("Unknown notification: \(notf.name)")
        }
    }
    
    func appstateObserver(notf: Notification) ->Void {
        switch notf.name {
        case ntDidTSTWinConLoaded:
            tstWC = notf.object as? TSTEditorWinC
        case ntDocWinconLoaded:
            docWincon = notf.object as? DocumentWC
        case ntLocatorWinconLoaded:
            locWC = notf.object as? LocationControlWC
        default:
            return
        }
    }

    func keyDown(with event: NSEvent) {
        // debug
//        print("keyDown in AppDelegate: \(event.keyCode)")
//        if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.shift.rawValue) != 0 { print("shift is pressed down") }
        
        let whichWin = frontWindow()
        // debug
//        print("current key window is \(String(describing: whichWin))")
        
        // dispatch keydown to keywindow
        switch whichWin {
        case .TSTWin?:
            guard tstWC != nil else {
                return
            }
            tstWC!.myKey(with: event)
        case .EventEditWin?:
            docWincon?.keyDownHook(with: event)

        default:
            return
        }
        
        return  // do nothing for now
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func openMenuCommand(_ sender: Any) {
        let op: NSOpenPanel = NSOpenPanel.init()
        
        op.allowsMultipleSelection = false
        op.canChooseDirectories = false
        let res = docCon?.runModalOpenPanel(op, forTypes: ["mid"])
        print("returned Int = \(String(describing: res))")
        if res != 1 { return }
        
        // open file
        guard let url = op.url else {
            return
        }

        do {
            let doc = try docCon?.makeDocument(withContentsOf: url, ofType: "mid")
            docCon?.addDocument(doc!)
            
        } catch {
            // debug; add more in catching errors
            print(error)
        } // end of closure of completion handler
    }
    
    func frontWindow() -> WindowTag? {
        guard app != nil else {
            return nil
        }
        guard app?.windows != nil else {
            return nil
        }
        
        for win in (app?.windows)! {
            if win.isKeyWindow {
                switch win.windowController {
                case docWincon:
                    return WindowTag.EventEditWin
                case tstWC:
                    return WindowTag.TSTWin
                case locWC:
                    return WindowTag.LocationControllerWin
                default:
                    if (win.windowController as? setupWindowController) != nil {
                        return WindowTag.ConfigurationWin
                    } else {
                        return nil
                    }
                }
            }
        }
        
        return nil
    }
    
    func displayAlert(_ mes:String) {
        let al = NSAlert.init()
        
        al.messageText = "Alert"
        al.informativeText = mes
        al.addButton(withTitle: "OK")
        
        al.runModal()
    }
    
    func saveDocumentAs(sender: Any) {
        print("save as is called")
    }
    // MARK: Menu commands
   
    @IBAction func changeModeAction(_ sender: Any) {
        let whichWin = frontWindow()
        if whichWin == .EventEditWin {
            let dc = NotificationCenter.default
            if changeMenuItem.state == NSControl.StateValue.on {
                changeMenuItem.state = NSControl.StateValue.off
            } else {
                changeMenuItem.state = NSControl.StateValue.on
            }
            
            dc.post(name: ntChangeEventMenuIssued, object: self)
        }
    }
    
    @IBAction func insertModeAction(_ sender: Any) {
        let whichwin = frontWindow()
        if whichwin == .EventEditWin {
            let dc = NotificationCenter.default
            if insMenuItem.state == NSControl.StateValue.on {
                insMenuItem.state = NSControl.StateValue.off
            } else {
                insMenuItem.state = NSControl.StateValue.on
            }
            
            dc.post(name: ntInsEventMenuIssued, object: self)
        }
    }
    
    @IBAction func noteTypingAction(_ sender: Any) {
        let whichWin = frontWindow()
        if whichWin == .EventEditWin {
            let dc = NotificationCenter.default
            if noteTypingMenuItem.state == NSControl.StateValue.on {
                noteTypingMenuItem.state = NSControl.StateValue.off
            } else {
                noteTypingMenuItem.state = NSControl.StateValue.on
            }
            
            dc.post(name: ntNoteTypingMenuIssued, object: self)
        }
    }
    
    // MARK: Error handling
    func errorHandle(err: ysError) {
        let message = String(format: "error in %s, line %d, type \(err.type)", err.source, err.line)
        print(message)
    }
}

