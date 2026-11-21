// 原路径: ReadMain/Views/Bookshelf/BookEditView.swift
// 证据:
//   - PGO: 37 条记录（index/task_functions.csv T-601-05 /
//     BookEditView.swift；伪代码域 2346 行）。关键地址：
//     body 0x100416c84 L18-109 / coverPreview 0x1004198bc L114-142 /
//     saveLocalCover 0x10041b988 L170-190 / saveBook（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/BookEditView.c
//     （2346 行）
//   - 字符串确证（位模式/指针）："书籍信息" L104/"[BookEdit] 保存封面失败: "
//     @ptr L421/"封面图片 URL" @ptr L510/"从配置获取封面" @ptr L578/
//     "清除已选图片" @ptr L601/"BookCovers" L2293 域（照片选择域）/
//     "book.closed" L1982 图标域
//   - 事实：body 三 Section 域（书架 listRowBackground + 书籍信息
//     keyboardType/PhotosPicker/Button 组 + 书名/作者 HStack(框架+TextField)
//     确证）；封面域（PhotosPicker + saveLocalCover + coverPreview）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + Section 域串确证）
// 还原: 2026-11-20

import SwiftUI
import PhotosUI

/// 书籍编辑视图（0x100416c84 L18-109 域确证）。
struct BookEditView: View {

    let book: Book
    let isLocal: Bool
    let onSaved: (Book) -> Void

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var coverURLText: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedCover: UIImage?
    @State private var showCoverConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Section1：封面预览（coverPreview L114-142 域确证）。
                Section {
                    coverPreview
                }
                // Section2（"书籍信息" L104 域确证）：名称/作者域。
                Section("书籍信息") {
                    HStack(spacing: 8.0) {
                        Text("书名")
                            .frame(width: 48.0, alignment: .leading)
                        TextField("书名", text: $title)
                    }
                    HStack(spacing: 8.0) {
                        Text("作者")
                            .frame(width: 48.0, alignment: .leading)
                        TextField("作者", text: $author)
                    }
                }
                // Section3（封面域确证）：URL + 照片选择 + 从配置获取。
                Section("封面") {
                    HStack(spacing: 8.0) {
                        Image(systemName: "link")
                            .frame(width: 20.0)
                        TextField("封面图片 URL", text: $coverURLText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images) {
                        Label("从相册选择", systemImage: "photo")
                    }
                    Button {
                        selectedCover = nil
                    } label: {
                        Label("清除已选图片", systemImage: "xmark.bin")
                    }
                }
            }
            .navigationTitle("编辑配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveBook() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = book.name
                author = book.author ?? ""
                coverURLText = book.coverUrl ?? ""
            }
            .onChange(of: selectedPhoto) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(
                        type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedCover = image
                        }
                    }
                }
            }
        }
    }

    /// coverPreview getter（0x1004198bc L114-142 域确证）。
    @ViewBuilder
    private var coverPreview: some View {
        HStack {
            Spacer()
            if let selectedCover {
                Image(uiImage: selectedCover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100.0, height: 140.0)
                    .cornerRadius(8, antialiased: true)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 100.0, height: 140.0)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
            }
            Spacer()
        }
    }

    // MARK: 保存

    /// saveBook（签名确证）。
    private func saveBook() {
        var updated = book
        updated.name = title
        updated.author = author.isEmpty ? nil : author
        if let selectedCover {
            saveLocalCover(selectedCover, bookId: updated.id)
            updated.coverUrl = updated.id  // 本地封面键
        } else if !coverURLText.isEmpty {
            updated.coverUrl = coverURLText
        } else {
            updated.coverUrl = nil
        }
        onSaved(updated)
        dismiss()
    }

    /// saveLocalCover（0x10041b988 L170-190 域确证；
    /// "[BookEdit] 保存封面失败: " @ptr L421 域确证）。
    private func saveLocalCover(_ image: UIImage, bookId: String) {
        guard let data = image.pngData() else {
            Logger.log("[BookEdit] 保存封面失败: pngData", level: .error)
            return
        }
        // LocalBookCoverCache 交叉（T-601-04）。
        LocalBookCoverCache.shared.saveCover(data: data, for: bookId)
    }
}
