//
//  OnelineTST.swift
//  MidiTyper
//
//  Created by Yoshi Sawada on 2018/05/02.
//  Copyright © 2018年 Yoshi Sawada. All rights reserved.
//

import Cocoa

enum TST {
    case TimeSig (meas: Int, num: Int, denom: Int)
    case Tempo (meas: Int, beat: Int, tick: Int, tempo: Double)
}

class OnelineTST: NSObject {
    var aTst: TST
    var type: String
    var meas: String
    var beat: String
    var tick: String
    var value: String

    override init() {
        aTst = TST.TimeSig(meas: 0, num: 4, denom: 4)
        type = "Time Sig"
        meas = "1"
        beat = "1"
        tick = "0"
        value = "4/4"
    }
    
    init(BarWithZerobaseMeas meas: Int, num: Int, denom: Int) { // Init as Bar
        aTst = TST.TimeSig(meas: meas, num: num, denom: denom)
        self.type = "Time Sig"
        self.meas = String(meas+1)
        self.beat = "***"
        self.tick = "***"
        self.value = String(num) + "/" + String(2 << (denom - 1))
    }
    
    init(TempoWithZerobaseMeas meas: Int, beat: Int, tick: Int, tmp: Double) {
        aTst = TST.Tempo(meas: meas, beat: beat, tick: tick, tempo: tmp)
        self.type = "Tempo"
        self.meas = String(meas+1)
        self.beat = String(beat+1)
        self.tick = String(tick+1)
        self.value = String(format: "%.2f", tmp)
    }
    
    func timeSigText() -> (meas: String?, timeSig: String?) {
        if case let .TimeSig(imeas, inum, idenom) = aTst {
            let denom = 2 << (idenom-1)
            let s = String(format: "%d/%d", inum, denom)
            return (String(imeas+1), s)
        }
        return (nil, nil)
    }
    
//  How to access this union structure
//  Assuming aTst is a union variable with the type of TST
//        if case let .TimeSig(ibar, inum, idenom, bar) = aTst {
//        // The variable has TimeSig data, do what you want for TimeSig
//            return
//        }
//        if case let .Tempo(ibar, ibeat, itick, dtempo) = aTst {
    //  // do what you want for Tempo data
//            return
//        }

}
