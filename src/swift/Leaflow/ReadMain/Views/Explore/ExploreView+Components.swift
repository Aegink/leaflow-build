// 原路径: ReadMain/Views/Explore/ExploreView.swift
// 发现首页站点与书源行/网格组件，机械拆分保留原归属。
import SwiftUI
import UIKit

// MARK: - 行/格视图

/// 浏览器站点行（0x1005cd834 L830-860 域确证）。
struct BrowserSiteRow: View {
    let site: BrowserSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10.0) {
                Image(systemName: "safari")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(site.name).lineLimit(1)
                    Text(site.displayURL)
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 添加站点面板（canSave 0x1005ce39c + body 0x1005ce75c 域确证）。
struct AddBrowserSiteSheet: View {
    @ObservedObject var store: BrowserSiteStore
    @State private var name: String = ""
    @State private var rawURL: String = ""
    @Environment(\.dismiss) private var dismiss

    /// canSave getter（0x1005ce39c L869-871 域确证）。
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && BrowserSite.normalizedURL(from: rawURL) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("添加站点") {
                    TextField("名称", text: $name)
                    TextField("https://…", text: $rawURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("添加站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.addSite(
                            name: name.trimmingCharacters(in: .whitespaces),
                            rawURL: rawURL)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

/// 书源行（0x1005cfecc L914-983 域确证）。
struct ExploreSourceRow: View {
    let source: BookSource

    /// simplifiedUrl（签名确证）。
    private func simplifiedUrl(_ url: String) -> String {
        var trimmed = url
        for prefix in ["https://", "http://"] where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    var body: some View {
        NavigationLink {
            ExploreSourceFeedView(source: source)
        } label: {
            HStack(spacing: 10.0) {
                ExploreHomeIcon(source: source)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(source.bookSourceName).lineLimit(1)
                    Text(simplifiedUrl(source.bookSourceUrl))
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }
}

/// 主页图标（iconText/defaultCover/body 签名域确证）。
struct ExploreHomeIcon: View {
    let source: BookSource

    /// iconText getter（0x1005d1b00 L1011-1014 域确证）。
    private var iconText: String {
        String(source.bookSourceName.prefix(1))
    }

    /// defaultCover getter（0x1005d1cb8 L1016-1020 域确证）。
    private var defaultCover: UIImage? {
        nil
    }

    var body: some View {
        // 0x1005d1cd0 L1022-1044 域确证。
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.15))
            Text(iconText)
                .appThemeText(.headline)
                .foregroundColor(.blue)
        }
        .frame(width: 40.0, height: 40.0)
        .modifier(ExploreHomeIconSizing())
    }
}

/// 图标尺寸修饰（0x1005d2830 L1052-1061 域确证）。
struct ExploreHomeIconSizing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 40.0, height: 40.0)
            .cornerRadius(8, antialiased: true)
    }
}

/// 站点网格格（0x1005d31ac L1071-1097 域确证）。
struct BrowserSiteGridCell: View {
    let site: BrowserSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6.0) {
                Image(systemName: "safari")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(site.name)
                    .appThemeText(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14.0)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }
}

/// 书源网格格（0x1005d32c0 L1109-1149 域确证）。
struct ExploreSourceGridCell: View {
    let source: BookSource

    var body: some View {
        NavigationLink {
            ExploreSourceFeedView(source: source)
        } label: {
            VStack(spacing: 6.0) {
                ExploreHomeIcon(source: source)
                Text(source.bookSourceName)
                    .appThemeText(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10.0)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// glassBookCardStyle（0x1004c1f94 L1304-1306 域确证）。
    func glassBookCardStyle() -> some View {
        self
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension View {

    /// 伪代码 0x1008f6e14（L1181-1208）：玻璃芯片样式（发现页顶栏域）。
    func glassChipStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppThemeSurface.fill(opacity: 0.9, followsAppearance: true))
            .clipShape(Capsule())
    }
}
