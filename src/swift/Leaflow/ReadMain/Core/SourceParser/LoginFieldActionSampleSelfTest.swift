// T-1602：使用生产调度器验证连续输入替换、字段隔离、关闭取消和非防抖动作。
import Foundation

@MainActor
enum LoginFieldActionSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let waits = ScreenAwakeSampleSelfTest.Waits()
        let scheduler = LoginFieldActionScheduler(wait: { await waits.sleep(.milliseconds(600)) })
        var calls: [String] = []
        let old = scheduler.schedule(key: "account", debounced: true) { calls.append("旧值") }
        await waits.waitForPending()
        let latest = scheduler.schedule(key: "account", debounced: true) { calls.append("新值") }
        while waits.pending.count < 2 { await Task.yield() }
        waits.finishFirst()
        await old.value
        emit("login_field_debounce_cancels_previous", ["true"], [String(calls.isEmpty)])
        waits.finishFirst()
        await latest.value
        emit("login_field_debounce_runs_latest", ["新值"], [calls.joined(separator: ",")])
        calls = []
        let first = scheduler.schedule(key: "a", debounced: true) { calls.append("甲") }
        let second = scheduler.schedule(key: "b", debounced: true) { calls.append("乙") }
        while waits.pending.count < 2 { await Task.yield() }
        waits.finishFirst()
        waits.finishFirst()
        await first.value
        await second.value
        emit("login_field_different_keys_independent", ["乙,甲"], [calls.sorted().joined(separator: ",")])
        calls = []
        let cancelled = scheduler.schedule(key: "a", debounced: true) { calls.append("不应执行") }
        await waits.waitForPending()
        scheduler.cancelAll()
        waits.finishFirst()
        await cancelled.value
        emit("login_field_close_cancels_pending", ["true"], [String(calls.isEmpty)])
        let immediate = scheduler.schedule(key: "select", debounced: false) { calls.append("选择") }
        await immediate.value
        emit("login_field_selection_without_delay", ["选择", "true"],
            [calls.joined(separator: ","), String(waits.pending.isEmpty)])
    }
}
