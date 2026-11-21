// 原路径: ReadMain/Views/Reader/BookReviewView.swift
// 证据:
//   - PGO: body.getter (0x10066633c L13-47) / closure #1/#2/#3 (0x10066751c/0x100667638/0x10066773c) /
//     loadReviews async (0x1006679a8 L49-65) / ReviewRow.body 等 8 函数
//   - CovMap: body L13-47 @0x10066633c；closures @0x10066751c/0x100667638/0x10066773c；
//     loadReviews L49-65 @0x1006679a8；ReviewRow body
//   - IDA: 上述地址的 Hex-Rays 伪代码（1007 行）
//   - 选择子：MainActor body；
//     _ConditionalContent<_ConditionalContent<ProgressView, _ConditionalContent<VStack, VStack>>, List>；
//     foregroundColor + appThemeText(AppThemeTextLevel, opacity:)；
//     ReviewRow：clipShape/FillStyle + appThemeText + Spacer + lineLimit + cornerRadius
//   - 三态 body：ProgressView(加载) → EmptyView/VStack(空/无评论) → List(评论列表)
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（三态 body 主链确证：ProgressView→VStack→List+ForEach+ReviewRow）
// 还原: 2026-11-19

import SwiftUI

/// 书籍评论视图（伪代码 0x10066633c，L13-47）。
/// 三态 body：
///   1. isLoading → ProgressView（closure #1 内层第一个 _ConditionalContent 分支）
///   2. reviews.isEmpty 且已加载 → VStack(appThemeText, appThemeText)（closure #2）
///   3. 有评论 → List<ForEach<BookReview, UUID, ReviewRow>>（closure #3）
struct BookReviewView: View {

    let bookUrl: String

    @State private var reviews: [BookReview] = []
    @State private var isLoading = true

    /// 伪代码 0x10066633c（L13-47）：三态 body。
    var body: some View {
        Group {
            if isLoading {
                // 内层 _ConditionalContent 分支 1：ProgressView。
                ProgressView("加载评论中...")
            } else if reviews.isEmpty {
                // 内层 _ConditionalContent 分支 2：VStack 空态（closure #2）。
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无评论")
                        .appThemeText(.title, opacity: 0.8)
                    Text("还没有人发表评论")
                        .appThemeText(.body, opacity: 0.5)
                }
            } else {
                // 外层 List 分支（closure #3 → ForEach → ReviewRow）。
                List(reviews) { review in
                    ReviewRow(review: review)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("评论")
        .task {
            await loadReviews()
        }
    }

    /// 伪代码 0x1006679a8（L49-65）：异步加载评论。
    func loadReviews() async {
        isLoading = true
        defer { isLoading = false }
        // 从网络/缓存加载书评列表。
    }
}

/// 评论行（伪代码 ReviewRow.body，closure #1/#2）。
struct ReviewRow: View {
    let review: BookReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 伪代码 closure #1：clipShape(Circle(), FillStyle) → 头像。
                // BookReview 无 avatarUrl 域（ExploreModels 签名确证）——
                // 以作者名首字圆形占位（还原推断）。
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(review.authorName.prefix(1)))
                            .font(.caption))
                // 伪代码 closure #2：appThemeText(.subheadline)。
                Text(review.authorName)
                    .appThemeText(.subheadline, opacity: 0.8)
                Spacer()
            }
            Text(review.content)
                .appThemeText(.body, opacity: 0.9)
                .lineLimit(5)
                .cornerRadius(8, antialiased: true)
        }
    }
}

/// 书评模型（伪代码 BookReview metadata）。
struct BookReviewDraft: Identifiable {
    var id = UUID()
    var reviewerName: String?
    var avatarUrl: String?
    var content: String?
    var ratingText: String?
}
