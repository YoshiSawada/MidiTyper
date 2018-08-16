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
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet var midiKeyIn: MidiKeyin!
    @IBOutlet weak var noteText: NSTextField!
    @IBOutlet weak var velocityText: NSTextField!
    @IBOutlet weak var gatetimeText: NSTextField!
    @IBOutlet weak var steptimeText: NSTextField!
    @IBOutlet weak var barText: NSTextField!
    @IBOutlet weak var beatText: NSTextField!
    @IBOutlet weak var tickText: NSTextField!
    
    var docCon: NSDocumentController?
    var midi:MidiData?
    var focusTrack: Int?
    var lines: [OnelineMidi] = Array<OnelineMidi>()
    var inEdit: Bool {
        get {
            if editButton.state == NSControl.StateValue.off {
                return false
            } else {
                return true
            }
        }
        set(state) {
            if state == true {
                editButton.state = NSControl.StateValue.on
            } else {
                editButton.state = NSControl.StateValue.off
            }
            
        }
    }
    
    var selectedRow: Int = -1
    var barIndexInTable = Array<Int>.init(repeating: 0, count: 64)
    var barInFocus: Bar?
    
    let tsColor = NSColor.systemOrange
    let tmpColor = NSColor.black
    
    let midiChButton: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
    let lineReserveCapacity = 1024
    let del = NSApplication.shared.delegate as? AppDelegate

    
    // MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: ntDocumentOpened, object: nil, queue: nil, using: editViewObserver)
        nc.addObserver(forName: NSTableView.selectionDidChangeNotification, object: nil, queue: nil, using: selectedRowChanged)
        nc.addObserver(forName: ntMidiNoteKeyIn, object: nil, queue: nil, using: editViewObserver)

        // Do any additional setup after loading the view.
        midiChannelPopUP.removeAllItems()
        midiChannelPopUP.addItems(withTitles: midiChButton)
        lines.reserveCapacity(lineReserveCapacity)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
            self.keyDownHook(with: aEvent)
            return aEvent
        }
        
        self.inEdit = false
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func editViewObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntMidiNoteKeyIn:
            
            let noteEvent = notf.object as? MidiEvent
            
            if noteEvent == nil { return }
            if midi == nil { return }
            if midi!.tracks?[focusTrack!] == nil { return }
            sendNoteMonitor(note: noteEvent!)
            
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
        barIndexInTable.removeAll(keepingCapacity: true)
        lines.removeAll(keepingCapacity: true)

        let midich = midi!.tracks![focusTrack!].playChannel
        let index = Int(midich ?? 0)
        midiChannelPopUP.selectItem(at: index)
        
        // load events
        let tr = midi!.tracks![focusTrack!]
        
        let numOfBars = tr.bars?.count ?? 0
        if numOfBars == 0 { return }
        
        for bar in tr.bars! {
            let one = OnelineMidi.init(bar: bar)
            barIndexInTable.append(lines.count)
            
            //  Add bar mark line
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
    
    func keyDownHook(with event: NSEvent) -> Void {
        if inEdit == false { return }
        
        let typed = midiKeyIn.keyIn(event: event)
        
        let note = typed.typedString["Note"]!
        let vel = typed.typedString["Vel"]!
        let gt = typed.typedString["GateTime"]!
        let st = typed.typedString["StepTime"]!
        
        setEventLine(note: note, vel: vel, gate: gt, step: st)
        
        return
    }
    
    func setEventLine(note: String, vel: String, gate: String, step: String) -> Void {
        noteText.stringValue = note
        velocityText.stringValue = vel
        gatetimeText.stringValue = gate
        steptimeText.stringValue = step
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
    
    func selectedRowChanged(notif: Notification) -> Void {
        selectedRow = editorTableView.selectedRow
        // if no row is selected, then the result will be -1
        if selectedRow == -1 { return }
        
        // Finding an item in which bar object is selected in the tableview
        var i: Int = -1
        var residual: Int = 0
        var barIndex: Int = -1

        pos1: for j in 0..<barIndexInTable.count {
            if barIndexInTable[j] == selectedRow {
                barInFocus = midi!.tracks![focusTrack!].bars?[j]
                barIndex = j
                i = j
                residual = 0
                break pos1
            }
            if barIndexInTable[j] > selectedRow {
                i = j > 0 ? j - 1 : 0
                barInFocus = midi!.tracks![focusTrack!].bars![i]
                barIndex = i
                residual = selectedRow - barIndexInTable[i]
                break pos1
            }
        }
        if i == -1 { // selectedRow should point to an event in the last bar
            i = midi!.tracks![focusTrack!].bars!.count
            barInFocus = midi!.tracks![focusTrack!].bars![i-1]
            barIndex = i - 1
            residual = selectedRow - barIndexInTable[i-1]
        }
        
        if residual == 0 { // selected row is on bar
            setEventLine(note: "***", vel: "***", gate: "***", step: "***")
            setTimeFields(forBar: barInFocus!, ix: nil)
        } else {
            // selected row has an event
            //
            
            let oneline = barInFocus?.events[residual-1].stringValue()
            
            if oneline == nil {
                return
            }
            
            // get step time
            var stepTime: Int
            let mev: MidiEvent = barInFocus!.events[residual-1]
            
            // let it sound through MIDI
            sendNoteMonitor(note: mev)

            if barInFocus!.events.count > residual {
                // I have more events to follow in the bar
                let mevNext:MidiEvent = barInFocus!.events[residual]
                stepTime = Int(mevNext.eventTick) - Int(mev.eventTick)
            } else {
                // next event is in the next bar or this is the last event in the track
                    // See if we have more bar
                if midi!.tracks![focusTrack!].bars!.count > barIndex + 1 {
                    // I have more bar(s)
                    let curTick = barInFocus!.startTick + Int(mev.eventTick)
                    // See if the next bar has any event
                    if midi!.tracks![focusTrack!].bars![barIndex+1].events.count > 0 {
                        // the next bar has an event
                        let nextEventTick = Int(midi!.tracks![focusTrack!].bars![barIndex+1].events[0].eventTick) + midi!.tracks![focusTrack!].bars![barIndex+1].startTick
                        stepTime = nextEventTick - curTick
                    } else {
                        // the next bar doesn't have an event
                        stepTime = -1   // mark it no more event
                    }
                } else {
                    // I don't have a bar anymore
                    stepTime = -1   // mark it no more event
                }
            }
            var stStr: String
            if stepTime == -1 {
                stStr = "***"
            } else {
                stStr = String(stepTime)
            }
            setEventLine(note: oneline!.0, vel: oneline!.1, gate: oneline!.2, step: stStr)
            setTimeFields(forBar: barInFocus!, ix: residual-1)
        }
    }
    
    // MARK: Sub functions
    //
    func sendNoteMonitor(note: MidiEvent) -> Void {

        var data:[UInt8] = [0,0,0]
        
        if note.eventStatus & UInt8(0x90) != UInt8(0x90) {
            // if not note on event, return
            return
        }
        
        if del?.objMidi == nil {
            return
        }
        
        _ = del?.objMidi.midiPacketInit()
        data[0] = note.eventStatus
        // adjust channel if playChannel is set
        if midi?.tracks?[focusTrack!].playChannel != nil {
            data[0] = data[0] | midi!.tracks![focusTrack!].playChannel!
        }
        data[1] = note.note
        data[2] = note.vel
        
        let now = mach_absolute_time()
        _ = del?.objMidi.setEvent(Int32(3), data: &data, eventTime: now)
        // send note off
        data[2] = 0
        _ = del?.objMidi.setEvent(Int32(3), data: &data, eventTime: now + 100000000)
        // set gate time to 0.1 sec
        del?.objMidi.send() // send it
    }
    
    func setTimeFields(forBar bar:Bar, ix: Int?) -> Void {
        // ix == nil, then the focused line is bar itself
        barText.stringValue = String(bar.measNum + 1)
        if ix == nil {
            beatText.stringValue = "***"
            tickText.stringValue = "***"
        } else {
            if ix! - 1 > bar.events.count {
                // error
                return
            }
            let beatAndTick = bar.beatAndTick(fromRelTick: Int(bar.events[ix!].eventTick))
            if beatAndTick.beat == nil || beatAndTick.tick == nil {
                beatText.stringValue = "??" // error
                tickText.stringValue = "??"
                return
            }
            beatText.stringValue = String(beatAndTick.beat!)
            tickText.stringValue = String(beatAndTick.tick!)
        }
    }

    // MARK: Control actions
    //
    @IBAction func trackSelectBoxAction(_ sender: Any) {
        let val = trackSelectBox.integerValue
        
        let _ = updateTrackSelectionControls(zerobaseTracknum: val - 1)
    }
    
    @IBAction func editButtonAction(_ sender: Any) {
        inEdit = editButton.state == NSControl.StateValue.off ? false : true
    }
    
    @IBAction func setMidiChannel(_ sender: Any) {
        if midi?.tracks?[focusTrack!] == nil {
            return
        }
        if midiChannelPopUP.integerValue < 1 || midiChannelPopUP.integerValue > 16 {
            return
        }
        midi!.tracks![focusTrack!].playChannel = UInt8(midiChannelPopUP.integerValue - 1)
        midi!.tracks![focusTrack!].dirty = true
    }
    
    @IBAction func trackSelectPopupAction(_ sender: Any) {
        let selected = trackSelectPopUp.indexOfSelectedItem
        
       _ = updateTrackSelectionControls(zerobaseTracknum: selected)
    }
}

