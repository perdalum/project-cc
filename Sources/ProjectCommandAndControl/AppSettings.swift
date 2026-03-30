import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let persistentStoragePathKey = "persistentStoragePath"

    static var defaultPersistentStorageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("ProjectCommandAndControl")
        return folder.appendingPathComponent("projects.json")
    }

    @Published var persistentStoragePath: String {
        didSet {
            if persistentStoragePath.isEmpty {
                defaults.removeObject(forKey: Self.persistentStoragePathKey)
            } else {
                defaults.set(persistentStoragePath, forKey: Self.persistentStoragePathKey)
            }
        }
    }

    var persistentStorageURL: URL {
        if persistentStoragePath.isEmpty {
            Self.defaultPersistentStorageURL
        } else {
            URL(fileURLWithPath: persistentStoragePath)
        }
    }

    var usesDefaultPersistentStorage: Bool {
        persistentStoragePath.isEmpty
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.persistentStoragePath = defaults.string(forKey: Self.persistentStoragePathKey) ?? ""
    }

    func setPersistentStorageURL(_ url: URL) {
        persistentStoragePath = url.path
    }

    func useDefaultPersistentStorage() {
        persistentStoragePath = ""
    }
}
