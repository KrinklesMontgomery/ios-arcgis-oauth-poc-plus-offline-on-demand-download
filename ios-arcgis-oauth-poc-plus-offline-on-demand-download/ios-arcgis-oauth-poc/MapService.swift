//
//  MapService.swift
//  ios-arcgis-oauth-poc
//
//  Created by Darius Vallejo on 4/17/23.
//

import Foundation
import ArcGIS

// Initial map specific stuff
extension ViewController {
    
    // Init the map (Basemaps, not Portal specific)
    func initMap() -> Void {
        let map = AGSMap(basemapStyle: .arcGISTopographic)
        self.mapView.map = map
        self.mapView.touchDelegate = self

         // denver
         let lat = 39.731243
         let long = -104.968526
         let scale: Double = 50_000

        let viewPoint = AGSViewpoint(
            latitude: lat,
            longitude: long,
            scale: scale
        )
        
        self.mapView.setViewpoint(viewPoint)
    }
    
    // Initializes an AGS Map with an AGSPortal item
    private func _initPortalWithMap(mapId: String, useArcGisOnline: Bool) -> AGSMap {
        var portal: AGSPortal
        
        if (useArcGisOnline == true) {
            portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        } else {
            portal = AGSPortal(url: URL(string: OfflineMapConfig().baseURL)!, loginRequired: false)
        }
        return AGSMap(item: AGSPortalItem(portal: portal, itemID: mapId))
    }
    
    // Creates an offline task from the portal map with the provided area of interest
    func downloadAndSetOfflineMap(mapId: String, areaOfInterest: AGSEnvelope, downloadDirectoryMap: URL) -> Void {
        let map = self._initPortalWithMap(mapId: mapId, useArcGisOnline: false)

        map.load { error -> Void in
            if let error = error {
                print("There was an error in map load!!!!!!")
                print(error.localizedDescription)
                exit(1)
            }

            let offlineMapTask = AGSOfflineMapTask(onlineMap: map)
            self.createOfflineMapJob(mapArea: areaOfInterest,
                                     offlineMapTask: offlineMapTask,
                                     downloadDirectoryMap: downloadDirectoryMap)
        }
    }
}
