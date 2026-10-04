import Foundation

/// Which part of a video to keep. The 30 second cap is a league rule, enforced
/// again by the server; this is the arithmetic of the trim handles. Mirrors
/// web/src/lib/trim.ts and the web Trimmer's `move`.
public enum Clip {
    public static let maxSeconds = 30.0
    public static let minSeconds = 1.0
    public enum End: Sendable { case start, end }

    /// What's kept before anyone touches the handles: the start, up to the cap.
    public static func whole(_ duration: Double) -> ClosedRange<Double> { 0...min(max(duration, 0), maxSeconds) }

    /// Move one handle to `t`. A handle stops at the other one; it only ever
    /// pushes the other to keep the clip under the cap, which is what lets a
    /// 30 second window slide along a long video. Snaps to tenths of a second.
    public static func move(_ range: ClosedRange<Double>, _ end: End, to t: Double, duration: Double) -> ClosedRange<Double> {
        let t = (min(duration, max(0, t)) * 10).rounded() / 10
        var lo = range.lowerBound, hi = range.upperBound
        switch end {
        case .start:
            lo = min(t, hi - minSeconds)
            hi = min(hi, lo + maxSeconds)
        case .end:
            hi = max(t, lo + minSeconds)
            lo = max(lo, hi - maxSeconds)
        }
        lo = max(0, lo)
        return lo...max(lo, min(duration, hi))
    }

    // MARK: Zoom
    //
    // On a long video the kept 30 seconds is a sliver of the strip, too coarse
    // to place by finger. Holding a handle still zooms the strip to the
    // seconds around it (as Photos does); the drag then moves the handle
    // relative to where the zoom began, and the window follows the handle.

    /// Seconds across the strip while zoomed.
    public static let zoomSpan = 10.0

    /// Whether holding a handle zooms: only when the whole video is long
    /// enough that the zoomed strip is a real magnification.
    public static func canZoom(_ duration: Double) -> Bool { duration > maxSeconds }

    /// The zoomed window around time `t`, which sits at `fraction` (0...1) of
    /// the strip's width, so the handle stays under the finger. Kept inside the video.
    public static func zoomWindow(around t: Double, at fraction: Double, duration: Double) -> ClosedRange<Double> {
        let span = min(zoomSpan, duration)
        let lo = min(max(0, t - min(max(fraction, 0), 1) * span), duration - span)
        return lo...(lo + span)
    }

    /// The window moved just enough to show `t`.
    public static func follow(_ window: ClosedRange<Double>, _ t: Double, duration: Double) -> ClosedRange<Double> {
        let span = window.upperBound - window.lowerBound
        var lo = window.lowerBound
        if t < lo { lo = t } else if t > lo + span { lo = t - span }
        lo = min(max(0, lo), max(0, duration - span))
        return lo...(lo + span)
    }
}
