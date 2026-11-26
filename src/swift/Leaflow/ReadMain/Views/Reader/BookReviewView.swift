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
//   - 类型表9166-9173补证：完整source/book/chapter?上下文及errorMessage。
//   - 0x10066773c实际加载，PGO loadReviews标签0x1006679a8是行布局。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（三态 body 主链确证：ProgressView→VStack→List+ForEach+ReviewRow）
// 还原: 2026-11-19

import SwiftUI

/// 书籍评论视图（伪代码 0x10066633c，L13-47）。
/// 加载、错误、空态与评论列表：
///   1. isLoading → ProgressView（closure #1 内层第一个 _ConditionalContent 分支）
///   2. reviews.isEmpty 且已加载 → VStack(appThemeText, appThemeText)（closure #2）
///   3. 有评论 → List<ForEach<BookReview, UUID, ReviewRow>>（closure #3）
struct BookReviewView: View {

    let source: BookSource
    let book: Book
    let chapter: Chapter?
    var request: LocalSourceParser.ReviewRequest? = nil

    @State private var reviews: [BookReview] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// 伪代码 0x10066633c（L13-47）：三态 body。
    var body: some View {
        Group {
            if isLoading {
                // 内层 _ConditionalContent 分支 1：ProgressView。
                ProgressView("加载评论中...")
                    .accessibilityIdentifier("book-review-loading")
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(errorMessage).font(.caption).appThemeText(.body)
                        .accessibilityIdentifier("book-review-error")
                }
                .padding()
            } else if reviews.isEmpty {
                // 内层 _ConditionalContent 分支 2：VStack 空态（closure #2）。
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无评论")
                        .appThemeText(.title, opacity: 0.8)
                }
                .accessibilityIdentifier("book-review-empty")
            } else {
                // 外层 List 分支（closure #3 → ForEach → ReviewRow）。
                List(reviews) { review in
                    ReviewRow(review: review)
                }
                .listStyle(.plain)
                .accessibilityIdentifier("book-review-list")
            }
        }
        .navigationTitle("评论")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReviews()
        }
    }

    /// 伪代码 0x1006679a8（L49-65）：异步加载评论。
    func loadReviews() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            reviews = try await SourceService.shared.getReviews(
                source: source, book: book, chapter: chapter, request: request)
        } catch is CancellationError {
            return
        } catch {
            reviews = []
            errorMessage = error.localizedDescription
        }
    }
}
/// 评论行（伪代码 ReviewRow.body，closure #1/#2）。
struct ReviewRow: View {
    let review: BookReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 类型表4633-4639与0x10066817c：头像28pt及发布时间，不含作者名。
                if let avatar = review.avatar, !avatar.isEmpty, let url = URL(string: avatar) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                        Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                }
                if let time = review.postTime {
                    Text(time).font(.caption2).appThemeText(.body)
                }
                Spacer()
            }
            Text(review.content)
                .font(.subheadline)
                .lineLimit(nil)
            if let quote = review.quote, !quote.isEmpty {
                Text(quote).font(.caption).appThemeText(.body)
                    .padding(6)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
    }
}
