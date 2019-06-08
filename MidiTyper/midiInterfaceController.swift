//
//  MIDIViewController.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/05/25.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Cocoa

fileprivate enum CellIdentifiers {
    static let DeviceCell = "DeviceCell"
    static let EntityCell = "EntityCell"
    static let SourceCell = "SourceCell"
    static let DestinationCell = "DestinationCell"
}



class midiInterfaceController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    let del = NSApplication.shared.delegate as! AppDelegate
    var midiIF: MidiInterface?
    var thisWin: NSWindow?
    var closeButton: NSButton?
    
    @IBOutlet weak var setSource: NSButton!
    @IBOutlet weak var setDestination: NSButton!
    @IBOutlet weak var selectedDestinationText: NSTextField!
    @IBOutlet weak var IFtableView: NSTableView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        if midiIF == nil {
            midiIF = del.midiInterface!
            
            // debug
            // IFtableView.reloadData()
        } // end if midiIF == nil
        let sr = IFtableView?.selectedRow
        if sr != nil {
            validatingSetDestinationbutton(sr!)
        }
        
        thisWin = self.view.window
        setDestinationText()
        closeButton = thisWin?.standardWindowButton(NSWindow.ButtonType.closeButton)
        closeButton?.isEnabled = true
        
    } // end of viewDidLoad()
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier! == "ShowKeyAssignTableSheetSegue" {
            let kavc = segue.destinationController as! KeyAssignViewController
            // this code below doesn't work for unknown reason
            // I'm using notification to set var window in
            // keyAssignTableView controller
            kavc.parentWin = thisWin
        }
    }
    

    /* tableview delegate
     */

    func numberOfRows(in tableView: NSTableView) -> Int {
        if let count = midiIF?.endPoints.count {
            return count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var color: NSColor
        
        // load the data in this row first
        if tableColumn == nil {
            return nil
        }
        
        let endp = midiIF!.endPoints[row]
        
        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        
        if midiIF?.endPoints[row].connected == true {
            let rowView = tableView.rowView(atRow: row, makeIfNecessary: true)
            rowView?.backgroundColor = NSColor.systemOrange
        }
        
        switch (tableColumn?.identifier)!.rawValue {
        case CellIdentifiers.DeviceCell:
            cell?.textField?.stringValue = endp.names["Device"]!
            if endp.endpointType == midiRefType.kDestinationPoint {
                color = NSColor.controlTextColor
            } else {
                color = NSColor.lightGray
            }
        case CellIdentifiers.EntityCell:
            cell?.textField?.stringValue = endp.names["Entity"]!
            if endp.endpointType == midiRefType.kDestinationPoint {
                color = NSColor.controlTextColor
            } else {
                color = NSColor.lightGray
            }
        case CellIdentifiers.DestinationCell:
            if endp.endpointType == midiRefType.kDestinationPoint {
                //cell?.textField?.stringValue = endp.names["EndPoint"]!
                cell?.imageView?.image = NSImage(named: "if_Midi_113178.icns")
                color = NSColor.controlTextColor
                if endp.connected == true {
                    cell?.textField?.stringValue = "Connected"
                }
            } else {
                color = NSColor.lightGray
            }
        case CellIdentifiers.SourceCell:
            if endp.endpointType == midiRefType.kSourcePoint {
                //cell?.textField?.stringValue = endp.names["EndPoint"]!
                cell?.imageView?.image = NSImage(named: "if_Midi_113178.icns")
                if endp.connected == true {
                    cell?.textField?.stringValue = "Connected"
                }
            }
            if endp.endpointType == midiRefType.kDestinationPoint {
                color = NSColor.controlTextColor
            } else {
                color = NSColor.lightGray
            }
        default:
            color = NSColor.lightGray
            break
        }
        cell?.textField?.textColor = color
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if midiIF == nil {
            return false
        }
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let sr = IFtableView!.selectedRow
        validatingSetDestinationbutton(sr)
    }
    
    func validatingSetDestinationbutton(_ row:Int) {
        let sr = IFtableView!.selectedRow
        if sr == -1 {
            setDestination.isEnabled = false
            return
        }
        
        if midiIF?.endPoints[sr].endpointType == midiRefType.kDestinationPoint {
            setDestination.isEnabled = true
        } else {
            setDestination.isEnabled = false
        }
    }

    @IBAction func setMidiDestination(_ sender: Any) {
        if midiIF != nil {
            let sr = IFtableView!.selectedRow
            midiIF!.setDestination(numInArray:sr)
            setDestinationText()
        }
    }
    
    private func setDestinationText() {
        if midiIF == nil { return }
        
        if midiIF!.connectedDestination != nil {
            let devName = midiIF!.connectedDestination?.names["Device"]
            let EntName = midiIF!.connectedDestination?.names["Device"]
            let epName = midiIF!.connectedDestination?.names["EndPoint"]
            if devName != nil && EntName != nil && epName != nil {
                selectedDestinationText.stringValue = devName! + ": " + EntName! + ": " + epName!
            }
        }
    }
    

} // end of class

