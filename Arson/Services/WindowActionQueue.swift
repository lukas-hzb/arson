import Foundation

/// Preserves submission order across suspension points, including animations.
@MainActor
final class WindowActionQueue {
    private var tail: Task<Void, Never>?
    private var tasks: [UUID: Task<Void, Never>] = [:]

    @discardableResult
    func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let id = UUID()
        let previous = tail
        let task = Task { @MainActor [weak self] in
            defer {
                self?.tasks[id] = nil
                if self?.tasks.isEmpty == true {
                    self?.tail = nil
                }
            }
            await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
        }
        tasks[id] = task
        tail = task
        return task
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
    }
}
