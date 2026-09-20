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
}
