// 原路径: ReadMain/Views/Bookshelf/LocalBookCoverImage.swift
// 证据:
//   - PGO: 13 条记录（index/task_functions.csv T-601-07 /
//     LocalBookCoverImage.swift；伪代码域 216 行）。关键域：
//     LocalBookCoverImage.init(bookId:title:author:fileType:)（签名）/
//     body getter（签名）/ LocalBookCoverMenuLabel.body（0x100486c24
//     L61-84）/ coverMenuImage(UIImage) 0x10048b460 L86-98
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     LocalBookCoverImage.c（216 行）
//   - 字符串域（位模式）："ellipsis" L120 域（菜单域确证）
//   - 事实：封面域（init 四参签名 + LocalBookCoverCache 交叉）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（签名 + 菜单域确证）
// 还原: 2026-11-20

import SwiftUI

/// 本地书封面图（init 四参签名确证）。
struct LocalBookCoverImage: View {

    let bookId: String
    let title: String
    let author: String?
    let fileType: String

    @State private var coverImage: UIImage?

    var body: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.blue.opacity(0.12))
                VStack(spacing: 4.0) {
                    Text(String(title.prefix(1)))
                        .appThemeText(.headline)
                        .foregroundColor(.blue)
                    Text(fileType)
                        .appThemeText(.caption, opacity: 0.5)
                }
            }
        }
        .onAppear {
            Task {
                coverImage = await LocalBookCoverCache.shared.loadCover(
                    for: bookId)
            }
        }
    }
}

/// 本地书封面菜单标签（0x100486c24 L61-84 域确证）。
struct LocalBookCoverMenuLabel: View {

    let bookId: String
    let title: String

    @State private var coverImage: UIImage?

    var body: some View {
        // 0x100486c24 L61-84 域确证。
        Label {
            Text(title)
        } icon: {
            if let coverImage {
                coverMenuImage(coverImage)
            } else {
                Image(systemName: "book.closed")
            }
        }
        .task {
            coverImage = await LocalBookCoverCache.shared.loadCover(
                for: bookId)
        }
    }

    /// coverMenuImage(UIImage)（0x10048b460 L86-98 域确证）。
    private func coverMenuImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 24.0, height: 24.0)
            .cornerRadius(4, antialiased: true)
    }
}
