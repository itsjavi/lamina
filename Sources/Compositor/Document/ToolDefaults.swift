import Foundation

/// Toggles that belong to the person rather than to a document: Auto Select, the transform box,
/// rulers, guides, the grid (and its spacing and look), the snapping switches and the brushes (`BrushDefaults`).
/// They keep whatever they were last set to, across tabs and across launches, the way Photoshop's tool options do.
///
/// Tests get the compiled defaults instead, so one test flipping a switch can't reach another —
/// or the app the person is actually using. They run in `swift test`'s tool, never in an app bundle.
nonisolated enum ToolDefaults {
    private static let prefix = "tool."
    private static let isTesting = Bundle.main.bundleURL.pathExtension != "app"
    /// Where the settings live: the app's defaults, or nowhere under `swift test`. A test that needs to see them
    /// saved and read back passes a store of its own.
    static var store: (any ToolDefaultsStore)? { isTesting ? nil : UserDefaults.standard }

    static func bool(_ key: String, _ fallback: Bool, in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> Bool {
        store?.object(forKey: prefix + key) as? Bool ?? fallback
    }

    static func set(_ value: Bool, _ key: String, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        store?.set(value, forKey: prefix + key)
    }

    static func int(_ key: String, _ fallback: Int, in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> Int {
        store?.object(forKey: prefix + key) as? Int ?? fallback
    }

    static func set(_ value: Int, _ key: String, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        store?.set(value, forKey: prefix + key)
    }

    static func double(_ key: String, _ fallback: Double, in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> Double {
        store?.object(forKey: prefix + key) as? Double ?? fallback
    }

    static func set(_ value: Double, _ key: String, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        store?.set(value, forKey: prefix + key)
    }

    static func string(_ key: String, _ fallback: String, in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> String {
        store?.object(forKey: prefix + key) as? String ?? fallback
    }

    static func set(_ value: String, _ key: String, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        store?.set(value, forKey: prefix + key)
    }
}

/// What `ToolDefaults` reads and writes: `UserDefaults`, or a test's own store.
nonisolated protocol ToolDefaultsStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: ToolDefaultsStore {}
