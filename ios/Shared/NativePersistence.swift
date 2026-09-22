import Foundation
import Darwin

protocol NativePersistence: AnyObject {
  func object(forKey key: String) throws -> Any?
  func set(_ value: Any?, forKey key: String) throws
}

final class DefaultsNativePersistence: NativePersistence {
  let defaults: UserDefaults
  init(_ defaults: UserDefaults) { self.defaults = defaults }
  func object(forKey key: String) throws -> Any? { defaults.object(forKey: key) }
  func set(_ value: Any?, forKey key: String) throws {
    if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
  }
}

/// A nonblocking, process-held lock. Closing the descriptor (including process death)
/// releases it. Never wait for a suspended app while executing a widget intent.
final class NativeFileLease {
  private let descriptor: Int32
  init(url: URL) throws {
    descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw SharedNativePersistence.storageFailure }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      close(descriptor)
      throw RestrictionFailure(code: "busy", message: "Finish the current Unbound action and try again.")
    }
  }
  deinit { flock(descriptor, LOCK_UN); close(descriptor) }
}

/// Access through the coordinator's transaction lock. Every read sees the file;
/// there is no process-local preference cache or second copy of the tokens.
final class SharedNativePersistence: NativePersistence {
  static let group = "group.com.tyleryates.takeback"
  static let intentKey = "takeback.ios.lockdownRequested.v1"
  static let pendingClearKey = "takeback.ios.clearPending.v1"
  static let migrationKey = "takeback.ios.sharedMigration.v1"
  static let verifiedAuthorizationKey = "takeback.ios.verifiedAuthorization.v1"
  static var storageFailure: RestrictionFailure {
    RestrictionFailure(code: "shared_storage_unavailable", message: "Could not access Unbound’s shared state. You can still retry UNLOCK.")
  }
  private let container: () -> URL?
  // Injectable for interrupted/failed-write tests.
  private let writeData: (Data, URL) throws -> Void

  init(container: @escaping () -> URL? = {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }, writeData: @escaping (Data, URL) throws -> Void = { data, url in
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }) {
    self.container = container
    self.writeData = writeData
  }

  private func directory() throws -> URL {
    guard let root = container() else { throw Self.storageFailure }
    let directory = root.appendingPathComponent("takeback-native", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
  private func stateURL() throws -> URL { try directory().appendingPathComponent("state-v1.plist") }
  func lease(_ name: String) throws -> NativeFileLease {
    try NativeFileLease(url: directory().appendingPathComponent(name + ".lock"))
  }
  func transaction<T>(_ body: () throws -> T) throws -> T {
    let lease = try lease("transaction")
    return try withExtendedLifetime(lease) { try body() }
  }
  private func read() throws -> [String: Any]? {
    let url = try stateURL()
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any],
          values[Self.migrationKey] as? Int == 1 else { throw Self.storageFailure }
    return values
  }
  private func write(_ values: [String: Any]) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
    let url = try stateURL()
    try writeData(data, url)
    guard try Data(contentsOf: url) == data else { throw Self.storageFailure }
  }
  func requireInitialized() throws {
    guard try read() != nil else {
      throw RestrictionFailure(code: "setup_required", message: "Open Unbound once to finish shared setup.")
    }
  }
  func object(forKey key: String) throws -> Any? {
    try requireInitialized()
    return try read()?[key]
  }
  func set(_ value: Any?, forKey key: String) throws {
    guard var values = try read() else {
      throw RestrictionFailure(code: "setup_required", message: "Open Unbound once to finish shared setup.")
    }
    if let value { values[key] = value } else { values.removeValue(forKey: key) }
    try write(values)
  }

  /// Called by Runner only, under the transaction lock, before reconciliation.
  func migrate(from legacy: UserDefaults) throws {
    if try read() == nil {
      var values: [String: Any] = [Self.migrationKey: 1]
      if let data = legacy.data(forKey: AllowedAppsStore.selectionKey),
         (try? AllowedAppsStore.decode(data)) != nil {
        values[AllowedAppsStore.selectionKey] = data
      }
      if legacy.bool(forKey: Self.intentKey) { values[Self.intentKey] = true }
      if legacy.bool(forKey: Self.pendingClearKey) { values[Self.pendingClearKey] = true }
      try write(values)
    }
    // A committed marker always wins, even if the process died before deletion.
    legacy.removeObject(forKey: AllowedAppsStore.selectionKey)
    legacy.removeObject(forKey: Self.intentKey)
    legacy.removeObject(forKey: Self.pendingClearKey)
  }
}
