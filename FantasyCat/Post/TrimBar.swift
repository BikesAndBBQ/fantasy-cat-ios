import FantasyCatCore
import AVFoundation
import SwiftUI

/// The native counterpart of the web's Trimmer (reference page, "Trim"): a
/// strip of frames from the whole video, an accent frame around what's kept,
/// two handles. A handle stops at the other one and only pushes it to stay
/// under the cap, which is how a 30 second window slides along a long video.
///
/// On a long video, holding a handle still zooms the strip to the ten seconds
/// around it (as Photos does), so the end can be placed to a tenth of a
/// second; letting go shows the whole video again. The arithmetic is `Clip`'s.
struct TrimBar: View {
    let url: URL
    let duration: Double
    @Binding var range: ClosedRange<Double>
    /// Called while dragging, with the time under the handle, so the preview can scrub to it.
    var scrub: (Double) -> Void = { _ in }

    /// A frame of the strip and the seconds it stands for.
    private struct Tile: Identifiable { let id: Int; let span: ClosedRange<Double>; let image: UIImage }
    /// Where a zoomed drag began: from then on the handle moves by the finger's travel, not to its position.
    private struct Grab { let end: Clip.End; let x: CGFloat; let t: Double }

    @State private var frames: [Tile] = []
    @State private var zoomTiles: [Int: Tile] = [:]
    /// The seconds the strip shows while zoomed; nil shows the whole video.
    @State private var window: ClosedRange<Double>?
    @State private var grab: Grab?
    @State private var holdX: CGFloat?
    @State private var hold: Task<Void, Never>?
    private let handleWidth: CGFloat = 14
    private let height: CGFloat = 48
    private let zoomTileSeconds = Clip.zoomSpan / 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let x0 = x(range.lowerBound, w), x1 = x(range.upperBound, w)
                ZStack(alignment: .leading) {
                    ZStack(alignment: .leading) {
                        Tokens.sunken
                        strip(frames, w)
                        if window != nil { strip(Array(zoomTiles.values), w).transition(.opacity) }
                        // Wash out what's cut.
                        Tokens.paper.opacity(0.75).frame(width: min(w, max(0, x0)), height: height)
                        Tokens.paper.opacity(0.75).frame(width: min(w, max(0, w - x1)), height: height).offset(x: max(0, x1))
                        Rectangle().strokeBorder(Tokens.accent, lineWidth: 3).frame(width: max(0, x1 - x0), height: height).offset(x: x0)
                    }
                    .frame(width: w, height: height, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                    .allowsHitTesting(false)
                    handle(leading: true, at: x0, width: w)
                    handle(leading: false, at: x1, width: w)
                }
                .coordinateSpace(name: "trimstrip")
            }
            .frame(height: height)
            .padding(.horizontal, handleWidth / 2)
            HStack(alignment: .firstTextBaseline) {
                Text("\(clock(range.lowerBound)) to \(clock(range.upperBound))" + (duration > Clip.maxSeconds ? " · 30 seconds at most" : ""))
                    .type(.small).foregroundStyle(Tokens.muted)
                Spacer()
                (Text(String(format: "%.1f", range.upperBound - range.lowerBound)).font(Font(TypeStyle.scoreSmall.uiFont())).foregroundStyle(Tokens.ink)
                    + Text(" s kept").font(Font(TypeStyle.small.uiFont())).foregroundStyle(Tokens.muted))
                    .monospacedDigit()
            }
            if Clip.canZoom(duration) {
                Text(window == nil ? "Hold a handle still to zoom in." : "Zoomed in to \(Int(Clip.zoomSpan)) seconds. Let go to see the whole video.")
                    .type(.small).foregroundStyle(window == nil ? Tokens.muted : Tokens.accent)
                    .accessibilityHidden(true) // VoiceOver adjusts the handles directly
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: window != nil) { _, zoomed in zoomed }
        .task(id: url) { await loadFrames() }
        .task(id: window) { await loadZoomTiles() }
        .onAppear(perform: debugZoom)
        .accessibilityElement(children: .contain)
    }

    /// What the strip shows: the zoom window, or the whole video.
    private var shown: ClosedRange<Double> { window ?? 0...max(duration, 0.001) }

    private func x(_ t: Double, _ w: CGFloat) -> CGFloat {
        CGFloat((t - shown.lowerBound) / (shown.upperBound - shown.lowerBound)) * w
    }

    /// Tiles laid out by the seconds they stand for, so zooming stretches them and the window pans them.
    private func strip(_ tiles: [Tile], _ w: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(tiles) { tile in
                let a = x(tile.span.lowerBound, w), b = x(tile.span.upperBound, w)
                if b > 0, a < w {
                    Image(uiImage: tile.image).resizable().scaledToFill().frame(width: b - a, height: height).clipped().offset(x: a)
                }
            }
        }
        .frame(width: w, height: height, alignment: .leading)
    }

    /// 44 pt wide to catch a thumb; the visible grip is the 14 pt bar in its middle.
    /// While zoomed, the other end may be out of view: it hides until the zoom ends.
    @ViewBuilder private func handle(leading: Bool, at x: CGFloat, width w: CGFloat) -> some View {
        let visible = x >= -1 && x <= w + 1
        ZStack {
            Color.clear
            UnevenRoundedRectangle(topLeadingRadius: leading ? Tokens.Radius.field : 0, bottomLeadingRadius: leading ? Tokens.Radius.field : 0,
                                   bottomTrailingRadius: leading ? 0 : Tokens.Radius.field, topTrailingRadius: leading ? 0 : Tokens.Radius.field, style: .continuous)
                .fill(Tokens.accent).frame(width: handleWidth)
            Capsule().fill(Tokens.onAccent).frame(width: 3, height: 16)
        }
        .frame(width: 44, height: height)
        .contentShape(Rectangle())
        .offset(x: x - 22)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .gesture(drag(leading ? .start : .end, width: w))
        .accessibilityElement()
        .accessibilityLabel(leading ? "Start of clip" : "End of clip")
        .accessibilityValue(clock(leading ? range.lowerBound : range.upperBound))
        .accessibilityAdjustableAction { direction in
            let by = direction == .increment ? 0.5 : -0.5
            move(leading ? .start : .end, to: (leading ? range.lowerBound : range.upperBound) + by)
        }
    }

    private func drag(_ end: Clip.End, width w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("trimstrip"))
            .onChanged { g in
                let fx = g.location.x
                if let grab, let window {
                    let span = window.upperBound - window.lowerBound
                    move(end, to: grab.t + Double((fx - grab.x) / max(w, 1)) * span)
                    self.window = Clip.follow(window, at(end), duration: duration)
                } else {
                    move(end, to: Double(fx / max(w, 1)) * duration)
                    armHold(end, x: fx, width: w)
                }
            }
            .onEnded { _ in
                hold?.cancel()
                hold = nil
                holdX = nil
                grab = nil
                withAnimation(.snappy) { window = nil }
            }
    }

    /// Zooms once the finger has rested on a handle (within a few points) for a moment.
    private func armHold(_ end: Clip.End, x fx: CGFloat, width w: CGFloat) {
        guard Clip.canZoom(duration) else { return }
        if let holdX, abs(fx - holdX) < 4 { return }
        holdX = fx
        hold?.cancel()
        hold = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let t = at(end)
            grab = Grab(end: end, x: fx, t: t)
            withAnimation(.snappy) { window = Clip.zoomWindow(around: t, at: Double(fx / max(w, 1)), duration: duration) }
        }
    }

    private func at(_ end: Clip.End) -> Double { end == .start ? range.lowerBound : range.upperBound }

    private func move(_ end: Clip.End, to t: Double) {
        range = Clip.move(range, end, to: t, duration: duration)
        scrub(at(end))
    }

    private func clock(_ t: Double) -> String { TimeText.clock(t) }

    nonisolated private static func generator(_ url: URL) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true // phones record sideways and flag it
        generator.maximumSize = CGSize(width: 0, height: 120)
        return generator
    }

    private func loadFrames() async {
        frames = []
        zoomTiles = [:]
        let generator = Self.generator(url)
        let count = 8
        for i in 0..<count {
            let t = CMTime(seconds: (Double(i) + 0.5) / Double(count) * duration, preferredTimescale: 600)
            guard let cg = try? await generator.image(at: t).image else { continue }
            if Task.isCancelled { return }
            frames.append(Tile(id: i, span: (Double(i) / Double(count) * duration)...(Double(i + 1) / Double(count) * duration), image: UIImage(cgImage: cg)))
        }
    }

    /// Frames for the zoomed strip, on a fixed grid of seconds so a panning window reuses what it has.
    private func loadZoomTiles() async {
        guard let window else { return }
        try? await Task.sleep(for: .milliseconds(80)) // let a pan settle before asking for frames
        if Task.isCancelled { return }
        let generator = Self.generator(url)
        let first = Int(window.lowerBound / zoomTileSeconds), last = Int(window.upperBound / zoomTileSeconds)
        for i in first...last where zoomTiles[i] == nil {
            let lo = Double(i) * zoomTileSeconds
            guard lo < duration else { break }
            let span = lo...min(duration, lo + zoomTileSeconds)
            guard let cg = try? await generator.image(at: CMTime(seconds: (span.lowerBound + span.upperBound) / 2, preferredTimescale: 600)).image else { continue }
            if Task.isCancelled { return }
            zoomTiles[i] = Tile(id: i, span: span, image: UIImage(cgImage: cg))
        }
    }

    /// Debug builds: `-trimzoom` shows the strip zoomed around the start handle, for a screenshot.
    private func debugZoom() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-trimzoom"), Clip.canZoom(duration) else { return }
        window = Clip.zoomWindow(around: range.lowerBound, at: 0.3, duration: duration)
        #endif
    }
}
