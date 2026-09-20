import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// What the person chose, as a file this app owns.
struct PickedMedia: Equatable, Sendable {
    enum Kind: Sendable { case image, video }
    var kind: Kind
    var url: URL
    /// Videos only.
    var duration: Double = 0

    static func inspect(_ url: URL) async throws -> PickedMedia {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true {
            let seconds = try await AVURLAsset(url: url).load(.duration).seconds
            guard seconds.isFinite, seconds > 0 else { throw PrepError.unreadable }
            return PickedMedia(kind: .video, url: url, duration: seconds)
        }
        return PickedMedia(kind: .image, url: url)
    }
}

enum PrepError: Error { case unreadable, exportFailed(String) }

/// The league rule, enforced again by the server. Mirrors web/src/lib/trim.ts.
enum Clip {
    static let maxSeconds = 30.0
    static let minSeconds = 1.0
    static func whole(_ duration: Double) -> ClosedRange<Double> { 0...min(duration, maxSeconds) }
}

enum MediaPrep {
    /// Cut the kept part out of a video and re-encode it as 1080p HEVC, on the
    /// phone, before anything is uploaded. This is why the app can take a
    /// ten-minute 4K video the web can't: what crosses the network is at most
    /// thirty seconds (tens of megabytes), exact to the frame, and the server
    /// (which makes its own 720p H.264 from whatever it gets) never sees the rest.
    /// Photos go up untouched; the server already handles HEIC and orientation.
    static func exportClip(from source: URL, range: ClosedRange<Double>, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let presets = [AVAssetExportPresetHEVC1920x1080, AVAssetExportPreset1920x1080, AVAssetExportPresetHighestQuality]
        var session: AVAssetExportSession?
        for preset in presets {
            if await AVAssetExportSession.compatibility(ofExportPreset: preset, with: asset, outputFileType: .mp4) {
                session = AVAssetExportSession(asset: asset, presetName: preset)
                break
            }
        }
        guard let session else { throw PrepError.exportFailed("no usable export preset") }
        let out = FileManager.default.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mp4")
        session.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                                        end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
        session.shouldOptimizeForNetworkUse = true
        // Location and device tags stay on the phone. (The server strips them too.)
        session.metadataItemFilter = .forSharing()

        // AVAssetExportSession isn't Sendable. The watcher only reads its progress
        // stream, which AVFoundation documents as safe alongside export(to:as:).
        nonisolated(unsafe) let watched = session
        let watcher = Task {
            for await state in watched.states(updateInterval: 0.2) {
                if case .exporting(let p) = state { progress(p.fractionCompleted) }
            }
        }
        defer { watcher.cancel() }
        do {
            try await session.export(to: out, as: .mp4)
        } catch {
            throw PrepError.exportFailed(String(describing: error))
        }
        progress(1)
        return out
    }
}
