// 在macOS主机识别XCTest导出的原始截图，避开模拟器Metal图像转换路径。
import Foundation
import Vision

struct PixelCheck: Codable {
    let test: String
    let file: String
    let expected: String
    let recognized: String
    let passed: Bool
}
struct PixelEvidence: Codable {
    let all_pass: Bool
    let checks: [PixelCheck]
    let errors: [String]
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let screenshots = root.appendingPathComponent("ui-screenshots")
var checks: [PixelCheck] = []
var errors: [String] = []
let required = [
    "testBookReviewRenderedStates": 3,
    "testReaderHorizontalPageTurns": 5,
    "testReaderCurlPageTurns": 5,
    "testLocalBookFileImport": 3,
    "testExploreDetailReadingHandoff": 1
]
do {
    let data = try Data(contentsOf: screenshots.appendingPathComponent("manifest.json"))
    guard let manifest = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw NSError(domain: "像素证据", code: 1)
    }
    for entry in manifest {
        let identifier = entry["testIdentifier"] as? String ?? ""
        let test = identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "()", with: "") ?? ""
        for attachment in entry["attachments"] as? [[String: Any]] ?? [] {
            let name = attachment["suggestedHumanReadableName"] as? String ?? ""
            guard name.hasPrefix("pixel-text-") else { continue }
            let hex = String(name.dropFirst("pixel-text-".count).prefix(while: { $0 != "-" }))
            let bytes = stride(from: 0, to: hex.count, by: 2).compactMap { offset -> UInt8? in
                let start = hex.index(hex.startIndex, offsetBy: offset)
                guard let end = hex.index(start, offsetBy: 2, limitedBy: hex.endIndex) else { return nil }
                return UInt8(hex[start..<end], radix: 16)
            }
            guard !bytes.isEmpty, bytes.count * 2 == hex.count,
                  let expected = String(bytes: bytes, encoding: .utf8),
                  let file = attachment["exportedFileName"] as? String,
                  URL(fileURLWithPath: file).lastPathComponent == file else {
                errors.append("无效截图记录：\(name)"); continue
            }
            do {
                let request = VNRecognizeTextRequest()
                request.usesCPUOnly = true
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hans", "en-US"]
                try VNImageRequestHandler(url: screenshots.appendingPathComponent(file)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined()
                let passed = text.contains(expected)
                checks.append(PixelCheck(test: test, file: file, expected: expected, recognized: text, passed: passed))
                print("像素检查 \(test)：\(expected)，通过=\(passed)，识别=\(text)")
            } catch { errors.append("截图识别失败：\(file)，\(error.localizedDescription)") }
        }
    }
    for (test, count) in required {
        let actual = checks.filter { $0.test == test }.count
        if actual != count { errors.append("\(test)截图数\(actual)/\(count)") }
    }
    if checks.contains(where: { !$0.passed }) { errors.append("截图缺少预期正文") }
} catch { errors.append("读取截图失败：\(error.localizedDescription)") }
let evidence = PixelEvidence(all_pass: errors.isEmpty && !checks.isEmpty, checks: checks, errors: errors)
do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(evidence).write(to: root.appendingPathComponent("ui-pixels.json"), options: .atomic)
} catch { print("保存像素证据失败：\(error)"); exit(1) }
for error in errors { print(error) }
exit(evidence.all_pass ? 0 : 1)
