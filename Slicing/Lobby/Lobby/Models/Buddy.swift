//
//  Buddy.swift
//  The app's one character (fixed for now).
//

import Foundation

nonisolated enum Buddy {
    /// Name shown before the child picks their own.
    static let defaultName = "Kiko"

    /// Asset-catalog image name of the character.
    static let imageName = "Image"

    /// Key used to save the child's chosen name on the device.
    static let nameStorageKey = "buddyName"

    /// Keeps the name short enough to fit the name plate.
    static let maxNameLength = 12
}
