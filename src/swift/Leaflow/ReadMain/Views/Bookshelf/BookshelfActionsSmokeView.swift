// T-1602：仅 -smokeBookActions 使用固定书籍；真实卡片/操作表，阅读和删除替换为结果回执。
import SwiftUI

struct BookshelfActionsSmokeView: View {
    private let book = Book(bookUrl: "https://sample.invalid/bookshelf", name: "固定书架样本", author: "测试作者")
    @State private var result = "未执行"
    @State private var isEditing = false
    @State private var isSelected = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if ProcessInfo.processInfo.arguments.contains("-smokeBookGrid") {
                    BookGridItem(book: book, isSelected: isSelected, isEditing: isEditing,
                        onDelete: { result = "已删除" }, onOpenReader: read, onTap: tap)
                        .frame(width: 160)
                } else {
                    BookCardItem(book: book, cardHeight: 90, isSelected: isSelected, isEditing: isEditing,
                        onDelete: { result = "已删除" }, onOpenReader: read, onTap: tap)
                }
                Text(result).accessibilityIdentifier("bookshelf-action-result")
                Text(isSelected ? "已选择样本" : "未选择样本").accessibilityIdentifier("bookshelf-selection-result")
                Spacer()
            }
            .padding()
            .navigationTitle("书架操作验证")
            .toolbar { Button(isEditing ? "完成" : "编辑") { isEditing.toggle() } }
        }
    }

    private func read(_ selected: Book) { result = "已请求阅读：\(selected.name)" }
    private func tap() {
        if isEditing { isSelected.toggle() }
        else { read(book) }
    }
}
