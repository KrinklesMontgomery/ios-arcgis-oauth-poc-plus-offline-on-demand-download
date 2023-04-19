//
//  Constants.swift
//  ios-arcgis-oauth-poc
//
//  Created by Darius Vallejo on 4/17/23.
//

import Foundation

// Inspired by GFEE, mainly holds configuration variable strings

struct OfflineMapConfig {
    let basemapDirectory: String = "MAP_TILE_PACKAGE_DATA"
    let offlineMapDirectory: String = "GIS_DOWNLOAD_MAP_DATA"
    let basemapFilenames: [String:String] = ["CO":"CO.vtpk"]
    let mapId: String = getMapId()
    let baseURL: String = "https://gdl-xcelenergytest.msappproxy.net/arcgis/home"
}

// The map id of the AGSPortal map we want to load
func getMapId() -> String {
    return "e378b213219f4abb9a2cbc8aa1aa33c4"
    // TODO: DEMO - Use Gas Distribution Map
    // return "fe835b80f7e54f35b9de90f1ba587f5c"
    // basemap demo
    // return "8807c580594e4c73a23f71e02d437721"
    // single GD layer demo
    // return "ae0d8e9af4ca412fbb00218baedf1cb0"
    // trailheads sample data from tutorial
    // return "ef722b2c44c2443090d98115a9ce8058"
}
