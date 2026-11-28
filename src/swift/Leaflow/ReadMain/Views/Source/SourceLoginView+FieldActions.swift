// 原路径: ReadMain/Views/Source/SourceLoginView.swift
// 0x100c8e634：输入动作600毫秒防抖；同字段替换与关闭页面均取消旧任务。
import Foundation

@MainActor
final class LoginFieldActionScheduler {
    private var pending: [String: (UUID, Task<Void, Never>)] = [:]
    private let wait: () async throws -> Void

    init(wait: @escaping () async throws -> Void = { try await Task.sleep(nanoseconds: 600_000_000) }) {
        self.wait = wait
    }

    @discardableResult
    func schedule(key: String, debounced: Bool, action: @escaping () -> Void) -> Task<Void, Never> {
        pending[key]?.1.cancel()
        let id = UUID()
        let wait = wait
        let task = Task { [weak self] in
            if debounced {
                do { try await wait() } catch { return }
            }
            guard !Task.isCancelled, let self, self.pending[key]?.0 == id else { return }
            self.pending.removeValue(forKey: key)
            action()
        }
        pending[key] = (id, task)
        return task
    }

    func cancelAll() {
        for (_, task) in pending.values { task.cancel() }
        pending.removeAll()
    }
}
