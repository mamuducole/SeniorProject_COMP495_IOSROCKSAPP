import Foundation

enum RolePermission: CaseIterable {
    case viewPublicContent
    case registerForEvents
    case requestMentorship
    case participateInCommunity
    case reviewMentorshipRequests
    case manageChapterContent
    case manageNationalContent
}

extension AppRole {
    func can(_ permission: RolePermission) -> Bool {
        switch permission {
        case .viewPublicContent:
            true
        case .registerForEvents, .requestMentorship, .participateInCommunity:
            self != .guest
        case .reviewMentorshipRequests:
            self == .mentor || self == .chapterAdmin || self == .nationalAdmin
        case .manageChapterContent:
            self == .chapterAdmin || self == .nationalAdmin
        case .manageNationalContent:
            self == .nationalAdmin
        }
    }
}
