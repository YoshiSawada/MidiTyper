//
//  MIDIInterface.swift
//  MyFirstMidi
//
//  Created by Yoshi Sawada on 2017/04/26.
//  Copyright © 2017年 Yoshi Sawada. All rights reserved.
//

import Foundation
import Cocoa
import CoreMIDI


enum midiRefType {
    case kDriver
    case kEntity
    case kSourcePoint
    case kDestinationPoint
}

    // MARK: - MIDI Node definition -

class MIDINode {
    var refType: midiRefType = .kDriver
    var midiRef: MIDIDeviceRef = 0
    var isOnline: Bool = false
    var name: String = ""
    var parent: MIDINode?
    var children = [MIDINode]()
    
    func setDev(refType type:midiRefType, midiRef mr:MIDIDeviceRef, isOnline online:Bool, name n:String) {
        refType = type
        midiRef = mr
        isOnline = online
        name = n
    }
    
}

class MidiIFEndpoint {
    let endpointType:midiRefType
    var names = [String:String]()   // device/entity/endpoint names
    var refNum = [String:UInt32]()  // device/tntity/endpoint reference numbers
    var connected:Bool = false
    
    // keys of dict shall be: "Device", "Entity" and "Endpoint"
    init?(MidiNode node:MIDINode) {
        
        if node.parent == nil { return nil }
        if node.parent!.parent == nil { return nil }
        
        endpointType = node.refType
        
        // initialize names
        self.names["EndPoint"] = node.name
        self.names["Entity"] = node.parent?.name
        self.names["Device"] = node.parent?.parent?.name
        
        self.refNum["EndPoint"] = node.midiRef
        self.refNum["Entity"] = node.parent?.midiRef
        self.refNum["Device"] = node.parent?.parent?.midiRef
    }
}

class MidiInterface: NSObject {

    var midiGraph = [MIDINode]()
    var scanned: Bool = false
    var objMidi:objCMIDIBridge?
    var del:AppDelegate?
    var endPoints = Array<MidiIFEndpoint>()
    var connectedDestination:MidiIFEndpoint?
    
    // actively connected end point
    var activeSource:MIDIDeviceRef = 0
    var activeDestination:MIDIDeviceRef = 0

    override init() {
        super.init()
    }

    override func awakeFromNib(){
        //var startTime: UInt64
        var er: OSStatus?

        if scanned == false {
            del = NSApp.delegate as? AppDelegate
            objMidi = del?.objMidi
            if objMidi == nil {
                del?.displayAlert("Cannot get reference to objMidi")
            }

            objMidi!.ysCreateClient()
            er = objMidi!.ysCreateOutputPort()
            if er != noErr {
                print("Cannot create output port for myself")
            }
            
            self.prepareContent()            
        }
    }

    
    func prepareContent() {

        var midiDevRef:MIDIDeviceRef?
        // let objc : objCBridge = objCBridge()
        
        // Explore MIDI device and port.
        
        let deviceCount = MIDIGetNumberOfDevices()
        if deviceCount==0 {
            print("MIDI device count is zero")
            return
        }
        
        var isOffline:Int32 = 0
        var isOnline:Bool
        
        
        // Explore Midi device driver and their end points
        //
        //
        for i in 0..<deviceCount {
            midiDevRef = MIDIGetDevice(i)
            if midiDevRef == nil {
                del?.displayAlert("midiDevRef is nill while the Midi dev count is valid")
                return
            }
            
            // add midiDevRef to array var
            //
            // getName finally worked on 2017/5/10. Yhey
            
            var name:String = objMidi!.getName(midiDevRef!)


            // check if it's online
            MIDIObjectGetIntegerProperty(midiDevRef!, kMIDIPropertyOffline, &isOffline)
            if isOffline == 0 {
                isOnline = true
            } else {
                isOnline = false
            }
            
            // set MIDI node info here
            let midiNode = MIDINode()
            midiNode.setDev(refType: midiRefType.kDriver, midiRef: midiDevRef!, isOnline: isOnline, name: name)
            midiGraph.append(midiNode)
            
            if isOnline == true {
                let midiEntityCount = MIDIDeviceGetNumberOfEntities(midiNode.midiRef)
                // iterate midi device/entity
                if midiEntityCount > 0 {
                    
                    // explore entities
                    for j in 0..<midiEntityCount {
                        
                        let entity:MIDIEntityRef = MIDIDeviceGetEntity(midiDevRef!, j)
                        name = objMidi!.getName(entity)
                        
                        let midiEntity = MIDINode()
                        midiEntity.setDev(refType: midiRefType.kEntity, midiRef: entity, isOnline: true, name: name)

                        midiEntity.parent = midiNode
                        midiGraph[i].children.append(midiEntity)
                        
                        // Finding endpoints of source
                        let sourceCount = MIDIEntityGetNumberOfSources(entity)
                        for k in 0..<sourceCount {

                            let midiEndpoint = MIDINode()   // iterated node
                            let source:MIDIEndpointRef = MIDIEntityGetSource(entity, k)
                            name = objMidi!.getName(source)
                            midiEndpoint.setDev(refType: midiRefType.kSourcePoint, midiRef: source, isOnline: true, name: name)
                            
                            // add source End Point
                            midiEndpoint.parent = midiEntity
                            midiGraph[i].children[j].children.append(midiEndpoint)
                                // midiEndp is midi end point to be shown in the tableview
                            let midiEndp = MidiIFEndpoint.init(MidiNode: midiEndpoint)
                            endPoints.append(midiEndp!)
                        }
                        
                        // finding endpoints of Destination
                        let destinationCount = MIDIEntityGetNumberOfDestinations(entity)
                        for k in 0..<destinationCount {
                            let midiEndpoint = MIDINode()
                            let destination:MIDIEndpointRef = MIDIEntityGetDestination(entity, k)
                            name = objMidi!.getName(destination)
                                // midiEndpoint is midinode found in iteration
                            midiEndpoint.setDev(refType: midiRefType.kDestinationPoint, midiRef: destination, isOnline: true, name: name)
                            midiEndpoint.parent = midiEntity
                            
                            midiGraph[i].children[j].children.append(midiEndpoint)
                                // midiEndp is midi end point to be shown in the tableview
                            let midiEndp = MidiIFEndpoint.init(MidiNode: midiEndpoint)
                            endPoints.append(midiEndp!)

                        // end of destination point loop
                        }
                    // end of entity loop
                    }
                // end of entity loop
                }
            // end of if device is online clause
            }
        // end of device driver loop
        }
        
        /* read preference and set Midi destination if at all
         */
        
        let defaults = UserDefaults.standard
        let defaultConnection:Dictionary = defaults.dictionaryRepresentation()
        var a1 = [Int]()
        var a2 = [Int]()
        
        for i in 0..<endPoints.count {
            if defaultConnection["Device"] as? String == endPoints[i].names["Device"] && endPoints[i].endpointType == midiRefType.kDestinationPoint {
                a1.append(i)
            }
        }
        
        for j in 0..<a1.count {
            if defaultConnection["Entity"] as? String == endPoints[a1[j]].names["Entity"] {
                a2.append(a1[j])
            }
        }
        
        for k in 0..<a2.count {
            if defaultConnection["EndPoint"] as? String == endPoints[a2[k]].names["EndPoint"] {
                // hit
                self.setDestination(numInArray: a2[k])
                break
            }
        }

        scanned = true
    }
    
    func setDestination(numInArray destination:Int) {
        if destination == -1 { print("invalid Midi destination"); return }

        objMidi!.setDestination(endPoints[destination].refNum["EndPoint"]!)
        endPoints[destination].connected = true
        for i in 0..<endPoints.count {
            if i != destination {
                endPoints[i].connected = false
            }
        }
        connectedDestination = endPoints[destination]

        // change or update default Midi destination in user default
        let defaults = UserDefaults.standard
        defaults.setValuesForKeys(endPoints[destination].names)
    }
    
    func setDestination(byMidiRefNum refnum:MIDIEndpointRef) {
        if refnum <= 0 { return }
        let index = endPoints.index(where: { $0.refNum["EndPoint"] == refnum} )
        if index == nil { return }
        
        self.setDestination(numInArray: index!)
    }
    
    // test midi
    func testMidi() {
        
        objMidi?.start()
        objMidi?.sendNote(1, 60, 90, 0, 3072)
        objMidi?.sendNote(1, 64, 90, 480, 460)
        objMidi?.sendNote(1, 67, 90, 960, 460)
    }
    
}
