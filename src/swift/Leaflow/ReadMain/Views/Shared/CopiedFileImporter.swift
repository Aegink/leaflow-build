// 原路径: ReadMain/Views/Shared/CopiedFileImporter.swift
// 证据:
//   - PGO: 13 个主函数（index/task_functions.csv T-101-06 / CopiedFileImporter.swift），
//     地址：copiedFileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:
//     onSelection:) 扩展 0x100441a98 L70-82（+closure 链：URL → CopiedImportFile）/
//     CopiedFilePicker.makeCoordinator/makeUIViewController/makeDocumentPicker/
//     updateUIViewController/Coordinator.init/documentPicker/didPickDocumentsAt/
//     documentPickerWasCancelled（签名确证）；CopiedImportFile 本体属
//     CopiedFileImportService（T-901-03 分册，init(pickerCopy:)/init(url:directory:) 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/CopiedFileImporter.c（870 行）
//   - 事实：copiedFileImporter —— fileImporter 包装：URL → CopiedImportFile(pickerCopy:)
//     映射（closure 链确证）→ onSelection 回调；CopiedFilePicker ——
//     UIDocumentPickerViewController Representable（Coordinator didPick/WasCancelled 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（包装链/Coordinator 确证）
// 还原: 2026-11-19

import SwiftUI
import UniformTypeIdentifiers

/// 文件选择 Representable（签名确证）。
struct CopiedFilePicker: UIViewControllerRepresentable {

    var allowedContentTypes: [UTType]
    var allowsMultipleSelection: Bool
    var onDocumentsPicked: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsPicked: onDocumentsPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        makeDocumentPicker(coordinator: context.coordinator)
    }

    func updateUIViewController(
        _ picker: UIDocumentPickerViewController, context: Context
    ) {}

    /// 伪代码 makeDocumentPicker：组装选择器。
    /// coordinator 经参数注入（makeUIViewController 上下文域，wave-16）。
    private func makeDocumentPicker(
        coordinator: Coordinator
    ) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = coordinator
        return picker
    }

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {

        let onDocumentsPicked: ([URL]) -> Void

        init(onDocumentsPicked: @escaping ([URL]) -> Void) {
            self.onDocumentsPicked = onDocumentsPicked
        }

        /// 伪代码 documentPicker(_:didPickDocumentsAt:)（签名确证）。
        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onDocumentsPicked(urls)
        }

        /// 伪代码 documentPickerWasCancelled（签名确证）。
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // 取消无需回调。
        }
    }
}

extension View {

    /// 伪代码 0x100441a98（L70-82）+ closure 链：
    /// fileImporter 包装；URL → CopiedImportFile(pickerCopy:) 映射 → onSelection。
    func copiedFileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        allowsMultipleSelection: Bool,
        onSelection: @escaping (Result<[CopiedImportFile], Error>) -> Void
    ) -> some View {
        fileImporter(
            isPresented: isPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection)
        { result in
            switch result {
            case .success(let urls):
                let files = urls.map { CopiedImportFile(pickerCopy: $0) }
                onSelection(.success(files))
            case .failure(let error):
                onSelection(.failure(error))
            }
        }
    }

    /// 单文件便捷重载（骨架签名 copiedFileImporter(isPresented:allowedContentTypes:
    /// onCompletion:) 确证）。
    func copiedFileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        onCompletion: @escaping (Result<URL, Error>) -> Void
    ) -> some View {
        fileImporter(
            isPresented: isPresented,
            allowedContentTypes: allowedContentTypes)
        { result in
            onCompletion(result)
        }
    }
}


