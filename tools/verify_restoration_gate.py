"""T-1602 多维交叉验证门禁。

维度：
  D1 函数轴（矩阵 CSV：伪代码函数 → Swift 声明/成员）
  D2 规模轴（逐文件 swift/pseudo 行数比 + 模块聚合 + 80% 目标达成数）
  D3 桩密度（待真机/骨架/占位/TODO 标记）
  D4 死页面（同文件+跨文件引用均 0；D4a 跨文件口径仅作参考）
  D5 入口可达性（从 LeaflowApp/MainTabView 做文件级 BFS，列出不可达页面）
  D6 行为样本（RuleSampleSelfTest 样本数 + last_selftest.json 交叉核对）
  D7 构建门禁（last_build.json：errors / selftest_fail）
  D8 页面矩阵进度（T-1602_pages.json：各批次 80% 达成数）

用法：
  python -I tools/verify_restoration_gate.py [--strict-phase]

退出码：
  0 = 硬门禁通过（D4b=0、无不可达页面、构建已知且零错误、样本数达标）
  1 = 硬门禁失败
  2 = 缺少矩阵/清单输入
"""

from __future__ import annotations

import csv
import json
import re
import runpy
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_ROOT = ROOT / "src" / "swift" / "Leaflow"
MATRIX_CSV = ROOT / "docs" / "reports" / "restoration_matrix.csv"
MANIFEST = ROOT / "docs" / "11" / "T-1602_pages.json"
BUILD_EVIDENCE = ROOT / "docs" / "reports" / "last_build.json"
SELFTEST_EVIDENCE = ROOT / "docs" / "reports" / "last_selftest.json"
CHECKS = runpy.run_path(str(ROOT / "tools" / "restoration_gate_checks.py"))
OUT_JSON = ROOT / "docs" / "reports" / "restoration_gate.json"
OUT_MD = ROOT / "docs" / "reports" / "restoration_gate.md"

VIEW_RE = re.compile(
        r"^\s*(?:@\w+\s+)*struct\s+([A-Za-z_][A-Za-z0-9_]*)(?:<[^{}\n]+>)?\s*:\s*View\b",
    re.M,
)
COMPONENT_SUFFIXES = (
    "Badge", "Row", "Bar", "Cell", "Button", "Field", "Icon", "Overlay",
    "Panel", "Menu", "Label", "Item", "Tag", "Wrap", "Grid", "Block",
    "Text", "Image", "Shape", "Style", "Modifier", "Card", "Chip",
)


def load_matrix() -> list[dict]:
    if not MATRIX_CSV.exists():
        print(f"[FAIL] 缺少矩阵 CSV：{MATRIX_CSV}")
        sys.exit(2)
    with MATRIX_CSV.open(encoding="utf-8") as matrix:
        rows = list(csv.DictReader(matrix))
    for r in rows:
        r["scale_ratio"] = float(r["scale_ratio"])
        r["swift_lines"] = int(r["swift_lines"])
        r["pseudo_lines"] = int(r["pseudo_lines"])
        r["scale_ratio"] = r["swift_lines"] / r["pseudo_lines"] * 100 if r["pseudo_lines"] else 0.0
        r["markers"] = int(r["markers"])
        r["pseudo_funcs"] = int(r["pseudo_funcs"])
        r["gap_funcs"] = int(r["gap_funcs"])
    return rows


def d1_function_axis(rows: list[dict]) -> dict:
    funcs = sum(r["pseudo_funcs"] for r in rows)
    gaps = sum(r["gap_funcs"] for r in rows)
    cover = round((funcs - gaps) / funcs * 100, 1) if funcs else 100.0
    return {"pseudo_funcs": funcs, "gaps": gaps, "coverage": cover}


def d2_scale_axis(rows: list[dict], manifest: dict) -> dict:
    ps = sum(r["pseudo_lines"] for r in rows)
    sw = sum(r["swift_lines"] for r in rows)
    global_ratio = round(sw / ps * 100, 2) if ps else 0.0
    mods = defaultdict(lambda: [0, 0])
    for r in rows:
        mods[r["module"]][0] += r["swift_lines"]
        mods[r["module"]][1] += r["pseudo_lines"]
    module_rows = [
        {
            "module": m,
            "swift_lines": v[0],
            "pseudo_lines": v[1],
            "ratio": round(v[0] / v[1] * 100, 2) if v[1] else 0.0,
        }
        for m, v in mods.items()
    ]
    module_rows.sort(key=lambda x: x["ratio"])
    target = max(80.0, float(manifest.get("target_ratio", 80.0)))
    met = [r for r in rows if r["scale_ratio"] >= target]
    return {
        "swift_lines": sw,
        "pseudo_lines": ps,
        "global_ratio": global_ratio,
        "target_ratio": target,
        "files_total": len(rows),
        "files_met_target": len(met),
        "modules": module_rows,
    }


def d3_stubs(rows: list[dict]) -> dict:
    total = sum(r["markers"] for r in rows)
    top = sorted(rows, key=lambda r: -r["markers"])[:10]
    return {
        "markers_total": total,
        "top": [
            {"file": r["file"], "markers": r["markers"]} for r in top
        ],
    }


def collect_views() -> tuple[list[dict], dict[str, str], dict[str, str]]:
    """返回 (views, name→file, file→text)。"""
    texts: dict[str, str] = {}
    for p in SWIFT_ROOT.rglob("*.swift"):
        texts[str(p)] = CHECKS["swift_code"](p.read_text(encoding="utf-8", errors="replace"))
    views: list[dict] = []
    name_to_file: dict[str, str] = {}
    for path, text in texts.items():
        for m in VIEW_RE.finditer(text):
            name = m.group(1)
            name_to_file[name] = path
            views.append({"view": name, "file": path})
    return views, name_to_file, texts


def d4_dead_pages(views: list[dict], name_to_file: dict[str, str],
                  texts: dict[str, str]) -> dict:
    rows = []
    counts = {path: Counter(re.findall(r'\b[A-Za-z_]\w*\b', text))
              for path, text in texts.items()}
    total = Counter()
    for count in counts.values():
        total.update(count)
    for v in views:
        name, path = v["view"], v["file"]
        same = max(0, counts[path][name] - 1)
        outside = total[name] - counts[path][name]
        rows.append({
            "view": name,
            "file": str(Path(path).relative_to(SWIFT_ROOT)),
            "refs_same_file": same,
            "refs_outside": outside,
            "unreferenced": same == 0 and outside == 0,
        })
    unreferenced = [r for r in rows if r["unreferenced"]]
    cross_only = [
        r for r in rows if r["refs_outside"] == 0 and r["refs_same_file"] > 0
    ]
    return {
        "views_total": len(rows),
        "d4b_unreferenced": unreferenced,
        "d4a_cross_file_zero": len(cross_only),
        "d4b_count": len(unreferenced),
    }


def d5_reachability(views: list[dict], name_to_file: dict[str, str],
                    texts: dict[str, str]) -> dict:
    roots = [p for p in texts if p.endswith("LeaflowApp.swift")]
    symbols = CHECKS["dependency_symbols"](texts)
    symbols.update(name_to_file)
    reachable_files: set[str] = set(roots)
    queue = deque(roots)
    edges = 0
    while queue:
        f = queue.popleft()
        text = texts[f]
        tokens = set(re.findall(r'\b[A-Za-z_]\w*\b', text))
        for name in sorted(tokens & symbols.keys()):
            target = symbols[name]
            if target == f or target in reachable_files:
                continue
            reachable_files.add(target)
            queue.append(target)
            edges += 1
    unreachable = []
    for v in views:
        name, path = v["view"], v["file"]
        if path in reachable_files:
            continue
        if not name.endswith(("View", "Sheet")):
            continue
        if name.endswith(COMPONENT_SUFFIXES):
            continue
        unreachable.append({
            "view": name,
            "file": str(Path(path).relative_to(SWIFT_ROOT)),
        })
    return {
        "root_files": [str(Path(p).relative_to(SWIFT_ROOT)) for p in roots],
        "reachable_files": len(reachable_files),
        "graph_edges": edges,
        "unreachable_page_views": sorted(unreachable, key=lambda x: x["file"]),
        "unreachable_count": len(unreachable),
    }


def d6_samples() -> dict:
    sample_file = (
        SWIFT_ROOT / "ReadMain" / "Core" / "SourceParser"
        / "RuleSampleSelfTest.swift"
    )
    names: set[str] = set()
    for sample_file in SWIFT_ROOT.rglob("*SelfTest.swift"):
        text = sample_file.read_text(encoding="utf-8", errors="replace")
        names |= set(re.findall(
            r'Sample\(\s*name:\s*"([^"]+)"', text, re.S))
        names |= set(re.findall(
            r'emit\(\s*name:\s*"([^"]+)"', text))
        names |= set(re.findall(r'emit\(\s*"([^"]+)"', text))
    evidence = None
    if SELFTEST_EVIDENCE.exists():
        evidence = json.loads(SELFTEST_EVIDENCE.read_text(encoding="utf-8"))
    return {
        "declared_unique_samples": len(names),
        "sample_names": sorted(names),
        "evidence": evidence,
    }


def d7_build() -> dict:
    if not BUILD_EVIDENCE.exists():
        return {"known": False}
    data = json.loads(BUILD_EVIDENCE.read_text(encoding="utf-8"))
    data["known"] = True
    return data


def d8_page_progress(manifest: dict, rows: list[dict], d5: dict,
                     d6: dict, build_ok: bool, digest: str, d4: dict | None = None) -> dict:
    by_file = {r["file"]: r for r in rows}
    batches = []
    seen = []
    unreachable = {CHECKS["original_source_file"](x["file"]).replace(".swift", ".c")
                   for x in d5["unreachable_page_views"]}
    unconsumed = {CHECKS["original_source_file"](x["file"]).replace(".swift", ".c")
                  for x in (d4 or {}).get("d4b_unreferenced", [])}
    for b in manifest.get("batches", []):
        files = []
        met = 0
        for f in b.get("files", []):
            seen.append(f["file"])
            r = by_file.get(f["file"])
            ratio = r["scale_ratio"] if r else 0.0
            target = max(80.0, float(f.get("target_ratio", 80.0)))
            ok = ratio >= target
            if ok:
                met += 1
            acceptance = CHECKS["file_acceptance"](
                r, f.get("acceptance", {}), target,
                unreachable, d6, build_ok, ROOT, digest, unconsumed)
            files.append({
                "file": f["file"],
                "current_ratio": ratio,
                "target_ratio": target,
                "met": ok,
                **acceptance,
            })
        batches.append({
            "name": b["name"],
            "module": b.get("module", ""),
            "files_total": len(files),
            "files_met": met,
            "files_restored": sum(f["restored"] for f in files),
            "files": files,
        })
    return {
        "batches": batches,
        "files_total": sum(b["files_total"] for b in batches),
        "files_met": sum(b["files_met"] for b in batches),
        "files_restored": sum(b["files_restored"] for b in batches),
        "manifest_errors": sorted(set(seen) ^ set(by_file))
            + (["重复文件"] if len(seen) != len(set(seen)) else []),
    }


def main() -> int:
    if not MANIFEST.exists():
        print(f"[FAIL] 缺少页面清单：{MANIFEST}")
        return 2
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    rows = load_matrix()
    views, name_to_file, texts = collect_views()

    d1 = d1_function_axis(rows)
    d2 = d2_scale_axis(rows, manifest)
    d3 = d3_stubs(rows)
    d4 = d4_dead_pages(views, name_to_file, texts)
    d5 = d5_reachability(views, name_to_file, texts)
    allow_d4 = set(manifest.get("d4b_allowlist", []))
    if allow_d4:
        d4["d4b_unreferenced"] = [
            x for x in d4["d4b_unreferenced"]
            if x["view"] not in allow_d4
        ]
        d4["d4b_count"] = len(d4["d4b_unreferenced"])
    allow_d5 = set(manifest.get("reachability_allowlist", []))
    if allow_d5:
        d5["unreachable_page_views"] = [
            x for x in d5["unreachable_page_views"]
            if x["view"] not in allow_d5
        ]
        d5["unreachable_count"] = len(d5["unreachable_page_views"])
    d6 = d6_samples()
    d7 = d7_build()
    digest = CHECKS["source_digest"](SWIFT_ROOT)
    evidence_failures = CHECKS["build_failures"](d7, d6, digest)
    d8 = d8_page_progress(manifest, rows, d5, d6, not evidence_failures, digest, d4)

    hard = manifest.get("hard_gates", {})
    failures: list[str] = []
    failures.extend(CHECKS["matrix_failures"](rows, SWIFT_ROOT))
    failures.extend(evidence_failures)
    failures.extend(CHECKS["phase_failures"](d1, d2, d3, d8))
    if d4["d4b_count"] > int(hard.get("d4b_dead_pages", 0)):
        failures.append(f"D4b 死页面 {d4['d4b_count']} > 0")
    if d5["unreachable_count"] > 0:
        failures.append(
            f"D5 不可达页面 {d5['unreachable_count']} 个")
    expected_samples = int(manifest.get("expected_samples", 0))
    if d6["declared_unique_samples"] < expected_samples:
        failures.append(
            f"D6 样本数 {d6['declared_unique_samples']} < {expected_samples}")
    if d7.get("known"):
        if int(d7.get("errors", 0)) > int(hard.get("build_errors", 0)):
            failures.append(f"D7 构建错误 {d7['errors']}")
        if int(d7.get("selftest_fail", 0)) > int(hard.get("selftest_fail", 0)):
            failures.append(f"D7 自测失败 {d7['selftest_fail']}")
    else:
        failures.append("D7 缺少 last_build.json（构建证据未知）")

    result = {
        "phase": manifest.get("phase", "T-1602"),
        "source_digest": digest,
        "D1_function_axis": d1,
        "D2_scale_axis": d2,
        "D3_stubs": d3,
        "D4_dead_pages": d4,
        "D5_reachability": d5,
        "D6_samples": d6,
        "D7_build": d7,
        "D8_page_progress": d8,
        "hard_gate_failures": failures,
        "passed": not failures,
    }
    OUT_JSON.write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

    md = [
        "# 还原门禁（T-1602 多维交叉验证）",
        "",
        f"> 生成：`python -I tools/verify_restoration_gate.py`  ",
        f"> 结论：{'PASS' if not failures else 'FAIL'}",
        "",
        "## 硬门禁",
        "",
    ]
    if failures:
        md += [f"- ❌ {f}" for f in failures]
    else:
        md.append("- ✅ 全部硬门禁通过")
    md += [
        "",
        "## 维度汇总",
        "",
        "| 维度 | 值 |",
        "|---|---|",
        f"| D1 函数轴 | {d1['coverage']}%（{d1['pseudo_funcs']} 函数 / {d1['gaps']} 缺口） |",
        f"| D2 规模轴 | {d2['global_ratio']}%（{d2['swift_lines']} / {d2['pseudo_lines']} 行） |",
        f"| D2 80% 达成 | {d2['files_met_target']} / {d2['files_total']} 文件 |",
        f"| D3 桩标记 | {d3['markers_total']} 处 |",
        f"| D4b 真正死页面 | {d4['d4b_count']} |",
        f"| D4a 跨文件零引用 | {d4['d4a_cross_file_zero']}（同文件已用） |",
        f"| D5 不可达页面 | {d5['unreachable_count']} |",
        f"| D6 声明样本 | {d6['declared_unique_samples']} |",
        f"| D7 构建 | errors={d7.get('errors', '?')} / fail={d7.get('selftest_fail', '?')} / run={d7.get('run_id', '?')} |",
        f"| D8 页面矩阵 | {d8['files_met']} / {d8['files_total']} 文件达 80% |",
        f"| D8 完整还原 | {d8['files_restored']} / {d8['files_total']} 文件全部过门 |",
        "",
        "## D5 不可达页面（前 50）",
        "",
        "| View | 文件 |",
        "|---|---|",
    ]
    for item in d5["unreachable_page_views"][:50]:
        md.append(f"| {item['view']} | {item['file']} |")
    md += ["", "## D8 批次进度", "",
           "| 批次 | 模块 | 达成 |", "|---|---|---:|"]
    for b in d8["batches"]:
        md.append(
            f"| {b['name']} | {b['module']} | {b['files_met']}/{b['files_total']} |")
    md += ["", "## D3 桩密度 Top10", "",
           "| 文件 | 标记数 |", "|---|---:|"]
    for t in d3["top"]:
        md.append(f"| {t['file']} | {t['markers']} |")
    OUT_MD.write_text("\n".join(md) + "\n", encoding="utf-8")

    print(f"D1 函数轴: {d1['coverage']}% ({d1['pseudo_funcs']} / gap {d1['gaps']})")
    print(f"D2 规模轴: {d2['global_ratio']}% "
          f"({d2['swift_lines']}/{d2['pseudo_lines']}); "
          f"80% 达成 {d2['files_met_target']}/{d2['files_total']}")
    print(f"D3 桩标记: {d3['markers_total']}")
    print(f"D4b 死页面: {d4['d4b_count']} (D4a {d4['d4a_cross_file_zero']})")
    print(f"D5 不可达页面: {d5['unreachable_count']}")
    print(f"D6 声明样本: {d6['declared_unique_samples']}")
    print(f"D7 构建: {d7}")
    print(f"D8 矩阵: {d8['files_met']}/{d8['files_total']} 达 80%")
    print(f"门禁: {'PASS' if not failures else 'FAIL'}")
    for f in failures:
        print("  -", f)
    print(f"报告: {OUT_JSON}\n      {OUT_MD}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
