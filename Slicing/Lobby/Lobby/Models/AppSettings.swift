//
//  AppSettings.swift
//  The choices on the Settings pop-up, and the keys they are saved under on the device.
//  Any screen can read a setting with @AppStorage and the key below.
//

import Foundation

nonisolated enum AppLanguage: String, CaseIterable {
    case english
    case bahasa
}

nonisolated enum AppSettings {
    /// English or Bahasa Indonesia. (The texts are not translated yet.)
    static let languageKey = "appLanguage"
    /// How loud the background music is, from 0 (silent) to 1 (full).
    static let backgroundVolumeKey = "backgroundSoundVolume"
    /// How loud the sound effects are, from 0 (silent) to 1 (full).
    static let soundEffectsVolumeKey = "soundEffectsVolume"
    /// Whether the player wears an eye patch. Testing option: turn it off to play
    /// with both eyes open (for example a child without amblyopia). The games then
    /// skip the "one eye only" patch check.
    static let wearsEyePatchKey = "wearsEyePatch"
    /// Testing option: when on, only Whack a Mole can be played. The other games
    /// show a lock on the Game Map and are never picked.
    // Use a fresh key now that all three games are playable. Older installs saved
    // `gamesLocked = true` as the default while the other games were placeholders.
    static let gamesLockedKey = "gamesLockedAfterIntegration"
}
