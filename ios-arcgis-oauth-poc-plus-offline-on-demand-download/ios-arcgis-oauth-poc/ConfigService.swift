//
//  ConfigService.swift
//  ios-arcgis-oauth-poc
//
//  Created by Samuel Haycraft on 4/8/23.
//

import Foundation

public class ConfigService {
    public static func getConfigValue(key: String) -> Any? {
        if let configValue = Bundle.main.infoDictionary?[key] {
            return configValue
        } else {
            return nil
        }
    }
}
