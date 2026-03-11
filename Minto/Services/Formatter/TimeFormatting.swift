import Foundation

enum TimeFormatting {
    static func mmss(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    static func mmss(_ seconds: Double) -> String {
        mmss(Int(seconds))
    }
}
