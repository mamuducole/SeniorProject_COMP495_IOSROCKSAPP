import Foundation

struct Chapter: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let city: String?
    let state: String?
    let description: String
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool
    let mailingAddress: String?
    let contactPerson: String?
    let email: String?
    let website: URL?
    let installation: String?

    init(
        id: UUID,
        name: String,
        city: String?,
        state: String?,
        description: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isActive: Bool = true,
        mailingAddress: String? = nil,
        contactPerson: String? = nil,
        email: String? = nil,
        website: URL? = nil,
        installation: String? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.isActive = isActive
        self.mailingAddress = mailingAddress
        self.contactPerson = contactPerson
        self.email = email
        self.website = website
        self.installation = installation
    }

    var locationLabel: String {
        let trimmedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedState = state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch (trimmedCity.isEmpty, trimmedState.isEmpty) {
        case (false, false): return "\(trimmedCity), \(trimmedState)"
        case (false, true): return trimmedCity
        case (true, false): return trimmedState
        case (true, true): return "Location not available"
        }
    }

    func matches(searchText: String) -> Bool {
        let query = Self.normalizedSearchText(searchText)
        guard !query.isEmpty else { return true }

        let searchableFields = [
            name,
            locationLabel,
            city ?? "",
            state ?? "",
            installation ?? "",
            description
        ]
        return searchableFields.contains {
            Self.normalizedSearchText($0).localizedCaseInsensitiveContains(query)
        }
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    var hasVerifiedCoordinates: Bool {
        guard let latitude, let longitude else { return false }
        return (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    var coordinate: (latitude: Double, longitude: Double)? {
        guard hasVerifiedCoordinates, let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }

    var normalizedName: String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    var directoryMatchKey: String {
        switch normalizedName {
        case "alamorocksftsamhoustontx": return "alamorocks"
        case "allamericanchapterrocksfortlibertync": return "allamericanchapterrocks"
        case "alohachapteroftherocksoahuhi": return "alohachapteroftherocks"
        case "buffalosoldierrocksfortleavenworthks": return "buffalosoldierrocks"
        case "fortdrumnyclimbtogloryrocks": return "climbtogloryrocks"
        case "forthuachucarocks", "forthuachucaaz": return "forthuachucachapter"
        case "hamptonroadsrocksva": return "hamptonroadsrocks"
        case "henryoflipperrockswestpointny": return "henryoflipperrocks"
        case "jblmrainierrocks", "jblmrainierrocksftlewismcchordwa": return "jblmrainerrocks"
        case "mgcharlesrogersrocksawc", "mgcharlesrogersrocksawccarlislebarracks": return "mgcharlesrogersrocks"
        case "phantomwarriorsrocksfortcavazostx": return "phantomwarriorsrocks"
        case "washingtondc": return "washingtondcchapter"
        default: return normalizedName
        }
    }

    var emailActionURL: URL? {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty,
              !email.contains(where: \.isWhitespace) else { return nil }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix(".") else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        return components.url
    }

    var websiteActionURL: URL? {
        guard let website,
              website.scheme?.lowercased() == "https",
              let host = website.host,
              !host.isEmpty else { return nil }
        return website
    }

    var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if let coordinate {
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")
            ]
        } else {
            let cityName = city?.trimmingCharacters(in: .whitespacesAndNewlines)
            let installationName = installation?.trimmingCharacters(in: .whitespacesAndNewlines)
            let place = cityName.flatMap { $0.isEmpty ? nil : $0 } ?? installationName
            guard let place, !place.isEmpty else {
                return nil
            }
            let cityState = [Optional(place), state]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            components?.queryItems = [URLQueryItem(name: "q", value: cityState)]
        }
        return components?.url
    }

    var isInterestGroup: Bool {
        name.localizedCaseInsensitiveContains("interest group")
    }

    static let requestedChapterNames: Set<String> = [
        "Washington D.C. Chapter",
        "Phantom Warriors ROCKS",
        "Hampton Roads ROCKS",
        "Hampton University ROCKS",
        "JBLM Rainer ROCKS",
        "Fort Huachuca chapter",
        "Alamo ROCKS",
        "All American Chapter ROCKS",
        "MG Charles Rogers ROCKS",
        "Climb to Glory ROCKS",
        "Henry O. Flipper ROCKS",
        "Aloha Chapter of the ROCKS",
        "Buffalo Soldier ROCKS"
    ]

    static var requestedChapters: [Chapter] {
        examples.filter { requestedChapterNames.contains($0.name) }
    }

    static let examples: [Chapter] = {
        func chapter(
            _ suffix: Int,
            _ name: String,
            _ city: String?,
            _ state: String?,
            installation: String? = nil,
            mailingAddress: String? = nil,
            contactPerson: String? = nil,
            email: String? = nil,
            website: String? = nil,
            description: String = "Listed on the official ROCKS, Inc. chapter finder."
        ) -> Chapter {
            Chapter(
                id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", suffix)) ?? UUID(),
                name: name,
                city: city,
                state: state,
                description: description,
                mailingAddress: mailingAddress,
                contactPerson: contactPerson,
                email: email,
                website: website.flatMap(URL.init(string:)),
                installation: installation
            )
        }

        return [
            chapter(1, "Alamo ROCKS", "Fort Sam Houston", "TX", installation: "Fort Sam Houston", mailingAddress: "PO BOX 340378\nFort Sam Houston, TX 78234"),
            chapter(2, "All American Chapter ROCKS", nil, "NC", installation: "Fort Liberty", mailingAddress: "Post Office Box 73233\nFort Bragg, NC 28310"),
            chapter(3, "Aloha Chapter of the ROCKS", nil, "HI", mailingAddress: "P.O. Box 30797\nHonolulu, HI 96820", description: "The official chapter finder lists the chapter in Oahu, HI."),
            chapter(4, "Buffalo Soldier ROCKS", "Fort Leavenworth", "KS", installation: "Fort Leavenworth", mailingAddress: "P.O. Box 3122\nFort Leavenworth, KS 66027", website: "https://www.rocksinc.org/"),
            chapter(5, "Central Virginia ROCKS", "Fort Gregg-Adams", "VA", installation: "Fort Gregg-Adams"),
            chapter(6, "El Paso ROCKS", "Fort Bliss", "TX", installation: "Fort Bliss"),
            chapter(7, "Follow Me ROCKS", "Fort Benning", "GA", installation: "Fort Benning"),
            chapter(8, "Climb to Glory ROCKS", nil, "NY", installation: "Fort Drum"),
            chapter(9, "Fort Huachuca chapter", nil, "AZ", installation: "Fort Huachuca"),
            chapter(10, "Fort Riley ROCKS", "Fort Riley", "KS", installation: "Fort Riley"),
            chapter(11, "Gator ROCKS", "Fort Polk", "LA", installation: "Fort Polk"),
            chapter(12, "Gold Vault ROCKS", "Fort Knox", "KY", installation: "Fort Knox"),
            chapter(13, "Hampton Roads ROCKS", "Hampton Roads", "VA", mailingAddress: "P.O. Box 4499\nFort Eustis, VA 23604"),
            chapter(14, "Hampton University ROCKS", nil, nil, website: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=663331&actr=4"),
            chapter(15, "Harry S. Truman ROCKS", "Fort Leonard Wood", "MO", installation: "Fort Leonard Wood"),
            chapter(16, "Henry O. Flipper ROCKS", "West Point", "NY", installation: "West Point", mailingAddress: "P.O. Box 174\nWest Point, NY 10996"),
            chapter(17, "Iron Horse ROCKS", "Fort Carson", "CO", installation: "Fort Carson"),
            chapter(18, "James Webster Smith Chapter", "Fort Jackson", "SC", installation: "Fort Jackson"),
            chapter(19, "JBLM Rainer ROCKS", nil, "WA", installation: "Joint Base Lewis-McChord"),
            chapter(20, "Marne ROCKS", "Fort Stewart", "GA", installation: "Fort Stewart"),
            chapter(21, "Masters Chapter of the ROCKS", "Fort Gordon", "GA", installation: "Fort Gordon"),
            chapter(22, "MG Charles Rogers ROCKS", nil, "PA", installation: "Carlisle Barracks"),
            chapter(23, "Patriot ROCKS", "", "GA", installation: "Georgia Army National Guard"),
            chapter(24, "Phantom Warriors ROCKS", nil, "TX", installation: "Fort Cavazos", website: "https://www.facebook.com/FortHoodPhantomWarriorROCKS/", description: "The official chapter finder lists Fort Cavazos, TX; the contact card still displays the legacy location name Fort Hood, TX."),
            chapter(25, "Screaming Eagles ROCKS", "Fort Campbell", "KY", installation: "Fort Campbell"),
            chapter(26, "Washington D.C. Chapter", "Washington", "DC", mailingAddress: "c/o WSC Associates, LLP\nP.O. Box 47435\nForestville, MD 20753", website: "https://therocksdc.org/", description: "The official chapter website states the chapter mission is mentoring and networking to strengthen the U.S. Armed Forces officer corps."),
            chapter(27, "Interest Group: Balad, Iraq", "Balad", ""),
            chapter(28, "Interest Group: Tampa, FL ROCKS", "Tampa", "FL"),
            chapter(29, "Interest Group: California National Guard", "", "CA", installation: "California National Guard"),
            chapter(30, "Interest Group: Camp Victory, Iraq", "Camp Victory", ""),
            chapter(31, "Interest Group: Chesapeake Bay ROCKS (CBRIG)", "Chesapeake Bay", "MD"),
            chapter(32, "Interest Group: Coraopolis, PA", "Coraopolis", "PA"),
            chapter(33, "Interest Group: Ultimate Weapon ROCKS", "Fort Dix", "NJ", installation: "Fort Dix"),
            chapter(34, "Interest Group: High Desert ROCKS", "Fort Irwin", "CA", installation: "Fort Irwin"),
            chapter(35, "Interest Group: Fort Riley, KS", "Fort Riley", "KS", installation: "Fort Riley"),
            chapter(36, "Interest Group: Fort Sill, OK", "Fort Sill", "OK", installation: "Fort Sill"),
            chapter(37, "Interest Group: Germany ROCKS", "", "", installation: "Germany"),
            chapter(38, "Interest Group: Honshu, Japan ROCKS (Rising Sun)", "Honshu", "", installation: "Japan"),
            chapter(39, "Interest Group: Mississippi National Guard", "", "MS", installation: "Mississippi National Guard"),
            chapter(40, "Interest Group: Rock Island Arsenal, IL", "Rock Island Arsenal", "IL", installation: "Rock Island Arsenal"),
            chapter(41, "Interest Group: Kuwait", "", "", installation: "Kuwait"),
            chapter(42, "Interest Group: Saudi Arabia", "", "", installation: "Saudi Arabia"),
            chapter(43, "Interest Group: South Korea Morning Calm", "", "", installation: "South Korea"),
            chapter(44, "Interest Group: Virginia Military Institute", "Lexington", "VA", installation: "Virginia Military Institute"),
            chapter(45, "Interest Group: Wiesbaden Europe", "Wiesbaden", "", installation: "Germany")
        ]
    }()
}
