import Foundation
import Testing
@testable import FantasyCatCore

@Suite struct ServerDateTests {
    @Test func goTimestampsInEveryShape() {
        // The exact string that broke sign-in, then the other shapes Go produces.
        #expect(ServerDate.parse("2026-09-17T12:57:12.99077-07:00")?.timeIntervalSince1970 == 1_789_675_032.99)
        #expect(ServerDate.parse("2026-09-17T12:57:12-07:00")?.timeIntervalSince1970 == 1_789_675_032)
        #expect(ServerDate.parse("2026-09-17T19:57:12Z")?.timeIntervalSince1970 == 1_789_675_032)
        #expect(ServerDate.parse("2026-09-17T19:57:12.5Z")?.timeIntervalSince1970 == 1_789_675_032.5)
        let nanos = ServerDate.parse("2026-09-17T19:57:12.123456789Z")?.timeIntervalSince1970 ?? 0
        #expect(abs(nanos - 1_789_675_032.123) < 0.0005) // truncated to milliseconds, not rejected
    }

    @Test func rubbishIsNilNotACrash() {
        for s in ["", "nonsense", "2026-09-17", "12:57:12", "2026-13-40T99:99:99Z"] { #expect(ServerDate.parse(s) == nil) }
    }
}

@Suite struct TimeTextTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func countdown() {
        #expect(TimeText.countdown(to: now.addingTimeInterval(2 * 86400 + 4 * 3600 + 17 * 60), now: now) == "2d 04:17")
        #expect(TimeText.countdown(to: now.addingTimeInterval(4 * 3600 + 17 * 60 + 9), now: now) == "04:17:09")
        #expect(TimeText.countdown(to: now.addingTimeInterval(-50), now: now) == "00:00:00") // passed: never negative
    }

    @Test func deadlineIsTheMinuteBeforeMidnight() {
        // Stored as Sunday 00:00; people think of it as Saturday 11:59 PM.
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let sundayMidnight = ServerDate.parse("2026-09-20T00:00:00-07:00")!
        #expect(TimeText.deadline(sundayMidnight, timeZone: la, locale: Locale(identifier: "en_US")) == "Saturday at 11:59\u{202F}PM")
    }

    @Test func ago() {
        #expect(TimeText.ago(now.addingTimeInterval(-30), now: now) == "just now")
        #expect(TimeText.ago(now.addingTimeInterval(-600), now: now) == "10 min ago")
        #expect(TimeText.ago(now.addingTimeInterval(-3 * 3600), now: now) == "3 hr ago")
        #expect(TimeText.ago(now.addingTimeInterval(-86400), now: now) == "yesterday")
        #expect(TimeText.ago(now.addingTimeInterval(-5 * 86400), now: now) == "5 days ago")
    }

    @Test func clock() {
        #expect(TimeText.clock(0) == "0:00.0")
        #expect(TimeText.clock(64.5) == "1:04.5")
    }
}

@Suite struct ClipTests {
    @Test func wholeIsTheStartUpToTheCap() {
        #expect(Clip.whole(6.4) == 0...6.4)
        #expect(Clip.whole(40) == 0...30)
    }

    @Test func aHandleStopsAtTheOtherOne() {
        // Dragging the end far left must not push the start (a bug the web version had first).
        #expect(Clip.move(12.2...30, .end, to: 10, duration: 40) == 12.2...13.2)
        #expect(Clip.move(5...20, .start, to: 25, duration: 40) == 19...20)
    }

    @Test func itOnlyPushesToStayUnderTheCap() {
        // Sliding a 30 second window along a long video by either end.
        #expect(Clip.move(0...30, .end, to: 40, duration: 60) == 10...40)
        #expect(Clip.move(20...50, .start, to: 5, duration: 60) == 5...35)
    }

    @Test func staysInsideTheVideoAndSnapsToTenths() {
        #expect(Clip.move(0...10, .end, to: 99, duration: 12) == 0...12)
        #expect(Clip.move(0...10, .start, to: -5, duration: 12) == 0...10)
        #expect(Clip.move(0...10, .end, to: 7.26, duration: 12) == 0...7.3)
    }

    @Test func everyResultIsLegal() {
        for d in [1.5, 6.4, 29.9, 30, 31, 600] {
            for t in stride(from: -5.0, through: d + 5, by: 0.7) {
                for end in [Clip.End.start, .end] {
                    let r = Clip.move(Clip.whole(d), end, to: t, duration: d)
                    let length = r.upperBound - r.lowerBound
                    #expect(r.lowerBound >= 0 && r.upperBound <= d + 1e-9 && length <= Clip.maxSeconds + 1e-9)
                    #expect(length >= min(Clip.minSeconds, d) - 1e-9)
                }
            }
        }
    }
}

@Suite struct InviteTests {
    @Test func linksAndBareCodes() {
        #expect(Invite.code(from: "https://fantasycat.co/join/PineStCats") == "pinestcats")
        #expect(Invite.code(from: "  pinestcats\n") == "pinestcats")
        #expect(Invite.code(from: "http://localhost:5173/join/pinestcats?utm=x") == "pinestcats")
        #expect(Invite.code(from: "") == "")
    }
}
