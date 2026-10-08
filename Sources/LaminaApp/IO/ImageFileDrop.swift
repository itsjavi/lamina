import SwiftUI
import UniformTypeIdentifiers

/// Resolve in pasteboard order; the importer validates contents rather than trusting extensions.
@MainActor
enum ImageFileDrop {
    static func importProviders(_ providers: [NSItemProvider], into session: EditorSession, at point: CGPoint?, projects: ProjectController? = nil, workspace: ProjectWorkspace? = nil, destination: UUID? = nil) async {
        var urls: [URL] = []
        var unreadable = false
        var blocked: [URL] = []
        for provider in providers {
            let url: URL? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let value = item as? URL { url = value }
                    else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else { url = nil }
                    continuation.resume(returning: url?.isFileURL == true ? url : nil)
                }
            }
            if let url { urls.append(url) }
            // Not a file on disk: a screenshot's thumbnail, or an image dragged from a web page or another app,
            // hands over image data (or a file it only promises). Copy it somewhere the importer can read.
            else if let copy = await temporaryFile(from: provider) { urls.append(copy) }
            // A browser showing a local file hands it over as a promise for the original, which the App Sandbox
            // won't let the app read. The user can still grant access by choosing it.
            else if let file = referencedFile(for: provider) { blocked.append(file) }
            else { unreadable = true }
        }
        var refused = false
        if !blocked.isEmpty {
            let granted = await askForAccess(to: blocked)
            urls += granted
            refused = granted.isEmpty
        }
        if let workspace { await workspace.receive(urls, into: destination, at: point) }
        else if let projects { await projects.receive(urls, at: point) }
        else { await session.importImages(urls, at: point) }
        var messages: [String] = []
        if refused {
            messages.append("Your browser handed over a file this app isn’t allowed to read. Drag it from Finder instead.")
        }
        if unreadable, !providers.isEmpty {
            messages.append("Some dropped items couldn’t be read. Drag JPEG, PNG, HEIC, WebP, TIFF, or Photoshop (PSD) files from Finder.")
        }
        if !messages.isEmpty {
            session.importError = ([session.importError].compactMap { $0 } + messages).joined(separator: "\n\n")
        }
    }

    /// The local file a dragged item refers to, from the drag's URLs: Chromium-based browsers put the page's or the
    /// image's address there, which is a file URL when they show a file from disk. Matched by name when there are several.
    static func referencedFile(for provider: NSItemProvider, in pasteboard: NSPasteboard = NSPasteboard(name: .drag)) -> URL? {
        let files = (pasteboard.pasteboardItems ?? [])
            .compactMap { $0.string(forType: .URL).flatMap(URL.init(string:)) }
            .filter(\.isFileURL)
        if let name = provider.suggestedName,
           let match = files.first(where: { $0.lastPathComponent == name || $0.deletingPathExtension().lastPathComponent == name }) {
            return match
        }
        return files.count == 1 ? files[0] : nil
    }

    /// An Open panel pointed at the files, so one click gives the sandboxed app access. Empty when cancelled.
    private static func askForAccess(to files: [URL]) async -> [URL] {
        let panel = NSOpenPanel()
        panel.message = files.count == 1
            ? "Your browser handed over “\(files[0].lastPathComponent)” as a reference this app can’t open on its own. Choose Open to let it read the file."
            : "Your browser handed over files this app can’t open on its own. Choose Open to let it read them."
        panel.prompt = "Open"
        panel.allowsMultipleSelection = files.count > 1
        panel.canChooseDirectories = false
        // A file URL as the starting point selects that file.
        panel.directoryURL = files[0]
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow { response = await panel.beginSheetModal(for: window) }
        else { response = panel.runModal() }
        return response == .OK ? panel.urls : []
    }

    /// A dropped item's image written to a temporary file, or nil when it holds no image.
    private static func temporaryFile(from provider: NSItemProvider) async -> URL? {
        let types = [UTType.png, .jpeg, .heic, .webP, .tiff, .photoshopImage, .photoshopLargeImage, .rawImage, .image].map(\.identifier)
        guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else { return nil }
        return await withCheckedContinuation { continuation in
            // The file only exists until this closure returns, so it is copied, not referenced.
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                guard let url else { continuation.resume(returning: nil); return }
                let name = url.deletingPathExtension().lastPathComponent
                let suffix = url.pathExtension.isEmpty ? (UTType(type)?.preferredFilenameExtension ?? "png") : url.pathExtension
                // A unique folder rather than a unique file name: the copy keeps the name the file
                // was dropped under, which is the name the import sheet and the new layers show.
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                let copy = folder
                    .appendingPathComponent(name.isEmpty ? "Dropped" : name)
                    .appendingPathExtension(suffix)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch { continuation.resume(returning: nil) }
            }
        }
    }
}
