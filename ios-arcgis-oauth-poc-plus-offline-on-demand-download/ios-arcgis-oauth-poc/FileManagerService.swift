//
//  FileManagerService.swift
//  ios-arcgis-oauth-poc
//
//  Created by Darius Vallejo on 4/13/23.
//

import Foundation

// For creating local file directories etc. via FileManager
class FileManagerService {
    func _getDownloadDirectory(directoryName: String) -> URL? {
        return FileManager.default.temporaryDirectory.appendingPathComponent(directoryName)
    }
    
    func _createDownloadDirectory(directoryName: String) throws -> URL? {
        let downloadDirectoryMap = try self._createTemporaryDirectory(directoryName: directoryName)
        
        print(downloadDirectoryMap)
        return downloadDirectoryMap
    }
    
    private func _createTemporaryDirectory(directoryName: String) throws -> URL? {
        let defaultManager = FileManager.default
        let temporaryDownloadURL = defaultManager.temporaryDirectory.appendingPathComponent(directoryName)
        
        if defaultManager.fileExists(atPath: temporaryDownloadURL.path) {
            try defaultManager.removeItem(atPath: temporaryDownloadURL.path)
        }
        try  defaultManager.createDirectory(at: temporaryDownloadURL, withIntermediateDirectories: true, attributes: nil)
        
        print( String(describing: defaultManager.subpaths(atPath: FileManager.default.temporaryDirectory.path)))
        return temporaryDownloadURL
    }
}
