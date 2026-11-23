import Foundation

extension Date {
    static let rocksDisplayDate: Date.FormatStyle = .dateTime.month(.abbreviated).day().year()

    /// Compact relative timestamp used by the community feed and notifications ("5h", "2d").
    var rocksRelative: String {
        let interval = max(0, Date.now.timeIntervalSince(self))
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day

        switch interval {
        case ..<minute:
            return "now"
        case ..<hour:
            return "\(Int(interval / minute))m"
        case ..<day:
            return "\(Int(interval / hour))h"
        case ..<week:
            return "\(Int(interval / day))d"
        default:
            return "\(Int(interval / week))w"
        }
    }
}
