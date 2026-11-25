// T-1602：消费生产待阅读请求，核验关闭时序、一次性与完整书籍载荷。
import Foundation

enum BookshelfActionSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let selected = Book(bookUrl: "https://sample.invalid/book/7", name: "编辑后书名",
            author: "样本作者", bookSourceUrl: "https://sample.invalid/source-a")
        var pending: Book? = selected
        let blocked = NetworkBookReaderRequest.takePending(isPresented: true, pending: &pending)
        emit("bookshelf_reader_deferred", ["true", "true"], [String(blocked == nil), String(pending != nil)])
        let taken = NetworkBookReaderRequest.takePending(isPresented: false, pending: &pending)
        emit("bookshelf_reader_payload", [selected.id, selected.name, selected.bookSourceUrl ?? ""],
            [taken?.id ?? "", taken?.name ?? "", taken?.bookSourceUrl ?? ""])
        let repeated = NetworkBookReaderRequest.takePending(isPresented: false, pending: &pending)
        emit("bookshelf_reader_once", ["true", "true"], [String(pending == nil), String(repeated == nil)])
        var cancelled: Book?
        emit("bookshelf_reader_cancelled", ["true"],
            [String(NetworkBookReaderRequest.takePending(isPresented: false, pending: &cancelled) == nil)])
    }
}
