"""T-1602 证据核验：缺失、过期或不完整的证据一律不能通过。

输入：源码、矩阵、构建/样本 JSON、逐文件验收记录；无写入副作用。
"""

from __future__ import annotations

import hashlib
import re
from collections import defaultdict
from pathlib import Path

STUB_MARKERS = ("待真机", "骨架", "占位", "计数器桩", "推断", "未展开", "TODO", "真机核清")


def matrix_failures(rows: list[dict], swift_root: Path) -> list[str]:
    stale = []
    for row in rows:
        path = swift_root / row["file"].replace(".c", ".swift")
        text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
        lines = text.count("\n") + 1 if path.exists() else 0
        markers = sum(text.count(marker) for marker in STUB_MARKERS)
        if lines != row["swift_lines"] or markers != row["markers"]:
            stale.append(row["file"])
    return [f"矩阵过期：{len(stale)} 个文件需重跑 verify_restoration_matrix.py"] if stale else []


def swift_code(text: str) -> str:
    """剔除注释和字面量，保留行号，不把取证注释当成入口。"""
    pattern = r'/\*.*?\*/|//[^\n]*|\#*""".*?"""\#*|\#*"(?:\\.|[^"\\])*"\#*'
    return re.sub(pattern, lambda m: "\n" * m[0].count("\n"), text, flags=re.S)


def dependency_symbols(texts: dict[str, str]) -> dict[str, str]:
    candidates: dict[str, set[str]] = defaultdict(set)
    for path, code in texts.items():
        for name in re.findall(r'\b(?:struct|class|enum|func)\s+([A-Za-z_]\w*)', code):
            candidates[name].add(path)
    return {name: next(iter(paths)) for name, paths in candidates.items()
            if len(paths) == 1 and name not in {"body", "init"}}


def source_digest(root: Path) -> str:
    digest = hashlib.sha256()
    # Windows Path 按大小写折叠排序，macOS 不折叠；统一使用相对 POSIX 路径。
    for path in sorted(root.rglob("*.swift"), key=lambda p: p.relative_to(root).as_posix()):
        digest.update(path.relative_to(root).as_posix().encode("utf-8") + b"\0")
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
        digest.update(b"\0")
    return digest.hexdigest()


def build_failures(build: dict, samples: dict, digest: str) -> list[str]:
    failures = []
    required = ("run_id", "head_sha", "source_digest", "errors", "selftest_fail",
                "smoke_pass", "crash_count")
    if not build.get("known") or any(key not in build for key in required):
        failures.append("D7 构建证据不完整（需源码指纹、三入口冒烟和崩溃计数）")
    if build.get("source_digest") != digest:
        failures.append("D7 构建证据与当前源码不一致")
    if build.get("errors") != 0 or build.get("selftest_fail") != 0:
        failures.append("D7 构建或样本存在错误/结果未知")
    if build.get("smoke_pass") != 3 or build.get("crash_count") != 0:
        failures.append("D7 三入口冒烟未通过或存在崩溃/结果未知")
    evidence = samples.get("evidence") or {}
    declared = set(samples.get("sample_names", []))
    passed = set(evidence.get("passed_samples", []))
    if (not declared or passed != declared or evidence.get("fail_lines") != 0
            or evidence.get("all_pass") is not True
            or evidence.get("run_id") != build.get("run_id")
            or evidence.get("source_digest") != digest):
        failures.append("D6 缺少当前源码逐名全绿样本证据")
    return failures


def file_acceptance(row: dict | None, record: dict, target: float,
                    unreachable: set[str], samples: dict, build_ok: bool,
                    root: Path, digest: str) -> dict:
    target = max(80.0, target)
    evidence = samples.get("evidence") or {}
    sample_names = record.get("samples", [])
    device = record.get("device") or {}
    checklist_id = device.get("checklist_id", "")
    checklist = root / "docs" / "11" / "待验清单.md"
    checklist_ok = bool(checklist_id and checklist.is_file() and re.search(
        r'^\|\s*' + re.escape(checklist_id) + r'\s*\|[^\n]*\|\s*\[x\]\s*\|',
        checklist.read_text(encoding="utf-8"), re.M | re.I))
    artifact = device.get("artifact", "")
    artifact_path = (root / artifact).resolve() if artifact else None
    artifact_ok = bool(artifact_path and artifact_path.is_relative_to(root.resolve())
                       and artifact_path.is_file())
    file = row["file"] if row else ""
    checks = {
        "scale": bool(row and row["scale_ratio"] >= target),
        "stubs": bool(row and row["markers"] == 0),
        "symbols": bool(row and row["gap_funcs"] == 0),
        "reachable": bool(row and file not in unreachable),
        "samples": bool(sample_names and all(name in evidence.get("passed_samples", [])
                                             for name in sample_names)),
        "build": build_ok,
        "device": bool(device.get("checked") is True and device.get("model")
                       and device.get("os") and device.get("source_digest") == digest
                       and artifact_ok and checklist_ok),
    }
    return {"checks": checks, "restored": all(checks.values())}


def phase_failures(d1: dict, d2: dict, d3: dict, d8: dict) -> list[str]:
    failures = []
    if d1["gaps"]:
        failures.append(f"D1 函数缺口 {d1['gaps']} > 0")
    if d2["files_met_target"] != d2["files_total"]:
        failures.append(f"D2 规模未达标 {d2['files_total'] - d2['files_met_target']} 个文件")
    if d3["markers_total"]:
        failures.append(f"D3 桩标记 {d3['markers_total']} > 0")
    if d8["files_total"] != 336 or d8["manifest_errors"]:
        failures.append("D8 页面清单与 336 文件矩阵不一致")
    if d8["files_restored"] != 336:
        failures.append(f"D8 八维及真机全部过门 {d8['files_restored']}/336")
    return failures
