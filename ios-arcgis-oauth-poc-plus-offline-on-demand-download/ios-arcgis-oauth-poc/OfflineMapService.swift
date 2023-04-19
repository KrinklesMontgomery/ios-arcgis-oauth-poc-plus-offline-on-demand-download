//
//  OfflineMapService.swift
//  ios-arcgis-oauth-poc
//
//  Created by Darius Vallejo on 4/16/23.
//

import Foundation
import ArcGIS

// TODO: SAFELY Unwrap values
// Offline download stuff
extension ViewController {
    func setupOfflineDirectories(basemapDirectory: String, basemapFilename: String, offlineMapDirectory: String) {
        self.basemapDirectory = createMapDirectory(mapDirectoryString: basemapDirectory)
        self.basemapFilename = basemapFilename
        self.offlineMapDirectory = createMapDirectory(mapDirectoryString: offlineMapDirectory)
    }
    
    private func createMapDirectory(mapDirectoryString: String) -> URL {
        do {
            return try FileManagerService()._createDownloadDirectory(
                directoryName: mapDirectoryString)!
        } catch {
            return URL(string: "")!
        }
    }
    
    // Kicks off the offline map creation job. Currently also sets the map view.
    // Takes an AGSEnvelope to determine the area to download, an offline map task that represents the download task,
    // and a URL for the offline map download path
    func createOfflineMapJob(
        mapArea: AGSEnvelope,
        offlineMapTask: AGSOfflineMapTask?,
        downloadDirectoryMap: URL?) -> Void {
        self.timestamp = Date().currentTimeMillis()
        print("We are in process map area now \(mapArea)")
        offlineMapTask?.defaultGenerateOfflineMapParameters(withAreaOfInterest: mapArea, completion: { parameters, error in
            if let error = error {
                Utils()._printError(message: "Error returned in download parameters")
                print(error.localizedDescription)
                return
            }
            
            guard parameters != nil else {
                Utils()._printError(message: "parameters object is null")
                return
            }
            
            if let parameters = parameters {
                parameters.continueOnErrors = true
                parameters.includeBasemap = false
                // parameters.referenceBasemapDirectory = self.basemapDirectory
                // parameters.referenceBasemapFilename = self.basemapFilename ?? ""
                
                print("parameters set")
                print(String(describing: parameters))
                
                var downloadMapJob = self.instantiateDownloadJobObject(
                    offlineMapTask: offlineMapTask,
                    downloadDirectoryMap: downloadDirectoryMap,
                    parameters: parameters)
                
                guard downloadMapJob != nil else { return }
                
                print("DEBUG: map job = \(String(describing: downloadMapJob))")
                self.runDownloadMapJob(downloadPreplannedMapJob: downloadMapJob)
            }
        })
    }
    
    // Tries to create an offline map job using the current offline map task, the specific parameters,
    // and the provided download directory
    private func instantiateDownloadJobObject(
        offlineMapTask: AGSOfflineMapTask?,
        downloadDirectoryMap: URL?,
        parameters: AGSGenerateOfflineMapParameters) -> AGSGenerateOfflineMapJob? {
            return offlineMapTask!.generateOfflineMapJob(
                with: parameters,
                downloadDirectory: self.offlineMapDirectory.unsafelyUnwrapped)
    }
    
    // Starts the download map job and prints download progress to console. Sets the map view to the offline map
    // after successful download completion.
    private func runDownloadMapJob(downloadPreplannedMapJob: AGSGenerateOfflineMapJob?) -> Void {
        downloadPreplannedMapJob?.start(statusHandler: { (status) in
            let normalizedFraction = (downloadPreplannedMapJob!.progress.fractionCompleted) * 100
            let percentComplete: String = String(format: "%.0f", normalizedFraction)
            print("Status [\(percentComplete) % complete...]: \(status)")
        }, completion: { (result, error) in
            print("File download completed")
            if let error = error {
                Utils()._printError(message: "Error occurred in download map job completion")
                print(error.localizedDescription)
                print(error)
            }
            
            guard let result = result else { return }
            
            if result.hasErrors {
                Utils()._printError(message: "result of download offline map has errors")
                print("\(result.layerErrors)")
                print("\(result.tableErrors)")
            } else {
                print("Downloaded data info ...")
                print(String(describing: result.mobileMapPackage))
                if let path = Bundle.main.path(forResource: "CO", ofType: "vtpk") {
                    let basemapFileURL = URL(string: path)
                    let vectorTileCache = AGSVectorTileCache(fileURL: basemapFileURL.unsafelyUnwrapped)
                    let vectorTiledLayer = AGSArcGISVectorTiledLayer(vectorTileCache: vectorTileCache)
                    result.offlineMap.basemap = AGSBasemap(baseLayer: vectorTiledLayer)
                    self.offlineMap = result.offlineMap
                }
            }
             var currentTimestamp = Date().currentTimeMillis() - self.timestamp
             print("Elapsed time: \(currentTimestamp)")
        })
    }
}
