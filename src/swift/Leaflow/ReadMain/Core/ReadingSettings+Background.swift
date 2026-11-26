// 原始归属: ReadMain/Core/ReadingSettings.swift。
// 类型表3428与0x100215024读取offset 0xC8，ReadingSettings.c:3741写Color.white。
// ReaderContentBackground 0x10079984c先取背景图片，否则取此背景色，不能复用正文色。
import SwiftUI
import UIKit

extension ReadingSettings {
    var backgroundColor: Color {
        backgroundColorHex.isEmpty ? .white : leaflowColor(backgroundColorHex)
    }

    var readerBackgroundUIColor: UIColor { UIColor(backgroundColor) }
}
