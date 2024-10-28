#if os(macOS)
import AppKit
import Social
import UniformTypeIdentifiers

class MacShareViewController: NSViewController {
    private var sharedText: String?
    private var sharedURL: URL?
    private var sharedFiles: [URL] = []
    
    private lazy var textField: NSTextField = {
        let field = NSTextField(frame: NSRect(x: 20, y: 50, width: 300, height: 24))
        field.placeholderString = "Add a note (optional)"
        return field
    }()
    
    private lazy var shareButton: NSButton = {
        let button = NSButton(frame: NSRect(x: 220, y: 20, width: 100, height: 24))
        button.title = "Share"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(shareButtonClicked)
        return button
    }()
    
    private lazy var cancelButton: NSButton = {
        let button = NSButton(frame: NSRect(x: 120, y: 20, width: 100, height: 24))
        button.title = "Cancel"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(cancelButtonClicked)
        return button
    }()
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 100))
        print("MacShareViewController: loadView")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MacShareViewController: viewDidLoad")
        
        view.addSubview(textField)
        view.addSubview(shareButton)
        view.addSubview(cancelButton)
        
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
                print("No attachments found")
                continue
            }
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                        if let error = error {
                            print("Error loading URL: \(error)")
                        }
                        if let sharedURL = url as? URL {
                            print("Successfully loaded URL: \(sharedURL)")
                            DispatchQueue.main.async {
                                self?.sharedURL = sharedURL
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc private func shareButtonClicked() {
        sharedText = textField.stringValue
        
        uploadToAirtable { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Upload Failed"
                    alert.informativeText = "Failed to upload to Airtable"
                    alert.addButton(withTitle: "OK")
                    alert.beginSheetModal(for: self?.view.window ?? NSWindow()) { _ in
                        self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.yourdomain.shareextension", code: -1, userInfo: nil))
                    }
                }
            }
        }
    }
    
    @objc private func cancelButtonClicked() {
        self.extensionContext?.cancelRequest(withError: NSError(domain: "com.yourdomain.shareextension", code: 0, userInfo: nil))
    }
    
    private func uploadToAirtable(completion: @escaping (Bool) -> Void) {
        print("Starting Airtable upload")
        var fields: [String: Any] = [:]
        
        if let text = sharedText, !text.isEmpty {
            print("Adding text to fields: \(text)")
            fields[Configuration.Fields.notes] = text
        }
        
        if let url = sharedURL {
            print("Adding URL to fields: \(url)")
            fields[Configuration.Fields.url] = url.absoluteString
        }
        
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
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("Making Airtable request with fields: \(fields)")
        
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
}
#endif
