//
//  AppDelegate.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/02/20.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

// Error definitions
//

// Notification definition
let ntPlayable = Notification.Name(rawValue: "Ready to play")
let ntPlaying = Notification.Name(rawValue: "Playing")
let ntStopped = Notification.Name(rawValue: "Stopped")
let ntEndReached = Notification.Name(rawValue: "Reached the End")
let ntKeyAssignTableLoaded = Notification.Name(rawValue: "Key Assign Table is Loaded")
let ntAppLaunched = Notification.Name(rawValue: "Application Launched")
let ntDocumentOpened = Notification.Name(rawValue: "Document is opened")

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
    }
    var source: String  // source file name
    var line: Int   // line of code
    var type: errorID
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var docCon: NSDocumentController?
    let objMidi:objCMIDIBridge = objCMIDIBridge()
    let storyboard: NSStoryboard?

    var midiInterface: MidiInterface?


    override init() {
        docCon = nil
        storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        docCon = NSDocumentController.shared
        if docCon == nil {
            print("shared document controller is nil !!")
        }
        // debug
        print("document count = \(docCon?.documents.count ?? -1)")
        
        // regist notifications to observe
        let dc = NotificationCenter.default

        dc.addObserver(forName:ntPlayable, object:nil, queue:nil, using:appObserver)
        dc.addObserver(forName: ntPlaying, object: nil, queue: nil, using: appObserver)
        dc.addObserver(forName: ntStopped, object: nil, queue: nil, using: appObserver)
        dc.addObserver(forName: ntEndReached, object: nil, queue: nil, using: appObserver)
        
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

    }

    func appObserver(notf: Notification) -> Void {
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
    
    func displayAlert(_ mes:String) {
        let al = NSAlert.init()
        
        al.messageText = "Alert"
        al.informativeText = mes
        al.addButton(withTitle: "OK")
        
        al.runModal()
    }
    
}

