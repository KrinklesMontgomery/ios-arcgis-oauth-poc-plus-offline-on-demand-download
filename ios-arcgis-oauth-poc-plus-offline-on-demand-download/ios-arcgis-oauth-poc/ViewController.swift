//
//  ViewController.swift
//  ios-arcgis-ui-elems-poc
//
//  Created by Samuel Haycraft on 4/1/23.
//

import UIKit
import ArcGIS
import AuthenticationServices

extension ViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

class ViewController: UIViewController, AGSGeoViewTouchDelegate {
    // UI elements
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var coordinateLabel: UILabel!
    @IBOutlet weak var btnLoad: UIButton!
    @IBOutlet weak var onlineSwitch: UISwitch!
    var offline: Bool = false
    
    // OAuth
    var _session: ASWebAuthenticationSession?
    let _clientId: String = ConfigService.getConfigValue(key: "OAUTH_CLIENT_ID") as! String
    let _appId: String = ConfigService.getConfigValue(key: "OAUTH_APP_ID") as! String
    let _scheme: String = ConfigService.getConfigValue(key: "OAUTH_SCHEME") as! String
    let _redirectUri: String = ConfigService.getConfigValue(key: "OAUTH_REDIRECT_URI") as! String
    let _proxyBaseUri: String = ConfigService.getConfigValue(key: "PROXY_BASE_URL") as! String
    let _scope: String = ConfigService.getConfigValue(key: "OAUTH_SCOPE") as! String
    
    // Offline
    var basemapDirectory: URL?
    var basemapFilename: String?
    var offlineMapDirectory: URL?
    var offlineMap: AGSMap?
        
    // Utils
    var timestamp = Date().currentTimeMillis()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.initMap()
        
        // Sets up offline map directories
        // TODO: Error handling
        
        var basemapFilename = OfflineMapConfig().basemapFilenames["CO"] ?? ""
        self.setupOfflineDirectories(basemapDirectory: OfflineMapConfig().basemapDirectory,
                                     basemapFilename: basemapFilename,
                                     offlineMapDirectory: OfflineMapConfig().offlineMapDirectory)
        
        
        self.btnLoad.addTarget(self, action: #selector(self._startAuth), for: .touchUpInside)
        self.onlineSwitch.addTarget(self, action: #selector(self.toggleOffline), for: .touchUpInside)
        self._setupAuthSession()
    }
    
    // interface methods for AGSGeoViewTouchDelegate
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) -> Void {
        let projectPoint = AGSGeometryEngine.projectGeometry(mapPoint, to: AGSSpatialReference(wkid: 4326)!)! as! AGSPoint
        
        self.coordinateLabel.text = "Lat/long = {\( String(format: "%.3f", projectPoint.x)), \(String(format: "%.3f", projectPoint.y)) }"
    }
    
    // Starts the auth session on button press
    @objc private func _startAuth() -> Void {
        if (self._session!.canStart) {
            self._session!.start()
        } else {
            // we're auth and can retry the DL?
            self.initOfflineMapDownload()
        }
    }
    
    // Offline toggle (DEMO)
    @objc private func toggleOffline() -> Void {
        self.offline = !self.offline
        print("offline? \(self.offline)")
        if (self.offline) {
            print("Offline. Using download maps...")
            self.loadOfflineMap()
        } else {
            print("Online. Switching to live maps.")
            self.loadOnlineMap()
        }
    }

    // Sets up the auth session
    private func _setupAuthSession() -> Void {
        let authUrlString = "https://login.microsoftonline.com/\(self._appId)/oauth2/v2.0/authorize?response_type=code&client_id=\(self._clientId)&scope=\(self._scope)&redirect_uri=\(self._redirectUri)"
        
        guard let authURL = URL(string: authUrlString) else { return }
        
        let scheme = self._scheme
        
        // Initialize the session.
        self._session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme)
        { callbackURL, error in
            // Handle the callback.
            
            guard error == nil else {
                print("Got an error in auth....")
                print(error!.localizedDescription)
                print(String(describing: error))
                print(String(describing: callbackURL))
                
                return
            }
            guard let callbackURL = callbackURL else {
                print("Error in callbackURL set")
                return
            }
            
            let codeToken = self._getQueryStringParameter(url: callbackURL.absoluteString, param: "code")!
            self._issueCodeForToken(code: codeToken)
            
        }
        self._session!.presentationContextProvider = self
    }
    
    // Returns the specified parameter value from the URL string
    private func _getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    private func _issueCodeForToken(code: String) -> Void {
        let url = URL(string: "https://login.microsoftonline.com/\(self._appId)/oauth2/v2.0/token?")!
        
        let requestData = "code=\(code)&grant_type=authorization_code&scope=\(self._scope)&client_id=\(self._clientId)&redirect_uri=\(_redirectUri)".data(using: .utf8)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.uploadTask(with: request, from: requestData) { data, response, error in
            do {
                if let json = try JSONSerialization.jsonObject(with: data!) as? [String: Any] {
                    let accessToken = json["access_token"] as! String
                    
                    // TODO: DEMO - temporarily disabled (causes issues authing into test portals?)
                    AGSRequestConfiguration.global().userHeaders = [ "Authorization": "Bearer \(accessToken)" ]

                    // Start the download
                    self.initOfflineMapDownload()
                }
            }
            catch {
                print("Error parsing json")
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
    
    func initOfflineMapDownload() {
        let portalMapId = OfflineMapConfig().mapId // make optional param
        // TODO: Safely unwrap
        var areaOfInterest = self.mapView.visibleArea.unsafelyUnwrapped.extent // make optional param
        self.downloadAndSetOfflineMap(mapId: portalMapId,
                                      areaOfInterest: areaOfInterest,
                                      downloadDirectoryMap: self.offlineMapDirectory.unsafelyUnwrapped)
    }
    
    // If we have set an offline map, load it. Otherwise, try to load it from offline files.
    private func loadOfflineMap() {
        var map = self.offlineMap
        map?.initialViewpoint = AGSViewpoint(targetExtent: self.mapView.visibleArea.unsafelyUnwrapped.extent)
        if (self.offlineMap != nil) {
            self.mapView.map = self.offlineMap
        } else {
            // Manually creates a new map from the offline map files (if they exist)
            map = AGSMap(basemapStyle: .arcGISStreets)
            let filename = self.offlineMapDirectory?.appendingPathComponent("demo", isDirectory: false).appendingPathExtension("geodatabase")
            var geodatabase = AGSGeodatabase(fileURL: filename!)
            print(geodatabase.fileURL)
            
            // basemap
            let basemapFileURL = self.basemapDirectory?.appendingPathComponent("CO", isDirectory: false).appendingPathExtension("vtpk")
            print(basemapFileURL)
            let vectorTileCache = AGSVectorTileCache(fileURL: basemapFileURL.unsafelyUnwrapped)
            let vectorTiledLayer = AGSArcGISVectorTiledLayer(vectorTileCache: vectorTileCache)
            map?.basemap = AGSBasemap(baseLayer: vectorTiledLayer)
            
            // loading geodatabase layers
            geodatabase.load(completion: { error in
                if ((error) != nil) {
                    print(error)
                }
                geodatabase.geodatabaseFeatureTables.forEach { featureTable in
                    featureTable.load { [weak self] error in
                        guard let self = self else { return }
                        if let error = error {
                            print(error)
                        } else {
                            // Create and load the feature layer from the feature table.
                            let featureLayer = AGSFeatureLayer(featureTable: featureTable)
                            // Add the feature layer to the map.
                            map?.operationalLayers.add(featureLayer)
                        }
                    }
                }
                self.mapView.map = map
            })
        }
    }
    
    private func loadOnlineMap() {
        let map = AGSMap(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = AGSViewpoint(targetExtent: self.mapView.visibleArea.unsafelyUnwrapped.extent)
        self.mapView.map = map
    }
}

//    private func _addMapLayers() -> Void {
//        let featureLayer: AGSFeatureLayer = {
//            print("DEBUG foobar")
//            print(self._proxyBaseUri)
//            let featureServiceURL = URL(string: "\(self._proxyBaseUri)/arcgis/rest/services/GFEE/Gas_Distribution/FeatureServer/11")!
//            let featureServiceTable = AGSServiceFeatureTable(url: featureServiceURL)
//            return AGSFeatureLayer(featureTable: featureServiceTable)
//        }()
//
//        featureLayer.load{ [weak self] (error) in
//            if let error = error {
//                print("ERROR IN LOADING FEATURE LAYER <<<<<<<<<<<<<<")
//                print(error.localizedDescription)
//
//                return
//            }
//
//            self?.mapView.map!.operationalLayers.add(featureLayer)
//
//            self?.mapView.setViewpoint(
//                AGSViewpoint(
//                    latitude: 39.737,
//                    longitude: -104.990,
//                    scale: 200_000
//                )
//            )
//
//            print("____ LAYER LOADED _____")
//        }
//    }

