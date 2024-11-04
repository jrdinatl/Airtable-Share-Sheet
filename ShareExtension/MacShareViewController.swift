#if os(macOS)
import Cocoa
import Social
import UniformTypeIdentifiers
import Foundation

@objc(MacShareViewController)
class MacShareViewController: NSViewController {
    private var sharedText: String?
    private var sharedURL: URL?
    private var sharedImage: NSImage?
    private var sharedFile: URL?
    
    // Initialize with explicit type
    private let airtableService: AirtableService = AirtableService.shared
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        processInputItems()
    }
    
    private func processInputItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        
        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }
            
            for attachment in attachments {
                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] url, error in
                        if let url = url as? URL {
                            self?.sharedURL = url
                            self?.uploadToAirtable()
                        }
                    }
                }
                
                // Handle text
                if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] text, error in
                        if let text = text as? String {
                            self?.sharedText = text
                            self?.uploadToAirtable()
                        }
                    }
                }
                
                // Handle images
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] image, error in
                        if let image = image as? NSImage {
                            self?.sharedImage = image
                            self?.uploadToAirtable()
                        }
                    }
                }
            }
        }
    }
    
    private func uploadToAirtable() {
        airtableService.uploadContent(
            text: sharedText,
            url: sharedURL,
            image: sharedImage
        ) { [weak self] (success: Bool) in
            DispatchQueue.main.async {
                if success {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Error"
                    alert.informativeText = "Failed to upload to Airtable"
                    alert.addButton(withTitle: "OK")
                    alert.beginSheetModal(for: self?.view.window ?? NSWindow()) { _ in
                        self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.error", code: -1))
                    }
                }
            }
        }
    }
}
#endif
