import FantasyCatCore
import AVKit
import PhotosUI
import SwiftUI

/// Post a photo or video to this week's round.
struct PostView: View {
    @State private var model: PostModel
    @State private var selection: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var loopObserver: Any?
    @State private var camera = false
    @Environment(\.dismiss) private var dismiss

    init(league: Components.Schemas.LeagueView, category: Int64? = nil) {
        let m = PostModel(league: league)
        if let category { m.categoryID = category }
        _model = State(initialValue: m)
        let args = ProcessInfo.processInfo.arguments
        autopost = args.firstIndex(of: "-autopost").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil }
    }
    private let autopost: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(model.media?.kind == .video ? "Post a video" : "Post a photo", eyebrow: model.league.currentRound.map { "Round \($0.number)" })
                if !model.isOpen {
                    Card { Text("Submissions are closed. The next round opens when this one goes to voting.").type(.body).foregroundStyle(Tokens.muted) }
                } else {
                    if let failure = model.failure { notice(failure) }
                    chooser
                    if model.media != nil { details }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PageBackground())
        .task { await model.loadPets() }
        .task(id: autopost) { await runAutopost() }
        .onChange(of: selection) { _, item in if let item { load(item) } }
        .onChange(of: model.media) { _, m in startPlayer(for: m) }
        .onChange(of: model.trim) { old, new in
            // Moved from code rather than by a drag (which scrubs by itself): show where the clip now starts.
            if old.lowerBound != new.lowerBound, player?.timeControlStatus != .playing { seek(new.lowerBound) }
        }
        .onDisappear { stopPlayer() }
        .fullScreenCover(isPresented: $camera) {
            CameraCapture { url in
                camera = false
                guard let url else { return }
                Task { do { model.picked(try await PickedMedia.inspect(url)) } catch { model.pickFailed("That couldn't be read. Try again.") } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: model.stage) { _, s in if case .posted = s { dismiss() } }
    }

    // MARK: Choosing

    @ViewBuilder private var chooser: some View {
        if let media = model.media {
            VStack(alignment: .leading, spacing: 8) {
                preview(media).frame(maxWidth: .infinity).frame(maxHeight: 420)
                    .background(Tokens.sunken).clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    .overlay(alignment: .bottom) { progressOverlay }
                if media.kind == .video, media.duration > Clip.minSeconds + 0.2 {
                    TrimBar(url: media.url, duration: media.duration, range: $model.trim) { t in
                        player?.pause()
                        seek(t)
                    }
                    .coordinateSpace(name: "trim")
                    .disabled(model.busy)
                }
                HStack {
                    picker { Text("Choose a different one") }.buttonStyle(.fc(size: .sm)).disabled(model.busy)
                    if CameraCapture.isAvailable { Button("Take another") { camera = true }.buttonStyle(.fc(size: .sm)).disabled(model.busy) }
                }
            }
        } else {
            picker {
                VStack(spacing: 6) {
                    if case .loading(let p) = model.stage {
                        ProgressView(value: p).tint(Tokens.accent).frame(width: 160)
                        Text("Getting it from Photos…").type(.small).foregroundStyle(Tokens.muted)
                    } else {
                        Text("Choose a photo or video").type(.cardTitle).foregroundStyle(Tokens.ink)
                        Text("Any length: you pick which 30 seconds of a video to keep.").type(.small).foregroundStyle(Tokens.muted).multilineTextAlignment(.center)
                    }
                }
                .padding(24).frame(maxWidth: .infinity).aspectRatio(Tokens.photoRatio, contentMode: .fit)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).strokeBorder(Tokens.line, style: .init(lineWidth: 1.5, dash: [6, 5])) }
            }
            .buttonStyle(.plain)
            .disabled(model.busy)
            if CameraCapture.isAvailable {
                Button { camera = true } label: { Label("Take a photo or video", systemImage: "camera.fill") }
                    .buttonStyle(.fc(block: true)).disabled(model.busy).accessibilityIdentifier("post-camera")
            }
        }
    }

    /// `.current` asks Photos for the file as it is. The default, `.compatible`,
    /// converts video to H.264 first: slow, bigger, and the step that fails
    /// silently for long videos in the web picker (server D34).
    private func picker<L: View>(@ViewBuilder label: () -> L) -> some View {
        // Built here on the main actor and only ever rendered there; PhotosPicker's
        // label closure is nonetheless typed @Sendable.
        nonisolated(unsafe) let content = label()
        return PhotosPicker(selection: $selection, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current) { content }
            .accessibilityIdentifier("post-picker")
    }

    @ViewBuilder private func preview(_ media: PickedMedia) -> some View {
        switch media.kind {
        case .video:
            VideoPlayer(player: player).aspectRatio(contentMode: .fit)
        case .image:
            AsyncImage(url: media.url) { $0.image?.resizable().scaledToFit() }
        }
    }

    @ViewBuilder private var progressOverlay: some View {
        let (label, fraction): (String?, Double) = switch model.stage {
        case .preparing(let p): ("Trimming…", p)
        case .uploading(let p): (p < 1 ? "Uploading… \(Int(p * 100))%" : "Almost there…", p)
        case .submitting: ("Posting…", 1)
        default: (nil, 0)
        }
        if let label {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: fraction).tint(Tokens.accent)
                Text(label).font(Font(TypeStyle.small.uiFont())).foregroundStyle(.white)
            }
            .padding(12).background(.black.opacity(0.55))
        }
    }

    // MARK: Details

    @ViewBuilder private var details: some View {
        group("Category") {
            FlowChips(items: model.categories.map { ($0.id, $0.name) }, selected: model.categoryID) { model.categoryID = $0 }
        }
        group("Which cat?") {
            if model.pets.isEmpty {
                FCField(label: "Your cat's name", text: $model.newCatName, help: "You can add more cats later from your account.")
            } else {
                FlowChips(items: model.pets.map { ($0.id, $0.name) }, selected: model.petID) { model.petID = $0 }
            }
        }
        FCField(label: "Caption", text: $model.caption, help: "Optional.")
        HStack(spacing: 10) {
            Button("Cancel") { dismiss() }.buttonStyle(.fc()).disabled(model.busy)
            Button("Post it") { Task { await model.post() } }
                .buttonStyle(.fc(.primary, block: true, busy: model.busy))
                .disabled(!model.canPost)
                .accessibilityIdentifier("post-submit")
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { Eyebrow(title); content() }
    }

    private func notice(_ text: String) -> some View {
        Text(text).type(.small).foregroundStyle(Tokens.danger).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
    }

    // MARK: Playback

    /// Playing shows exactly what will post: it starts at the kept part and loops inside it.
    private func startPlayer(for media: PickedMedia?) {
        stopPlayer()
        guard let media, media.kind == .video else { return }
        let p = AVPlayer(url: media.url)
        p.isMuted = true
        loopObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            MainActor.assumeIsolated {
                let t = time.seconds
                if t >= model.trim.upperBound || t < model.trim.lowerBound - 0.3 { seek(model.trim.lowerBound) }
            }
        }
        player = p
        seek(model.trim.lowerBound)
    }

    private func stopPlayer() {
        if let loopObserver { player?.removeTimeObserver(loopObserver) }
        loopObserver = nil
        player?.pause()
        player = nil
    }

    private func seek(_ t: Double) {
        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Loading

    private func load(_ item: PhotosPickerItem) {
        model.setLoading(0)
        // Unlike the web, this reports progress (an iCloud original downloading)
        // and a real error if Photos can't produce the file.
        let progress = item.loadTransferable(type: PickedFile.self) { result in
            Task { @MainActor in
                switch result {
                case .success(let file?):
                    do { model.picked(try await PickedMedia.inspect(file.url)) } catch { model.pickFailed("That file couldn't be read. Try a different one.") }
                case .success(nil):
                    model.pickFailed("Photos didn't hand over that file. Try a different one.")
                case .failure(let error):
                    model.pickFailed("Photos couldn't get that file ready: \(error.localizedDescription)")
                }
                selection = nil
            }
        }
        Task { @MainActor in
            while !progress.isFinished, !progress.isCancelled {
                if case .loading = model.stage { model.setLoading(progress.fractionCompleted) }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    /// Debug builds: `-autopost <file>` behaves as if that file had been picked,
    /// keeps seconds 1 to 3 of a video, and posts (or, with `-nopost`, stops there), so the prepare, upload and
    /// submit path can be checked from the command line. The picker itself can't.
    private func runAutopost() async {
        #if DEBUG
        guard let autopost, model.media == nil else { return }
        do {
            let m = try await PickedMedia.inspect(autopost)
            model.picked(m)
            let show = ProcessInfo.processInfo.arguments.contains("-nopost")
            if m.kind == .video, m.duration > 3.5 { model.trim = show ? (m.duration * 0.25)...(m.duration * 0.6) : 1...3 }
            if ProcessInfo.processInfo.arguments.contains("-nopost") { return } // just show the screen
            while model.pets.isEmpty { try await Task.sleep(for: .milliseconds(100)) }
            await model.post()
        } catch { model.pickFailed("autopost: \(error)") }
        #endif
    }
}

/// Chips that wrap onto as many lines as they need.
struct FlowChips: View {
    let items: [(Int64, String)]
    let selected: Int64?
    let pick: (Int64) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.0) { id, name in
                Button { pick(id) } label: { Chip(name, tone: id == selected ? .selected : .default) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(id == selected ? .isSelected : [])
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            for (i, x) in row.items { subviews[i].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified) }
        }
    }

    private struct Row { var items: [(Int, CGFloat)] = []; var y: CGFloat = 0; var height: CGFloat = 0; var width: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + s.width > width, !rows[rows.count - 1].items.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            rows[rows.count - 1].items.append((i, rows[rows.count - 1].width))
            rows[rows.count - 1].width += s.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, s.height)
        }
        return rows
    }
}
