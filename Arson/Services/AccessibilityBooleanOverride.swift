import ApplicationServices

/// Owns restoration of a best-effort AX boolean override. Some AppKit setters
/// change the attribute and still return `.notImplemented`; an error is not a
/// guarantee that the target's state was left untouched.
struct AccessibilityBooleanOverride {
    private let originalValue: Bool?
    let writeError: AXError?

    init(
        originalValue: Bool?,
        temporaryValue: Bool,
        write: (Bool) -> AXError
    ) {
        guard let originalValue, originalValue != temporaryValue else {
            self.originalValue = nil
            writeError = nil
            return
        }
        // Record restoration before attempting the write, including timeout and
        // error paths where the target may already have applied the new value.
        self.originalValue = originalValue
        writeError = write(temporaryValue)
    }

    @discardableResult
    func restore(write: (Bool) -> AXError) -> AXError? {
        guard let originalValue else { return nil }
        return write(originalValue)
    }
}
