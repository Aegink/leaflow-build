// 原路径: ReadMain/Services/LoginService.swift
// 类型表6401/6409及0x10034d5f0/0x10034db00/0x10034e528：原版字段与宽松标量解码。
import Foundation

struct LoginUiItem: Codable, Identifiable, Hashable {
    var name: String
    var type: String?
    var placeholder: String?
    var value: String?
    var defaultValue: String?
    var viewName: String?
    var chars: [String?]?
    var action: String?
    var style: LoginUiStyle?
    // 旧重建页面仍消费label/values，原版chars保留空位。
    var label: String?
    var values: [String]? { chars?.compactMap { $0 } }
    // TODO(T-1602): 原版身份生成仍需取证，不能把字段解码视为整个模型还原。
    var id: String { name + "/" + (type ?? "") + "/" + (viewName ?? "") }

    var resolvedDefaultValue: String {
        if let defaultValue { return defaultValue }
        let kind = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if kind == "select" || kind == "toggle" { return chars?.compactMap { $0 }.first ?? "" }
        return ""
    }

    var literalViewName: String? {
        // 0x10034d158 / 0x10035c2fc：只有两端单引号的文本是字面值。
        guard let text = viewName?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.count >= 2, text.first == "'", text.last == "'" else { return nil }
        return String(text.dropFirst().dropLast())
    }

    enum CodingKeys: String, CodingKey {
        case name, type, placeholder, value, defaultValue, viewName, chars, action, style, label, values
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? { (try? values.decode(LoginUiScalar.self, forKey: key))?.text }
        name = text(.name) ?? ""
        type = text(.type)
        placeholder = text(.placeholder)
        value = text(.value)
        defaultValue = text(.defaultValue)
        viewName = text(.viewName)
        action = text(.action)
        label = text(.label)
        chars = ((try? values.decode([LoginUiScalar].self, forKey: .chars))
            ?? (try? values.decode([LoginUiScalar].self, forKey: .values)))?.map(\.text)
        style = try? values.decode(LoginUiStyle.self, forKey: .style)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encodeIfPresent(type, forKey: .type)
        try values.encodeIfPresent(placeholder, forKey: .placeholder)
        try values.encodeIfPresent(value, forKey: .value)
        try values.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try values.encodeIfPresent(viewName, forKey: .viewName)
        try values.encodeIfPresent(chars, forKey: .chars)
        try values.encodeIfPresent(action, forKey: .action)
        try values.encodeIfPresent(style, forKey: .style)
        try values.encodeIfPresent(label, forKey: .label)
    }
}

/// 无效的嵌套值必须消费，数组后面的有效选项不能因此丢失。
private struct LoginUiScalar: Decodable {
    let text: String?
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { text = nil }
        else if let string = try? value.decode(String.self) { text = string }
        else if let integer = try? value.decode(Int.self) { text = String(integer) }
        else if let double = try? value.decode(Double.self) { text = String(double) }
        else if let bool = try? value.decode(Bool.self) { text = bool ? "true" : "false" }
        else if (try? value.decode([LoginUiScalar].self)) != nil { text = nil }
        else if (try? value.decode([String: LoginUiScalar].self)) != nil { text = nil }
        else { throw DecodingError.dataCorruptedError(in: value, debugDescription: "无法消费登录字段") }
    }
}

struct LoginUiStyle: Codable, Hashable {
    var layoutFlexGrow: Double?
    var layoutFlexShrink: Double?
    var layoutFlexBasisPercent: Double?
    var layoutWrapBefore: Bool?
    var layoutJustifySelf: String?
    var backgroundColor: String?
    var buttonColor: String?

    enum CodingKeys: String, CodingKey {
        case layoutFlexGrow, layoutFlexShrink, layoutFlexBasisPercent, layoutWrapBefore, layoutJustifySelf
        case backgroundColor, buttonColor
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys) -> Double? {
            if let number = try? values.decode(Double.self, forKey: key) { return number }
            if let string = try? values.decode(String.self, forKey: key) { return Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
            return nil
        }
        layoutFlexGrow = number(.layoutFlexGrow)
        layoutFlexShrink = number(.layoutFlexShrink)
        layoutFlexBasisPercent = number(.layoutFlexBasisPercent)
        if let bool = try? values.decode(Bool.self, forKey: .layoutWrapBefore) { layoutWrapBefore = bool }
        else if let integer = try? values.decode(Int.self, forKey: .layoutWrapBefore) { layoutWrapBefore = integer != 0 }
        else if let string = try? values.decode(String.self, forKey: .layoutWrapBefore) {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes": layoutWrapBefore = true
            case "false", "0", "no": layoutWrapBefore = false
            default: layoutWrapBefore = nil
            }
        }
        layoutJustifySelf = try? values.decode(String.self, forKey: .layoutJustifySelf)
        backgroundColor = try? values.decode(String.self, forKey: .backgroundColor)
        buttonColor = try? values.decode(String.self, forKey: .buttonColor)
    }
}
