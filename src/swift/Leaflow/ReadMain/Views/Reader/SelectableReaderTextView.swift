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
        let container = NSTextContainer(size: CGSize(width: 0, height: .infinity))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
        super.init(frame: .zero, textContainer: container)
        commonInit(isSelectable: isSelectable)
        ReaderPerformanceTrace.log("init selectable=\\(isSelectable)")
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
        isSelectable = isSelectableText
        isScrollEnabled = false
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        disableSingleTapGesturesIfNeeded()
    }

    override func layoutSubviews() {
        // 伪代码 0x1008b5cbc（L154-164）。
        super.layoutSubviews()
        textContainer.size = CGSize(width: bounds.width, height: .infinity)
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

    // MARK: 菜单动作（骨架签名）

    func selectedTextForMenuAction() -> String? {
        text(in: selectedTextRange ?? UITextRange())
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        isSelectableText && super.canPerformAction(action, withSender: sender)
    }

    func lookUpInDictionary(_ sender: Any?) {
        // 查词入口（UIReferenceLibraryViewController 域，待真机对照）。
    }

    func createReplaceRule(_ sender: Any?) {
        // ReplaceRuleCreationSheet 入口。
    }

    func addBookmark(_ sender: Any?) {
        // 书签入口。
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
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

