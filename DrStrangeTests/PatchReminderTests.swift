import UIKit
import XCTest
@testable import DrStrange

final class PatchReminderTests: XCTestCase {
    func testUsesTheCharacterSelectStorageKey() {
        XCTAssertEqual(PatchReminderCharacter.storageKey, GameCharacter.storageKey)
    }

    func testEveryLobbyCharacterHasPatchFrames() {
        for character in GameCharacter.all {
            let reminder = PatchReminderCharacter(rawValue: character.id)
            XCTAssertNotNil(reminder, character.id)
            for isOn in [true, false] {
                let name = reminder?.frame(patchOn: isOn) ?? ""
                XCTAssertNotNil(UIImage(named: name), name)
            }
        }
    }

    func testSelectedCharacterComesFromSavedChoiceWithFoxFallback() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PatchReminderTests"))
        defaults.removePersistentDomain(forName: "PatchReminderTests")
        XCTAssertEqual(PatchReminderCharacter.selected(in: defaults), .fox)
        defaults.set("raccoon", forKey: PatchReminderCharacter.storageKey)
        XCTAssertEqual(PatchReminderCharacter.selected(in: defaults), .raccoon)
        defaults.set("unknown", forKey: PatchReminderCharacter.storageKey)
        XCTAssertEqual(PatchReminderCharacter.selected(in: defaults), .fox)
        defaults.removePersistentDomain(forName: "PatchReminderTests")
    }
}
