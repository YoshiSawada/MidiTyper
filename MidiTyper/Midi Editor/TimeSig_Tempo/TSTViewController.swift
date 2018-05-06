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

    @IBOutlet weak var TSTtableView: NSTableView!
    @IBOutlet weak var typeSelectionPopUp: NSPopUpButton!
    @IBOutlet weak var barField: NSTextField!
    @IBOutlet weak var beatField: NSTextField!
    @IBOutlet weak var tickField: NSTextField!
    @IBOutlet weak var valueField: NSTextField!
    
    var docCon: NSDocumentController?
    var midi: MidiData?
    var tstLines: [OnelineTST] = Array<OnelineTST>()
    
    let tsColor = NSColor.systemOrange
    let tmpColor = NSColor.black

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        docCon = NSDocumentController.shared
        let nc = NotificationCenter.default
        nc.addObserver(forName: ntDocumentOpened, object: nil, queue: nil, using: TSTviewObserver)

        typeSelectionPopUp.removeAllItems()
        typeSelectionPopUp.addItems(withTitles: types)
        
        // debug
        if docCon?.currentDocument != nil {
            print("doc con has a currentDocument")
        } else {
            print("current doc is nil")
        }
        
        loadData()
    }
    
    func loadData() {
        guard docCon?.currentDocument != nil else {
            return
        }
        midi = docCon!.currentDocument! as? MidiData
        
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
                let residual = meta.eventTick - bar2.startTick
                let tickPerBeat = bar2.barLen / bar2.timeSig["num"]!
                let beat = residual / tickPerBeat
                let residualTick = residual - beat * tickPerBeat
                
                let tmp = midi!.monitor!.tempo(atTick: meta.eventTick, ticksPerQ: Int(tpq))
                let tempo = OnelineTST.init(TempoWithZerobaseMeas: measnum!, beat: beat, tick: residualTick, tmp: tmp!, obj: meta)
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
    
}
