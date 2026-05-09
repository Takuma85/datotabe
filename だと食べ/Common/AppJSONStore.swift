import Foundation

enum AppJSONStore {
    static func load<T: Decodable>(
        _ type: T.Type = T.self,
        key: String,
        fallback: @autoclosure () -> T,
        defaults: UserDefaults = .standard
    ) -> T {
        guard let data = defaults.data(forKey: key) else {
            return fallback()
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode \(key):", error)
            return fallback()
        }
    }

    static func save<T: Encodable>(
        _ value: T,
        key: String,
        defaults: UserDefaults = .standard
    ) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            print("Failed to encode \(key):", error)
        }
    }

    static func remove(key: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
