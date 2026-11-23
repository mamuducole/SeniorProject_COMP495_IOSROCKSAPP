import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "rocksCommunityService" asset catalog image resource.
    static let rocksCommunityService = DeveloperToolsSupport.ImageResource(name: "rocksCommunityService", bundle: resourceBundle)

    /// The "rocksHeroLeadership" asset catalog image resource.
    static let rocksHeroLeadership = DeveloperToolsSupport.ImageResource(name: "rocksHeroLeadership", bundle: resourceBundle)

    /// The "rocksHomeHero" asset catalog image resource.
    static let rocksHomeHero = DeveloperToolsSupport.ImageResource(name: "rocksHomeHero", bundle: resourceBundle)

    /// The "rocksHomeMentorship" asset catalog image resource.
    static let rocksHomeMentorship = DeveloperToolsSupport.ImageResource(name: "rocksHomeMentorship", bundle: resourceBundle)

    /// The "rocksLeadership" asset catalog image resource.
    static let rocksLeadership = DeveloperToolsSupport.ImageResource(name: "rocksLeadership", bundle: resourceBundle)

    /// The "rocksLogo" asset catalog image resource.
    static let rocksLogo = DeveloperToolsSupport.ImageResource(name: "rocksLogo", bundle: resourceBundle)

    /// The "rocksMentorship" asset catalog image resource.
    static let rocksMentorship = DeveloperToolsSupport.ImageResource(name: "rocksMentorship", bundle: resourceBundle)

    /// The "rocksScholarship" asset catalog image resource.
    static let rocksScholarship = DeveloperToolsSupport.ImageResource(name: "rocksScholarship", bundle: resourceBundle)

}

