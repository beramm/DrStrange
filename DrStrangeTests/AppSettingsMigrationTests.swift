import XCTest
@testable import DrStrange

final class AppSettingsMigrationTests: XCTestCase {
    func testLanguagesMapToBundledLocalizationIdentifiers() {
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.bahasa.localeIdentifier, "id")
    }

    func testIndonesianSettingsTranslationIsBundled() throws {
        let localizationPath = try XCTUnwrap(
            Bundle.main.path(
                forResource: AppLanguage.bahasa.localeIdentifier,
                ofType: "lproj"
            )
        )
        let localizationBundle = try XCTUnwrap(Bundle(path: localizationPath))
        let translation = localizationBundle.localizedString(
            forKey: "Settings",
            value: nil,
            table: "Localizable"
        )

        XCTAssertEqual(translation, "Pengaturan")
    }

    func testLegacyBackgroundSoundOffMigratesToMutedVolume() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "backgroundSoundOn")

        let volume = AppSettings.migratedBackgroundVolume(defaults: defaults)

        XCTAssertEqual(volume, 0)
        XCTAssertEqual(defaults.double(forKey: AppSettings.backgroundVolumeKey), 0)
    }

    func testLegacyBackgroundSoundOnMigratesToFullVolume() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "backgroundSoundOn")

        let volume = AppSettings.migratedBackgroundVolume(defaults: defaults)

        XCTAssertEqual(volume, 1)
        XCTAssertEqual(defaults.double(forKey: AppSettings.backgroundVolumeKey), 1)
    }

    func testExistingVolumeTakesPrecedenceOverLegacySetting() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "backgroundSoundOn")
        defaults.set(0.35, forKey: AppSettings.backgroundVolumeKey)

        let volume = AppSettings.migratedBackgroundVolume(defaults: defaults)

        XCTAssertEqual(volume, 0.35, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: AppSettings.backgroundVolumeKey), 0.35, accuracy: 0.001)
    }

    func testGlobalEyePatchChoiceOverridesOldGameSetting() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: AppSettings.wearsEyePatchKey)

        XCTAssertFalse(AppSettings.wearsEyePatch(defaults: defaults, fallback: true))
    }

    func testOldGameEyePatchChoiceIsUsedUntilGlobalChoiceIsSaved() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(AppSettings.wearsEyePatch(defaults: defaults, fallback: false))
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "AppSettingsMigrationTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
}
