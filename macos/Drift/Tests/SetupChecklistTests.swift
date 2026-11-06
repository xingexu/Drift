import XCTest
@testable import Drift

final class SetupChecklistTests: XCTestCase {
    private let allPermissionStates: [PermissionState] = [.granted, .denied, .notDetermined, .unknown]

    private func state(
        _ accessibility: PermissionState,
        _ automation: PermissionState,
        sessions: Int = 0,
        tracking: Bool = false
    ) -> SetupChecklistState {
        SetupChecklistState(accessibility: accessibility, automation: automation, sessionCount: sessions, isTracking: tracking)
    }

    // MARK: Named scenarios

    func testFreshInstallShowsAllSteps() {
        let s = state(.denied, .unknown)
        XCTAssertTrue(s.isNeeded)
        XCTAssertFalse(s.accessibilityDone)
        XCTAssertFalse(s.sessionDone)
        XCTAssertFalse(s.canStartSession, "tracking can't work without Accessibility")
        XCTAssertFalse(s.lostAccessibility)
        XCTAssertEqual(s.headline, "Finish setting up Drift")
    }

    func testAccessibilityGrantedOffersFirstSession() {
        let s = state(.granted, .notDetermined)
        XCTAssertTrue(s.isNeeded)
        XCTAssertTrue(s.canStartSession)
        XCTAssertEqual(s.automationAction, .none, "macOS asks on first use; nothing to click yet")
    }

    func testFullySetUpHidesChecklist() {
        XCTAssertFalse(state(.granted, .granted, sessions: 1).isNeeded)
    }

    func testTrackingCountsAsFirstSession() {
        let s = state(.granted, .granted, sessions: 0, tracking: true)
        XCTAssertTrue(s.sessionDone)
        XCTAssertFalse(s.canStartSession)
        XCTAssertFalse(s.isNeeded)
    }

    func testPermissionLostAfterRebuild() {
        let s = state(.denied, .granted, sessions: 12)
        XCTAssertTrue(s.isNeeded)
        XCTAssertTrue(s.lostAccessibility)
        XCTAssertEqual(s.headline, "Drift lost Accessibility access")
        XCTAssertTrue(s.message.contains("rebuilt"))
        XCTAssertTrue(s.sessionDone)
    }

    func testDeniedAutomationKeepsChecklistAndOffersSettings() {
        let s = state(.granted, .denied, sessions: 5)
        XCTAssertTrue(s.isNeeded)
        XCTAssertEqual(s.automationAction, .openSettings)
    }

    func testUnknownOrUnaskedAutomationDoesNotPinChecklist() {
        // No browser running / not asked yet must not be treated as "Required".
        for automation in [PermissionState.unknown, .notDetermined] {
            let s = state(.granted, automation, sessions: 3)
            XCTAssertFalse(s.isNeeded, "\(automation)")
            XCTAssertEqual(s.automationAction, .none, "\(automation)")
            XCTAssertFalse(s.automationDone, "\(automation)")
        }
    }

    func testAutomationCopyNeverSaysRequiredWhenBrowserClosed() {
        XCTAssertTrue(SetupChecklistState.automationDetail(.unknown).hasPrefix("Open Chrome"))
        XCTAssertFalse(SetupChecklistState.automationDetail(.notDetermined).contains("Turned off"))
    }

    // MARK: Exhaustive invariants over every input combination

    func testInvariantsHoldForEveryCombination() {
        for accessibility in allPermissionStates {
            for automation in allPermissionStates {
                for sessions in [0, 1, 40] {
                    for tracking in [false, true] {
                        let s = state(accessibility, automation, sessions: sessions, tracking: tracking)
                        let label = "\(accessibility)/\(automation)/\(sessions)/\(tracking)"

                        XCTAssertEqual(s.accessibilityDone, accessibility == .granted, label)
                        XCTAssertEqual(s.automationDone, automation == .granted, label)
                        XCTAssertEqual(s.sessionDone, sessions > 0 || tracking, label)
                        // Hidden only when tracking works, a session exists, and automation isn't blocked.
                        XCTAssertEqual(
                            s.isNeeded,
                            accessibility != .granted || automation == .denied || !(sessions > 0 || tracking),
                            label
                        )
                        if s.canStartSession { XCTAssertTrue(s.accessibilityDone && !s.sessionDone, label) }
                        if s.lostAccessibility { XCTAssertTrue(sessions > 0 && !s.accessibilityDone && s.isNeeded, label) }
                        XCTAssertEqual(s.automationAction == .openSettings, automation == .denied, label)
                    }
                }
            }
        }
    }
}
