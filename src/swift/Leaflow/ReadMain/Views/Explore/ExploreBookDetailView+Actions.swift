// 原路径: ReadMain/Views/Explore/ExploreBookDetailView.swift
// 本分册仍计入原文件的规模、桩与样本门禁。
import SwiftUI

extension BookDetailView {
    // MARK: 菜单

    /// moreMenu（0x1004db150 L364-436 域确证；七按钮 TupleView 域确证）。
    var moreMenu: some View {
        Menu {
            // "配置登录" L3546。
            Button {
                // TODO(T-401-06): SourceLoginView 接入（source:sourceStateSource）。
            } label: {
                Label("配置登录", systemImage: "person.badge.key")
            }
            // "源变量" L3597。
            Button {
                sourceVariableText = currentSourceVariable()
                showVariableEditor = true
            } label: {
                Label("源变量", systemImage: "variable")
            }
            // "书籍变量" L3648。
            Button {
                bookVariableText = displayBook.getVariable("custom") ?? ""
                showBookVariableEditor = true
            } label: {
                Label("书籍变量", systemImage: "book.closed")
            }
            // "更多书架操作" @ptr L3708。
            Button {
                showGroupPicker = true
            } label: {
                Label("更多书架操作", systemImage: "folder.badge.gearshape")
            }
            // "在浏览器中打开" @ptr L13066。
            Button {
                if let url = URL(string: displayBook.bookUrl ?? "") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("在浏览器中打开", systemImage: "safari")
            }
            // 类型切换 + 更新跳过（"bookType"/"skipUpdate" 域确证）。
            Menu("书籍类型") {
                ForEach(bookTypeOptions, id: \.value) { option in
                    Button(option.title) {
                        applyBookTypeSelection(option.value)
                    }
                }
            }
            Button {
                toggleSkipUpdate()
            } label: {
                Label(updateToggleValue, systemImage: "bell")
            }
            Divider()
            // "清除源变量" L12144。
            Button(role: .destructive) {
                clearSourceVariable()
            } label: {
                Label("清除源变量", systemImage: "xmark.bin")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("book-detail-menu")
        .disabled(!ready)
    }

    /// applyBookTypeSelection（0x1004babc4 L339-350 域确证）。
    func applyBookTypeSelection(_ value: Int) {
        commitBookChange(BookDetailState.selectingType(value, in: displayBook))
    }

    /// toggleSkipUpdate（0x1004bdfbc L352-360 域确证；"skipUpdate" L3058）。
    func toggleSkipUpdate() {
        commitBookChange(BookDetailState.togglingUpdate(in: displayBook))
    }

    /// bookshelfGroupPickerTitle getter（签名确证）。
    var bookshelfGroupPickerTitle: String {
        "选择分组"
    }

    /// bookshelfGroupPicker（分组选择；applyBookshelfGroupSelection 消费）。
    var bookshelfGroupPicker: some View {
        SourceGroupPickerSheet(
            existingGroups: bookService.groups,
            mergeSourceGroup: "") { group in
            applyBookshelfGroupSelection(group)
        }
    }

    /// applyBookshelfGroupSelection（0x1004b87c8 L527-550 域确证）。
    func applyBookshelfGroupSelection(_ group: String?) {
        let normalized = BookDetailState.normalizedGroup(group)
        if let normalized { bookService.addGroup(name: normalized) }
        if !isInBookshelf {
            guard bookService.addBook(displayBook, useReplaceRule: true, preferredCoverUrl: nil) else { return }
        }
        guard let stored = bookshelfBook else { return }
        bookService.setBookGroup(bookId: stored.id, groupName: normalized)
        showGroupPicker = false
    }

    // MARK: 变量编辑器

    /// variableEditorSheet（0x1004b8298 L1023-1072 域确证；"源变量" L3597）。
    var variableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("源变量")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $sourceVariableText)
                    .accessibilityIdentifier("book-detail-source-variable")
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveSourceVariable() }
                    .accessibilityIdentifier("book-detail-save-source-variable")
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("源变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showVariableEditor = false }
                }
            }
        }
    }

    /// bookVariableEditorSheet（0x1004b91a8 L1076-1125 域确证；
    /// "书籍变量 (bookVariable)" @ptr L12675）。
    var bookVariableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("书籍变量 (bookVariable)")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $bookVariableText)
                    .accessibilityIdentifier("book-detail-book-variable")
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveBookVariable() }
                    .accessibilityIdentifier("book-detail-save-book-variable")
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("书籍变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showBookVariableEditor = false }
                }
            }
        }
    }

    /// saveSourceVariable（0x1004d0cd0 L1164-1171 域确证）。
    func saveSourceVariable() {
        BookDetailState.saveSourceVariable(sourceVariableText, source: sourceStateSource)
        showVariableEditor = false
    }

    /// saveBookVariable（0x1004d2be0 L1129-1141 域确证）。
    func saveBookVariable() {
        commitBookChange(BookDetailState.settingCustomVariable(bookVariableText, in: displayBook))
        showBookVariableEditor = false
    }

    /// clearSourceVariable（"清除源变量" L12144 域确证）。
    func clearSourceVariable() {
        BookDetailState.saveSourceVariable("", source: sourceStateSource)
        sourceVariableText = ""
    }

    func commitBookChange(_ updated: Book) {
        let wasInBookshelf = isInBookshelf
        baseBook = updated
        if wasInBookshelf { bookService.updateBook(updated) }
        syncAuxiliaryState(with: updated)
    }

}
