//
//  TSTViewController.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/05/02.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class TSTViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    let types: [String] = ["Time Sig", "Tempo"]
    override var acceptsFirstResponder: Bool { return true }


    @IBOutlet weak var TSTtableView: NSTableView!
    @IBOutlet weak var typeSelectionPopUp: NSPopUpButton!
    @IBOutlet weak var barField: NSTextField!
    @IBOutlet weak var beatField: NSTextField!
    @IBOutlet weak var tickField: NSTextField!
    @IBOutlet weak var valueField: NSTextField!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var insertButton: NSButton!
    
    var docCon: NSDocumentController?
    var midi: MidiData?
    var tstLines: [OnelineTST] = Array<OnelineTST>()
    
    let tsColor = NSColor.systemOrange
    let tmpColor = NSColor.black
    let del = NSApplication.shared.delegate as? AppDelegate
    
    enum FocusedField {
        case Meas
        case Beat
        case Tick
        case Value
        case none
    }
    
    var curFocus: FocusedField = FocusedField.Meas

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        docCon = NSDocumentController.shared
        let nc = NotificationCenter.default
        nc.addObserver(forName: ntDocumentOpened, object: nil, queue: nil, using: TSTviewObserver)

        typeSelectionPopUp.removeAllItems()
        typeSelectionPopUp.addItems(withTitles: types)
        typeSelectionPopUp.isEnabled = false
        
        editButton.isEnabled = false
        removeButton.isEnabled = false
        insertButton.isEnabled = false
        
        // debug
        // we cannot expect docCon?.currentDocument is set.
//        if docCon?.currentDocument != nil {
//            print("doc con has a currentDocument")
//        } else {
//            print("current doc is nil")
//        }
        
        midi = del?.curDoc
        
        if midi != nil {
            loadData()
        } else {
            print("cannot get Midi Data")
        }
        
        // debug
        TSTtableView.refusesFirstResponder = true
    }
    
    func loadData() {

        if midi == nil {
            return
        }
        
        if (midi?.numOfTracks)! < 1 {
            return
        }
        
        tstLines.removeAll()
        
        // parse meta event
        var curOccuranceBar: Bar?
        for bar in midi!.barSeqTemplate.bars! {
            var tsChange: Bool
            
            tsChange = false
            
            if curOccuranceBar == nil {
                curOccuranceBar = bar
                tsChange = true
            } else {
                if curOccuranceBar?.timeSig != bar.timeSig {
                    curOccuranceBar = bar
                    tsChange = true
                }
            }
            
            if tsChange {   // Either initial time sig
                // or change of time sig
                let ts = OnelineTST.init(BarWithZerobaseMeas: bar.measNum, num: bar.timeSig["num"]!, denom: bar.timeSig["denom"]!, barIns: bar)
                //let ts = TST.TimeSig(bar: bar.measNum, num: bar.timeSig["num"]!, denom: bar.timeSig["denom"]!)
                //let one = OnelineTST.init(tst: ts)
                tstLines.append(ts)
            }
        }
        
        let tpq = midi!.ticksPerQuarter!
        
        for meta in midi!.commonTrackSeq! {
            if meta.metaTag == tagTempo {
                let measnum = midi!.barSeqTemplate.findBar(tick: meta.eventTick, Expandable: false)
                let bar2 = (midi!.barSeqTemplate.bars?[measnum!])!
                let (beat, residualTick) = bar2.beatAndTick(fromAbsTick: meta.eventTick)
                
                let tmp = midi!.monitor!.tempo(atTick: meta.eventTick, ticksPerQ: Int(tpq))
                let tempo = OnelineTST.init(TempoWithZerobaseMeas: measnum!, beat: beat!, tick: residualTick!, tmp: tmp!, obj: meta)
                //let tempo = TST.Tempo(bar: measnum!, beat: beat, tick: residualTick, tempo: tmp!)
                //let one = OnelineTST.init(tst: tempo)
                tstLines.append(tempo)
            }
        }
        tstLines.sort(by: {
            // compare bar number first.
            // If they are the same, then time signature comes
            // first followed by tempo
            if Int($0.meas) == Int($1.meas) {
                if $0.type == "Time Sig" {
                    return true
                } else {
                    return false
                }
            }
            if Int($0.meas)! < Int($1.meas)! {
                return true
            }
            return false
            }
        )
        
        TSTtableView.reloadData()
    }
    
    func TSTviewObserver(notf: Notification) {
        switch notf.name {
        case ntDocumentOpened:
            midi = notf.object as? MidiData
            loadData()
        default:
            print("TST view receive notification \(notf.name.rawValue)")
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if midi == nil {
            return 0
        }
        return tstLines.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let tsFlag = tstLines[row].type == "Time Sig" ? true : false
        
        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        
        switch (tableColumn?.identifier)!.rawValue {
        case "TST Type":
            cell?.textField?.stringValue = tstLines[row].type
        case "TST Bar":
            cell?.textField?.stringValue = tstLines[row].meas
        case "TST Beat":
            cell?.textField?.stringValue = tstLines[row].beat
        case "TST Tick":
            cell?.textField?.stringValue = tstLines[row].tick
        case "TST Value":
            cell?.textField?.stringValue = tstLines[row].value
        default: // then this must be value field
            cell?.textField?.stringValue = "***"
        }
        cell?.textField?.textColor = tsFlag ? tsColor : tmpColor

        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = TSTtableView.selectedRow
        if selectedRow >= 0 && selectedRow < tstLines.count-1  {
            let line = tstLines[selectedRow]
            if line.type == "Time Sig" {
                let (meas, ts) = line.timeSigText()
                if meas == nil || ts == nil {
                    return
                }
                barField.stringValue = meas!
                beatField.stringValue = "***"
                tickField.stringValue = "***"
                valueField.stringValue = ts!
                typeSelectionPopUp.selectItem(withTitle: "Time Sig")
            } else {
                // it must be tempo
                barField.stringValue = line.meas
                beatField.stringValue = line.beat
                tickField.stringValue = line.tick
                valueField.stringValue = line.value
                typeSelectionPopUp.selectItem(withTitle: "Tempo")
            }
            editButton.isEnabled = true
            removeButton.isEnabled = true
            insertButton.isEnabled = true
        }
    } // closure of tableViewSelectionDidChange
    
    @IBAction func editAction(_ sender: Any) {
        // edit button action
        if editButton.state == NSTextField.StateValue.on {
            // show Measure field is on focus
            focusField(tag: FocusedField.Meas)
        } else {
            offFocus()
        }
    }
    
    func offFocus() ->Void {
        switch curFocus {
        case .Meas:
            barField.backgroundColor = NSColor.controlBackgroundColor
        case .Beat:
            beatField.backgroundColor = NSColor.controlBackgroundColor
        case .Tick:
            tickField.backgroundColor = NSColor.controlBackgroundColor
        //case .Value:
        default:
             valueField.backgroundColor = NSColor.controlBackgroundColor
        
        }
    }
    
//    override func keyDown(with event: NSEvent) {
//        print("keyCode in TST editor = \(event.keyCode), char = \(String(describing: event.characters))")
//    }
    
    func myKey(with event:NSEvent) {
        if editButton.state == NSTextField.StateValue.off {
            return
        }
        switch event.keyCode {
        case 48: // tab key
            // cycle key focus
            keyTab(with: event)
        default:
            print("myKey in TSTViewController is called, keycode:\(event.keyCode), char:\(String(describing: event.characters))")
        }
    }
    
    func keyTab(with event: NSEvent) {
        
        if editButton.state == NSTextField.StateValue.off {
            return
        }
        
        if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
            // shift is pressed down
            switch curFocus {
            case .Meas:
                curFocus = .Value
            case .Beat:
                curFocus = .Meas
            case .Tick:
                curFocus = .Beat
            case .Value:
                curFocus = .Tick
            default:
                curFocus = .Meas
            }
        } else {
            switch curFocus {
            case .Meas:
                curFocus = .Beat
            case .Beat:
                curFocus = .Tick
            case .Tick:
                curFocus = .Value
            case .Value:
                curFocus = .Meas
            default:
                curFocus = .Meas
            }
        }
        focusField(tag: curFocus)
    }
    
    func focusField(tag: FocusedField) {
        
        switch tag {
        case .Meas:
            barField.backgroundColor = NSColor.systemYellow
            beatField.backgroundColor = NSColor.controlBackgroundColor
            tickField.backgroundColor = NSColor.controlBackgroundColor
            valueField.backgroundColor = NSColor.controlBackgroundColor
        case .Beat:
            barField.backgroundColor = NSColor.controlBackgroundColor
            beatField.backgroundColor = NSColor.systemYellow
            tickField.backgroundColor = NSColor.controlBackgroundColor
            valueField.backgroundColor = NSColor.controlBackgroundColor
        case .Tick:
            barField.backgroundColor = NSColor.controlBackgroundColor
            beatField.backgroundColor = NSColor.controlBackgroundColor
            tickField.backgroundColor = NSColor.systemYellow
            valueField.backgroundColor = NSColor.controlBackgroundColor
        case .Value:
            barField.backgroundColor = NSColor.controlBackgroundColor
            beatField.backgroundColor = NSColor.controlBackgroundColor
            tickField.backgroundColor = NSColor.controlBackgroundColor
            valueField.backgroundColor = NSColor.systemYellow
        default:    // none
            barField.backgroundColor = NSColor.controlBackgroundColor
            beatField.backgroundColor = NSColor.controlBackgroundColor
            tickField.backgroundColor = NSColor.controlBackgroundColor
            valueField.backgroundColor = NSColor.controlBackgroundColor
        }
    }
    
    
    override func becomeFirstResponder() -> Bool {
        // return true
        return false
    }
    
    override func resignFirstResponder() -> Bool {
        return true
    }
}
