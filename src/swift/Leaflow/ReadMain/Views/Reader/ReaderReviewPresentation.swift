// 原始归属: ReadMain/Views/Reader/ReaderViewModifiers.swift
// 0x1008a15ac L453-464：完整书源/书籍/当前可选章节，NavigationStack承载评论。
import SwiftUI

struct ReaderReviewPresentationModifier: ViewModifier {
    let vm: ReaderViewModel
    @Binding var showReview: Bool
    var request: LocalSourceParser.ReviewRequest? = nil

    func body(content: Content) -> some View {
        content.sheet(isPresented: $showReview) {
            if let source = vm.currentBookSource, let book = vm.currentBook {
                NavigationStack {
                    BookReviewView(source: source, book: book,
                        chapter: vm.chapters.indices.contains(vm.currentChapterIndex)
                            ? vm.chapters[vm.currentChapterIndex] : nil, request: request)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { showReview = false }
                                    .accessibilityIdentifier("book-review-close")
                            }
                        }
                }
            }
        }
    }
}
