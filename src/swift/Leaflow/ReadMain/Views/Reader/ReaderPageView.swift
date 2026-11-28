// 原路径: ReadMain/Views/Reader/ReaderPageView.swift
// 证据:
//   - PGO: 12 个主函数（index/task_functions.csv T-301-07 / ReaderPageView.swift），
//     地址：ReaderChapterTitleView.hasSnapshot 0x1007bfce4 L13-15（+闭包 ×2 0x100bfa f4/0x100bfbec）/
//     currentTextColor 变量初始化 0x1007c14cc L17 / configureWithSnapshot(image:animated:)
//     0x1007c0224 L76-101（+闭包 0x1007c15a0/0x1007c05c0） / applyStyle 0x1007c060c
//     L117-150 / layoutSubviews 0x1007c0e8c L152-155 / ReaderPageView ivar 初始化
//     （contentTextView 0x1007c1540 L165 / widgetLabels 0x1007c15d8 L168 /
//     widgetImageViews 0x1007c1604 L169 / bookName 0x1007c1694 L174）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderPageView.c（892 行）
//   - 事实：ReaderChapterTitleView —— 快照图（snapshotImageView）+ 文本 UITextView
//     （layoutSubviews：setScrollEnabled:false/setEditable:false/setSelectable:false/
//     setLineFragmentPadding:/setLineBreakMode:/clearColor 确证）；
//     configureWithSnapshot：UIImageView 装配（setContentMode/setFrame/setHidden/
//     setAlpha + animateWithDuration 确证）；applyStyle：NSAttributedString 属性链
//     （addAttribute/setAlignment/setLineBreakStrategy 确证）；
//     hasSnapshot：snapshotImageView.image 存在且未隐藏（labelColor 闭包确证）
//   - 约束链：addSubview + leadingAnchor/bottomAnchor/constraintLessThanOrEqualToAnchor/
//     activateConstraints（0x1007bfce4 块确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - configureWithSnapshot/applyStyle/layoutSubviews/hasSnapshot: high（选择子链确证）
//   - ReaderPageView 容器结构: medium（ivar 集确证；布局细节待真机对照）
// 还原: 2026-11-19

import UIKit

/// 章节标题视图：文本样式 + 快照图双通道。
@MainActor
final class ReaderChapterTitleView: UIView {

    private let titleLabel: UITextView = {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textContainer.lineBreakMode = .byWordWrapping
        return textView
    }()

    private let snapshotImageView = UIImageView()
    private var currentTextColor: UIColor = .label

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    /// 约束链（0x1007bfce4 块确证：leading/bottom/lessThanOrEqualTo）。
    private func setupViews() {
        backgroundColor = .clear
        addSubview(titleLabel)
        addSubview(snapshotImageView)
        snapshotImageView.contentMode = .scaleAspectFill
        snapshotImageView.isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        // 伪代码 0x1007c0e8c（L152-155）：文本视图属性复位（确证）。
        super.layoutSubviews()
        titleLabel.frame = bounds
        snapshotImageView.frame = bounds
    }

    /// 伪代码 0x1007bfce4（L13-15）：快照可用判定
    ///（image 存在 && 未隐藏；labelColor 闭包确证）。
    var hasSnapshot: Bool {
        snapshotImageView.image != nil && !snapshotImageView.isHidden
    }

    /// 伪代码 0x1007c0224（L76-101）+ closure（0x1007c05c0）：
    /// 快照装配（setContentMode/setFrame/setHidden/setAlpha +
    /// animateWithDuration 动画确证）。
    func configureWithSnapshot(image: UIImage, animated: Bool) {
        snapshotImageView.image = image
        snapshotImageView.contentMode = .scaleAspectFill
        snapshotImageView.frame = bounds
        if animated {
            snapshotImageView.isHidden = false
            snapshotImageView.alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.snapshotImageView.alpha = 1
            }
        } else {
            snapshotImageView.isHidden = false
            snapshotImageView.alpha = 1
        }
    }

    /// 伪代码 0x1007c060c（L117-150）：文本样式应用
    ///（addAttribute/setAlignment/setLineBreakStrategy/setAttributedText 确证）。
    func applyStyle(text: String, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        snapshotImageView.isHidden = true
        currentTextColor = color
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakStrategy = .standard
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        attributed.addAttribute(.font, value: font, range: fullRange)
        attributed.addAttribute(.foregroundColor, value: color, range: fullRange)
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        titleLabel.attributedText = attributed
    }

    /// 设置标题高亮（PageContentViews TTS 链使用；API 名为还原命名）。
    func setHighlighted(_ highlighted: Bool, color: UIColor?) {
        titleLabel.backgroundColor = highlighted ? color : .clear
    }
}

/// 页面视图容器（ivar 集确证：contentTextView/widgetLabels/widgetImageViews/bookName）。
@MainActor
final class ReaderPageView: UIView {

    private(set) var contentTextView: SelectableReaderTextView
    private(set) var widgetLabels: [UUID: UILabel] = [:]
    private(set) var widgetImageViews: [UUID: UIImageView] = [:]
    private(set) var bookName: String = ""

    init(contentTextView: SelectableReaderTextView) {
        self.contentTextView = contentTextView
        super.init(frame: .zero)
        addSubview(self.contentTextView)
    }

    required init?(coder: NSCoder) {
        self.contentTextView = SelectableReaderTextView(isSelectable: false)
        super.init(coder: coder)
        addSubview(self.contentTextView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentTextView.frame = bounds
    }
}
