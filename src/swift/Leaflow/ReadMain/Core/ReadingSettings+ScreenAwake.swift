// 原路径: ReadMain/Core/ReadingSettings.swift
// 类型表3504与0x10021fcd4/0x10022008c：单任务取消、系统常亮、时限到达后释放。
import UIKit

extension ReadingSettings {
    // 系统休眠是应用级状态；只有这一实例接收应用生命周期，编辑/备份实例不争抢系统开关。
    static let screenAwakeRuntime = ReadingSettings.load()

    func refreshScreenAwakeSettingForActiveApp() {
        screenAwakeApplicationActive = true
        applyScreenAwakeSetting()
    }

    func suspendScreenAwakeSettingForInactiveApp() {
        screenAwakeApplicationActive = false
        screenAwakeGeneration += 1
        screenAwakeExpirationTask?.cancel()
        screenAwakeExpirationTask = nil
        setScreenIdleTimerDisabled(false)
    }

    func applyScreenAwakeSetting() {
        screenAwakeGeneration += 1
        let generation = screenAwakeGeneration
        screenAwakeExpirationTask?.cancel()
        screenAwakeExpirationTask = nil
        guard screenAwakeApplicationActive, screenAwake != .system else {
            setScreenIdleTimerDisabled(false)
            return
        }
        setScreenIdleTimerDisabled(true)
        guard let duration = screenAwake.duration else { return }
        let wait = waitForScreenAwakeExpiration
        screenAwakeExpirationTask = Task { [weak self] in
            do { try await wait(duration) }
            catch { return }
            guard !Task.isCancelled, let self, self.screenAwakeApplicationActive,
                  self.screenAwakeGeneration == generation else { return }
            self.screenAwakeExpirationTask = nil
            self.setScreenIdleTimerDisabled(false)
        }
    }

    static func synchronizeScreenAwakePreference() {
        let runtime = screenAwakeRuntime
        let saved = loadScreenAwakeOption(from: .standard)
        if runtime.screenAwake != saved { runtime.screenAwake = saved }
    }
}
