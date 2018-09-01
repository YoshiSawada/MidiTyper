//
//  ViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/02/20.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

let UpArrow: UInt16 = 126
let DownArrow: UInt16 = 125

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var midiChannelPopUP: NSPopUpButton!
    @IBOutlet weak var trackSelectPopUp: NSPopUpButton!
    @IBOutlet weak var trackSwitch: NSButton!
    @IBOutlet weak var trackSelectBox: NSTextField!
    @IBOutlet weak var editorTableView: NSTableView!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var insButton: NSButton!
    @IBOutlet var midiKeyIn: MidiKeyin!
    @IBOutlet weak var noteText: NSTextField!
    @IBOutlet weak var velocityText: NSTextField!
    @IBOutlet weak var gatetimeText: NSTextField!
    @IBOutlet weak var steptimeText: NSTextField!
    @IBOutlet weak var barText: NSTextField!
    @IBOutlet weak var beatText: NSTextField!
    @IBOutlet weak var tickText: NSTextField!
    @IBOutlet weak var escapeText: EscapeTextField!
    @IBOutlet weak var noteTypingButton: NSButton!
    
    var docCon: NSDocumentController?
    var midi:MidiData?
    var trackIndexInFocus: Int?
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
            // Don't control the button state if called from the action of itself.
            if state == true {
                barText.becomeFirstResponder()
                trackSelectPopUp.isEnabled = false
                midiChannelPopUP.isEnabled = false
                trackSelectBox.isEnabled = false
                
                do {
                    try goEdit()
                } catch {
                    del?.displayAlert("Cannot get into change edit mode")
                }

            } else {
                trackSelectBox.isEnabled = true
                trackSelectPopUp.isEnabled = true
                midiChannelPopUP.isEnabled = true
                trackSelectBox.isEnabled = true
            }
            
        }
    }
    var isNoteTyping: Bool {
        get {
            if noteTypingButton.state == NSControl.StateValue.on {
                return true
            } else {
                return false
            }
        }
        set {
            if newValue == true {
                //noteTypingButton.state = NSControl.StateValue.on
                escapeText.isEnabled = true
                escapeText.becomeFirstResponder()
                escapeText.resign = false
            } else {
                //noteTypingButton.state = NSControl.StateValue.off
                escapeText.isEnabled = false
                barText.becomeFirstResponder()  // this may not be necessary.
                escapeText.resign = true
            }
        }
    }
    
    var selectedRow: Int = -1
    var barIndexInTable = Array<Int>.init(repeating: 0, count: 64)
    var barInFocus: Bar?
    var eventInFocus: MidiEvent?
    var eventIndexInFocus: Int = 0
    
    let tsColor = NSColor.systemOrange
    let tmpColor = NSColor.black
    
    let midiChButton: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]
    let lineReserveCapacity = 1024
    var undoTrack: Track?
    let del = NSApplication.shared.delegate as? AppDelegate
    
    // variables to show the newly edit event
    var lineToSelect: Int?
    var measToSelect: Int?
    var midiEventToSelect: MidiEvent?
    
    // MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        docCon = NSDocumentController.shared
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: ntDocumentOpened, object: nil, queue: nil, using: editViewObserver)
        nc.addObserver(forName: NSTableView.selectionDidChangeNotification, object: nil, queue: nil, using: selectedRowChanged)
        nc.addObserver(forName: ntMidiNoteKeyIn, object: nil, queue: nil, using: editViewObserver)
        nc.addObserver(forName: ntChangeEventMenuIssued, object: nil, queue: nil, using: editViewObserver)
        nc.addObserver(forName: ntNoteTypingMenuIssued, object: nil, queue: nil, using: editViewObserver)
        nc.addObserver(forName: ntInsEventMenuIssued, object: nil, queue: nil, using: editViewObserver)

        // Do any additional setup after loading the view.
        midiChannelPopUP.removeAllItems()
        midiChannelPopUP.addItems(withTitles: midiChButton)
        lines.reserveCapacity(lineReserveCapacity)
        
//        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
//            self.keyDownHook(with: aEvent)
//            return aEvent
//        }
        
        self.inEdit = false
        editButton.isEnabled = false
        insButton.isEnabled = false
        noteTypingButton.isEnabled = false
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func editViewObserver(notf: Notification) -> Void {
        switch notf.name {
        case ntMidiNoteKeyIn:
            // used only to send monitor note to Midi IF
            let noteEvent = notf.object as? MidiEvent
            
            if noteEvent == nil { return }
            if midi == nil { return }
            if midi!.tracks?[trackIndexInFocus!] == nil { return }
            sendNoteMonitor(note: noteEvent!)
            
        case ntDocumentOpened:
            midi = notf.object as? MidiData
            do {
                try loadSong()
            } catch {
                del?.displayAlert("error in reading SMF in tableview")
            }
            
            title = midi?.title

            // enable edit manu itmes
            del?.changeMenuItem.isEnabled = true
                // I put this as Xcode turns it on (checked)
            del?.changeMenuItem.state = NSControl.StateValue.off
            del?.insMenuItem.isEnabled = true
            del?.noteTypingMenuItem.isEnabled = true
            editButton.isEnabled = true
            insButton.isEnabled = true
            noteTypingButton.isEnabled = true

            editorTableView.reloadData()

        case ntChangeEventMenuIssued:
            // notification observer gets called twice for some reason..
            //
            if midi == nil { return }
            if del?.changeMenuItem.state == NSControl.StateValue.on {
                inEdit = true
                editButton.state = NSControl.StateValue.on
            } else {
                inEdit = false
                editButton.state = NSControl.StateValue.off
            }
        case ntInsEventMenuIssued:
            if midi == nil { return }
            if del?.insMenuItem.state == NSControl.StateValue.on {
                insButton.state = NSControl.StateValue.on
            } else {
                insButton.state = NSControl.StateValue.off
            }
        case ntNoteTypingMenuIssued:
            if midi == nil { return }
            //let app = notf.object as? AppDelegate
            if del?.noteTypingMenuItem.state == NSControl.StateValue.on {
                isNoteTyping = true
                noteTypingButton.state = NSControl.StateValue.on
            } else {
                isNoteTyping = false
                noteTypingButton.state = NSControl.StateValue.off
            }
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
        
        trackIndexInFocus = updateTrackSelectionControls(zerobaseTracknum: 0)
        if trackIndexInFocus == nil {
            err.line = 88
            throw err
        }

        loadTrack()
    }
    
    func loadTrack() { // load focusTrack
        // make sure focusTrack is valid
        guard midi != nil && trackIndexInFocus != nil else {
            return
        }
        
        let trackCount = midi!.tracks!.count
        if trackCount < trackIndexInFocus! - 1 {
            return
        }
        
        // clean up lines
        barIndexInTable.removeAll(keepingCapacity: true)
        lines.removeAll(keepingCapacity: true)

        let midich = midi!.tracks![trackIndexInFocus!].playChannel
        let index = Int(midich ?? 0)
        midiChannelPopUP.selectItem(at: index)
        
        // load events
        let tr = midi!.tracks![trackIndexInFocus!]
        
        let numOfBars = tr.bars?.count ?? 0
        if numOfBars == 0 { return }
        
        for bar in tr.bars! {
            var barTobeSelected: Bool = false
            let one = OnelineMidi.init(bar: bar)
            
            if bar.measNum == measToSelect {
                barTobeSelected = true
            }
            
            barIndexInTable.append(lines.count)
            
            //  Add bar mark line
            lines.append(one)
            
            for ev in bar.events {
                if barTobeSelected == true {
                    if ev == midiEventToSelect {
                        lineToSelect = lines.count - 1
                    }
                }
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
        if midi == nil { return }


        // up/down arrow will change the selected row in event list
        if event.keyCode == UpArrow { // up arrow
            let sr = editorTableView.selectedRow
            if sr != 0 {
                let ixset = IndexSet.init(integer: sr - 1)
                editorTableView.selectRowIndexes(ixset, byExtendingSelection: false)
            }
            return
        }
        if event.keyCode == DownArrow {
            let sr = editorTableView.selectedRow
            // add code to check the last line
            if sr < numberOfRows(in: editorTableView) - 1 {
                let ixset = IndexSet.init(integer: sr + 1)
                editorTableView.selectRowIndexes(ixset, byExtendingSelection: false)
            }
            return
        }

        let typed = midiKeyIn.keyIn(event: event)

        // if enter is pressed, process it depending on either change or insert mode.
        
        if typed.isEnterKey {
            if insButton.state == NSControl.StateValue.off {
                // replace mode
                barInFocus?.events.remove(at: eventIndexInFocus)
            }
            
            do {
                try insertTypedEventToTrack()
            } catch {
                del?.errorHandle(err: error as! ysError)
            }
            
            if midi?.tracks?[trackIndexInFocus!].dirty == true {
                midi?.tracks?[trackIndexInFocus!].sort()
            }
            
            
            loadTrack()
            editorTableView.reloadData()
            
            return
        } // end of enter key process

        if isNoteTyping == true {
            // Below is code to get note from typing
            
            let note = typed.typedString["Note"]!
            let vel = typed.typedString["Vel"]!
            let gt = typed.typedString["GateTime"]!
            let st = typed.typedString["StepTime"]!
            
            setEventLine(note: note, vel: vel, gate: gt, step: st)
        }

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
                    trackIndexInFocus = trackCount - 1
                } else { // track count is zero
                    trackIndexInFocus = nil
                    return trackIndexInFocus
                }
            } else {
                trackIndexInFocus = zerobaseTracknum
            }
            
            // valid selection
                // load track
            loadTrack()
            
                // update UI
            trackSelectBox.stringValue = String((trackIndexInFocus ?? 0) + 1)
            trackSelectPopUp.selectItem(at: trackIndexInFocus ?? 0)
            
            return trackIndexInFocus
        }
        
        // track count is not valid
        trackIndexInFocus = nil
        trackSelectPopUp.removeAllItems()
        trackSelectPopUp.addItems(withTitles: ["--"])
        trackSelectBox.stringValue = "-"
        return trackIndexInFocus

    }
    
    // Follow the process below to get into edit mode
    //  Take care of control
    //  Call inEdit = true (or false when get back to browse mode)
    //  Finally call goEdit whic is actually called by set inEdit to true process
    
    func goEdit() throws -> Void {
        //  copy the currently focused track in buffer and start editing the data
        let err = ysError.init(source: "viewController", line: 259, type: .noContents)

        if midi?.tracks == nil { throw err }
        // put the current track data into undo buffer
        undoTrack = midi?.tracks?[trackIndexInFocus!].copy() as? Track
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
        
        // when reached the end, see if I should select a specific line
        if row == lines.count - 1 {
            if lineToSelect != nil {
                let ixset = IndexSet.init(integer: lineToSelect!)
                editorTableView.selectRowIndexes(ixset, byExtendingSelection: false)
                lineToSelect = nil
                measToSelect = nil
                midiEventToSelect = nil
            }
        }
        
        return field
    }
    
    func selectedRowChanged(notif: Notification) -> Void {
        selectedRow = editorTableView.selectedRow
        // if no row is selected, then the result will be -1
        if selectedRow == -1 {
            barInFocus = nil
            eventInFocus = nil
            return
        }
        
        // Finding an item in which bar object is selected in the tableview
        var i: Int = -1
        var residual: Int = 0
        var barIndex: Int = -1

        pos1: for j in 0..<barIndexInTable.count {
            if barIndexInTable[j] == selectedRow {
                barInFocus = midi!.tracks![trackIndexInFocus!].bars?[j]
                barIndex = j
                i = j
                residual = 0
                break pos1
            }
            if barIndexInTable[j] > selectedRow {
                i = j > 0 ? j - 1 : 0
                barInFocus = midi!.tracks![trackIndexInFocus!].bars![i]
                barIndex = i
                residual = selectedRow - barIndexInTable[i]
                break pos1
            }
        }
        if i == -1 { // selectedRow should point to an event in the last bar
            i = midi!.tracks![trackIndexInFocus!].bars!.count
            barInFocus = midi!.tracks![trackIndexInFocus!].bars![i-1]
            barIndex = i - 1
            residual = selectedRow - barIndexInTable[i-1]
        }
        
        if residual == 0 { // selected row is on bar
            setEventLine(note: "***", vel: "***", gate: "***", step: "***")
            setTimeFields(forBar: barInFocus!, ix: nil)
            eventInFocus = nil
        } else {
            // selected row has an event
            //
            eventInFocus = barInFocus?.events[residual-1]
            eventIndexInFocus = residual - 1
            let oneline = eventInFocus?.stringValue()
            
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
                if midi!.tracks![trackIndexInFocus!].bars!.count > barIndex + 1 {
                    // I have more bar(s)
                    let curTick = barInFocus!.startTick + Int(mev.eventTick)
                    // See if the next bar has any event
                    if midi!.tracks![trackIndexInFocus!].bars![barIndex+1].events.count > 0 {
                        // the next bar has an event
                        let nextEventTick = Int(midi!.tracks![trackIndexInFocus!].bars![barIndex+1].events[0].eventTick) + midi!.tracks![trackIndexInFocus!].bars![barIndex+1].startTick
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

            midiKeyIn.set(MidiEvent: eventInFocus!)
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
        if midi?.tracks?[trackIndexInFocus!].playChannel != nil {
            data[0] = data[0] | midi!.tracks![trackIndexInFocus!].playChannel!
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
    
    func getTimeField(forBar bar:Bar) -> (measnum: Int?, tick: Int?) {
        let meas = barText.integerValue < 1 ? nil : barText.integerValue
        let beat = beatText.integerValue < 1 ? nil : beatText.integerValue
        if meas == nil || beat == nil { return (nil, nil) }
        let tick = tickText.integerValue
        let reltick = bar.relTick(fromBeat: beat!, andTick: tick)
        
        return (meas! - 1, reltick)
    }
    
    func insertTypedEventToTrack() throws -> Void {
        
        var er = ysError.init(source: "insertTypedEventToTrack in ViewController", line: 618, type: ysError.errorID.typedinEvent)

        
        let measnum = barText.integerValue < 1 ? nil : barText.integerValue - 1
        let beat = beatText.integerValue < 1 ? nil : beatText.integerValue
        let tick = tickText.integerValue
        
        if measnum == nil || beat == nil {
            er.line = 625
            throw(er)
        }
        
        if barInFocus == nil {
            er.line = 630
            throw(er)
        }
        
        if midi?.tracks?[trackIndexInFocus!] == nil {
            er.line = 635
            throw(er)
        }
        
        measToSelect = measnum
        
        if measnum == barInFocus!.measNum {
            // don't have to change the target bar
            let tickInBar = barInFocus?.relTick(fromBeat: beat!, andTick: tick)
            if tickInBar == nil {
                er.line = 649
                throw(er)
            }
            
            let typedMidiEvent = midiKeyIn.typedData.midiEvent
            if typedMidiEvent == nil {
                er.line = 649
                throw(er)
            }
            
            typedMidiEvent!.eventTick = Int32(tickInBar!)
            barInFocus!.events.append(typedMidiEvent!)
            barInFocus?.sort()
            
            midi!.tracks![trackIndexInFocus!].dirty = true
            midiEventToSelect = typedMidiEvent!.copy() as? MidiEvent
        
        } else {
            // I have to change the target bar in the track
            //    See if I have to make a new bar
            let ix = midi!.tracks![trackIndexInFocus!].index(forMeas: measnum!)
            if ix == nil {  // bar doesn't exist. I have to create a new one
                var bar: Bar?
                
                let ix = midi!.barSeqTemplate.index(forMeas: measnum!)
                if ix == nil {
                    // meas doesn't even exist in barseq template. Extend the length
                    // of the song.
                    bar = newBarInBarSeqTemplate(meas: measnum!)
                    midi!.tracks![trackIndexInFocus!].dirty = true
                } else {
                    // duplicate the bar from the template
                    bar = midi!.barSeqTemplate.bars![ix!].copy() as? Bar
                }
                
                let tickInBar = bar?.relTick(fromBeat: beat!, andTick: tick)
                if tickInBar == nil {
                    er.line = 667
                    throw(er)
                }
                
                let typedMidiEvent = midiKeyIn.typedData.midiEvent
                if typedMidiEvent == nil {
                    er.line = 674
                    throw(er)
                }
                
                typedMidiEvent?.eventTick = Int32(tickInBar!)
                bar?.events.append(typedMidiEvent!)
                
                midiEventToSelect = typedMidiEvent!.copy() as? MidiEvent
                
                // add the bar to the track
                midi!.tracks![trackIndexInFocus!].bars!.append(bar!)
                midi!.tracks![trackIndexInFocus!].dirty = true
                
            } else { // add the event in the existing bar
                let bar = midi!.tracks![trackIndexInFocus!].bars![ix!]
                // debug note
                // I think the bar has a reference to the real data
                // if it's a copy, then I must add the MidiEvent direclty
                // to the real data
                let ticksInBar = bar.relTick(fromBeat: beat!, andTick: tick)
                if ticksInBar == nil {
                    er.line = 699
                    throw(er)
                }
                
                let typedMidiEvent = midiKeyIn.typedData.midiEvent
                if typedMidiEvent == nil {
                    er.line = 705
                    throw(er)
                }
                
                typedMidiEvent!.eventTick = Int32(ticksInBar!)
                bar.events.append(typedMidiEvent!)
                bar.sort()
                midi!.tracks![trackIndexInFocus!].dirty = true
                
                midiEventToSelect = typedMidiEvent!.copy() as? MidiEvent
            }
        }
    }
    
    // Will be used when creating a bar beyond the end of the song
    // This function returns a copy of bar template so it won't create
    //
    func newBarInBarSeqTemplate(meas: Int) -> Bar? {
        if midi == nil { return nil }
        let x = midi!.barSeqTemplate.index(forMeas: meas)
        if x != nil { // bar template exists. Return the copy of it
            return midi!.barSeqTemplate.bars![x!].copy() as? Bar
        }
        // based on the time sig of the last bar, extend the length
        // of the song and make bar template.
        let lastBar = midi!.barSeqTemplate.bars?.last
        let lastMeas = lastBar?.measNum
        if lastMeas == nil { return nil }
        // make new bars from last Meas to the specified meas
        var startTick4Bar = lastBar!.nextBarTick
        for i in lastMeas! + 1...meas {
            let bar = Bar.init(measNum: i, startTick: startTick4Bar, numerator: lastBar!.timeSig["num"]!, denominator: lastBar!.timeSig["denom"]!, ticksPerQuarter: Int(midi!.ticksPerQuarter!))
            midi!.barSeqTemplate.bars!.append(bar.copy() as! Bar)
            startTick4Bar = bar.nextBarTick
        }
        
        return midi!.barSeqTemplate.bars!.last!.copy() as? Bar
        // Before playback the song. I have to update TrackTable in play.swift
    }

    // MARK: Control actions
    //
    @IBAction func trackSelectBoxAction(_ sender: Any) {
        let val = trackSelectBox.integerValue
        
        let _ = updateTrackSelectionControls(zerobaseTracknum: val - 1)
    }
    
    @IBAction func editButtonAction(_ sender: Any) {
        if editButton.state == NSControl.StateValue.on {
            inEdit = true
            del?.changeMenuItem.state = NSControl.StateValue.on
        } else {
            inEdit = false
            del?.changeMenuItem.state = NSControl.StateValue.off
        }
    }
    
    @IBAction func setMidiChannel(_ sender: Any) {
        if midi?.tracks?[trackIndexInFocus!] == nil {
            return
        }
//        if midiChannelPopUP.indexOfSelectedItem < 0 || midiChannelPopUP.indexOfSelectedItem > 15 {
//            return
//        }
        midi!.tracks![trackIndexInFocus!].playChannel = UInt8(midiChannelPopUP.indexOfSelectedItem)
        midi!.tracks![trackIndexInFocus!].dirty = true
    }
    
    @IBAction func noteTypingButtonAction(_ sender: Any) {
        if noteTypingButton.state == NSControl.StateValue.on {
            del?.noteTypingMenuItem.state = NSControl.StateValue.on
            isNoteTyping = true
        } else {
            del?.noteTypingMenuItem.state = NSControl.StateValue.off
            isNoteTyping = false
        }
    }
    
    @IBAction func insModeAction(_ sender: Any) {
        if insButton.state == NSControl.StateValue.on {
            del?.insMenuItem.state = NSControl.StateValue.on
            // get into insert mode
        } else {
            del?.insMenuItem.state = NSControl.StateValue.off
            // exit from insert mode
        }
    }
    
    
    @IBAction func trackSelectPopupAction(_ sender: Any) {
        let selected = trackSelectPopUp.indexOfSelectedItem
        
       _ = updateTrackSelectionControls(zerobaseTracknum: selected)
    }
}

