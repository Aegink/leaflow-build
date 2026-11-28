// 仅-smokeSourceLogin：隔离书源，消费实际书籍详情菜单及登录页。
import SwiftUI

@MainActor
struct SourceLoginSmokeView: View {
    @State private var ready = false
    @State private var failure: String?
    @State private var service = SourceService(storageDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("source-login-smoke"))
    private var source: BookSource {
        var source = BookSource(bookSourceUrl: "https://sample.invalid/source-login", bookSourceName: "登录样本")
        source.loginUi = #"[{"name":"account","type":"text","placeholder":"账号"},{"name":"status","type":"text","placeholder":"状态"},{"name":"apply","type":"button","viewName":"'执行按钮'","action":"apply()"},{"name":"fail","type":"button","viewName":"'失败按钮'","action":"throw new Error('固定失败')"}]"#
        source.loginUrl = """
        @js:function login(){ result.put('status','登录:' + result.get('account')); source.putLoginInfo(result); }
        function apply(){ result.put('status','按钮:' + result.get('account')); source.putLoginInfo(result); }
        """
        return source
    }
    var body: some View {
        NavigationStack {
            if ready {
                BookDetailView(book: Book(bookUrl: source.bookSourceUrl + "/book", name: "固定登录书籍",
                    author: "登录隔离样本", intro: "固定简介", bookSourceUrl: source.bookSourceUrl),
                    availableSources: [], onRead: { _ in }, initialChapters: [], sourceService: service)
            } else if let failure { Text(failure) }
            else { ProgressView("准备登录样本") }
        }
        .task {
            guard !ready else { return }
            do {
                let data = try JSONEncoder().encode([source])
                guard await service.importSourcesAsync(from: String(decoding: data, as: UTF8.self), storageKind: .local) >= 0
                else { throw AppError.parsing("登录样本写盘失败") }
                ready = true
            } catch { failure = error.localizedDescription }
        }
    }
}
