//
//  KeyAssignViewController.swift
//  myFirstMidi_r0.2
//
//  Created by Yoshi Sawada on 2017/11/13.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Cocoa

class keyAssign: NSObject, NSCoding {

    
    let position: Int
    let action: String
    var keyLabel: String
    var keycode: UInt16

    init(position:Int, action:String, keyLabel:String, code:UInt16) {
        self.position = position
        self.action = action
        self.keyLabel = keyLabel
        self.keycode = code
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(position, forKey: "position")
        aCoder.encode(action, forKey: "action")
        aCoder.encode(keyLabel, forKey: "keyLabel")
        aCoder.encode(Int(keycode), forKey: "keycode")
    }
    
    required convenience init?(coder aDecoder: NSCoder) {

        let pos = aDecoder.decodeInteger(forKey: "position")
        
        let ac = aDecoder.decodeObject(forKey: "action")
        if ac == nil { return nil }

        let keylbl = aDecoder.decodeObject(forKey: "keyLabel")
        if keylbl == nil { return nil}
        
        let i = aDecoder.decodeInteger(forKey: "keycode")
        let kc = UInt16(i)

        self.init(position: pos , action: ac as! String, keyLabel: keylbl as! String, code: kc)
    }
}

class KeyAssignViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    
    // in case property list is broken, I need to create the key assinment file from this scratch
    let defaultKeyAssignTable:[keyAssign] = [
        keyAssign(position: 1, action: "C", keyLabel: "1", code: 83),
        keyAssign(position: 2, action: "C#", keyLabel: "2", code: 84),
        keyAssign(position: 3, action: "D", keyLabel: "3", code: 85),
        keyAssign(position: 4, action: "D#", keyLabel: "4", code: 86),
        keyAssign(position: 5, action: "E", keyLabel: "5", code: 87),
        keyAssign(position: 6, action: "F", keyLabel: "6", code: 88),
        keyAssign(position: 7, action: "F#", keyLabel: "7", code: 89),
        keyAssign(position: 8, action: "G", keyLabel: "8", code: 91),
        keyAssign(position: 9, action: "G#", keyLabel: "9", code: 92),
        keyAssign(position: 10, action: "A", keyLabel: "clear", code: 71),
        keyAssign(position: 11, action: "A#", keyLabel: "=", code: 81),
        keyAssign(position: 12, action: "B", keyLabel: "/", code: 75),
        keyAssign(position: 13, action: "32th", keyLabel: "F15", code: 113),
        keyAssign(position: 14, action: "16th", keyLabel: "0", code: 82),
        keyAssign(position: 15, action: "8th", keyLabel: ".", code: 65),
        keyAssign(position: 16, action: "4th", keyLabel: "pagedown", code: 121),
        keyAssign(position: 17, action: "half", keyLabel: "pageup", code: 116),
        keyAssign(position: 18, action: "whole", keyLabel: "del->", code: 117),
        keyAssign(position: 19, action: "chord", keyLabel: "F16", code: 106),
        keyAssign(position: 20, action: "triplet", keyLabel: "F17", code: 64),
        keyAssign(position: 21, action: "dot", keyLabel: "F18", code: 79),
        keyAssign(position: 22, action: "slur", keyLabel: "F19", code: 80),
        keyAssign(position: 23, action: "+", keyLabel: "+", code: 69),
        keyAssign(position: 24, action: "-", keyLabel: "-", code: 78),
        keyAssign(position: 25, action: "enter", keyLabel: "enter", code: 76)
    ]
    
//    @IBOutlet weak var keyAssignTableView: NSTableView!
    @IBOutlet weak var keyAssignTableView: NSTableView!
    @IBOutlet weak var restore2defaultButton: NSButton!
    @IBOutlet weak var editShortcutKeyButton: NSButton!
    @IBOutlet weak var compareButton: NSButton!
    //    @IBOutlet weak var restore2defaultButton: NSButton!
//    @IBOutlet weak var editShortcutKeyButton: NSButton!
//    @IBOutlet weak var compareButton: NSButton!
//    @IBOutlet var containingView: NSView!
    
    var del:AppDelegate?
    var keyAssignTable = Array<keyAssign>()
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
        
        loadKeyAssign()
        
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

        
        //keyAssignTableView.window?.delegate = self as NSWindowDelegate
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
        let idx = keyAssignTable.index(where: { $0.position == row+1 } )
        if idx == nil { return }
        keyAssignTable[idx!].keyLabel = event.characters!
        keyAssignTable[idx!].keycode = event.keyCode
        isTableDirty = true
        
        // change the values in tableview, column char
        let idx2 = textFielsInTable.index(where: { $0.posInTable.0 == row && $0.posInTable.1 == 1 })
        let cell = textFielsInTable[idx2!]
        
        // some keycode doesn't have corresponding single char representation, clear for instance
        // In that case, force it to have more human readable string
        switch keyAssignTable[idx!].keycode {
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
            cell.stringValue = keyAssignTable[idx!].keyLabel
        }
        
        // change the value in tableview, column keycode
        let idx3 = textFielsInTable.index(where: { $0.posInTable.0 == row && $0.posInTable.1 == 2 } )
        
        let cell2 = textFielsInTable[idx3!]
        cell2.stringValue = String.init(format:"%d", keyAssignTable[idx!].keycode)
        
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
    
    func saveKeyAssign () {
        // make plist path
        var plistPath:String?
        var data:Data?
        let plistFileName = "keyAssign.plist"
        let fileMgr = FileManager.default
        var ret:Bool
        
        plistPath = Bundle.main.path(forResource: "KeyAssignTable", ofType: "plist")
        if plistPath == nil { // if budle.main is not accessile then
            let directorys : [String]? = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory,FileManager.SearchPathDomainMask.allDomainsMask, true)
            if directorys != nil {
                for str in directorys! {
                    if str.prefix(7) == "/Users/" {
                        plistPath = str
                        plistPath = plistPath?.appending("/MidiTyper/" + plistFileName)
                        if plistPath == nil {
                            del?.displayAlert("plistPath is nil")
                            return
                        }
                        ret = fileMgr.fileExists(atPath: plistPath!)
                        if ret == false {
                            do {
                                try fileMgr.createDirectory(atPath: str.appending("/MidiTyper"), withIntermediateDirectories: false, attributes: nil)
                            } catch {
                                print(error)
                                return
                            }
                        }
                        print(plistPath!)
                        data = NSKeyedArchiver.archivedData(withRootObject: keyAssignTable)
                        if data != nil {
                            let b = fileMgr.createFile(atPath: plistPath!, contents: data!, attributes: nil)
                            if b == false {
                                del?.displayAlert("Cannot save keyassign table")
                                return
                            }
                            // succeed
                        } else {
                            // must not happen
                            del?.displayAlert("failed to create key assign table data")
                            return
                        }
                        // save the path for key assign table to preference
                        let defaults = UserDefaults.standard
                        defaults.setValue(plistPath!, forKey: "KeyAssignTablePath")
                        isTableDirty = false

                        break
                    } // close of if str.prefix(9)
                }
            } // close of directorys != nil

        } else {  // close of if plistPath == nil and else clause follows
           return   // place holder, debug
        }
    }   // close of saveKeyAssign
    
    func loadKeyAssign() {
        let defaults = UserDefaults.standard
        let fileMgr = FileManager.default
        var ret:Bool

        //let path:String? = defaults.dictionary(forKey: "KeyAssignTablePath") as? String
        let path = defaults.value(forKey: "KeyAssignTablePath")
        var table: [keyAssign]?
        
        // debug -- store default values
        // when debug saveKeyAssign, let the line below; if path != nil, otherwise if path == nil
        if path == nil {    // path to preference doesn't exist
            table = defaultKeyAssignTable
            makeKeyAssignTable(from: table!)
            saveKeyAssign() // if this is the first time to launch
                // save the default key table in file
            return
        }
        
        ret = fileMgr.fileExists(atPath: path as! String)
        if ret == false {   // path string exists but the file doesn't
            table = defaultKeyAssignTable
            makeKeyAssignTable(from: table!)
            saveKeyAssign() // if this is the first time to launch
            // save the default key table in file
            return
        }

        table = (NSKeyedUnarchiver.unarchiveObject(withFile: path! as! String) as? [keyAssign])
        if table == nil { // file exists but no data there
            table = defaultKeyAssignTable
            table = table?.sorted(by: { $0.position < $1.position})
            makeKeyAssignTable(from: table!)
            saveKeyAssign()
        } else {
            table = table?.sorted(by: { $0.position < $1.position})
            makeKeyAssignTable(from: table!)
        }
    }
    
    // MARK: - tableView coding
    //
    func numberOfRows(in tableView: NSTableView) -> Int {
        return keyAssignTable.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        
        switch (tableColumn?.identifier)!.rawValue {
        case "ActionCell":
            cell?.textField?.stringValue = keyAssignTable[row].action
        case "KeyCell":
            let texf: KeyAssignTextField? = cell?.textField as? KeyAssignTextField
            texf?.stringValue = keyAssignTable[row].keyLabel
            texf?.posInTable = (row, 1)
        case "CodeCell":
            let texf: KeyAssignTextField? = cell?.textField as? KeyAssignTextField
            let st = String.init(format:"%d",keyAssignTable[row].keycode)
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
        
        if event != nil {
            switch event!.type {
            case NSEvent.EventType.keyDown:
                print("I've got keyDown")
                return false
            default:
                print("got into default in validating")
            }
        }

        return false
    }
    
    // MARK: Private functions
    //
    private func makeKeyAssignTable(from table:[keyAssign]) {
        
        if keyAssignTable.count > 0 {
            keyAssignTable.removeAll()
        }
        
        for item in table {
            let el = keyAssign.init(position: item.position, action: item.action, keyLabel: item.keyLabel, code: item.keycode)
            keyAssignTable.append(el)
        }
        // make sure the order in Array is identical to the order in position
        keyAssignTable = keyAssignTable.sorted(by: { $0.position < $1.position} )
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
            guard let ind = textFielsInTable.index(where: {$0.posInTable.0 == from}) else {
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
            guard let ind = textFielsInTable.index(where: {$0.posInTable.0 == keyAssignTableView.selectedRow}) else {
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
            compareKeyAssignBuffer = keyAssignTable
            makeKeyAssignTable(from: defaultKeyAssignTable)
            keyAssignTableView.reloadData()
        } else {
            if compareKeyAssignBuffer.count > 0 {
                makeKeyAssignTable(from: compareKeyAssignBuffer)
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
            if self.keyAssignTable.count > 0 {
                self.keyAssignTable.removeAll()
            }
            self.makeKeyAssignTable(from: self.defaultKeyAssignTable)
            self.saveKeyAssign()
            self.keyAssignTableView.reloadData()
        })
    }
}   // end of class
