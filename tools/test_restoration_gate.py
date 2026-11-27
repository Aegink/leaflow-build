"""T-1602 门禁回归测试；标准库，运行 python -I tools/test_restoration_gate.py。"""
import runpy
import csv
import json
import hashlib
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
C = runpy.run_path(str(ROOT / "tools" / "restoration_gate_checks.py"))
G = runpy.run_path(str(ROOT / "tools" / "verify_restoration_gate.py"))
R = runpy.run_path(str(ROOT / "tools" / "record_build_evidence.py"))


class GateTests(unittest.TestCase):
    def test_immediate_sample_gate_requires_every_name_and_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / "RuleSampleSelfTest.swift").write_text('emit("a")\nemit("b")', encoding="utf-8")
            check = R["sample_evidence"]
            self.assertFalse(check(source, "SELFTEST a pass=true\nSELFTEST_END")["all_pass"])
            self.assertFalse(check(source, "SELFTEST a pass=true\nSELFTEST b pass=true")["all_pass"])
            self.assertFalse(check(source, "SELFTEST a pass=true\nSELFTEST b pass=false\nSELFTEST_END")["all_pass"])
            self.assertTrue(check(source, "SELFTEST a pass=true\nSELFTEST b pass=true\nSELFTEST_END")["all_pass"])

    def test_source_import_splits_preserve_ownership_and_missing_part_fails(self):
        owners = {
            "ReadMain/Views/Explore/ExploreBookDetailView.swift": [
                "ReadMain/Views/Explore/ExploreBookDetailView+Components.swift",
                "ReadMain/Views/Explore/ExploreBookDetailView+Actions.swift",
                "ReadMain/Views/Explore/ExploreBookDetailView+Loading.swift",
                "ReadMain/Views/Explore/ExploreBookDetailView+State.swift"],
            "ReadMain/Views/Explore/ExploreView.swift": [
                "ReadMain/Views/Explore/ExploreView+Models.swift",
                "ReadMain/Views/Explore/ExploreView+Components.swift",
                "ReadMain/Views/Explore/ExploreView+SourceAvailability.swift"],
            "ReadMain/Models/Book.swift": ["ReadMain/Models/Book+Identity.swift"],
            "ReadMain/Views/Explore/ExploreSourceDetailView.swift": [
                "ReadMain/Views/Explore/ExploreSourceDetailView+Loading.swift",
                "ReadMain/Views/Explore/ExploreSourceDetailView+Rules.swift"],
            "ReadMain/Views/Reader/PageViewController.swift": [
                "ReadMain/Views/Reader/PageViewController+Coordinator.swift",
                "ReadMain/Views/Reader/PageViewController+PageCurlDriver.swift"],
            "ReadMain/Views/Reader/PageContentViews.swift": [
                "ReadMain/Views/Reader/PageContentViews+UnderlineGeometry.swift",
                "ReadMain/Views/Reader/PageContentViews+Layout.swift",
                "ReadMain/Views/Reader/PageContentViews+Configuration.swift"],
            "ReadMain/Core/ReadingSettings.swift": ["ReadMain/Core/ReadingSettings+Background.swift"],
            "ReadMain/Core/SourceParser/LocalSourceParser.swift": ["ReadMain/Core/SourceParser/LocalSourceParser+Reviews.swift"],
            "ReadMain/Views/Reader/ReaderViewModifiers.swift": ["ReadMain/Views/Reader/ReaderSelectionPresentations.swift",
                                                                "ReadMain/Views/Reader/ReaderReviewPresentation.swift"],
            "ReadMain/Models/BookSource.swift": [
                "ReadMain/Models/BookSource+Decoding.swift", "ReadMain/Models/BookSource+Rules.swift"],
            "ReadMain/Services/SourceService.swift": ["ReadMain/Services/SourceService+Editing.swift"],
            "ReadMain/Services/SourceService+Storage.swift": ["ReadMain/Services/SourceService+Import.swift"],
            "ReadMain/Views/Source/SourceManageView.swift": [
                "ReadMain/Views/Source/SourceManageView+Content.swift",
                "ReadMain/Views/Source/SourceManageView+Actions.swift"],
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for owner, parts in owners.items():
                self.assertEqual(C["SWIFT_SOURCE_PARTS"][owner], parts)
                for name in [owner, *parts]:
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("// TODO\n", encoding="utf-8")
                    self.assertEqual(C["original_source_file"](name), owner)
                lines, markers, _ = C["source_metrics"](root, owner)
                self.assertEqual((lines, markers), (2 * (len(parts) + 1), len(parts) + 1))
                (root / parts[-1]).unlink()
                with self.assertRaises(ValueError):
                    C["source_metrics"](root, owner)

    def test_unconsumed_split_component_blocks_original_file(self):
        owner = C["original_source_file"]("ReadMain\\Views\\Bookshelf\\BookshelfItemViews+Actions.swift")
        self.assertEqual(owner, "ReadMain/Views/Bookshelf/BookshelfItemViews.swift")
        row = dict(file=owner.replace(".swift", ".c"), scale_ratio=80, markers=0, gap_funcs=0)
        _, samples = self.evidence()
        result = C["file_acceptance"](row, {}, 80, set(), samples, True, ROOT, "hash", {row["file"]})
        self.assertTrue(result["checks"]["reachable"])
        self.assertFalse(result["checks"]["consumed"])
        self.assertFalse(result["restored"])

    def test_bookshelf_splits_keep_original_ownership(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            relative = "ReadMain/Views/Bookshelf/BookshelfItemViews.swift"
            for name in [relative, *C["SWIFT_SOURCE_PARTS"][relative]]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// TODO\n", encoding="utf-8")
            lines, markers, _ = C["source_metrics"](root, relative)
            self.assertEqual((lines, markers), (6, 3))

    def test_ui_smoke_failure_cannot_pass_build_gate(self):
        build, samples = self.evidence()
        build.update(ui_smoke_required=True, ui_smoke_pass=False)
        self.assertTrue(C["build_failures"](build, samples, "hash"))
        build["ui_smoke_pass"] = True
        self.assertEqual(C["build_failures"](build, samples, "hash"), [])

    def test_generic_views_remain_in_reachability_inventory(self):
        matcher = G["VIEW_RE"]
        names = matcher.findall("struct TtsPlayerView<A: TtsPlayable>: View {}\n"
            "struct ReaderTtsQuickSettingsPanel<A: TtsPlayable>: View {}\n"
            "struct Plain: View {}")
        self.assertEqual(names, ["TtsPlayerView", "ReaderTtsQuickSettingsPanel", "Plain"])

    def test_split_metrics_keep_original_ownership(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            relative = "ReadMain/Views/Reader/TtsPlayerView.swift"
            primary = root / relative
            primary.parent.mkdir(parents=True)
            primary.write_text("struct MainView {}\n", encoding="utf-8")
            part = root / "ReadMain/Views/Reader/TtsPlayerView+Controls.swift"
            part.write_text("func ttsProgress() {}\n// TODO\n", encoding="utf-8")
            (root / "ReadMain/Views/Reader/TtsPlayerView+QuickSettings.swift").write_text("", encoding="utf-8")
            lines, markers, text = C["source_metrics"](root, relative)
            self.assertEqual((lines, markers), (6, 1))
            self.assertIn("ttsProgress", text)
            row = dict(file=relative.replace(".swift", ".c"), swift_lines=6, markers=1)
            self.assertEqual(C["matrix_failures"]([row], root), [])
            part.write_text("func ttsProgress() {}\n", encoding="utf-8")
            self.assertTrue(C["matrix_failures"]([row], root))

    def test_missing_split_source_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                C["source_metrics"](Path(directory), "ReadMain/Views/Reader/TtsPlayerView.swift")

    def test_comment_and_string_are_not_edges(self):
        code = C["swift_code"]('// DeadView()\n/* DeadView() */\nlet s = "DeadView()"\nRealView()')
        self.assertNotIn("DeadView", code)
        self.assertIn("RealView", code)

    def test_modifier_and_extension_calls_are_edges(self):
        texts = {
            "/LeaflowApp.swift": "struct LeaflowApp: App { MainTabView().splashOverlay() }",
            "/MainTabView.swift": "struct MainTabView: View { content.modifier(SheetModifier()) }",
            "/Modifier.swift": "struct SheetModifier: ViewModifier { BookmarksView() }",
            "/Splash.swift": "func splashOverlay() { SplashOverlayView() }\nstruct SplashOverlayView: View {}",
            "/Bookmarks.swift": "struct BookmarksView: View {}",
            "/Dead.swift": "struct DeadView: View {}",
        }
        views = [{"view": name, "file": path} for name, path in (
            ("MainTabView", "/MainTabView.swift"), ("SplashOverlayView", "/Splash.swift"),
            ("BookmarksView", "/Bookmarks.swift"), ("DeadView", "/Dead.swift"))]
        # 报告相对路径只影响输出，测试时把根设为文件系统根。
        reach = G["d5_reachability"]
        reach.__globals__["SWIFT_ROOT"] = Path("/")
        result = reach(views, {v["view"]: v["file"] for v in views}, texts)
        self.assertEqual([x["view"] for x in result["unreachable_page_views"]], ["DeadView"])

    def evidence(self):
        build = dict(known=True, run_id="1", head_sha="abc", source_digest="hash",
                     errors=0, selftest_fail=0, smoke_pass=3, crash_count=0)
        samples = dict(sample_names=["a"], evidence=dict(run_id="1", source_digest="hash",
                      passed_samples=["a"], fail_lines=0, all_pass=True))
        return build, samples

    def test_current_complete_evidence_passes(self):
        build, samples = self.evidence()
        self.assertEqual(C["build_failures"](build, samples, "hash"), [])

    def test_old_build_cannot_cover_new_code(self):
        build, samples = self.evidence()
        self.assertTrue(C["build_failures"](build, samples, "new_hash"))

    def test_missing_build_counters_fail(self):
        build, samples = self.evidence()
        del build["errors"]
        self.assertTrue(C["build_failures"](build, samples, "hash"))

    def test_count_without_sample_names_fails(self):
        build, samples = self.evidence()
        samples["evidence"]["passed_samples"] = []
        samples["evidence"]["unique_samples"] = 23
        self.assertTrue(C["build_failures"](build, samples, "hash"))

    def test_80_percent_is_not_restored(self):
        row = dict(file="a.c", scale_ratio=80, markers=0, gap_funcs=0)
        _, samples = self.evidence()
        result = C["file_acceptance"](row, {}, 80, set(), samples, True, ROOT, "hash")
        self.assertTrue(result["checks"]["scale"])
        self.assertFalse(result["restored"])

    def test_manifest_cannot_lower_80_percent_gate(self):
        row = dict(file="a.c", scale_ratio=79, markers=0, gap_funcs=0)
        _, samples = self.evidence()
        result = C["file_acceptance"](row, {}, 0, set(), samples, True, ROOT, "hash")
        self.assertFalse(result["checks"]["scale"])
        scale = G["d2_scale_axis"]([dict(file="a.c", module="Core", scale_ratio=79,
            swift_lines=79, pseudo_lines=100)], dict(target_ratio=0))
        self.assertEqual(scale["files_met_target"], 0)

    def test_all_file_checks_required(self):
        row = dict(file="a.c", scale_ratio=80, markers=0, gap_funcs=0)
        _, samples = self.evidence()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            artifact = root / "device.txt"
            artifact.touch()
            record = dict(samples=["a"], device=dict(checked=True, model="测试机", os="26",
                          source_digest="hash", artifact="device.txt", checklist_id="A01"))
            checklist = root / "docs" / "11" / "待验清单.md"
            checklist.parent.mkdir(parents=True)
            checklist.write_text("| A01 | 测试页面 | [x] | device.txt |\n", encoding="utf-8")
            check = C["file_acceptance"]
            self.assertTrue(check(row, record, 80, set(), samples, True, root, "hash")["restored"])
            self.assertFalse(check(row, record, 80, set(), samples, True, root, "hash", {"a.c"})["restored"])
            for key, value in (("markers", 1), ("gap_funcs", 1), ("scale_ratio", 79.9)):
                changed = {**row, key: value}
                self.assertFalse(check(changed, record, 80, set(), samples, True, root, "hash")["restored"])
            self.assertFalse(check(row, record, 80, {"a.c"}, samples, True, root, "hash")["restored"])
            self.assertFalse(check(row, record, 80, set(), samples, False, root, "hash")["restored"])
            checklist.write_text("| A01 | 测试页面 | [ ] | device.txt |\n", encoding="utf-8")
            self.assertFalse(check(row, record, 80, set(), samples, True, root, "hash")["restored"])

    def test_phase_cannot_pass_with_stub_or_scale_gap(self):
        d1 = dict(gaps=0)
        d2 = dict(files_total=336, files_met_target=336)
        d3 = dict(markers_total=0)
        d8 = dict(files_total=336, files_restored=336, manifest_errors=[])
        phase = C["phase_failures"]
        self.assertEqual(phase(d1, d2, d3, d8), [])
        self.assertTrue(phase(dict(gaps=1), d2, d3, d8))
        self.assertTrue(phase(d1, dict(files_total=336, files_met_target=335), d3, d8))
        self.assertTrue(phase(d1, d2, dict(markers_total=1), d8))
        self.assertTrue(phase(d1, d2, d3, {**d8, "files_total": 335}))
        self.assertTrue(phase(d1, d2, d3, {**d8, "files_restored": 335}))

    def test_matrix_and_digest_track_current_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            file = root / "a.swift"
            file.write_bytes(b"let a = 1\r\n")
            digest = C["source_digest"](root)
            file.write_bytes(b"let a = 1\n")
            self.assertEqual(digest, C["source_digest"](root))
            rows = [dict(file="a.c", swift_lines=2, markers=0)]
            self.assertEqual(C["matrix_failures"](rows, root), [])
            file.write_text("// TODO\nlet a = 1\n", encoding="utf-8")
            self.assertTrue(C["matrix_failures"](rows, root))
            self.assertNotEqual(digest, C["source_digest"](root))

    def test_digest_uses_portable_case_sensitive_order(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "a.swift").write_text("lower\n", encoding="utf-8")
            (root / "Z.swift").write_text("upper\n", encoding="utf-8")
            expected = hashlib.sha256()
            for name in ("Z.swift", "a.swift"):
                expected.update(name.encode() + b"\0")
                expected.update((root / name).read_bytes().replace(b"\r\n", b"\n") + b"\0")
            self.assertEqual(C["source_digest"](root), expected.hexdigest())

    def test_record_evidence_uses_real_build_exit_and_named_samples(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "src"
            source.mkdir()
            (source / "RuleSampleSelfTest.swift").write_text('emit(name: "a")', encoding="utf-8")
            for name in ("build.log", "device-build.log"):
                (root / name).write_text("BUILD SUCCEEDED\nxcodebuild exit: 0\n", encoding="utf-8")
            (root / "smoke-result.txt").write_text(
                "alive=1\nsources_alive=1\nbookshelf_alive=1\ncrash_reports=0\n", encoding="utf-8")
            (root / "selftest.log").write_text("SELFTEST a pass=true\nSELFTEST_END\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "1", "abc"), 0)
            self.assertEqual(R["record"](root, source, "1", "abc", True), 1)
            (root / "ui-smoke-result.txt").write_text("ui_test_exit=0\ncrash_reports=0\n", encoding="utf-8")
            (root / "ui-smoke.log").write_text("\n".join(
                f"SMOKE_UI {name} pass=true" for name in R["UI_SMOKE_NAMES"]), encoding="utf-8")
            self.assertEqual(R["record"](root, source, "1", "abc", True), 0)
            (root / "ui-smoke-result.txt").write_text("ui_test_exit=0\ncrash_reports=1\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "1", "abc", True), 1)
            (root / "ui-smoke-result.txt").write_text("ui_test_exit=0\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "1", "abc", True), 1)
            (root / "ui-smoke-result.txt").write_text("ui_test_exit=65\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "1", "abc", True), 1)
            (root / "build.log").write_text("BUILD FAILED\nxcodebuild exit: 65\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "2", "def"), 1)
            (root / "selftest.log").write_text("SELFTEST a pass=false\n", encoding="utf-8")
            self.assertEqual(R["record"](root, source, "3", "def"), 1)

    def test_missing_logs_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.assertEqual(R["record"](root, root, "1", "abc"), 1)

    def test_record_cli_returns_failure_for_missing_artifacts(self):
        script = str(ROOT / "tools" / "record_build_evidence.py")
        with tempfile.TemporaryDirectory() as temp:
            argv = [script, "--artifacts", temp, "--source", temp,
                    "--run-id", "1", "--head-sha", "abc"]
            with patch("sys.argv", argv), self.assertRaises(SystemExit) as raised:
                runpy.run_path(script, run_name="__main__")
            self.assertEqual(raised.exception.code, 1)

    def test_full_cli_counts_only_all_gated_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "swift"
            source.mkdir()
            names = ["LeaflowApp", "RootView"] + [f"File{i}" for i in range(334)]
            rows = []
            for name in names:
                text = "struct LeaflowApp: App { RootView() }\n" if name == "LeaflowApp" else (
                    "struct RootView: View {}\n" if name == "RootView" else "let value = 1\n")
                (source / f"{name}.swift").write_text(text, encoding="utf-8")
                rows.append(dict(file=f"{name}.c", module="Core", scale_ratio=200,
                    swift_lines=2, pseudo_lines=1, markers=0, pseudo_funcs=1, gap_funcs=0))
            (source / "RuleSampleSelfTest.swift").write_text('emit(name: "a")', encoding="utf-8")
            digest = C["source_digest"](source)
            (root / "device.txt").touch()
            acceptance = dict(samples=["a"], device=dict(checked=True, model="测试机",
                os="26", source_digest=digest, artifact="device.txt", checklist_id="A01"))
            checklist = root / "docs" / "11" / "待验清单.md"
            checklist.parent.mkdir(parents=True)
            checklist.write_text("| A01 | 测试页面 | [x] | device.txt |\n", encoding="utf-8")
            manifest = dict(target_ratio=80, expected_samples=1, batches=[dict(name="测试批次",
                module="Core", files=[dict(file=row["file"], acceptance=acceptance) for row in rows])])
            matrix = root / "matrix.csv"
            with matrix.open("w", encoding="utf-8", newline="") as file:
                writer = csv.DictWriter(file, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)
            build, samples = self.evidence()
            build["source_digest"] = digest
            samples["evidence"]["source_digest"] = digest
            paths = dict(ROOT=root, SWIFT_ROOT=source, MATRIX_CSV=matrix,
                MANIFEST=root / "manifest.json", BUILD_EVIDENCE=root / "build.json",
                SELFTEST_EVIDENCE=root / "samples.json", OUT_JSON=root / "gate.json",
                OUT_MD=root / "gate.md")
            for key, data in (("MANIFEST", manifest), ("BUILD_EVIDENCE", build),
                              ("SELFTEST_EVIDENCE", samples["evidence"])):
                paths[key].write_text(json.dumps(data), encoding="utf-8")
            main = G["main"]
            with patch.dict(main.__globals__, paths), patch("builtins.print"):
                self.assertEqual(main(), 0)
                result = json.loads(paths["OUT_JSON"].read_text(encoding="utf-8"))
                self.assertEqual(result["D8_page_progress"]["files_restored"], 336)
                # 分册内死组件归回原文件，即使样本/设备齐全也不能算还原完成。
                d8 = G["d8_page_progress"](manifest, rows,
                    dict(unreachable_page_views=[]), samples, True, digest,
                    dict(d4b_unreferenced=[dict(file="File0.swift")]))
                self.assertEqual(d8["files_restored"], 335)
                # 勾选数量不变，但删掉设备证据，完整还原数必须归零。
                (root / "device.txt").unlink()
                self.assertEqual(main(), 1)
                result = json.loads(paths["OUT_JSON"].read_text(encoding="utf-8"))
                self.assertEqual(result["D8_page_progress"]["files_restored"], 0)


if __name__ == "__main__":
    result = unittest.TextTestRunner().run(
        unittest.defaultTestLoader.loadTestsFromTestCase(GateTests))
    raise SystemExit(0 if result.wasSuccessful() else 1)
