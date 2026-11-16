//
//  AppSettings.swift
//  The choices on the Setting pop-up, and the keys they are saved under on the device.
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
    /// Background music on or off.
    static let backgroundSoundKey = "backgroundSoundOn"
    /// Sound effects on or off.
    static let soundEffectsKey = "soundEffectsOn"
    /// Whether the player wears an eye patch. Testing option: turn it off to play
    /// with both eyes open (for example a child without amblyopia). The games then
    /// skip the "one eye only" patch check.
    static let wearsEyePatchKey = "wearsEyePatch"
    /// Testing option: when on, only Whack a Mole can be played. The other games
    /// show a lock on the Game Map and are never picked.
    static let gamesLockedKey = "gamesLocked"
}
