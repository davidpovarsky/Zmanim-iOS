import Foundation
import os

public enum AppGroupHandshakeStatus: Sendable, Equatable {
    case pass(ackTimestamp: Date)
    case pending(reason: String)
    case storeUnavailable
    case containerUnavailable
    case nonceMismatch(expected: String, got: String)
}

public enum AppGroupDiagnostics {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim", category: "AppGroupDiagnostics")

    private static let nonceKey = "app_group_handshake_nonce"
    private static let writeTimeKey = "app_group_handshake_write_timestamp"
    private static let schemaKey = "app_group_handshake_schema"
    private static let ackNonceKey = "app_group_handshake_ack_nonce"
    private static let ackTimeKey = "app_group_handshake_ack_timestamp"
    private static let ackProcessKey = "app_group_handshake_ack_process"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStore.groupID)
    }

    /// Evaluates filesystem container availability for the App Group.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupStore.groupID)
    }

    /// App-side: initiates or updates the diagnostics handshake by writing an insensitive UUID nonce.
    @discardableResult
    public static func initiateAppHandshake(nonce: String = UUID().uuidString) -> Bool {
        guard let defaults else {
            logger.error("app.write: Shared UserDefaults suite unavailable")
            return false
        }

        defaults.set(nonce, forKey: nonceKey)
        defaults.set(Date().timeIntervalSince1970, forKey: writeTimeKey)
        defaults.set(1, forKey: schemaKey)

        logger.info("app.write: Handshake initiated with schema 1")
        return true
    }

    /// Widget-side: called during widget timeline execution or entity query to ACK the active nonce.
    @discardableResult
    public static func recordWidgetAck(processName: String = "widget") -> Bool {
        guard let defaults else {
            logger.error("widget.read: Shared UserDefaults suite unavailable")
            return false
        }

        guard let activeNonce = defaults.string(forKey: nonceKey), !activeNonce.isEmpty else {
            logger.debug("widget.read: No active app handshake nonce found")
            return false
        }

        defaults.set(activeNonce, forKey: ackNonceKey)
        defaults.set(Date().timeIntervalSince1970, forKey: ackTimeKey)
        defaults.set(processName, forKey: ackProcessKey)

        logger.info("widget.ack: Acknowledged active app nonce")
        return true
    }

    /// App-side: verifies whether the widget extension has acknowledged the written nonce.
    public static func verifyHandshake() -> AppGroupHandshakeStatus {
        guard containerURL != nil else {
            logger.error("app.verify: Container URL for App Group is nil")
            return .containerUnavailable
        }

        guard let defaults else {
            logger.error("app.verify: Shared UserDefaults suite unavailable")
            return .storeUnavailable
        }

        guard let expectedNonce = defaults.string(forKey: nonceKey), !expectedNonce.isEmpty else {
            return .pending(reason: "No active handshake written")
        }

        guard let ackNonce = defaults.string(forKey: ackNonceKey), !ackNonce.isEmpty else {
            logger.debug("app.verify: Widget ACK pending (waiting for widget timeline execution)")
            return .pending(reason: "Waiting for widget execution")
        }

        if ackNonce == expectedNonce {
            let timestamp = defaults.double(forKey: ackTimeKey)
            let ackDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date()
            logger.info("app.verify: Handshake verified successfully (PASS)")
            return .pass(ackTimestamp: ackDate)
        } else {
            logger.warning("app.verify: Handshake nonce mismatch")
            return .nonceMismatch(expected: expectedNonce, got: ackNonce)
        }
    }
}
