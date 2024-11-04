#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif
import Foundation

@objc public class AirtableService: NSObject {
    @objc public static let shared = AirtableService()
    private let baseURL: String
    
    public override init() {
        self.baseURL = "https://api.airtable.com/v0/\(Configuration.airtableBaseId)/\(Configuration.airtableTableName)"
        super.init()
    }
    
    public func uploadContent(text: String? = nil, url: URL? = nil, image: PlatformImage? = nil, completion: @escaping (Bool) -> Void) {
        var fields: [String: Any] = [:]
        
        if let text = text {
            fields[Configuration.Fields.notes] = text
        }
        
        if let url = url {
            fields[Configuration.Fields.url] = url.absoluteString
        }
        
        guard let requestURL = URL(string: baseURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Configuration.airtableApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let body = ["fields": fields]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
                DispatchQueue.main.async {
                    completion(success)
                }
            }.resume()
        } catch {
            completion(false)
        }
    }
} 