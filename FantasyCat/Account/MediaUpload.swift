import PhotosUI
import SwiftUI

enum MediaUpload {
    /// Upload a photo and wait until the server has made its renditions, so the
    /// new picture is there the moment the caller refreshes. Mirrors the web's
    /// waitForMedia.
    static func photo(_ file: URL) async throws(Failure) -> Int64 {
        let uploaded: Components.Schemas.MediaView
        do { uploaded = try await Uploader.shared.upload(file) { _ in } } catch { throw Failure.from(error) }
        guard uploaded.kind == .image else { throw Failure(message: "A picture has to be a photo, not a video.") }
        for _ in 0..<80 {
            guard case .ok(let ok) = try? await API.client.getMedia(path: .init(id: uploaded.id)), let m = try? ok.body.json else { break }
            if m.status == .ready { return m.id }
            if m.status == .failed { throw Failure(message: m.error ?? "We couldn't read that photo.") }
            try? await Task.sleep(for: .milliseconds(750))
        }
        throw Failure(message: "That photo is taking too long. Try again.")
    }
}

/// A face you can tap to change. Picks a photo, uploads it, waits for it to be
/// ready, then hands the media id to `onPicked`.
struct AvatarPicker: View {
    let url: URL?
    let kind: Avatar.Kind
    var size: Avatar.Size = .md
    let label: String
    let onPicked: (Int64) async -> String?

    @State private var selection: PhotosPickerItem?
    @State private var busy = false
    @State private var failure: String?

    var body: some View {
        // Built on the main actor and only rendered there; see PostView.picker.
        nonisolated(unsafe) let face = ZStack {
            Avatar(url: url, kind: kind, size: size).opacity(busy ? 0.4 : 1)
            if busy { ProgressView() }
        }
        PhotosPicker(selection: $selection, matching: .images, preferredItemEncoding: .current) { face }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel(label)
            .onChange(of: selection) { _, item in if let item { pick(item) } }
            .alert("That didn't work", isPresented: .init(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(failure ?? "") }
    }

    private func pick(_ item: PhotosPickerItem) {
        busy = true
        Task {
            defer { busy = false; selection = nil }
            do {
                guard let file = try await item.loadTransferable(type: PickedFile.self) else { failure = "Photos didn't hand over that picture."; return }
                let id = try await MediaUpload.photo(file.url)
                failure = await onPicked(id)
            } catch { failure = Failure.from(error).message }
        }
    }
}
