//
//  Utils.swift
//  ios-arcgis-oauth-poc
//
//  Created by Darius Vallejo on 4/14/23.
//

import Foundation

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

struct Utils {
    func _printError(message: String) -> Void {
        print(">>>>>>> ERROR: \(message) <<<<<<<")
    }
}
