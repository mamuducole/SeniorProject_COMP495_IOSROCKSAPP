import XCTest
@testable import ROCKS

final class EventRegistrationTests: XCTestCase {
    @MainActor
    func testRegistrationCanBeAddedAndCancelled() async {
        let viewModel = EventRegistrationViewModel(service: MockEventRegistrationService())
        let event = ROCKSEvent.examples[0]

        await viewModel.toggleRegistration(for: event)
        XCTAssertTrue(viewModel.isRegistered)

        await viewModel.toggleRegistration(for: event)
        XCTAssertFalse(viewModel.isRegistered)
    }
}
