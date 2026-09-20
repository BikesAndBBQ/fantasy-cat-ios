import AVFoundation
import SwiftUI

/// The native counterpart of the web's Trimmer (reference page, "Trim"): a
/// strip of frames from the whole video, an accent frame around what's kept,
/// two handles. A handle stops at the other one and only pushes it to stay
/// under the cap, which is how a 30 second window slides along a long video.
struct TrimBar: View {
    let url: URL
    let duration: Double
    @Binding var range: ClosedRange<Double>
    /// Called while dragging, with the time under the handle, so the preview can scrub to it.
    var scrub: (Double) -> Void = { _ in }

    @State private var frames: [UIImage] = []
    private let handleWidth: CGFloat = 14
    private let height: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let x0 = CGFloat(range.lowerBound / duration) * w
                let x1 = CGFloat(range.upperBound / duration) * w
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(frames.indices, id: \.self) { i in
                            Image(uiImage: frames[i]).resizable().scaledToFill().frame(width: w / CGFloat(max(frames.count, 1)), height: height).clipped()
                        }
                    }
                    .frame(width: w, height: height, alignment: .leading)
                    .background(Tokens.sunken)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                    // Wash out what's cut.
                    Tokens.paper.opacity(0.75).frame(width: max(0, x0), height: height)
                    Tokens.paper.opacity(0.75).frame(width: max(0, w - x1), height: height).offset(x: x1)
                    Rectangle().strokeBorder(Tokens.accent, lineWidth: 3).frame(width: max(0, x1 - x0), height: height).offset(x: x0).allowsHitTesting(false)
                    handle(leading: true).offset(x: x0 - 22).gesture(drag(.start, width: w))
                    handle(leading: false).offset(x: x1 - 22).gesture(drag(.end, width: w))
                }
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
        }
        .task(id: url) { await loadFrames() }
        .accessibilityElement(children: .contain)
    }

    private enum End { case start, end }

    /// 44 pt wide to catch a thumb; the visible grip is the 14 pt bar in its middle.
    private func handle(leading: Bool) -> some View {
        ZStack {
            Color.clear
            UnevenRoundedRectangle(topLeadingRadius: leading ? Tokens.Radius.field : 0, bottomLeadingRadius: leading ? Tokens.Radius.field : 0,
                                   bottomTrailingRadius: leading ? 0 : Tokens.Radius.field, topTrailingRadius: leading ? 0 : Tokens.Radius.field, style: .continuous)
                .fill(Tokens.accent).frame(width: handleWidth)
            Capsule().fill(Tokens.onAccent).frame(width: 3, height: 16)
        }
        .frame(width: 44, height: height)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(leading ? "Start of clip" : "End of clip")
        .accessibilityValue(clock(leading ? range.lowerBound : range.upperBound))
        .accessibilityAdjustableAction { direction in
            let by = direction == .increment ? 0.5 : -0.5
            move(leading ? .start : .end, to: (leading ? range.lowerBound : range.upperBound) + by)
        }
    }

    private func drag(_ end: End, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("trim")).onChanged { g in
            move(end, to: Double(g.location.x / max(width, 1)) * duration)
        }
    }

    private func move(_ end: End, to t: Double) {
        let t = (min(duration, max(0, t)) * 10).rounded() / 10
        var lo = range.lowerBound, hi = range.upperBound
        switch end {
        case .start:
            lo = min(t, hi - Clip.minSeconds)
            hi = min(hi, lo + Clip.maxSeconds)
        case .end:
            hi = max(t, lo + Clip.minSeconds)
            lo = max(lo, hi - Clip.maxSeconds)
        }
        range = max(0, lo)...min(duration, hi)
        scrub(end == .start ? lo : hi)
    }

    private func clock(_ t: Double) -> String { String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60)) }

    private func loadFrames() async {
        frames = []
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true // phones record sideways and flag it
        generator.maximumSize = CGSize(width: 0, height: 120)
        let count = 8
        for i in 0..<count {
            let t = CMTime(seconds: (Double(i) + 0.5) / Double(count) * duration, preferredTimescale: 600)
            guard let cg = try? await generator.image(at: t).image else { continue }
            if Task.isCancelled { return }
            frames.append(UIImage(cgImage: cg))
        }
    }
}
