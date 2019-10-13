//
//  KeyAssignViewController.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/11/13.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Cocoa


class KeyAssignViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {

    
    @IBOutlet weak var keyAssignTableView: NSTableView!
    @IBOutlet weak var restore2defaultButton: NSButton!
    @IBOutlet weak var editShortcutKeyButton: NSButton!
    @IBOutlet weak var compareButton: NSButton!
    
    var del:AppDelegate?
    var compareKeyAssignBuffer = [keyAssign]()
    let nc = NotificationCenter.default
    var textFielsInTable = [KeyAssignTextField]()
    var selectedLine: Int = -1
    var isTableDirty: Bool = false
    var parentWin:NSWindow?
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        del = NSApp.delegate as? AppDelegate
        guard del != nil else {
            print("AppDelegate cannot be loaded in KeyAssignViewController")
            exit(1)
        } // I can use del! for the rest of the codes

        for i in 0 ..< keyAssignTableView.numberOfRows {
            let rview = keyAssignTableView.rowView(atRow:i, makeIfNecessary:true)
            rview?.resignFirstResponder()
            
            for k in 1 ..< keyAssignTableView.numberOfColumns {
                let cell:NSTableCellView? = keyAssignTableView.view(atColumn: k, row: i, makeIfNecessary: true) as? NSTableCellView
                cell?.textField?.isEditable = false
                cell?.textField?.isSelectable = true
                let myTextField = cell?.textField as? KeyAssignTextField
                if myTextField != nil {
                    // myTextField!.posInTable = (i, k)
                    // above line should be executed in tableView call
                    // otherwise the order of instance will be mingled.
                    textFielsInTable.append(myTextField!)
                } else {
                    print("myTextField is nil in i = \(i)")
                }
            }
        }
        
        if textFielsInTable.count > 0 {
            textFielsInTable = textFielsInTable.sorted(by: {$0.posInTable.0 < $1.posInTable.0})
        }
        
        keyAssignTableView.allowsTypeSelect = false
        
        nc.addObserver(forName: NSTableView.selectionIsChangingNotification, object: nil, queue: nil, using: tvObserver)
        nc.addObserver(forName: NSTableView.selectionDidChangeNotification, object: nil, queue: nil, using: tvObserver)
        
            // let setupWindowController know this object
        nc.post(name: ntKeyAssignTableLoaded, object: self)
        // prepare to get double click event
        //keyAssignTableView.target = self
        //keyAssignTableView.doubleAction = #selector(tableViewDoubleClick(_:))
    }
    
    func tvObserver(notice: Notification) -> Void {
        switch notice.name {
        case NSTableView.selectionIsChangingNotification:
            let col = keyAssignTableView.selectedColumn
            let row = keyAssignTableView.selectedRow
            print("selectionIsChanging from row:\(row), column:\(col)")
            
        case NSTableView.selectionDidChangeNotification:
            let col = keyAssignTableView.selectedColumn
            let row = keyAssignTableView.selectedRow
            doSelectionChange(from: selectedLine)
            print("got selectionDidChange row:\(row), column:\(col)")
        default:
            print("got notification : ")
            print(notice.name)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        
        if editShortcutKeyButton.state == NSControl.StateValue.off { return }
        
        if keyAssignTableView.selectedRow == -1 { return }  // no row is selected
        
        // edit keyAssignTable
        let row = keyAssignTableView.selectedRow
        let idx = del!.theKat?.keyAssignTable.firstIndex(where: { $0.position == row+1 } )
        if idx == nil { return }
        del!.theKat!.keyAssignTable[idx!].keyLabel = event.characters!
        del!.theKat!.keyAssignTable[idx!].keycode = event.keyCode
        del!.theKat!.isTableDirty = true
        isTableDirty = true
        
        // change the values in tableview, column char
        let idx2 = textFielsInTable.firstIndex(where: { $0.posInTable.0 == row && $0.posInTable.1 == 1 })
        let cell = textFielsInTable[idx2!]
        
        // some keycode doesn't have corresponding single char representation, clear for instance
        // In that case, force it to have more human readable string
        switch del!.theKat!.keyAssignTable[idx!].keycode {
        case 71:
            cell.stringValue = "clear"
        case 117:
            cell.stringValue = "del->"
        case 119:
            cell.stringValue = "end"
        case 121:
            cell.stringValue = "pagedown"
        case 116:
            cell.stringValue = "pageup"
        case 105:
            cell.stringValue = "F13"
        case 107:
            cell.stringValue = "F14"
        case 113:
            cell.stringValue = "F15"
        case 106:
            cell.stringValue = "F16"
        case 64:
            cell.stringValue = "F17"
        case 79:
            cell.stringValue = "F18"
        case 80:
            cell.stringValue = "F19"
        case 76:
            cell.stringValue = "enter"
        default:
            cell.stringValue = del!.theKat!.keyAssignTable[idx!].keyLabel
        }
        
        // change the value in tableview, column keycode
        let idx3 = textFielsInTable.firstIndex(where: { $0.posInTable.0 == row && $0.posInTable.1 == 2 } )
        
        let cell2 = textFielsInTable[idx3!]
        cell2.stringValue = String.init(format:"%d", del!.theKat!.keyAssignTable[idx!].keycode)
        
        var fr = cell.frame
        cell.draw(fr)
        fr = cell2.frame
        cell2.draw(fr)
        
        print("keyCode = \(event.keyCode), char = \(String(describing: event.characters))")

    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        return true
    }

    
    // MARK: - tableView coding
    //
    func numberOfRows(in tableView: NSTableView) -> Int {
        let count = del!.theKat?.keyAssignTable.count
        return count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        
        switch (tableColumn?.identifier)!.rawValue {
        case "ActionCell":
            cell?.textField?.stringValue = del!.theKat!.keyAssignTable[row].action
        case "KeyCell":
            let texf: KeyAssignTextField? = cell?.textField as? KeyAssignTextField
            texf?.stringValue = del!.theKat!.keyAssignTable[row].keyLabel
            texf?.posInTable = (row, 1)
        case "CodeCell":
            let texf: KeyAssignTextField? = cell?.textField as? KeyAssignTextField
            let st = String.init(format:"%d",del!.theKat!.keyAssignTable[row].keycode)
            texf?.stringValue = st
            texf?.posInTable = (row, 2)
        default:
            return nil
        }
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        if tableColumn == nil { return false }
        if tableColumn!.identifier.rawValue == "ActionCell" {
            return false
        }
        return true
    }
    
    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return true
    }
    
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        //if event == nil { return false }
        
//        if event != nil {
//            switch event!.type {
//            case NSEvent.EventType.keyDown:
//                print("I've got keyDown")
//                return false
//            default:
//                print("got into default in validating")
//            }
//        }

        return false
    }
    
    
    // MARK: - Field edit
    //
    
    // double clicked
    //
    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        let row = keyAssignTableView.clickedRow
        let column = keyAssignTableView.clickedColumn
        
        print("row:\(row), column:\(column)")
    }
    
    @IBAction func editShortcutKey(_ sender: Any) {
        let row = keyAssignTableView.selectedRow
        if editShortcutKeyButton.state == NSControl.StateValue.off {
            // Erase enclosure that indicates selection
            if row != -1 {
                doSelectionChange(from: selectedLine)
            }
            return
        }
        
        if keyAssignTableView.selectedRow == -1 {    // no cell is selected. Force the 1st cell be selected
            keyAssignTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)    // set it to default cell
        }
        
        doSelectionChange(from: selectedLine)
    }
    
    func doSelectionChange(from: Int) -> Void {
        // Erase the enclosure on the currently selected row
        var r: CGRect

        if from >= 0 && from < keyAssignTableView.numberOfRows {
            guard let ind = textFielsInTable.firstIndex(where: {$0.posInTable.0 == from}) else {
                print("doSelectionChange pos1; index for textFieldInTable out of range")
                return
            }
            
            for ix in ind...ind+1 {
                textFielsInTable[ix].selected = false
                r = textFielsInTable[ix].frame
                textFielsInTable[ix].setNeedsDisplay()
                textFielsInTable[ix].display(r)
            }
        }
        
        // Draw rect on newly selected row
        
        if editShortcutKeyButton.state == NSControl.StateValue.on {
            guard let ind = textFielsInTable.firstIndex(where: {$0.posInTable.0 == keyAssignTableView.selectedRow}) else {
                print("doSelectionChange pos2; index for textFieldInTable out of range")
                return
            }
            for ix in ind...ind+1 {
                // enclose the selected cells
                //
                textFielsInTable[ix].selected = true
                r = textFielsInTable[ix].frame
                textFielsInTable[ix].setNeedsDisplay()
                textFielsInTable[ix].draw(r)
            }
            selectedLine = keyAssignTableView.selectedRow
        }
    }
    
    @IBAction func compareWithDefault(_ sender: Any) {
        if compareButton.state == NSControl.StateValue.on {
            // temporary make the key assign table back to the default
            compareKeyAssignBuffer = del!.theKat!.keyAssignTable
            del!.theKat!.makeKeyAssignTable(from: del!.theKat!.defaultKeyAssignTable)
            keyAssignTableView.reloadData()
        } else {
            if compareKeyAssignBuffer.count > 0 {
                del!.theKat!.makeKeyAssignTable(from: compareKeyAssignBuffer)
                keyAssignTableView.reloadData()
            }
        }
    }
    
    
    @IBAction func restoreDefaultKeyAssign(_ sender: Any) {
        let al = NSAlert()
        al.messageText = "Are you sure?"
        al.informativeText = "You cannot recall the setting you currently have!!"
        al.alertStyle = .warning
        al.addButton(withTitle: "Cancel")
        al.addButton(withTitle: "Yes, do it")
        al.beginSheetModal(for: keyAssignTableView.window!, completionHandler: { (modalresponse) ->Void in
            if modalresponse == NSApplication.ModalResponse.alertFirstButtonReturn {
                return
            }
            if self.del!.theKat!.keyAssignTable.count > 0 {
                self.del!.theKat!.keyAssignTable.removeAll()
            }
            self.del!.theKat!.makeKeyAssignTable(from: self.del!.theKat!.defaultKeyAssignTable)
            // self.makeKeyAssignTable(from: self.defaultKeyAssignTable)
            self.del!.theKat?.saveKeyAssign()
            // self.saveKeyAssign()
            self.keyAssignTableView.reloadData()
        })
    }
}   // end of class
