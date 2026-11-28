// T-1602：生产计时状态机使用可控等待，验证取消、前后台和旧任务隔离，不改系统休眠。
import Foundation

@MainActor
enum ScreenAwakeSampleSelfTest {
    final class Waits {
        var durations: [Duration] = []
        var pending: [CheckedContinuation<Void, Never>] = []
        func sleep(_ duration: Duration) async {
            durations.append(duration)
            await withCheckedContinuation { pending.append($0) }
        }
        func finishFirst() { if !pending.isEmpty { pending.removeFirst().resume() } }
        func waitForPending() async { while pending.isEmpty { await Task.yield() } }
    }

    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.ScreenAwake." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReadingSettings(defaults: defaults)
        let waits = Waits()
        var disabled = false
        settings.setScreenIdleTimerDisabled = { disabled = $0 }
        settings.waitForScreenAwakeExpiration = { await waits.sleep($0) }
        settings.screenAwake = .fiveMinutes
        emit("awake_inactive_setting_does_not_apply", ["false", "true"],
            [String(disabled), String(settings.screenAwakeExpirationTask == nil)])
        settings.refreshScreenAwakeSettingForActiveApp()
        await waits.waitForPending()
        emit("awake_five_minutes_scheduled", ["true", "true"],
            [String(disabled), String(waits.durations == [.seconds(300)])])
        let first = settings.screenAwakeExpirationTask
        settings.screenAwake = .never
        waits.finishFirst()
        await first?.value
        emit("awake_old_task_cannot_disable_never", ["true", "true"],
            [String(disabled), String(settings.screenAwakeExpirationTask == nil)])
        settings.screenAwake = .tenMinutes
        await waits.waitForPending()
        let timed = settings.screenAwakeExpirationTask
        waits.finishFirst()
        await timed?.value
        emit("awake_expiration_releases_system", ["false", "true", "true"],
            [String(disabled), String(settings.screenAwakeExpirationTask == nil), String(waits.durations.last == .seconds(600))])
        settings.screenAwake = .thirtyMinutes
        await waits.waitForPending()
        let inactive = settings.screenAwakeExpirationTask
        settings.suspendScreenAwakeSettingForInactiveApp()
        waits.finishFirst()
        await inactive?.value
        emit("awake_inactive_cancels_timer", ["false", "false", "true"],
            [String(disabled), String(settings.screenAwakeApplicationActive), String(settings.screenAwakeExpirationTask == nil)])
        settings.refreshScreenAwakeSettingForActiveApp()
        await waits.waitForPending()
        emit("awake_foreground_restarts_selected_duration", ["true", "true"],
            [String(disabled), String(waits.durations.last == .seconds(1800))])
        let resumed = settings.screenAwakeExpirationTask
        settings.screenAwake = .system
        waits.finishFirst()
        await resumed?.value
        emit("awake_system_cancels_and_releases", ["false", "true"],
            [String(disabled), String(settings.screenAwakeExpirationTask == nil)])
        settings.suspendScreenAwakeSettingForInactiveApp()
    }
}
