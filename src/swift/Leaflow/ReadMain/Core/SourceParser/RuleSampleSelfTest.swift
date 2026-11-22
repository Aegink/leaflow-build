// 原路径: ReadMain/Core/SourceParser/RuleSampleSelfTest.swift（T-1601-B1 新增）
// 证据:
//   - T-1601.md §B-1 验收：固定 HTML 样本断言
//     getString(rule: "//div[@class='x']/text()") 与
//     getString(rule: "$.data.name") 非 nil（样本入测试文件可复算）。
//   - 分派依据：RuleExecutorRegistry（pipelineExecutor 家族协议化承载）
//     的 mode → 执行器映射；xpath/json/default_/mode8 四模式在
//     T-1601-B1 接线前于字符串链直接返回 nil。
// 说明: 本文件是**可复算样本**而非 XCTest 目标（构建仓无 test target）；
//       -selfTestRules 启动参数下运行并打印 SELFTEST 行，CI 以
//       simctl launch --console 抓取后 grep 判定。
// 状态: 语义级还原（不是原始源码）
// 置信度: high（样本输入/规则/期望值固定，输出逐条打印）

import Foundation

/// 书源解析固定样本自测（T-1601-B1 验收）。
enum RuleSampleSelfTest {

    /// 单条样本。
    struct Sample {
        let name: String
        let content: String
        let rule: String
        let expect: [String]
        let asList: Bool
    }

    static let samples: [Sample] = [
        Sample(
            name: "xpath_text",
            content: "<html><body><div class=\"x\">hello</div></body></html>",
            rule: "//div[@class='x']/text()",
            expect: ["hello"],
            asList: false),
        Sample(
            name: "json_name",
            content: "{\"data\":{\"name\":\"Alice\"}}",
            rule: "$.data.name",
            expect: ["Alice"],
            asList: false),
        Sample(
            name: "css_text",
            content: "<html><body><div class=\"x\">hello</div></body></html>",
            rule: "@css:.x@text",
            expect: ["hello"],
            asList: false),
        Sample(
            name: "xpath_list",
            content: "<html><body><ul><li>a</li><li>b</li></ul></body></html>",
            rule: "//li/text()",
            expect: ["a", "b"],
            asList: true),
        Sample(
            name: "json_list",
            content: "{\"data\":{\"list\":[\"a\",\"b\"]}}",
            rule: "$.data.list",
            expect: ["a", "b"],
            asList: true),
    ]

    /// -selfTestRules 时运行、打印并退出（仅 CI 参数触发）。
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-selfTestRules")
        else { return }
        run()
        exit(0)
    }

    static func run() {
        for sample in samples {
            let analyzer = AnalyzeRule(source: nil, parent: nil)
            analyzer.setContent(sample.content, baseUrl: "")
            let actual: [String]
            if sample.asList {
                actual = analyzer.getStringList(
                    rule: sample.rule, isUrl: false)
            } else if let single = analyzer.getString(
                rule: sample.rule, isUrl: false) {
                actual = [single]
            } else {
                actual = []
            }
            emit(name: sample.name, expected: sample.expect,
                 actual: actual)
        }

        // 模式接线直测：default_（JSoup 单值）与 mode8（[String] 归一）。
        let html = AnalyzeRule(source: nil, parent: nil)
        html.setContent(
            "<html><body><div class=\"x\">hello</div></body></html>",
            baseUrl: "")
        let defaultExecutor = RuleExecutorRegistry.executor(for: .default_)
        if let css = defaultExecutor?.execute(
            rule: ".x@text", context: html) {
            emit(name: "default_jsoup", expected: ["hello"],
                 actual: [css])
        } else {
            emit(name: "default_jsoup", expected: ["hello"], actual: [])
        }

        let json = AnalyzeRule(source: nil, parent: nil)
        json.setContent("{\"data\":{\"name\":\"Alice\"}}", baseUrl: "")
        let mode8Executor = RuleExecutorRegistry.executor(for: .mode8)
        if let list = mode8Executor?.executeForList(
            rule: "$.data.name", context: json) {
            emit(name: "mode8_normalize", expected: ["Alice"],
                 actual: list)
        } else {
            emit(name: "mode8_normalize", expected: ["Alice"], actual: [])
        }
    }

    /// 稳定输出（CI grep `SELFTEST` + `pass=`）。
    private static func emit(
        name: String, expected: [String], actual: [String]
    ) {
        let pass = expected == actual
        print(
            "SELFTEST \(name) pass=\(pass) "
                + "expected=\(expected) actual=\(actual)")
    }
}
