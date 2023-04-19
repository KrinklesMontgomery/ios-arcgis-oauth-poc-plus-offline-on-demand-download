import Foundation
import ArcGIS
import AuthenticationServices

extension ViewController {
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
}
