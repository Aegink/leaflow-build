"""从 CI 原始日志生成 T-1602 构建/逐名样本证据，缺项返回非零。

输入：当前 Swift 源码、两种 xcodebuild 日志、自测、三入口冒烟日志。
输出：last_build.json / last_selftest.json，禁止手工补通过数。
"""
import argparse
import json
import os
import re
import runpy
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECKS = runpy.run_path(str(ROOT / "tools" / "restoration_gate_checks.py"))
UI_SMOKE_NAMES = {"bookshelf_card_read_dismissal", "bookshelf_grid_editing",
                  "bookshelf_edit_cover_entries", "bookshelf_delete_confirmation",
                  "tts_rendered_skins", "tts_large_text_scroll"}


def record(root: Path, source: Path, run_id: str, sha: str, require_ui_smoke: bool = False) -> int:
    def read(name):
        path = root / name
        return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""

    logs = [read("build.log"), read("device-build.log")]
    exits = [re.findall(r"xcodebuild exit: (\d+)", log) for log in logs]
    build_ok = all(values and values[-1] == "0" and "BUILD SUCCEEDED" in log
                   for values, log in zip(exits, logs))
    errors = sum(len(re.findall(r": error:", log)) for log in logs)
    errors = max(errors, int(not build_ok))
    selftest = read("selftest.log")
    passed = sorted(set(re.findall(r"SELFTEST (\S+) pass=true", selftest)))
    failed = sorted(set(re.findall(r"SELFTEST (\S+) pass=false", selftest)))
    declared = set()
    for path in source.rglob("*SelfTest.swift"):
        text = path.read_text(encoding="utf-8")
        declared.update(re.findall(r'(?:Sample\(\s*name:|emit\(\s*(?:name:)?)\s*"([^"]+)"', text))
    all_pass = bool(declared) and set(passed) == declared and not failed and "SELFTEST_END" in selftest
    smoke = read("smoke-result.txt")
    smoke_pass = sum(re.search(rf"^{key}=1$", smoke, re.M) is not None
                     for key in ("alive", "sources_alive", "bookshelf_alive"))
    crashes = re.findall(r"^crash_reports=(\d+)$", smoke, re.M)
    crash_count = int(crashes[-1]) if crashes else None
    ui_log = read("ui-smoke.log")
    ui_passed = sorted(set(re.findall(r"SMOKE_UI (\S+) pass=true", ui_log)))
    ui_exits = re.findall(r"^ui_test_exit=(\d+)$", read("ui-smoke-result.txt"), re.M)
    ui_ok = (bool(ui_exits) and ui_exits[-1] == "0" and set(ui_passed) == UI_SMOKE_NAMES)
    if require_ui_smoke and not ui_ok:
        errors = max(errors, 1)
    digest = CHECKS["source_digest"](source)
    build = dict(run_id=run_id, head_sha=sha, source_digest=digest, errors=errors,
                 simulator_exit=exits[0][-1] if exits[0] else None,
                 device_exit=exits[1][-1] if exits[1] else None,
                 selftest_pass=len(passed), selftest_fail=len(failed) if all_pass else max(1, len(failed)),
                 smoke_pass=smoke_pass, crash_count=crash_count,
                 recorded_at=datetime.now(timezone.utc).isoformat())
    if require_ui_smoke:
        build.update(ui_smoke_required=True, ui_smoke_pass=ui_ok, ui_passed=ui_passed,
                     ui_test_exit=ui_exits[-1] if ui_exits else None)
    samples = dict(run_id=run_id, source_digest=digest, unique_samples=len(passed),
                   passed_samples=passed, failed_samples=failed,
                   pass_lines=len(re.findall(r"SELFTEST \S+ pass=true", selftest)),
                   fail_lines=len(re.findall(r"SELFTEST \S+ pass=false", selftest)), all_pass=all_pass)
    for name, data in (("last_build.json", build), ("last_selftest.json", samples)):
        (root / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ok = errors == 0 and all_pass and smoke_pass == 3 and crash_count == 0
    print(f"构建证据：errors={errors}，逐名样本={len(passed)}/{len(declared)}，冒烟={smoke_pass}/3，崩溃={crash_count}")
    return 0 if ok else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts", type=Path, default=ROOT)
    parser.add_argument("--source", type=Path, default=ROOT / "src/swift/Leaflow")
    parser.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", ""))
    parser.add_argument("--head-sha", default=os.environ.get("GITHUB_SHA", ""))
    parser.add_argument("--require-ui-smoke", action="store_true")
    args = parser.parse_args()
    if not args.run_id or not args.head_sha:
        parser.error("必须提供可追溯的 run-id 和 head-sha")
    raise SystemExit(record(args.artifacts, args.source, args.run_id, args.head_sha, args.require_ui_smoke))
