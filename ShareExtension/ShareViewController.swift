import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

enum Configuration {
    static let airtableBaseID = "app65i3Z1E0LL3Min"
    static let airtableAPIKey = "patyYl0UN5pzaj7SO.ed8727b78edca551908a84311a3bc2dea58ad802f9bf07c5ec8f420aff4731ee"
    static let airtableTableName = "tblWaT87C2KQTTXI5"
    
    enum Fields {
        static let notes = "Notes"
        static let url = "URL"
        static let image = "Image"
        static let imageUrl = "ImageURL"
        static let attachment = "Attachment"
        static let fileType = "FileType"
    }
}

class ShareViewController: SLComposeServiceViewController {
    // Content handlers
    private var sharedText: String?
    private var sharedURL: URL?
    private var sharedFiles: [URL] = []
    private var sharedImage: UIImage?
    private var imageURL: String?
    
    // Constants
    private let maxFileSize: Int = 5 * 1024 * 1024  // 5MB in bytes
    private let initialCompressionQuality: CGFloat = 0.8
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("iOS ShareViewController: viewDidLoad")
        
        // Configure the UI
        self.placeholder = "Add a note (optional)"
        self.navigationController?.navigationBar.tintColor = .systemBlue
        
        // Process shared items
        processExtensionContext()
    }
    
    private func processExtensionContext() {
        print("Starting to process extension context")
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("No extension items found")
            return
        }
        
        print("Found \(extensionItems.count) extension items")
        
        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                print("No attachments found in extension item")
                continue
            }
            
            print("Found \(attachments.count) attachments")
            
            for attachment in attachments {
                print("Processing attachment with identifiers: \(attachment.registeredTypeIdentifiers)")
                
                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    print("Found URL type attachment")
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                        if let error = error {
                            print("Error loading URL: \(error)")
                        }
                        if let sharedURL = url as? URL {
                            print("Successfully loaded URL: \(sharedURL)")
                            self?.sharedURL = sharedURL
                            let pathExtension = sharedURL.pathExtension.lowercased()
                            if pathExtension == "jpg" || pathExtension == "jpeg" || pathExtension == "png" || pathExtension == "gif" {
                                self?.imageURL = sharedURL.absoluteString
                            }
                        }
                    }
                }
                
                // Handle Images
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("Found image attachment")
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (imageData, error) in
                        if let error = error {
                            print("Error loading image: \(error)")
                            return
                        }
                        
                        if let image = imageData as? UIImage {
                            print("Successfully loaded image from Photos")
                            self?.sharedImage = image
                        } else if let imageURL = imageData as? URL {
                            print("Successfully loaded image URL")
                            self?.loadImageFromURL(imageURL)
                        }
                    }
                }
            }
        }
    }
    
    private func loadImageFromURL(_ url: URL) {
        do {
            let imageData = try Data(contentsOf: url)
            if let image = UIImage(data: imageData) {
                self.sharedImage = image
            }
        } catch {
            print("Error loading image from URL: \(error)")
        }
    }
    
    private func compressImage(_ image: UIImage, maxSizeInBytes: Int) -> Data? {
        var compression: CGFloat = initialCompressionQuality
        var imageData = image.jpegData(compressionQuality: compression)
        
        // If the image is already small enough, return it
        if let data = imageData, data.count <= maxSizeInBytes {
            print("Image already under size limit: \(data.count) bytes")
            return data
        }
        
        // If the image is too large, compress it
        while let data = imageData, data.count > maxSizeInBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
            print("Compressing image: quality = \(compression), size = \(data.count) bytes")
        }
        
        // If still too large, resize the image
        if let data = imageData, data.count > maxSizeInBytes {
            print("Image still too large after compression, attempting resize")
            var scale: CGFloat = 1.0
            
            while scale > 0.1 {
                scale -= 0.1
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    imageData = resizedImage.jpegData(compressionQuality: compression)
                    if let resizedData = imageData, resizedData.count <= maxSizeInBytes {
                        UIGraphicsEndImageContext()
                        print("Resizing successful: scale = \(scale), size = \(resizedData.count) bytes")
                        return resizedData
                    }
                }
                UIGraphicsEndImageContext()
            }
        }
        
        // Return the final data, even if it's still larger than maxSizeInBytes
        if let finalData = imageData {
            print("Final image size: \(finalData.count) bytes")
            if finalData.count > maxSizeInBytes {
                print("Warning: Could not compress image below \(maxSizeInBytes) bytes")
            }
            return finalData
        }
        
        return nil
    }
    
    override func didSelectPost() {
        // Get the text from the compose view
        let noteText = self.contentText
        print("Note text entered: \(noteText ?? "")")
        self.sharedText = noteText
        
        // Show loading indicator
        let alert = UIAlertController(title: "Uploading...", message: nil, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        
        // Upload to Airtable
        uploadToAirtable { [weak self] success in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    if success {
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    } else {
                        let errorAlert = UIAlertController(title: "Error", message: "Failed to upload to Airtable", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self?.present(errorAlert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    private func uploadToAirtable(completion: @escaping (Bool) -> Void) {
        print("Starting Airtable upload")
        var fields: [String: Any] = [:]
        
        // Handle text note
        if let text = self.sharedText, !text.isEmpty {
            print("Adding note to fields: \(text)")
            fields[Configuration.Fields.notes] = text
        }
        
        // Handle URL
        if let url = sharedURL {
            print("Adding URL to fields: \(url)")
            fields[Configuration.Fields.url] = url.absoluteString
        }
        
        // Handle Image
        if let image = sharedImage {
            print("Processing image for upload")
            if let imageData = compressImage(image, maxSizeInBytes: maxFileSize) {
                let base64String = imageData.base64EncodedString()
                fields[Configuration.Fields.image] = base64String
                
                // If we have an image URL, add it as well
                if let imgURL = imageURL {
                    fields[Configuration.Fields.imageUrl] = imgURL
                }
                
                print("Image processed and ready for upload: \(imageData.count) bytes")
            } else {
                print("Failed to process image for upload")
            }
        }
        
        print("Final fields dictionary: \(fields)")
        
        let endpoint = "https://api.airtable.com/v0/\(Configuration.airtableBaseID)/\(Configuration.airtableTableName)"
        print("Using Airtable endpoint: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("Failed to create endpoint URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Configuration.airtableAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["records": [["fields": fields]]]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request JSON body: \(jsonString)")
            }
        } catch {
            print("JSON serialization error: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Airtable upload error: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Airtable response status code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Airtable response: \(responseString)")
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid HTTP response")
                completion(false)
                return
            }
            
            print("Airtable upload completed successfully")
            completion(true)
        }.resume()
    }
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}
