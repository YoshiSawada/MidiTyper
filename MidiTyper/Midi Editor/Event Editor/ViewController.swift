//
//  ViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/02/20.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var midiChannelPopUP: NSPopUpButton!
    @IBOutlet weak var trackSelectPopUp: NSPopUpButton!
    @IBOutlet weak var trackSwitch: NSButton!
    @IBOutlet weak var trackSelectBox: NSTextField!
    @IBOutlet weak var editorTableView: NSTableView!
    
    var docCon: NSDocumentController?
    var midi:MidiData?
    var focusTrack: Int?
    var lines: [OnelineMidi] = Array<OnelineMidi>()
    
    let tsColor = NSColor.systemOrange
    let tmpColor = NSColor.black
    
    let midiChButton: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
    let lineReserveCapacity = 1024
    let del = NSApplication.shared.delegate as? AppDelegate
    
//    override init(nibName: nil, bundle: nil) {
//        super.init(nibName: nil, bundle: nil)
//    }
//
//    required init?(coder: NSCoder) {
//        return
//        //fatalError("init(coder:) has not been implemented")
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: ntDocumentOpened, object: nil, queue: nil, using: editViewObserver)

        // Do any additional setup after loading the view.
        midiChannelPopUP.removeAllItems()
        midiChannelPopUP.addItems(withTitles: midiChButton)
        lines.reserveCapacity(lineReserveCapacity)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func editViewObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntDocumentOpened:
            midi = notf.object as? MidiData
            do {
                try loadSong()
            } catch {
                del?.displayAlert("error in reading SMF in tableview")
            }
            editorTableView.reloadData()
            
        default:
            print("The observer in midi edit view received a notification")
        }
    }
    
    func loadSong() throws {
        // setup controlls
        
            // check if I have midi data
        var err = ysError.init(source: "viewController", line: 67, type: .noContents)
        if midi == nil { throw err }
        
            // setup track popup button
        let trackCount = midi!.tracks!.count
        var trackButtonArray: [String] = [String]()
        for i in 1...trackCount {
            trackButtonArray.append(String(i))
        }
        trackSelectPopUp.removeAllItems()
        trackSelectPopUp.addItems(withTitles: trackButtonArray)
        
        focusTrack = updateTrackSelectionControls(zerobaseTracknum: 0)
        if focusTrack == nil {
            err.line = 88
            throw err
        }

        loadTrack()
    }
    
    func loadTrack() { // load focusTrack
        // make sure focusTrack is valid
        guard midi != nil && focusTrack != nil else {
            return
        }
        
        let trackCount = midi!.tracks!.count
        if trackCount < focusTrack! - 1 {
            return
        }
        
        // clean up lines
        lines.removeAll(keepingCapacity: true)

        let midich = midi!.tracks![focusTrack!].playChannel
        let index = Int(midich ?? 0)
        midiChannelPopUP.selectItem(at: index)
        
        // load events
        let tr = midi!.tracks![focusTrack!]
        
        for bar in tr.bars! {
            let one = OnelineMidi.init(bar: bar)
            lines.append(one)
            for ev in bar.events {
                let evline = OnelineMidi.init(bar: bar, ev: ev)
                lines.append(evline)
            }
        }
        
        editorTableView.reloadData()

        midiChannelPopUP.selectItem(at: index)

        trackSwitch.state = NSControl.StateValue(rawValue: midi!.tracks![0].play ? 1 : 0)
    }
    
    func updateTrackSelectionControls(zerobaseTracknum: Int) -> Int? {
        if let trackCount = midi?.tracks?.count {
        // track count is valid
            if trackCount < zerobaseTracknum + 1 {
                if trackCount > 0 {
                    focusTrack = trackCount - 1
                } else { // track count is zero
                    focusTrack = nil
                    return focusTrack
                }
            } else {
                focusTrack = zerobaseTracknum
            }
            
            // valid selection
                // load track
            loadTrack()
            
                // update UI
            trackSelectBox.stringValue = String((focusTrack ?? 0) + 1)
            trackSelectPopUp.selectItem(at: focusTrack ?? 0)
            
            return focusTrack
        }
        
        // track count is not valid
        focusTrack = nil
        trackSelectPopUp.removeAllItems()
        trackSelectPopUp.addItems(withTitles: ["--"])
        trackSelectBox.stringValue = "-"
        return focusTrack

    }
    
    // MARK: tableView data source and delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        if midi == nil {
            return 0
        }
        return lines.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let str: String?
        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        
        let barFlag = lines[row].event == "Bar" ? true : false
        
        switch (tableColumn?.identifier)!.rawValue {
        case "Meas":
            str = lines[row].meas
        case "Beat":
            str = lines[row].beat
        case "Tick":
            str = lines[row].clock
        case "Event":
            str = lines[row].event
        case "Note":
            str = lines[row].note
        case "Vel":
            str = lines[row].vel
        default:
            str = lines[row].gatetime
        }
        cell?.textField?.stringValue = str ?? ""
        
        cell?.textField?.textColor = barFlag ? tsColor : tmpColor
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        
        let field: String?
        
        switch (tableColumn?.identifier)!.rawValue {
        case "Meas":
            field = lines[row].meas
        case "Beat":
            field = lines[row].beat
        case "Tick":
            field = lines[row].clock
        case "Event":
            field = lines[row].event
        case "Note":
            field = lines[row].note
        case "Vel": // must be velocity
            field = lines[row].vel
        default:
            field = lines[row].gatetime
        }
        return field
    }

    // MARK: Control actions
    //
    @IBAction func trackSelectBoxAction(_ sender: Any) {
        let val = trackSelectBox.integerValue
        
        let _ = updateTrackSelectionControls(zerobaseTracknum: val - 1)
    }
    
    @IBAction func trackSelectPopupAction(_ sender: Any) {
        let selected = trackSelectPopUp.indexOfSelectedItem
        
       _ = updateTrackSelectionControls(zerobaseTracknum: selected)
    }
}

