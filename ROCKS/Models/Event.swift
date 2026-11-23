import Foundation

struct ROCKSEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let chapterName: String?
    let startsAt: Date
    let endsAt: Date?
    let venueName: String?
    let locationLabel: String?
    let eventDescription: String?
    let category: String?
    let imageURL: URL?
    let imageName: String?
    let registrationRequired: Bool
    let attendeeCount: Int
    let attendeeNames: [String]
    var isRegisteredByCurrentUser: Bool

    init(
        id: UUID,
        title: String,
        chapterName: String? = nil,
        startsAt: Date,
        endsAt: Date? = nil,
        venueName: String? = nil,
        locationLabel: String? = nil,
        eventDescription: String? = nil,
        category: String? = nil,
        imageURL: URL? = nil,
        imageName: String? = nil,
        registrationRequired: Bool = false,
        attendeeCount: Int = 0,
        attendeeNames: [String] = [],
        isRegisteredByCurrentUser: Bool = false
    ) {
        self.id = id
        self.title = title
        self.chapterName = chapterName
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.venueName = venueName
        self.locationLabel = locationLabel
        self.eventDescription = eventDescription
        self.category = category
        self.imageURL = imageURL
        self.imageName = imageName
        self.registrationRequired = registrationRequired
        self.attendeeCount = attendeeCount
        self.attendeeNames = attendeeNames
        self.isRegisteredByCurrentUser = isRegisteredByCurrentUser
    }

    var isUpcoming: Bool { startsAt > .now }

    var timeLabel: String {
        startsAt.formatted(date: .omitted, time: .shortened)
    }

    var attendeeMembers: [MemberProfile] {
        attendeeNames.map { MemberProfile.placeholder(name: $0) }
    }

    static var upcomingExamples: [ROCKSEvent] {
        examples.sorted { $0.startsAt < $1.startsAt }
    }

    static let examples = [
        // MARK: Featured national events (2026).
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000010") ?? UUID(),
            title: "2026 AUSA Annual Meeting & Exposition",
            chapterName: nil,
            startsAt: Calendar.current.date(byAdding: .day, value: 20, to: .now) ?? .now,   // 2026 AUSA (Oct 12–14)
            endsAt: Calendar.current.date(byAdding: .day, value: 22, to: .now),
            venueName: "Walter E. Washington Convention Center",
            locationLabel: "Washington, DC",
            eventDescription: "A professional development forum. Join ROCKS members at the 2026 AUSA Annual Meeting & Exposition, October 12–14 in Washington, DC, featuring LTG Donna W. Martin, U.S. Army (Ret.), ROCKS National Chair.",
            category: "conference",
            imageName: nil,
            registrationRequired: true,
            attendeeCount: 412,
            attendeeNames: ["Marcus Johnson", "Jessica Williams", "Angela Carter", "Kevin Roberts"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000011") ?? UUID(),
            title: "JBLM Rainier ROCKS Fourth Anniversary",
            chapterName: "JBLM Rainier ROCKS",
            startsAt: Calendar.current.date(byAdding: .day, value: 37, to: .now) ?? .now,   // JBLM 4th Anniversary (Oct 29)
            venueName: "Lewis Army Museum",
            locationLabel: "Joint Base Lewis–McChord",
            eventDescription: "Celebrate four years of JBLM Rainier ROCKS. Keynote address by LTG Donna W. Martin, U.S. Army (Ret.), ROCKS National Chair: “State of The ROCKS, Inc.: Recent Accomplishments and Progress.” Opening remarks by LTC MJ Jackson, Chapter President, followed by a facilitated Q&A and refreshments.",
            category: "chapter",
            imageName: nil,
            registrationRequired: true,
            attendeeCount: 156,
            attendeeNames: ["David Thompson", "Monica Reed", "James Cole"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "National Leadership Conference 2026",
            chapterName: nil,
            startsAt: Calendar.current.date(byAdding: .day, value: 20, to: .now) ?? .now,
            endsAt: Calendar.current.date(byAdding: .day, value: 22, to: .now),
            venueName: "Hyatt Regency Atlanta",
            locationLabel: "Atlanta, GA",
            eventDescription: "The flagship national gathering of The ROCKS, Inc. — three days of mentorship, leadership development, and networking with senior leaders across the military, government, and industry.",
            category: "conference",
            // FLAGGED: no dedicated conference artwork yet. The bundled "rocksHeroLeadership"
            // asset is the 2026 "WIN WITH 10!" membership-drive banner and does NOT describe
            // this event, so the card renders the branded placeholder until real art exists.
            imageName: nil,
            registrationRequired: true,
            attendeeCount: 326,
            attendeeNames: ["Marcus Johnson", "Jessica Williams", "Kevin Roberts", "Angela Carter"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "ROCKS Mentorship Mixer",
            chapterName: "National Capital Chapter",
            startsAt: Calendar.current.date(byAdding: .day, value: 12, to: .now) ?? .now,
            venueName: "Virtual Event",
            locationLabel: "Virtual Event",
            eventDescription: "Meet mentors and mentees from across the ROCKS network. Breakout rooms are organized by career field and mentorship interests.",
            category: "mentorship",
            imageName: "rocksMentorship",
            registrationRequired: false,
            attendeeCount: 184,
            attendeeNames: ["David Thompson", "Monica Reed", "James Cole"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID(),
            title: "Chapter Presidents Summit",
            chapterName: nil,
            startsAt: Calendar.current.date(byAdding: .day, value: 34, to: .now) ?? .now,
            venueName: "Rosslyn Gateway",
            locationLabel: "Arlington, VA",
            eventDescription: "Chapter leadership alignment on programming, scholarships, and community impact for the coming year.",
            category: "chapter",
            imageName: "rocksLeadership",
            registrationRequired: true,
            attendeeCount: 96,
            attendeeNames: ["Angela Carter", "Marcus Johnson"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID(),
            title: "Leadership Development Roundtable",
            chapterName: "National Capital Chapter",
            startsAt: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now,
            venueName: "Online",
            locationLabel: "Online",
            eventDescription: "Monthly roundtable on leading with purpose, hosted by senior ROCKS mentors.",
            category: "professional_development",
            imageName: nil,
            registrationRequired: true,
            attendeeCount: 42,
            attendeeNames: ["Jessica Williams", "Monica Reed"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005") ?? UUID(),
            title: "Mentorship Connection Hour",
            chapterName: nil,
            startsAt: Calendar.current.date(byAdding: .day, value: 28, to: .now) ?? .now,
            venueName: "Online",
            locationLabel: "Online",
            eventDescription: "Open hour for new mentees to meet available mentors.",
            category: "mentorship",
            imageName: nil,
            registrationRequired: false,
            attendeeCount: 58,
            attendeeNames: ["Kevin Roberts", "David Thompson"]
        )
    ]

    static let pastExamples = [
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000101") ?? UUID(),
            title: "Community Service Day",
            chapterName: "Fort Liberty Chapter",
            startsAt: Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now,
            venueName: "Fort Liberty",
            locationLabel: "Fayetteville, NC",
            eventDescription: "A day of service alongside local partners in the Fayetteville community.",
            category: "community_service",
            imageName: "rocksCommunityService",
            registrationRequired: false,
            attendeeCount: 64,
            attendeeNames: ["James Cole", "Angela Carter", "David Thompson"]
        ),
        ROCKSEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000102") ?? UUID(),
            title: "Scholarship Awards Banquet",
            chapterName: nil,
            startsAt: Calendar.current.date(byAdding: .day, value: -48, to: .now) ?? .now,
            venueName: "National Press Club",
            locationLabel: "Washington, DC",
            eventDescription: "Celebrating this year's ROCKS scholarship recipients and their mentors.",
            category: "scholarship",
            imageName: "rocksScholarship",
            registrationRequired: true,
            attendeeCount: 210,
            attendeeNames: ["Marcus Johnson", "Jessica Williams", "Kevin Roberts", "Monica Reed"]
        )
    ]
}
