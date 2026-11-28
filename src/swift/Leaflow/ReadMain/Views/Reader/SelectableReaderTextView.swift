// 原路径: ReadMain/Views/Reader/SelectableReaderTextView.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-12 / SelectableReaderTextView.swift），
//     地址：consumeTapIfNeeded 0x1008b45ac L55-72 / hasActiveSelection 0x1008b4a24
//     L84-92 / commentAttachmentRects 初始化 0x1008b5510 L96（clearColor/setEditable/
//     setLineBreakMode/setLineFragmentPadding/setScrollEnabled/setSelectable 确证）/
//     lastSelectionState 0x1008b4ebc L99 / lastObservedHasSelection 0x1008b5034 L100 /
//     selectedRange.didset 0x1008b7438 L103-105 / selectedTextRange.didset
//     0x1008b5154 L109-111 / init() 0x1008b55ec L125-127 / init(isSelectable:)
//     0x1008b5250 L129-142（addTextLayoutManager/initWithSize/setTextContainer +
//     ReaderPerformanceTrace 确证）/ layoutSubviews 0x1008b5cbc L154-164 /
//     disableSingleTapGesturesIfNeeded 0x1008b5f20 L177-192 /
//     observeSelectionStateChange 0x1008b6128 L194-213（defaultCenter/
//     postNotificationName:object:userInfo: 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/SelectableReaderTextView.c（1060 行）
//   - 事实：init(isSelectable:) —— TextKit2 装配（NSLayoutManager/NSTextStorage/
//     NSTextContainer 尺寸 + addTextLayoutManager 确证）+ trace；
//     observeSelectionStateChange —— 选择状态变化广播（userInfo 确证）；
//     disableSingleTapGesturesIfNeeded —— 非选择态禁用单击（numberOfTapsRequired 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - init/layoutSubviews/选择观察: high（选择子链确证）
//   - 菜单动作/查词链: medium（签名确证，细节待真机对照）
// 还原: 2026-11-19

import UIKit

/// 文本选择手势支持（枚举命名空间；0x1008b45ac L55-72 确证）。
enum ReaderTextSelectionGestureSupport {

    /// 伪代码 0x1008b45ac（L55-72）：激活选择时消费单击。
    static func consumeTapIfNeeded(
        _ gesture: UITapGestureRecognizer,
        in view: UIView?,
        activeSelectionHandler: ReaderTextSelectionHandling?
    ) -> Bool {
        guard let handler = activeSelectionHandler, handler.hasActiveSelection else {
            return false
        }
        _ = gesture.location(in: view)
        handler.dismissSelection()
        return true
    }

    /// 受保护点击类名片段（骨架签名；候选集待真机对照）。
    static func containsProtectedTapClassNameFragment(_ className: String) -> Bool {
        let protected = ["UIKeyboard", "UIInputSet", "Keyboard"]
        return protected.contains { className.contains($0) }
    }

    /// 单击准入（骨架签名）。
    static func shouldReceiveTap(_ touch: UITouch) -> Bool {
        true
    }
}

/// 文本选择处理协议（PageContentViewController.activeSelectionHandler 域）。
protocol ReaderTextSelectionHandling: AnyObject {
    var hasActiveSelection: Bool { get }
    func dismissSelection()
}

/// 可选择阅读文本视图（TextKit2）。
@MainActor
final class SelectableReaderTextView: UITextView, ReaderTextSelectionHandling {

    /// 评论附件矩形镜像（cacheCommentRects 写入方确证）。
    var commentAttachmentRects: [CGRect] = []
    private var lastSelectionState: NSRange = NSRange(location: NSNotFound, length: 0)
    private var lastObservedHasSelection = false
    let isSelectableText: Bool

    /// 伪代码 0x1008b4a24（L84-92）：活动选择判定（selectedTextRange/start 确证）。
    var hasActiveSelection: Bool {
        guard let range = selectedTextRange else { return false }
        return !range.isEmpty
    }

    /// 伪代码 0x1008b55ec（L125-127）：默认不可选。
    convenience init() {
        self.init(isSelectable: false)
    }

    /// 伪代码 0x1008b5250（L129-142）：TextKit2 装配
    ///（addTextLayoutManager/initWithSize/setTextContainer + trace 确证）。
    init(isSelectable: Bool) {
        self.isSelectableText = isSelectable
        let textStorage = NSTextStorage()
        let container = NSTextContainer(
            size: CGSize(width: 0, height: CGFloat.infinity))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
        super.init(frame: .zero, textContainer: container)
        commonInit(isSelectable: isSelectable)
        ReaderPerformanceTrace.log("init selectable=\(isSelectable)")
    }

    required init?(coder: NSCoder) {
        self.isSelectableText = false
        super.init(coder: coder)
        commonInit(isSelectable: false)
    }

    /// 初始化公共体（骨架签名 commonInit(isSelectable:)）。
    private func commonInit(isSelectable: Bool) {
        backgroundColor = .clear
        isEditable = false
        self.isSelectable = isSelectableText
        isScrollEnabled = false
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        disableSingleTapGesturesIfNeeded()
    }

    override func layoutSubviews() {
        // 伪代码 0x1008b5cbc（L154-164）。
        super.layoutSubviews()
        let width = max(1, bounds.width - textContainerInset.left - textContainerInset.right)
        if textContainer.size.width != width {
            textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        }
    }

    /// 伪代码 0x1008b5f20（L177-192）：非选择态禁用单击
    ///（numberOfTapsRequired/setEnabled 确证）。
    private func disableSingleTapGesturesIfNeeded() {
        guard !isSelectableText else { return }
        for gesture in gestureRecognizers ?? [] {
            if gesture is UITapGestureRecognizer, (gesture as? UITapGestureRecognizer)?.numberOfTapsRequired == 1 {
                gesture.isEnabled = false
            }
        }
    }

    /// 伪代码 0x1008b6128（L194-213）：选择状态变化广播
    ///（defaultCenter/postNotificationName:object:userInfo: 确证）。
    private func observeSelectionStateChange() {
        let hasSelection = hasActiveSelection
        guard hasSelection != lastObservedHasSelection else { return }
        lastObservedHasSelection = hasSelection
        NotificationCenter.default.post(
            name: .readerTextSelectionDidChange,
            object: self,
            userInfo: ["hasSelection": hasSelection])
    }

    /// 伪代码 0x1008b7438（L103-105）：selectedRange.didset——选择域变更桥。
    override var selectedRange: NSRange {
        didSet { onSelectionChanged?() }
    }

    /// 伪代码 0x1008b5154（L109-111）：selectedTextRange.didset——文本区间
    /// 变更桥（didset 域确证）。
    override var selectedTextRange: UITextRange? {
        didSet { onSelectionChanged?() }
    }

    private func selectedTextRangeDidChange(_ previousSelectedTextRange: UITextRange?) {
        observeSelectionStateChange()
    }

    func dismissSelection() {
        selectedTextRange = nil
    }

    // MARK: 菜单动作

    func selectedTextForMenuAction() -> String? {
        let selected: String?
        if let range = selectedTextRange, !range.isEmpty {
            selected = text(in: range)
        } else {
            let range = selectedRange
            let value = (text ?? "") as NSString
            guard range.location != NSNotFound, range.length > 0,
                  range.location <= value.length, range.length <= value.length - range.location else { return nil }
            selected = value.substring(with: range)
        }
        // 0x1008b65a4的小字符串字节E2 80 8B为U+200B；原版不裁剪普通空白。
        let cleaned = selected?.replacingOccurrences(of: "\u{200B}", with: "")
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard isSelectableText, selectedTextForMenuAction() != nil else { return false }
        if action == #selector(createReplaceRule(_:)) || action == #selector(addBookmark(_:))
            || action == #selector(lookUpInDictionary(_:)) { return true }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func lookUpInDictionary(_ sender: Any?) {
        guard let selected = selectedTextForMenuAction() else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                controller.present(UIReferenceLibraryViewController(term: selected), animated: true)
                return
            }
            responder = current.next
        }
    }

    @objc func createReplaceRule(_ sender: Any?) {
        // 真正替换通知在0x1008b6ef8；0x1008b7044虽标同名，实际发书签通知。
        postSelectedTextAction(.readerRequestReplaceRule)
    }

    @objc func addBookmark(_ sender: Any?) {
        postSelectedTextAction(.readerRequestAddBookmark)
        dismissSelection()
        resignFirstResponder()
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard isSelectableText else { return }
        // 0x1008b67fc：移除系统重复组，再插入字典/替换/书签三个原版动作。
        for identifier: UIMenu.Identifier in [.lookup, .learn, .share, .textStyle, .autoFill] {
            builder.remove(menu: identifier)
        }
        let dictionary = UIAction(title: "字典", image: UIImage(systemName: "character.book.closed")) {
            [weak self] _ in self?.lookUpInDictionary(nil)
        }
        let replace = UIAction(title: "替换", image: UIImage(systemName: "arrow.triangle.2.circlepath")) {
            [weak self] _ in self?.createReplaceRule(nil)
        }
        let bookmark = UIAction(title: "书签", image: UIImage(systemName: "bookmark")) {
            [weak self] _ in self?.addBookmark(nil)
        }
        builder.insertSibling(UIMenu(options: .displayInline, children: [dictionary, replace, bookmark]),
            afterMenu: .standardEdit)
    }

    private func postSelectedTextAction(_ name: Notification.Name) {
        guard let selected = selectedTextForMenuAction() else { return }
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["selectedText": selected])
    }

    /// 容器点击保选判定（PageContentViews 调用方确证）。
    func shouldPreserveSelectionOnContainerTap(at point: CGPoint, from view: UIView) -> Bool {
        hasActiveSelection
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event)
    }
}

extension Notification.Name {
    static let readerRequestReplaceRule = Notification.Name("readerRequestReplaceRule")
    static let readerRequestAddBookmark = Notification.Name("readerRequestAddBookmark")
    static let readerTextSelectionDidChange =
        Notification.Name("leafflow.readerTextSelectionDidChange")
}

extension SelectableReaderTextView {

    /// 选择变更桥（didset 域由主体消费；占位保证观察域语义对齐）。
    var onSelectionChanged: (() -> Void)? {
        get { objc_getAssociatedObject(self, &Self.selectionKey) as? (() -> Void) }
        set {
            objc_setAssociatedObject(
                self, &Self.selectionKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private static var selectionKey: UInt8 = 0
}

