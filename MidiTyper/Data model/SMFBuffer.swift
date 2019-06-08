//
//  SMFBuffer.swift
//  MidiTyper
//
//  Created by Harry on 2019/05/14.
//  Copyright © 2019 Yoshi Sawada. All rights reserved.
//

import Foundation

class SMFBuffer: NSObject {
    var bufPointer: UnsafeMutableRawPointer
    var curPos: Int
    var endPoint: Int
    var bufSize: Int
    var incrementSize: Int
    let defaultBufSize: Int = 1024
    let defaultIncrementSize: Int = 1024
    
    override init() {
        bufPointer = UnsafeMutableRawPointer.allocate(byteCount: defaultBufSize, alignment: 1)
        curPos = 0
        bufSize = defaultBufSize
        incrementSize = defaultIncrementSize
        endPoint = 0
        super.init()
    }
    
    init(memSize: Int, incSize: Int) {
        bufPointer = UnsafeMutableRawPointer.allocate(byteCount: memSize, alignment: 1)
        curPos = 0
        bufSize = memSize
        incrementSize = incSize
        endPoint = 0
        
        super.init()
    }
    
    func append(singleByte sb: UInt8) -> Void {
        if curPos + 1 > bufSize {
            expand(newSize: bufSize+incrementSize)
        }
        
        unsafeAppend(singleByte: sb)
    }
    
    func unsafeAppend(singleByte sb: UInt8) -> Void {
        // This function doesn't check the size of buffer.
        // Use this in repeating calls to save overhead
        // Buffer size should be checked before the first call
        bufPointer.storeBytes(of: sb, toByteOffset: curPos, as: UInt8.self)
        curPos = curPos + 1
        endPoint = curPos
    }
    
    func append(array ar: [UInt8]) -> Void {
        if curPos + ar.count > bufSize {
            if curPos + ar.count > bufSize + incrementSize {
                expand(newSize: curPos + ar.count)
            } else {
                expand(newSize: curPos + incrementSize)
            }
        }
        for byte in ar {
            bufPointer.storeBytes(of: byte, toByteOffset: curPos, as: UInt8.self)
            curPos = curPos + 1
            endPoint = curPos
        }
    }
    
    func append(array ar: [UInt8], len: Int) -> Void {
        if curPos + len > bufSize {
            let inc = len > incrementSize ? len : incrementSize
            expand(newSize: curPos + inc)
        }
        for i in 0..<len {
            bufPointer.storeBytes(of: ar[i], toByteOffset: curPos, as: UInt8.self)
            curPos = curPos + 1
            endPoint = curPos
        }
    }
    
    func append(chunk buf:SMFBuffer) -> Void {
        let newSize = curPos + buf.endPoint
        if newSize > bufSize {
            expand(newSize: newSize > bufSize+incrementSize ? newSize : bufSize+incrementSize)
        }
        let insPoint = bufPointer.advanced(by: curPos)
        insPoint.copyMemory(from: buf.bufPointer, byteCount: buf.endPoint)
        curPos = curPos + buf.endPoint
        endPoint = curPos
    }
    
    func append(buffer buf: UnsafeMutableRawPointer, size: Int) -> Void {
        let newSize = curPos + size
        if newSize > bufSize {
            expand(newSize: newSize > bufSize+incrementSize ? newSize : bufSize+incrementSize)
        }
        let entryPoint = bufPointer.advanced(by: endPoint)
        entryPoint.copyMemory(from: buf, byteCount: size)
        curPos = curPos + size
        endPoint = curPos
    }
    
    func write(at loc: Int, array ar:[UInt8]) -> Void { // doen't update endPoint
        var pos = loc
        
        if pos + ar.count > bufSize {
            if pos + ar.count > bufSize + incrementSize {
                expand(newSize: pos + ar.count)
            } else {
                expand(newSize: pos + ar.count)
            }

        }
        for b in ar {
            bufPointer.storeBytes(of: b, toByteOffset: pos, as: UInt8.self)
            pos = pos + 1
        }
        
    }
    
    func swapAndWrite4ByteInt(at loc:Int, data: UInt32) -> Void { // doesn't update endPoint
        if loc + 4 > bufSize {
            expand(newSize: loc + 4 + incrementSize)
        }
        let swappedInt = CFSwapInt32(data)
        bufPointer.storeBytes(of: swappedInt, toByteOffset: loc, as: UInt32.self)
    }
    
    func swapAndWrite2ByteInt(at loc: Int, data: UInt16) -> Void { // doesn't update endPoint
        if loc + 2 > bufSize {
            expand(newSize: loc + 2 + incrementSize)
        }
        let swapped16 = CFSwapInt16(data)
        bufPointer.storeBytes(of: swapped16, toByteOffset: loc, as: UInt16.self)
    }
    
    func expand(newSize: Int) -> Void {
        if newSize < bufSize {
            return
        }
        
        let newPtr = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: 1)
        newPtr.copyMemory(from: bufPointer, byteCount: bufSize)
        bufPointer.deallocate()
        bufSize = newSize
        bufPointer = newPtr
    }
    
    func seek(pos: Int) -> Bool {
        if pos > bufSize - 1 {
            return false
        }
        curPos = pos
        endPoint = curPos
        return true
    }
    
    func deinitialize() -> Void {
        bufPointer.deallocate()
    }

}
