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
let ntDocumentViewDidPrepared = Notification.Name(rawValue: "Document View is loaded")
let ntInvalidLocation = Notification.Name(rawValue: "Invalid locator value")
let ntDidLoadLocationTextField = Notification.Name(rawValue: "Locator Field is opened")
let ntDidTSTWinConLoaded = Notification.Name(rawValue: "TST WinCon Loaded")
let ntLocatorWinconLoaded = Notification.Name(rawValue: "Locator Wincon Loaded")
let ntSetupWindowLoaded = Notification.Name(rawValue: "setupWinCon Loaded")
let ntDocWinconLoaded = Notification.Name(rawValue: "Document Wincon Loaded")
let ntMidiNoteKeyIn = Notification.Name(rawValue: "MidiNoteKeyIn")
let ntChangeEventMenuIssued = Notification.Name(rawValue: "ChangeEventMenuIssued")
let ntInsEventMenuIssued = Notification.Name(rawValue: "InsertEventMenuIssued")
let ntNoteTypingMenuIssued = Notification.Name(rawValue: "NoteTypingMenuIssued")
let ntUntitledDocumentCreated = Notification.Name(rawValue: "Untitled Document ready")

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
        case failedToLoadSong
        case RebuildingCommonTrackSeq
        case RebuildingTrackMap
        case eventListEditor
    }
    var source: String  // source file name
    var line: Int   // line of code
    var type: errorID
}

// Standard Midi File constant
let kDelta2byteLimit: UInt32 = 0x3fff
let kDelta3byteLimit: UInt32 = 0x1fffff


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var docCon: NSDocumentController?
    var curDocWincon: DocumentWC?
    var tstWC: TSTEditorWinC?
    var locWC: LocationControlWC?
    var setupWC: setupWindowController?
    let objMidi:objCMIDIBridge = objCMIDIBridge()
    let storyboard: NSStoryboard?
    var app: NSApplication?
    var curDoc: MidiData?
    var theKat: MidiKeyin?

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
        storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        // load key assign table
        theKat = MidiKeyin()
        theKat!.loadKeyAssign()
        
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        app = aNotification.object as? NSApplication
        
        // check if key assign table is loaded
        guard theKat != nil else {
            self.displayAlert("cannot instantiate MidiKeyIn")
            exit(1)
        } // I can use theKat! for the rest of the codes
        if theKat!.keyAssignTable.count < 10 {
            self.displayAlert("The item count of keyAssignTable is less than 10. It's got to be more")
            exit(1)
        }


        
        docCon = NSDocumentController.shared
        if docCon == nil {
            print("shared document controller is nil !!")
        }
        // debug
        curDoc = docCon?.documents.last as? MidiData
        if curDoc != nil {
            do {
                try curDoc?.viewCon?.loadSong(midiData: curDoc!)
            } catch {
                errorHandle(err: error as! ysError)
            }
        }
        
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
        dc.addObserver(forName: ntUntitledDocumentCreated, object: nil, queue: nil, using: appstateObserver)
        dc.addObserver(forName: ntSetupWindowLoaded, object: nil, queue: nil, using: appstateObserver)
        dc.addObserver(forName: ntDocumentViewDidPrepared, object: nil, queue: nil, using: appstateObserver)
        
        // scan Midi Interface
        midiInterface = MidiInterface()
        
        do {
            try midiInterface?.prepareContent()
        } catch {
            print(error)
            exit(1)
        }

        let wc = storyboard?.instantiateController(withIdentifier: "LocationControlWC") as? LocationControlWC
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
        
        if curDoc != nil {
            dc.post(name: ntDocumentOpened, object: curDoc)
            changeMenuItem.isEnabled = true
            insMenuItem.isEnabled = true
            noteTypingMenuItem.isEnabled = true
        } else {
            // clean up application menu items
            changeMenuItem.isEnabled = false
            insMenuItem.isEnabled = false
            noteTypingMenuItem.isEnabled = false
        }
        
        
        // debug makeDelta
        //      2019/4/7 tried enough cases and verified.
//        let (d, c) = makeDelta(tick: 0xfffffff)
//        var st = String(format:"0x%02X", d[0])
//        st += String(format:" 0x%02X", d[1])
//        st += String(format:" 0x%02X", d[2])
//        st += String(format:" 0x%02X", d[3])
//        print("d: \(st)")
//        print("c: \(c)")
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
        case ntUntitledDocumentCreated:
            curDoc = notf.object as? MidiData
        default:
            print("Unknown notification: \(notf.name)")
        }
    }
    
    func appstateObserver(notf: Notification) ->Void {
        switch notf.name {
        case ntDidTSTWinConLoaded:
            tstWC = notf.object as? TSTEditorWinC
        case ntDocWinconLoaded:
            //curDocWincon = notf.object as? DocumentWC
            // debug
            // I was trying to get var windowNumber in NSWindow
            // But it was set to -1 and I cannot set it either
            // as it is get-only var.
            
            // if this is an untitled doc (new doc) call loadSong in the MIDIData

            return
        case ntLocatorWinconLoaded:
            locWC = notf.object as? LocationControlWC
        case ntSetupWindowLoaded:
            setupWC = notf.object as? setupWindowController
        case ntDocumentViewDidPrepared:
            // write to load song data for new document
            
            guard let aDoc = notf.object as? MidiData else {
                return
            }

            if aDoc.isNew == true {
                do {
                    try aDoc.viewCon?.loadSong(midiData: aDoc)
                    // in the case of opening an existing MidiData
                    // I add the document in open menu
                    docCon?.addDocument(aDoc)
                } catch {
                    errorHandle(err: error as! ysError)
                }
            }
            return
        default:
            return
        }
    }
    
    func curDocChanged(To dc: DocumentWC) {
        curDocWincon = dc
        curDoc = curDocWincon?.document as? MidiData

        // change the contents of TST Window.
        let res = (tstWC?.contentViewController as? TSTViewController)?.setMidiData(midiData: curDoc)
        if res == false {
            displayAlert("failed to change TST window contents")
        }
    }

    func keyDown(with event: NSEvent) {
        
        let whichWin = frontWindow()
        
        // dispatch keydown to keywindow
        switch whichWin {
        case .TSTWin?:
            guard tstWC != nil else {
                return
            }
            tstWC!.myKey(with: event)
        case .EventEditWin?:
            // need to find out what doc the window belongs to
            curDocWincon?.keyDownHook(with: event)

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

            // set the document window to var window in document
            let cwin = app!.keyWindow
            if cwin != nil {
                doc?.setWindow(app!.keyWindow)
                doc?.addWindowController(cwin!.windowController!)
                cwin!.windowController!.document = doc
            }

            // currentDocument in NSDocumentController is now set to
            // doc here autonomously
            
        } catch {
            errorHandle(err: error as! ysError)
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
                case tstWC:
                    return WindowTag.TSTWin
                case locWC:
                    return WindowTag.LocationControllerWin
                case setupWC:
                    return WindowTag.ConfigurationWin
                default:
                    // find out which doc the keywindow belong to
                    if docCon == nil {
                        break
                    }
                    if curDocWincon == win.windowController {
                        return WindowTag.EventEditWin
                    }
                } // end of switch win.windowController
            } // end of ir win.isKeyWindow
        } // end of for win
        
        return nil
    }
    
    func displayAlert(_ mes:String) {
        let al = NSAlert.init()
        
        al.messageText = "Alert"
        al.informativeText = mes
        al.addButton(withTitle: "OK")
        
        al.runModal()
    }
    

    // MARK: Menu commands
    @IBAction func saveDocumentAs(_ sender: Any) {
        // debug creating SMF
        if docCon?.currentDocument == nil {
            displayAlert("You have no document")
            return
        }
        // (docCon!.currentDocument as! MidiData).tracks![0].makeTrackChunk(del: self)
        //(docCon!.currentDocument as! MidiData).entrySerializedToSmf()
        (docCon!.currentDocument as! MidiData).saveAs(sender)
        print("save as is called")
    }
    
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
    
    // MARK: Utilities
    
    func expandRawPointerMemory(srcPtr: UnsafeMutableRawPointer, srcSize: Int, newSize: Int) -> UnsafeMutableRawPointer {
        // srcPtr will have undated pointer with the size of newSize
        let newPtr = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: 1)

        newPtr.copyMemory(from: srcPtr, byteCount: srcSize)
        srcPtr.deallocate()
        
        return newPtr
    }
    
    func makeDelta(tick: UInt32) -> ([UInt8], Int) {
        var delta: Array<UInt8> = Array<UInt8>.init(repeating: 0, count: 4)
        var i8: UInt8

        switch tick {
        case 0...UInt32(0x7f):
            delta[0] = UInt8(tick)
            return (delta, 1)
        case 0x80...kDelta2byteLimit:
            // make msb
            i8 = UInt8((tick >> 7) & 0x7f)
            i8 = i8 | 0x80
            delta[0] = i8
            // make lsb
            i8 = UInt8(tick & 0x0000007f)
            delta[1] = i8
            return (delta, 2)
        case kDelta2byteLimit+1...kDelta3byteLimit:
            // make msb
            i8 = UInt8((tick >> 14) & 0x7f)
            i8 = i8 | 0x80
            delta[0] = i8
            //make 2nd byte
            i8 = UInt8((tick >> 7) & 0x7f)
            i8 = i8 | 0x80
            delta[1] = i8
            // make lsb
            i8 = UInt8(tick & 0x0000007f)
            delta[2] = i8
            return (delta,3)
        default:
            // make msb
            i8 = UInt8((tick >> 21) | 0x80)
            delta[0] = i8
            
            // make 2nd byte
            i8 = UInt8((tick >> 14) & 0x7f)
            i8 = i8 | 0x80
            delta[1] = i8
            
            // make 3rd byte
            i8 = UInt8((tick >> 7) & 0x7f)
            i8 = i8 | 0x80
            delta[2] = i8
            
            // make the lsb
            i8 = UInt8(tick & 0x0000007f)
            delta[3] = i8

            return (delta, 4)
        }
    }
    
    // MARK: Error handling
    func errorHandle(err: ysError) {
        let al = NSAlert.init()
        
        al.messageText = "error handle"
        al.informativeText = "see debug string"
        al.addButton(withTitle: "OK")
        
        al.runModal()

        let message = String(format: "error in %s, line %d, type \(err.type)", err.source, err.line)
        print(message)
        
        exit(0)
    }
}

