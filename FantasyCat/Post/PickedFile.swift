import CoreTransferable
import UniformTypeIdentifiers

/// Receives what the photo picker hands over, as a file copied into our own
/// temporary directory (the picker's copy disappears when the call returns).
/// Importing by file, never by Data, is what lets a multi-gigabyte video
/// through without loading it into memory.
struct PickedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // Most specific first: a movie is also "data".
        FileRepresentation(importedContentType: .movie) { try copy($0) }
        FileRepresentation(importedContentType: .image) { try copy($0) }
    }

    private static func copy(_ received: ReceivedTransferredFile) throws -> PickedFile {
        let ext = received.file.pathExtension.isEmpty ? "bin" : received.file.pathExtension
        let dest = FileManager.default.temporaryDirectory.appending(path: "picked-\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: received.file, to: dest)
        return PickedFile(url: dest)
    }
}
