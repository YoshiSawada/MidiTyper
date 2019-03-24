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
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var enterButton: NSButton!
    @IBOutlet weak var changeRadioButton: NSButton!
    @IBOutlet weak var insertRadioButton: NSButton!
    
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
        //typeSelectionPopUp.isEnabled = false
        
        //changeRadioButton.isEnabled = false
        removeButton.isEnabled = false
        //enterButton.isEnabled = false
        
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
        //TSTtableView.refusesFirstResponder = true
    }
    
    func setMidiData(midiData:MidiData?) -> Bool {
        
        guard midiData != nil else {
            print("midiData in parameter for setMidiData is nil")
            return false
        }
        
        midi = midiData
        
        loadData()
        
        return true
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
                let ts = OnelineTST.init(BarWithZerobaseMeas: bar.measNum, num: bar.timeSig["num"]!, denom: bar.timeSig["denom"]!)
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
                let tempo = OnelineTST.init(TempoWithZerobaseMeas: measnum!, beat: beat!, tick: residualTick!, tmp: tmp!)
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
        if selectedRow >= 0 && selectedRow < tstLines.count  {
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
            typeSelectionPopUp.isEnabled = true
            changeRadioButton.isEnabled = true
            removeButton.isEnabled = true
            enterButton.isEnabled = true
        } else {
            typeSelectionPopUp.isEnabled = false
            changeRadioButton.isEnabled = false
            removeButton.isEnabled = false
            enterButton.isEnabled = false
        }
    } // closure of tableViewSelectionDidChange
    
    func makeTSTLine() -> OnelineTST? {
        // validate bar field
        let barVal = barField.integerValue
        if barVal == 0 {
            print("bar value must be 1 or greater")
            return nil
        }
        
        let beatVal = beatField.integerValue
        if beatVal == 0 {
            print("beat value must be 1 or greater")
            return nil
        }
        
        let tickVal = tickField.integerValue
        
        var aLine: OnelineTST?
        
        if typeSelectionPopUp.titleOfSelectedItem == "Time Sig" {
            // validate time sig field
            let div = valueField.stringValue.firstIndex(of: "/")
            if div == nil {
                NSSound.beep()
                return nil
            }
            
            //let numStr = valueField.stringValue.prefix(upTo: div!)
            let two = valueField.stringValue.split(separator: "/")
            if two.count != 2 {
                NSSound.beep()
                return nil
            }
            //let numStr = valueField.stringValue[..<div!]
            let numStr = two[0]
            let num = Int(numStr)
            if num == nil || num == 0 {
                NSSound.beep()
                return nil
            }
            
//            let s = valueField.stringValue[div!..]
//            let denomStr = s.dropFirst()
            var denom = Int(two[1])
            var denomOK: Bool
            switch denom {
            case 2:
                denom = 1
                denomOK = true
            case 4:
                denom = 2
                denomOK = true
            case 8:
                denom = 3
                denomOK = true
            case 16:
                denom = 4
                denomOK = true
            case 32:
                denom = 5
                denomOK = true
            case 64:
                denom = 6
                denomOK = true
            default:
                denomOK = false
            }
            if denomOK == false {
                NSSound.beep()
                return nil
            }

            aLine = OnelineTST.init(BarWithZerobaseMeas: barVal-1, num: num!, denom: denom!)
            
        } else {
            // Then consider it's tempo
            if barVal < 1 {
                print("bar value must be 1 or greater")
            }
            if beatVal == 0 {
                print("beat value must be 1 or greater")
                return nil
            }
            if tickVal < 0 {
                print("tick value must be 0 or greater")
            }

            let tempo = valueField.doubleValue
            if tempo < 5 || tempo > 350 {
                // the limiter is place holder and I didn't decide
                // what the limit should be yet.
                print("tempo value is not valid or out of range")
                return nil
            }
            aLine = OnelineTST.init(TempoWithZerobaseMeas: barVal-1, beat: beatVal-1, tick: tickVal, tmp: tempo)
        }
        
        return aLine
    }   // closure of makeTSTLine
    
    @IBAction func changeAction(_ sender: Any) {
        // change button action
            // validate if the row is selected
        let tagval = (sender as! NSButton).tag
        print("tag value is \(tagval)")
    }
    
    @IBAction func removeAction(_ sender: Any) {
        let selRow = TSTtableView.selectedRow
        if selRow < 2 {
            // The first tempo and Time sig should not be deleted
            return
        }
        // check if the selected one is the first Tempo event
        if tstLines[selRow].type == "Tempo" {
            for i in 0..<selRow {
                if tstLines[i].type == "Tempo" {
                    // OK to delete the tempo in focus
                    tstLines.remove(at: selRow)
                    break
                }
            } // end for i in..
        } else {
            // then Time Sig
            tstLines.remove(at: selRow)
        }
        
        TSTtableView.reloadData()
    }
    
    @IBAction func typeSelected(_ sender: Any) {

        let selRow = TSTtableView.selectedRow
        
        if (sender as! NSPopUpButton).titleOfSelectedItem == "Time Sig" {
            if selRow != -1 {
                let line = tstLines[selRow]
                barField.stringValue = line.meas
            } else {
                barField.stringValue = "1"
            }
            beatField.stringValue = "***"
            tickField.stringValue = "***"
            valueField.stringValue = "4/4"
        } else {
            // tempo is selected
            if selRow != -1 {
                let line = tstLines[selRow]
                if Int(line.meas) ?? 1 < 1 {
                    barField.stringValue = "1"
                }
                if line.beat == "***" {
                    beatField.stringValue = "1"
                } else {
                    beatField.stringValue = line.beat
                }
                if line.tick == "***" {
                    tickField.stringValue = "0"
                } else {
                    tickField.stringValue = line.tick
                }
                
                var tval = Int(line.value) ?? 120
                if tval < line.lowestTempo {
                    tval = line.lowestTempo
                }
                if tval > line.highestTempo {
                    tval = line.highestTempo
                }
                
                valueField.stringValue = String(tval)
            } else {
                barField.stringValue = "1"
                beatField.stringValue = "1"
                tickField.stringValue = "0"
                valueField.stringValue = "120"
            }
        }
    }

    
    @IBAction func enterAction(_ sender: Any) {
        let aLine = makeTSTLine()
        if aLine == nil {
            return
        }
        
        let selectedRow = TSTtableView.selectedRow
        
        if insertRadioButton.state == NSControl.StateValue.on {
            // insert mode
            tstLines.append(aLine!)
            sortTstLines()
        } else {
            // change mode
            if selectedRow == -1 {
                return
            }
            tstLines.remove(at: selectedRow)
            tstLines.insert(aLine!, at: selectedRow)
            sortTstLines()
        }
        
        TSTtableView.reloadData()
        
        if rebuildBarSeq() == false {
            del?.displayAlert("failed to rebuild barSeqTemplate")
            return
        }
        
        if rebuildTempoMap() == false {
            del?.displayAlert("failed to rebuild tempoMap")
        }
    }
    
    // When rebuild Time signature and tempo,
    // rebuild Time Signature first as it's got the info
    // for ticks for bars.
    func rebuildBarSeq() -> Bool {
        if midi == nil { return false }
        if midi!.barSeqTemplate.bars == nil { return false }
        
        var bars = Array<Bar>()
        var elapsedTick: Int = 0
        
        for ts in tstLines {
            if case let .TimeSig(ibar, inum, idenom) = ts.aTst {
                let tpq = midi!.ticksPerQuarter ?? 480
                let bar = Bar.init(measNum: ibar, startTick: elapsedTick, numerator: inum, denominator: idenom, ticksPerQuarter: Int(tpq))
                
                elapsedTick = bar.nextBarTick
                
                bars.append(bar)
            }
        }

        midi!.barSeqTemplate.bars!.removeAll(keepingCapacity: true)
        for bar in bars {
            midi!.barSeqTemplate.bars!.append(bar)
        }

        return true
    }
    
    func rebuildTempoMap() -> Bool {
        
        guard let mon = midi?.monitor else {
            return false
        }
        
        mon.resetTempoMap()
        
        for ts in tstLines {
            if case let .Tempo(ibar, ibeat, itick, dtempo) = ts.aTst {
                guard let ticksForMeas = midi!.barSeqTemplate.ticksForMeas(zeroBaseMeas: ibar, Expandable: true) else {
                    return false
                }
                
                guard let relTick = midi!.barSeqTemplate.bars![ibar].relTick(fromBeat: ibeat, andTick: itick) else {
                    return false
                }
                
                let nanoPerQuarter = Double(60 * 1000000000) / dtempo
                let nanoPerTick = __uint64_t(nanoPerQuarter) / 480
                
                let tempoTick = ticksForMeas + relTick
                
                mon.addTempoMapElement(eventTick: tempoTick, nanoPerTick: nanoPerTick)
            }
        }
        return true
    }
    
    // after edit action on timesig or tempo, call this function and sort the order in the table
    func sortTstLines() -> Void {
        var sortedArray = Array<OnelineTST>()
        var earliest: OnelineTST
        var index:Int
        
        if tstLines.count < 2 { return }

        
        while tstLines.count > 1 {
            earliest = tstLines[0]
            index = 0
            // I should rewrite this with case clause 2019/2/19
            for i in 1..<tstLines.count {
                
                if sortTwoTST(a: earliest, b: tstLines[i]) == false {
                    earliest = tstLines[i]
                    index = i
                }
            } // end of for
            sortedArray.append(earliest)
            tstLines.remove(at: index)
            if tstLines.count == 1 {
                // the last one won't be compared.
                // I just put it at the end of sorted array
                sortedArray.append(tstLines[0])
            }
        }
        tstLines.removeAll()
        tstLines = sortedArray  // debug ; don't know if this instance will be kept further on.
    }
    
    private func sortTwoTST(a:OnelineTST, b:OnelineTST) -> Bool {
        enum TstType {
            case TimeSignature
            case Tempo
        }
        var (type1, meas1, beat1, tick1):(TstType, Int, Int, Int)
        var (type2, meas2, beat2, tick2):(TstType, Int, Int, Int)
        // parse a
        let aMeas = Int(a.meas) ?? 1
        if a.type == "Time Sig" {
            let aBeat = 1
            let aTick = 1
            (type1, meas1, beat1, tick1) = (.TimeSignature, aMeas, aBeat, aTick)
        } else { // tempo
            let aBeat = Int(a.beat) ?? 1
            let aTick = Int(a.tick) ?? 1
            (type1, meas1, beat1, tick1) = (.Tempo, aMeas, aBeat, aTick)
        }
        
        // parseb
        let bMeas = Int(b.meas) ?? 1
        if b.type == "Time Sig" {
            let bBeat = 1
            let bTick = 1
            (type2, meas2, beat2, tick2) = (.TimeSignature, bMeas, bBeat, bTick)
        } else {
            let bBeat = Int(b.beat) ?? 1
            let bTick = Int(b.tick) ?? 1
            (type2, meas2, beat2, tick2) = (.Tempo, bMeas, bBeat, bTick)

        }
        
        switch (type1, type2) {
        case (.TimeSignature, .TimeSignature):
            return aMeas < bMeas
        case (.TimeSignature, .Tempo):
            if meas1 <= meas2 {
                return true
            } else {
                // TimeSignature has no beat or tick
                // TimeSignature should come first
                return false
            }
        case (.Tempo, .TimeSignature):
            if meas1 < meas2 {
                return true
            } else { // if meas are the same, time sig should come first
                return false
            }
        default: // it's got to be .Tempo .Tempo
            if meas1 < meas2 {
                return true
            }
            if meas1 > meas2 {
                return false
            }
            // then meas 1 == meas2
            if beat1 < beat2 {
                return true
            }
            if beat1 > beat2 {
                return false
            }
            // beat1 == beat2 then
            if tick1 < tick2 {
                return true
            } else {
                return false
            }
        } // end of switch
    } // End of sortTwoTsT
    
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
        if changeRadioButton.state == NSTextField.StateValue.off {
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
        
        if changeRadioButton.state == NSTextField.StateValue.off {
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
        return true
        //return false
    }
    
    override func resignFirstResponder() -> Bool {
        return true
    }
}
