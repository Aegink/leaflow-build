// 原路径: ReadMain/Core/ReaderLayoutConfig.swift
// 类型表3043/3116及0x1001ef908：原版组件11字段，只有textAlignment允许缺省为left。
import Foundation
import CoreGraphics

struct LayoutWidget: Codable, Identifiable, Equatable {
    var id: UUID
    // 保留原版条目的原始字符串，未实现的显示种类也不能在备份往返中丢失。
    var item: String
    var xPercent: CGFloat
    var yPercent: CGFloat
    var fontSize: CGFloat
    var opacity: CGFloat
    var customColorHex: String?
    var customText: String?
    var customDateFormat: String?
    var pageScope: WidgetPageScope
    var textAlignment: WidgetTextAlignment

    init(id: UUID = UUID(), item: String, xPercent: CGFloat, yPercent: CGFloat,
         fontSize: CGFloat = 12, opacity: CGFloat = 0.85, customColorHex: String? = nil,
         customText: String? = nil, customDateFormat: String? = nil,
         pageScope: WidgetPageScope = .allPages, textAlignment: WidgetTextAlignment = .leading) {
        self.id = id
        self.item = item
        self.xPercent = xPercent
        self.yPercent = yPercent
        self.fontSize = fontSize
        self.opacity = opacity
        self.customColorHex = customColorHex
        self.customText = customText
        self.customDateFormat = customDateFormat
        self.pageScope = pageScope
        self.textAlignment = textAlignment
    }

    init(type: String, alignment: WidgetTextAlignment, showOnFirstPage: Bool) {
        let names = ["time": "currentTime", "battery": "batteryLevel", "progress": "pageProgress", "chapter": "chapterTitle"]
        self.init(item: names[type] ?? type, xPercent: alignment == .leading ? 0.08 : alignment == .center ? 0.5 : 0.92,
            yPercent: 0.96, pageScope: showOnFirstPage ? .allPages : .normalPageOnly, textAlignment: alignment)
    }

    var type: String {
        ["currentTime": "time", "batteryLevel": "battery", "pageProgress": "progress"][item] ?? item
    }
    var alignment: WidgetTextAlignment { textAlignment }
    var showOnFirstPage: Bool { pageScope.shouldShow(isFirstPage: true) }

    enum CodingKeys: String, CodingKey {
        case id, item, xPercent, yPercent, fontSize, opacity, customColorHex, customText, customDateFormat, pageScope, textAlignment
        case type, alignment, showOnFirstPage
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if !values.contains(.item), let legacy = try values.decodeIfPresent(String.self, forKey: .type) {
            let alignment = try values.decodeIfPresent(String.self, forKey: .alignment) ?? "leading"
            self.init(type: legacy, alignment: alignment == "trailing" || alignment == "right" ? .trailing : alignment == "center" ? .center : .leading,
                showOnFirstPage: try values.decodeIfPresent(Bool.self, forKey: .showOnFirstPage) ?? true)
            return
        }
        id = try values.decode(UUID.self, forKey: .id)
        item = try values.decode(String.self, forKey: .item)
        xPercent = try values.decode(CGFloat.self, forKey: .xPercent)
        yPercent = try values.decode(CGFloat.self, forKey: .yPercent)
        fontSize = try values.decode(CGFloat.self, forKey: .fontSize)
        opacity = try values.decode(CGFloat.self, forKey: .opacity)
        customColorHex = try values.decodeIfPresent(String.self, forKey: .customColorHex)
        customText = try values.decodeIfPresent(String.self, forKey: .customText)
        customDateFormat = try values.decodeIfPresent(String.self, forKey: .customDateFormat)
        pageScope = try values.decode(WidgetPageScope.self, forKey: .pageScope)
        textAlignment = try values.decodeIfPresent(WidgetTextAlignment.self, forKey: .textAlignment) ?? .leading
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(item, forKey: .item)
        try values.encode(xPercent, forKey: .xPercent)
        try values.encode(yPercent, forKey: .yPercent)
        try values.encode(fontSize, forKey: .fontSize)
        try values.encode(opacity, forKey: .opacity)
        try values.encodeIfPresent(customColorHex, forKey: .customColorHex)
        try values.encodeIfPresent(customText, forKey: .customText)
        try values.encodeIfPresent(customDateFormat, forKey: .customDateFormat)
        try values.encode(pageScope, forKey: .pageScope)
        try values.encode(textAlignment, forKey: .textAlignment)
    }

    /// 0x1007655ec：水平方向按文本对齐移动锚点并钳制，垂直按中心锚点放置。
    func frame(contentSize: CGSize, pageSize: CGSize) -> CGRect {
        let width = min(max(0, contentSize.width), max(0, pageSize.width))
        let anchor = pageSize.width * xPercent
        let offset = textAlignment == .leading ? 0 : textAlignment == .center ? width / 2 : width
        let x = max(0, min(max(0, pageSize.width - width), anchor - offset))
        return CGRect(x: x, y: pageSize.height * yPercent - contentSize.height / 2, width: width, height: contentSize.height)
    }
}
