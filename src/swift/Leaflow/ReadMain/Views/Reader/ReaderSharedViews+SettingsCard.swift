// 原路径: ReadMain/Views/Reader/ReaderSharedViews.swift
// PGO 0x100952240 L467-494：共享设置卡片，原实现迁回原文件分册，调用保持一致。
import SwiftUI

extension View {
    /// settingsCardRow(topGap:action:padding:cornerRadius:label:)
    /// （签名域确证：settingsCardRow<A>(topGap: CGFloat, action:
    /// (() -> ())?, padding: EdgeInsets, cornerRadius: CGFloat,
    /// label: () -> A)）。
    ///
    /// T-1601-A1：**label 域重载**——行内容由 `label` 提供，不引用 `self`。
    /// 修复裸调用（如 `settingsCardRow(topGap: 16) { Picker… }`）隐式
    /// self = 视图自身导致的 **body 自递归栈溢出闪退**；同时修复行内容
    /// 被丢弃渲染为空卡片的问题。
    func settingsCardRow<V: View>(
        topGap: CGFloat = 12,
        action: (() -> Void)? = nil,
        padding: EdgeInsets = EdgeInsets(
            top: 12, leading: 14, bottom: 12, trailing: 14),
        cornerRadius: CGFloat = 14,
        @ViewBuilder label: () -> V
    ) -> some View {
        settingsCard(
            content: label(),
            topGap: topGap, action: action,
            padding: padding, cornerRadius: cornerRadius)
    }

    /// settingsCardRow(topGap:action:padding:cornerRadius:)
    /// **receiver 域重载**——行内容即 `self`（链式调用形态，
    /// 如 `rowContent.settingsCardRow(topGap: 10, padding: …)`）。
    func settingsCardRow(
        topGap: CGFloat = 12,
        action: (() -> Void)? = nil,
        padding: EdgeInsets = EdgeInsets(
            top: 12, leading: 14, bottom: 12, trailing: 14),
        cornerRadius: CGFloat = 14
    ) -> some View {
        settingsCard(
            content: self,
            topGap: topGap, action: action,
            padding: padding, cornerRadius: cornerRadius)
    }

    /// 卡片装配（两形态共用——内容 + 圆角背景 + 可选点按）。
    fileprivate func settingsCard<Content: View>(
        content: Content,
        topGap: CGFloat,
        action: (() -> Void)?,
        padding: EdgeInsets,
        cornerRadius: CGFloat
    ) -> some View {
        let card = Group {
            if #available(iOS 15.0, *) {
                content
                    .padding(padding)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
            } else {
                content
                    .padding(padding)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
        }
        return Group {
            if let action {
                Button {
                    action()
                } label: {
                    card
                }
                .buttonStyle(.plain)
            } else {
                card
            }
        }
        .padding(.top, topGap)
    }

}
