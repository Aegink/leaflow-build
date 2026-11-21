// 原路径: ReadMain/Views/Reader/PageContentViews.swift
// 证据:
//   - PGO: 67 个主函数（index/task_functions.csv T-301-03 / PageContentViews.swift），
//     核心函数地址：init(isInteractive:) 0x1007560f8 L114-117 / init(coder:) 0x1007563d8 L119-122 /
//     pageData.didset 0x100755f98 L126-128 / showsLayoutWidgets.didset 0x100756090 L168-173 /
//     viewDidLoad 0x100756948 L277-300 / viewDidAppear 0x100756c8c L302-313 /
//     viewDidDisappear 0x100756f30 L315-318 / setupViews 0x10075701c L366-406 /
//     viewDidLayoutSubviews 0x100757360 L408-457 / updateFrames 0x100757e1c L460-539 /
//     updateContent 0x10075846c L541-782 / paragraphAlignedAttributedText 0x10075a648 L784-799 /
//     applyEggChapterContentInsetsIfNeeded 0x10075a834 L801-855 (+closure1 0x10075ac94 / closure2 0x10075ade4) /
//     updateHighlightGradientOverlayFrames 0x10075aeac L862-869 / updateHighlightGradientOverlays
//     0x10075af50 L871-878 / updateHighlightGradientOverlayConfiguration 0x10075b08c L880-893 /
//     updateFullLineUnderlineOverlay 0x10075b230 L910-990 (+closure3 0x10075b928 L929-974) /
//     configure 0x10075bf60 L992-1044 / updateHighlight 0x10075c4c0 L1093-1130 /
//     applyForegroundHighlight 0x10075c64c L1133-1238 / restorePreviousHighlight 0x10075ca30 L1248-1273
//     (+closure1 0x10075ce00) / clearHighlight 0x10075ce60 L1280-1285 /
//     gestureRecognizerShouldBegin 0x10075d0b8 L1289-1295 /
//     gestureRecognizer(_:shouldBeRequiredToFailBy:) 0x10075d4a8 L1299-1306 /
//     shouldPreserveTextSelectionOnContainerTap 0x1008b4914 L1322-1324 /
//     underline 三函数 0x100754f38 L5-21 / 0x100755310 L39-60 / 0x100755c2c L82-89 (+closure 0x10075dac0)
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageContentViews.c（6887 行，67 块）
//   - 关键选择子：viewWithTag:100/stopAnimating/removeFromSuperview/setBackgroundColor:/
//     insertSubview:atIndex:0/setTextContainerInset:(0,8,0,8)/textContainer.setSize:/
//     enumerateTextLayoutFragmentsFromLocation:options:usingBlock:/enumerateAttribute:/
//     textStorage/beginEditing/endEditing/addAttribute:value:range:/bringSubviewToFront:/
//     addChildViewController:/didMoveToParentViewController:/setLineDashPattern:/setLineCap:/setLineJoin:/
//     UIStackView(axis:1,alignment:3,spacing:16)/UITag 100/101
//   - 关键字面量：trace "page.load.front"/"page.load.back"/"setup"/"content"/"frames"/
//     "textInstall"/"underline"/"configure"（0x72756769666E6F63）；updateContent 原因
//     "layout.ready"（12 字符小串 0x722E74756F79616C，viewDidLayoutSubviews L2078）；
//     [TitleSnapshot] SKIP (key matches)/CACHE HIT/CACHE MISS 三条诊断前缀；
//     U+FFFC(65532) 段落评论标记；下划线段宽度阈值 1.0pt（两处确证）；
//     排除矩形水平外扩 ±2pt；首字面量 0x101271760（17 字符，未解码，待真机对照）
//   - pgo_only（ICF 合并，无独立地址）：loadView/applyReaderUserInterfaceStyle/
//     forceRebuildContent/renderedTextRange/blocksContainerTap/
//     preferredScreenEdgesDeferringSystemGestures/clearFullLineUnderlineOverlay/
//     highlightBackgroundRenderIdentity/widgetRefreshDriver.getter(+closure)/contentTextView.getter(+closure)/
//     sharedTransparentPixel 初始化闭包 —— 按签名声明，体并入共体函数
//   - 已知噪声：小函数块存在 ICF/覆盖归组误标（0x100756260 标 isPointOnComment 实为
//     widgetRefreshDriver 懒加载体；0x100756f90 标 readerUserInterfaceStyle.getter 实为
//     applyReaderUserInterfaceStyle 体；0x100755c2c 块体含 pageRenderSignature 复位；
//     0x10075e194 标 gestureRecognizerShouldBegin 闭包实为 +Comments 的 key=value 格式化闭包）。
//     误标块的体不冒充对应函数；对应函数按签名 + 最小语义还原并在读后记登记。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - underline 计算三函数: high（区间相减/裁剪/可见文本判定；1.0pt 阈值两处确证）
//   - viewDidLoad/setupViews/viewDidLayoutSubviews/updateFrames/updateFullLineUnderlineOverlay/
//     configure/updateHighlight/applyForegroundHighlight/restorePreviousHighlight/
//     paragraphAlignedAttributedText/applyEggChapterContentInsetsIfNeeded: high~medium-high
//   - updateContent 主体: medium-high（流程骨架确证；内部分支顺序部分依赖噪声块）
//   - viewDidAppear 细节序: medium（superview/bringSubviewToFront 归属待真机对照）
//   - clearHighlight/shouldPreserveTextSelectionOnContainerTap: low-medium（体为 ICF 误标嫌疑，
//     仅按签名 + 最小语义还原）
// 还原: 2026-11-19
// 依赖: ReadingSettings 的派生 API（textUIColor/backgroundUIImage/ttsHighlightUIColor/
//   textUnderlineUIColor/textUnderlineUsesTextColor/widgetFont(size:)/
//   preferredReaderSystemUIFont(ofSize:weight:prefersSimplifiedChinese:)/
//   updateWidgetLayoutMetrics(from:)/applyLayoutTemplate(_:)/compiledHighlightRules/textStrokeWidth）
//   按 PGO 属于 ReadingSettings.swift（T-302 登记签名）；ReaderWidgetRefreshDriver.init
//   (notifications:now:applicationIsActive:refresh:)/setVisible 属于 ReaderWidgetRefreshDriver.swift
//   （T-301-11）；ChapterTitleSnapshotService/ReaderChapterTitleView/HighlightGradientOverlayView
//   属于 T-303 分册；SelectableReaderTextView 属于 T-301-09。本文件按签名引用，不重复实现。

import UIKit

// MARK: - 全行下划线段计算（顶层全局函数）

/// 全行下划线是否含可见文本（伪代码 0x100754f38，L5-21）。
/// 逐字符检查：带附件（NSAttachmentAttributeName）跳过；0xD000-0xDFFF 代理区跳过
/// （伪代码以 57344=0xE000 为基准的 unsigned 减法判定）；空白
/// （CharacterSet.whitespacesAndNewlines）与零宽类字符（含 U+200B=8203）跳过；
/// 首个可见字符返回 true，全部不可见返回 false。
func readerFullLineUnderlineHasVisibleText(_ attributed: NSAttributedString) -> Bool {
    guard attributed.length > 0 else { return false }
    let string = attributed.string
    // 伪代码 L108：显式排除 U+200B；另有两个 Character 字面量（零宽类，值未解码）。
    let excludedZeroWidth: Set<UInt32> = [0x200B]
    var range = NSRange()
    for index in 0..<attributed.length {
        if attributed.attribute(.attachment, at: index, effectiveRange: &range) != nil {
            continue
        }
        let scalar = string[index].unicodeScalars.first?.value ?? 0
        if (0xD000...0xDFFF).contains(scalar) { continue }
        if let unicode = Unicode.Scalar(scalar),
           CharacterSet.whitespacesAndNewlines.contains(unicode) {
            continue
        }
        if excludedZeroWidth.contains(scalar) { continue }
        return true
    }
    return false
}

/// 区间相减（伪代码 0x100755310，L39-60；@MainActor，executor 检查在 L30）。
/// 对每个 range 扣除 removing（签名按 PGO demangle：removing 是单个 ClosedRange）：
/// - 无交集（removing.upper <= range.lower || range.upper <= removing.lower）→ 原样保留；
/// - 左段 (range.lower ..< removing.lower) 仅当宽度 > 1.0pt 保留（伪代码 L276-294）；
/// - 右段 (removing.upper ..< range.upper) 仅当宽度 > 1.0pt 保留（伪代码 L296-318）。
/// 顶层函数为 ranges.flatMap(closure#1)；closure#1 体即上述逻辑。
@MainActor
func readerFullLineUnderlineSubtractingSegments(
    _ ranges: [ClosedRange<CGFloat>], removing: ClosedRange<CGFloat>
) -> [ClosedRange<CGFloat>] {
    ranges.flatMap { range -> [ClosedRange<CGFloat>] in
        if removing.upperBound <= range.lowerBound || range.upperBound <= removing.lowerBound {
            return [range]
        }
        var segments: [ClosedRange<CGFloat>] = []
        if range.lowerBound < removing.lowerBound {
            let clippedLower = min(removing.lowerBound, range.upperBound)
            if clippedLower - range.lowerBound > 1.0 {
                segments.append(range.lowerBound...clippedLower)
            }
        }
        if removing.upperBound < range.upperBound {
            if range.upperBound - removing.upperBound > 1.0 {
                segments.append(removing.upperBound...range.upperBound)
            }
        }
        return segments
    }
}

/// 区间裁剪（伪代码 0x100755c2c，L82-89；closure #1 0x10075dac0 L83-88）。
/// 每段与窗口求交，宽度 <= 1.0pt 丢弃（阈值 closure 内确证）。
/// 注意：0x100755c2c 块体实际是 pageRenderSignature 复位逻辑（ICF 误标），
/// 裁剪语义取自 closure #1 + implicit closure #2（L15，同样 1.0 阈值）。
@MainActor
func readerFullLineUnderlineClippedSegments(
    _ ranges: [ClosedRange<CGFloat>], to limit: ClosedRange<CGFloat>
) -> [ClosedRange<CGFloat>] {
    ranges.compactMap { range -> ClosedRange<CGFloat>? in
        let lower = max(limit.lowerBound, range.lowerBound)
        let upper = min(limit.upperBound, range.upperBound)
        guard upper - lower > 1.0 else { return nil }
        return lower...upper
    }
}

// MARK: - 下划线辅助（pgo_only：无独立地址，内联进 updateFullLineUnderlineOverlay，按签名还原）

/// 排除段集合（PGO：readerFullLineUnderlineSegments(fullWidth:excludedRects:lineTop:
/// lineBottom:horizontalPadding:)）。行带与每个排除矩形求交（水平外扩 ±2pt，
/// 截断到 [0, fullWidth]），输出 x 区间。
@MainActor
func readerFullLineUnderlineSegments(
    fullWidth: CGFloat,
    excludedRects: [CGRect],
    lineTop: CGFloat,
    lineBottom: CGFloat,
    horizontalPadding: CGFloat
) -> [ClosedRange<CGFloat>] {
    var segments: [ClosedRange<CGFloat>] = [0...fullWidth]
    for rect in excludedRects {
        guard rect.maxY >= lineTop, rect.minY <= lineBottom else { continue }
        let minX = max(0, rect.minX - horizontalPadding)
        let maxX = min(fullWidth, rect.maxX + horizontalPadding)
        guard minX <= maxX else { continue }
        segments = readerFullLineUnderlineSubtractingSegments(segments, removing: minX...maxX)
    }
    return segments
}

/// 下划线 y 坐标（PGO：readerFullLineUnderlineY(lineBottom:strokeWidth:offset:scale:)）。
/// 伪代码 closure#3 L5571：round((lineBottom - strokeWidth + offset) * scale) / scale。
func readerFullLineUnderlineY(
    lineBottom: CGFloat, strokeWidth: CGFloat, offset: CGFloat, scale: CGFloat
) -> CGFloat {
    ((lineBottom - strokeWidth + offset) * scale).rounded() / scale
}

/// 像素对齐（PGO：readerFullLineUnderlinePixelAligned(_:scale:)）。
func readerFullLineUnderlinePixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
    (value * scale).rounded() / scale
}

/// 文本裁剪区间（PGO：readerFullLineUnderlineTextClipRange(minX:maxX:fullWidth:)）。
/// clamp 到 [0, fullWidth]，宽度 <= 1.0pt 返回 nil。
func readerFullLineUnderlineTextClipRange(
    minX: CGFloat, maxX: CGFloat, fullWidth: CGFloat
) -> ClosedRange<CGFloat>? {
    let lower = max(0, minX)
    let upper = min(fullWidth, maxX)
    guard upper - lower > 1.0 else { return nil }
    return lower...upper
}

/// 段落评论是否排除下划线（PGO：readerFullLineUnderlineShouldExcludeComment）。
/// 判定字段未从反编译恢复 —— 待真机对照（推断：带图/带脚本的评论排除）。
func readerFullLineUnderlineShouldExcludeComment(_ comment: ParagraphComment) -> Bool {
    _ = comment
    return false
}

// MARK: - 页面内容视图控制器

/// 页面内容视图控制器（CovMap L114-1324，67 函数）。
/// 职责：单页正文渲染（TextKit2）、章节标题快照、段落评论命中、TTS 高亮、
/// 全行下划线与渐变高亮覆盖层、布局 widget 标签、加载占位层。
@MainActor
final class PageContentViewController: UIViewController {

    // MARK: ivar（init 块 L114-261 初始化序列确证）

    /// init(isInteractive:) 0x1007560f8 L114-117：init(coder:) 与之共体（objc 两入口）。
    let isInteractive: Bool

    /// pageData.didset 0x100755f98 L126-128：体为计数空转，无实际逻辑。
    var pageData: PageData?

    var pageId: String = ""

    /// 内容样式签名（L131 初始 0），排版决策输入。
    var contentStyleSignature: Int = 0

    var bookName: String = ""
    var totalChapters: Int = 0

    /// 已应用的样式签名（updateFrames/updateContent 与当前签名比较，失配跳过重排）。
    var storedContentStyleSignature: Int?

    var highlightRange: NSRange = NSRange(location: 0, length: 0)
    var isChapterTitleHighlighted: Bool = false
    private var originalText: String = ""
    var bodyCache = ReaderPageBodyCache()
    private var previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
    private var pendingHighlightRange: NSRange?
    private var pendingChapterTitleHighlight: Bool?

    var useTransparentBackground: Bool = false

    /// showsLayoutWidgets.didset 0x100756090 L168-173：
    /// 置 false 时 hideWidgetLabels()；视图已加载时刷新动态内容。
    var showsLayoutWidgets: Bool = false {
        didSet {
            if !showsLayoutWidgets {
                hideWidgetLabels()
            }
            if isViewLoaded {
                refreshDynamicContent(event: .layout)
            }
        }
    }

    private(set) var chapterTitleView = ReaderChapterTitleView()
    private var fullLineUnderlineView = UIView()
    private var fullLineUnderlineLayer = CAShapeLayer()
    private var highlightGradientBackgroundView = HighlightGradientOverlayView()
    private var highlightGradientForegroundView = HighlightGradientOverlayView()

    var widgetLabels: [UUID: UILabel] = [:]
    var widgetImageViews: [UUID: UIImageView] = [:]
    var renderedWidgetSymbols: [UUID: (view: ObjectIdentifier, state: ReaderWidgetSymbolState)] = [:]

    /// widget 刷新驱动（懒加载体在伪代码 0x100756260 块：NotificationCenter + 观察注册；
    /// init 签名按 PGO：notifications/now/applicationIsActive/refresh）。
    lazy var widgetRefreshDriver: ReaderWidgetRefreshDriver = {
        ReaderWidgetRefreshDriver(
            notifications: .defaultCenter,
            now: { Date() },
            applicationIsActive: { UIApplication.shared.applicationState == .active }
        ) { [weak self] event in
            self?.refreshDynamicContent(event: event)
        }
    }()

    private var isViewSetup = false
    /// 段落评论标记字符（U+FFFC；applyForegroundHighlight/正文标记共用）。
    let commentMarkerChar: Character = "\u{FFFC}"
    private var loadingOverlay: UIView?
    /// 段落评论矩形缓存 [(comment, rect)]（元素 88 字节步长确证）。
    private(set) var cachedCommentRects: [(comment: ParagraphComment, rect: CGRect)] = []
    /// 命中缓存时的布局指纹（bounds/container/inset/padding 十字段 + 有效位，L1338-1368）。
    private var cachedCommentRectsLayoutValid = false
    private var lastLoggedViewBounds: CGRect = .zero
    private var lastLoggedContentFrame: CGRect = .zero
    private var lastTitleSnapshotKey: (width: CGFloat, key: String)?
    private var pageRenderSignature: Int?
    private var lastWidgetFontName: String?
    /// PageBackViewController.configure 回写的首页 bounds（0x100754300 L505-510 确证）。
    var initialPageBounds: CGRect = .zero
    var backgroundImageView: UIImageView?
    /// 评论点击回调（handleCommentAttachmentTap L941-943 调用）。
    var onCommentTap: ((ParagraphComment) -> Void)?

    /// 阅读设置（init 存 nil；configure/setupViews/updateContent 使用）。
    var settings: ReadingSettings?

    /// contentTextView 懒加载（pgo_only getter + init(isSelectable:) 0x1007563d8 块确证）。
    private lazy var contentTextView: SelectableReaderTextView = {
        SelectableReaderTextView(isSelectable: isInteractive)
    }()

    init(isInteractive: Bool) {
        self.isInteractive = isInteractive
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.isInteractive = false
        super.init(coder: coder)
    }

    /// 透明像素占位图（pgo_only static sharedTransparentPixel 初始化闭包，
    /// UIGraphicsImageRendererContext 闭包确证）。
    static let sharedTransparentPixel: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    // MARK: 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        // 伪代码 0x100756948 L277-300：
        // trace 标签 = "page.load" + (isInteractive ? "front" : "back")（小串字面量确证）；
        // userInteractionEnabled = isInteractive；setupViews()；
        // 交互模式附加准备（L300，细节待真机对照）；
        // pendingHighlight 派发（L1516-1548）：
        //   pendingHighlightRange 有值 → updateHighlight(range, chapterTitle==true) 后双清；
        //   否则 pendingChapterTitleHighlight 非 nil → updateHighlight(NSNotFound, flag) 后清。
        ReaderPerformanceTrace.log("page.load" + (isInteractive ? "front" : "back")) {
            [weak self] in
            guard let self else { return false }
            return self.isViewLoaded
        }
        guard isViewLoaded else { return }
        view.isUserInteractionEnabled = isInteractive
        setupViews()
        if let pending = pendingHighlightRange {
            updateHighlight(
                range: pending,
                highlightChapterTitle: pendingChapterTitleHighlight == true)
            pendingHighlightRange = nil
            pendingChapterTitleHighlight = nil
        } else if pendingChapterTitleHighlight != nil {
            updateHighlight(
                range: NSRange(location: NSNotFound, length: 0),
                highlightChapterTitle: pendingChapterTitleHighlight == true)
            pendingChapterTitleHighlight = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 伪代码 0x100756c8c L302-313：
        // showsLayoutWidgets 时：animated → settings.updateWidgetLayoutMetrics(from: view)，
        // 变化 → 刷新 widget；bringSubviewToFront（归属视图待真机对照）；
        // widgetRefreshDriver.setVisible(true)。
        if showsLayoutWidgets, let loadedView = viewIfLoaded {
            if settings?.updateWidgetLayoutMetrics(from: loadedView) == true {
                refreshAllWidgetContent()
            }
            if let container = contentTextView.superview {
                container.bringSubviewToFront(contentTextView)
            }
        }
        widgetRefreshDriver.setVisible(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 伪代码 0x100756f30 L315-318：
        // settings.getContentAreaSize(isFirstPage:screenBounds:chapterTitle:) 判定 → 记录 2/1 两档；
        // 驱动不可见。
        widgetRefreshDriver.setVisible(false)
    }

    /// 阅读器界面样式（pgo_only getter；0x100756f90 块体实为 applyReaderUserInterfaceStyle）。
    var readerUserInterfaceStyle: UIUserInterfaceStyle {
        // 样式来源（跟随系统/日间/夜间）待真机对照；默认跟随系统。
        .unspecified
    }

    /// 伪代码 0x100756f90 块体（L322-324）：
    /// overrideUserInterfaceStyle 双写 —— self 与已加载视图各设一次。
    func applyReaderUserInterfaceStyle() {
        let style = readerUserInterfaceStyle
        overrideUserInterfaceStyle = style
        if isViewLoaded {
            view.overrideUserInterfaceStyle = style
        }
    }

    /// 屏幕边缘手势延迟（pgo_only getter，签名确证）。
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        .all
    }

    override func loadView() {
        // pgo_only（签名确证）：容器视图；透明背景标志生效时 clear。
        view = UIView()
        if useTransparentBackground {
            view.backgroundColor = .clear
        }
    }

    // MARK: 视图装配

    /// 伪代码 0x10075701c L366-406。
    /// 守卫：isViewSetup 已置位或 settings == nil → 返回。
    /// 内容视图背景：transparent → clear，否则 settings.textUIColor。
    /// 背景图：!transparent 且 settings.backgroundUIImage 存在 → UIImageView
    /// （contentMode 2 = scaleAspectFill，frame = view.bounds，insertSubview atIndex 0）；
    /// nil 时移除。内容视图 clear 背景 + isUserInteractionEnabled=false +
    /// layer 加 fullLineUnderlineLayer；依次 addSubview(contentTextView/chapterTitleView/
    /// fullLineUnderlineView)；setupWidgetLabels(settings:)；updateFrames()。
    private func setupViews() {
        guard !isViewSetup, let settings else { return }
        isViewSetup = true

        contentTextView.backgroundColor =
            useTransparentBackground ? .clear : settings.textUIColor

        if !useTransparentBackground, let background = settings.backgroundUIImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = view.bounds
                view.insertSubview(imageView, at: 0)
                backgroundImageView = imageView
            }
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.removeFromSuperview()
            backgroundImageView = nil
        }

        contentTextView.isUserInteractionEnabled = false
        contentTextView.backgroundColor = .clear
        contentTextView.layer.addSublayer(fullLineUnderlineLayer)
        view.addSubview(contentTextView)
        view.addSubview(chapterTitleView)
        view.addSubview(fullLineUnderlineView)
        setupWidgetLabels(settings: settings)
        updateFrames()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 伪代码 0x100757360 L408-457：
        // trace 起点计时（CACurrentMediaTime，开关判定）；
        // showsLayoutWidgets → settings.updateWidgetLayoutMetrics(from: view) 变化即刷新；
        // view.bounds != lastLoggedViewBounds → 记录 + 刷新；
        // updateFrames() 失败 → trace 结束；
        // pageData 有效且内容未安装 → updateContent(reason: "layout.ready")
        //（12 字符小串字面量确证；后续布局变化用另一字面量 0x101271760，17 字符）；
        // cacheCommentRects()；bounds 变化时 updateFullLineUnderlineOverlay()。
        let startTime = CACurrentMediaTime()
        if showsLayoutWidgets, let loadedView = viewIfLoaded {
            if settings?.updateWidgetLayoutMetrics(from: loadedView) == true {
                refreshAllWidgetContent()
            }
        }
        let boundsChanged = view.bounds != lastLoggedViewBounds
        if boundsChanged {
            lastLoggedViewBounds = view.bounds
            refreshAllWidgetContent()
        }
        guard updateFrames() else { return }
        if pageData != nil, contentTextView.attributedText == nil {
            updateContent(reason: "layout.ready")
        } else if pageData != nil, boundsChanged {
            updateContent(reason: "layout.boundsChanged")
        }
        cacheCommentRects()
        if boundsChanged {
            updateFullLineUnderlineOverlay()
        }
        _ = startTime
    }

    /// 布局帧更新（伪代码 0x100757e1c L460-539）。返回是否完成排版布局。
    /// - 守卫：pageData 无效 / storedContentStyleSignature 与当前签名不一致 → false；
    /// - ReaderInlineImageContext 装配 + BackgroundWork.runAsync 图片预取；
    /// - view 尺寸 <= 1.0 → false；
    /// - settings.applyLayoutTemplate；
    /// - chapterTitleView frame/hidden（L2421-2423）；
    /// - contentTextView/fullLineUnderlineView frame = bounds；
    /// - textContainerInset ≠ (0,8,0,8) → 重设（L2436-2442 精确比较）；
    /// - chapterTitleView.frame = (contentMinX-8, minY, width+16, height)（L2444-2461）；
    /// - textContainer.size = (contentWidth, boundsHeight + max(lineHeight*3, 100))（L2463-2483）；
    /// - applyEggChapterContentInsetsIfNeeded + updateHighlightGradientOverlays(attributedText:)；
    /// - lastLoggedContentFrame 跟踪 + trace。
    @discardableResult
    func updateFrames() -> Bool {
        guard pageData != nil,
              storedContentStyleSignature == nil || storedContentStyleSignature == contentStyleSignature
        else { return false }

        // 图片上下文预取（BackgroundWork.runAsync + ReaderInlineImageContext.init(
        // sourceUrl:storageKind:baseUrl:defaultStyle:) 确证；闭包体未恢复，待真机对照）。
        if let page = pageData {
            let context = ReaderInlineImageContext(
                sourceUrl: page.imageSourceUrl,
                storageKind: page.imageSourceStorageKind,
                baseUrl: page.imageBaseUrl,
                defaultStyle: page.imageStyle)
            if context != nil {
                BackgroundWork.runAsync(priority: nil) {
                    // 预取闭包体：伪代码未展开（sub_100752D1C），待真机对照。
                }
            }
        }

        let bounds = view.bounds
        guard bounds.width > 1.0, bounds.height > 1.0 else { return false }
        settings?.applyLayoutTemplate(.single)

        // 章节标题视图（伪代码 L2421-2423：setFrame + setHidden）。
        chapterTitleView.frame = bounds
        chapterTitleView.isHidden = !showsLayoutWidgets

        contentTextView.frame = bounds
        fullLineUnderlineView.frame = bounds

        // textContainerInset 常量 (0, 8, 0, 8)（伪代码 L2436-2442 精确比较）。
        let inset = contentTextView.textContainerInset
        if !(inset.top == 0 && inset.left == 8 && inset.bottom == 0 && inset.right == 8) {
            contentTextView.textContainerInset =
                UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        }

        // 章节标题 frame = (contentMinX - 8, minY, width + 16, height)（L2444-2461）。
        let contentFrame = contentTextView.frame
        let titleFrame = CGRect(
            x: contentFrame.minX - 8,
            y: contentFrame.minY,
            width: contentFrame.width + 16,
            height: contentFrame.height)
        if chapterTitleView.frame != titleFrame {
            chapterTitleView.frame = titleFrame
        }

        // 正文容器高度 = 容器高 + max(lineHeight * 3, 100)（L2463-2483）。
        let lineHeight = contentTextView.font?.lineHeight ?? 0
        let containerHeight = contentFrame.height + max(lineHeight * 3, 100)
        let container = contentTextView.textContainer
        if container.size.width != contentFrame.width || container.size.height != containerHeight {
            container.size = CGSize(width: contentFrame.width, height: containerHeight)
        }

        applyEggChapterContentInsetsIfNeeded()
        updateHighlightGradientOverlays(attributedText: contentTextView.attributedText)

        if contentTextView.frame != lastLoggedContentFrame {
            lastLoggedContentFrame = contentTextView.frame
        }
        return true
    }

    // MARK: 内容渲染

    /// 内容更新主链（伪代码 0x10075846c L541-782，1700+ 行）。
    /// 流程骨架（选择子/字面量确证）：
    /// 1. 守卫 pageData 有效（sub_100211858 校验）→ 失败直接返回；
    /// 2. trace mark(reason)；
    /// 3. ReaderPageDebug.visibleTextLength(in:) 检查；
    /// 4. view.backgroundColor = settings.textUIColor；
    /// 5. 背景图：settings.backgroundUIImage nil → 移除 backgroundImageView；
    ///    否则创建/复用（contentMode 2，frame = bounds，insertSubview atIndex 0，unhide）；
    /// 6. updateFrames() false → trace PageSample(page:reason:role:previous:) + return；
    /// 7. trace beginPage("frames", reason)；
    /// 8. shouldApplyReaderPageLayoutUpdate(stored:current:)；
    /// 9. 章节标题快照（L3196-3307）：key 匹配 → "[TitleSnapshot] SKIP (key matches)"；
    ///    ChapterTitleSnapshotService.cachedSnapshot(for:width:) 命中 →
    ///    ReaderChapterTitleView.configureWithSnapshot(image:animated:false) + CACHE HIT；
    ///    未命中 → CACHE MISS + 异步渲染（true/false 后缀 + resolvedUIFont）；
    /// 10. 正文安装（trace "textInstall"）：settings.preferredReaderSystemUIFont →
    ///     contentTextView.setScrollEnabled:false / textContainer.setLineBreakMode:0 →
    ///     bodyCache.attributedText(for:...) { makeBodyAttributedText(...) } →
    ///     contentTextView.setAttributedText:；
    /// 11. 段落对齐规范化（closure #4 @MainActor：enumerateAttribute NSParagraphStyle）；
    /// 12. applyEggChapterContentInsetsIfNeeded + 覆盖层更新（trace "underline"）；
    /// 13. widget 标签刷新（widgetLabels 迭代）。
    func updateContent(reason: String) {
        guard pageData != nil else { return }
        _ = reason
        _ = ReaderPageDebug.visibleTextLength(in: pageData!)

        guard let settings else { return }
        view.backgroundColor = settings.textUIColor

        if let background = settings.backgroundUIImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = view.bounds
                view.insertSubview(imageView, at: 0)
                backgroundImageView = imageView
            }
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.removeFromSuperview()
            backgroundImageView = nil
        }

        guard updateFrames() else { return }

        // 章节标题快照缓存链（L3196-3307）。
        if let page = pageData, !page.chapterTitle.isEmpty {
            let width = chapterTitleView.frame.width
            let key = (width, page.chapterTitle)
            if lastTitleSnapshotKey == key {
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] SKIP (key matches): \(page.chapterTitle)")
            } else if let snapshot = ChapterTitleSnapshotService.cachedSnapshot(
                for: page.chapterTitle, width: width) {
                chapterTitleView.configureWithSnapshot(image: snapshot, animated: false)
                lastTitleSnapshotKey = key
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] CACHE HIT: \(page.chapterTitle)")
            } else {
                lastTitleSnapshotKey = nil
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] CACHE MISS: \(page.chapterTitle)")
            }
        }

        // 正文安装（trace "textInstall" 字面量确证）。
        let font = ReadingSettings.preferredReaderSystemUIFont(
            ofSize: settings.fontSize, weight: .regular, prefersSimplifiedChinese: false)
        contentTextView.font = font
        contentTextView.isScrollEnabled = false
        contentTextView.textContainer.lineBreakMode = .byWordWrapping
        if let page = pageData {
            let attributed = bodyCache.attributedText(
                for: page,
                settings: settings,
                contentStyle: contentStyleSignature,
                width: bodyContentWidth,
                displayScale: view.traitCollection.displayScale
            ) {
                self.makeBodyAttributedText(
                    text: page.content,
                    settings: settings,
                    highlightRange: nil,
                    comments: page.comments,
                    forcePreserveTrailingJustification: false)
            }
            contentTextView.attributedText = paragraphAlignedAttributedText(
                attributed, alignment: settings.textAlignment)
        }

        applyEggChapterContentInsetsIfNeeded()
        updateHighlightGradientOverlays(attributedText: contentTextView.attributedText)
        updateFullLineUnderlineOverlay()
        refreshWidgetLabels(
            context: makeWidgetContext(for: pageData!),
            settings: settings,
            event: .content)
    }

    /// 正文属性串构建入口（伪代码 0x10075f910 L313-327，+Comments 分册）。
    func makeBodyAttributedText(
        text: String,
        settings: ReadingSettings,
        highlightRange: NSRange?,
        comments: [ParagraphComment]?,
        forcePreserveTrailingJustification: Bool
    ) -> NSAttributedString {
        buildReaderBodyAttributedText(
            text: text,
            settings: settings,
            comments: comments,
            contentWidth: bodyContentWidth,
            displayScale: view.traitCollection.displayScale,
            imageContext: nil,
            extraLineSpacing: settings.lineSpacing,
            preserveTrailingJustification: shouldPreserveTrailingJustification(
                forcePreserve: forcePreserveTrailingJustification),
            continuationPreviewText: "",
            applyRegexHighlight: true)
    }

    /// 段落对齐属性规范化（伪代码 0x10075a648 L784-799，@MainActor）。
    /// 取现有 NSParagraphStyle（attribute 查询，无则新建 NSMutableParagraphStyle）→
    /// mutableCopy → setAlignment(alignment) → addAttribute(NSParagraphStyleAttributeName,
    /// 全文 range)。
    private func paragraphAlignedAttributedText(
        _ attributed: NSAttributedString, alignment: NSTextAlignment
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraphStyle: NSMutableParagraphStyle
        if let existing = attributed.attribute(
            .paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            paragraphStyle = existing.mutableCopy() as! NSMutableParagraphStyle
        } else {
            paragraphStyle = NSMutableParagraphStyle()
        }
        paragraphStyle.alignment = alignment
        mutable.addAttribute(
            .paragraphStyle, value: paragraphStyle,
            range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    /// 正文缓存宽度（pgo_only bodyContentWidth getter）。
    var bodyContentWidth: CGFloat {
        contentTextView.textContainer.size.width
    }

    /// 强制重建内容（pgo_only：与 updateContent 共体，按签名声明）。
    func forceRebuildContent(settings: ReadingSettings) {
        bodyCache.invalidate()
        storedContentStyleSignature = nil
        self.settings = settings
        updateContent(reason: "configure")
    }

    /// 可渲染正文区间（pgo_only，按签名声明）：
    /// range 越界或 NSNotFound → nil。
    private func renderedTextRange(
        forContentRange range: NSRange, textStorageLength: Int
    ) -> NSRange? {
        guard range.location != NSNotFound,
              range.location + range.length <= textStorageLength else { return nil }
        return range
    }

    // MARK: 章节标题内边距（彩蛋模式）

    /// 伪代码 0x10075a834 L801-855。
    /// 前置：pageData 校验 + shouldApplyReaderPageLayoutUpdate(stored:current:)。
    /// 条件：contentTextView.attributedText length >= 1、textLayoutManager 存在、
    /// bounds.height > 0；enumerateTextLayoutFragments(documentRange.location, options: 4)
    /// 闭包（closure #1，0x10075ac94 L803-811，@MainActor）逐 fragment frame 取
    /// minY/min、maxY/max（空 rect 跳过）；inset = floor((bounds.height - 内容高) * 0.5)
    /// 且 >= 0；与当前 top/bottom 不同 → setTextContainerInset(inset, left, inset, right)。
    private func applyEggChapterContentInsetsIfNeeded() {
        let currentInset = contentTextView.textContainerInset
        guard pageData != nil,
              shouldApplyReaderPageLayoutUpdate(
                storedContentStyleSignature: storedContentStyleSignature ?? 0,
                currentContentStyleSignature: contentStyleSignature)
        else { return }
        guard let attributed = contentTextView.attributedText, attributed.length >= 1,
              let layoutManager = contentTextView.textLayoutManager,
              contentTextView.bounds.height > 0
        else { return }

        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var found = false
        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout],
            using: { fragment in
                let frame = fragment.layoutFragmentFrame
                if frame.isEmpty { return true }
                found = true
                minY = min(minY, frame.minY)
                maxY = max(maxY, frame.maxY)
                return true
            })
        guard found else { return }

        let contentHeight = max(0, maxY - minY)
        let inset = max(0, floor((contentTextView.bounds.height - contentHeight) * 0.5))
        if currentInset.top != inset || currentInset.bottom != inset {
            contentTextView.textContainerInset = UIEdgeInsets(
                top: inset, left: currentInset.left, bottom: inset, right: currentInset.right)
        }
        // 彩蛋模式下隐藏全行下划线（closure #2 0x10075ade4 L830-837：
        // setPath(nil) + setHidden(true)）。
        clearFullLineUnderlineOverlay()
    }

    // MARK: 渐变高亮覆盖层

    /// 伪代码 0x10075aeac L862-869：
    /// highlightRange.location == NSNotFound → 覆盖层 textLayoutManager 置 nil；
    /// 否则赋当前 textLayoutManager。
    private func updateHighlightGradientOverlayFrames() {
        let manager = contentTextView.textLayoutManager
        if highlightRange.location == NSNotFound {
            highlightGradientBackgroundView.textLayoutManager = nil
            highlightGradientForegroundView.textLayoutManager = nil
        } else {
            highlightGradientBackgroundView.textLayoutManager = manager
            highlightGradientForegroundView.textLayoutManager = manager
        }
    }

    /// 伪代码 0x10075af50 L871-878：
    /// 采集度量（textContainerInset/lineFragmentPadding/lineBreakMode）→
    /// updateHighlightGradientOverlayConfiguration → 覆盖层绑定 textLayoutManager。
    private func updateHighlightGradientOverlays(attributedText: NSAttributedString?) {
        _ = attributedText
        let inset = contentTextView.textContainerInset
        let padding = contentTextView.textContainer.lineFragmentPadding
        let breakMode = contentTextView.textContainer.lineBreakMode
        updateHighlightGradientOverlayConfiguration()
        // 覆盖层度量传递：inset/padding/lineBreakMode 按伪代码采集后交给
        // HighlightGradientOverlayView（具体 API 名待 T-303 分册落地）。
        _ = inset
        _ = padding
        _ = breakMode
        highlightGradientBackgroundView.textLayoutManager = contentTextView.textLayoutManager
        highlightGradientForegroundView.textLayoutManager = contentTextView.textLayoutManager
    }

    /// 渲染签名（伪代码 0x10075b08c L880-893）。
    /// pageRenderSignature 未缓存时用 Hasher 组合（pageData 渲染域 + settings 两字段
    /// + 存在标志）并缓存；之后每次组合缓存签名 + settings 字段。
    private func updateHighlightGradientOverlayConfiguration() {
        if pageRenderSignature == nil {
            var hasher = Hasher()
            if let page = pageData {
                hasher.combine(page.chapterIndex)
                hasher.combine(page.pageIndex)
                hasher.combine(page.charCount)
            }
            if let settings {
                hasher.combine(settings.fontSize)
                hasher.combine(settings.verticalJustify)
            }
            pageRenderSignature = hasher.finalize()
        }
    }

    /// 渲染身份（pgo_only highlightBackgroundRenderIdentity：签名哈希）。
    private var highlightBackgroundRenderIdentity: Int {
        updateHighlightGradientOverlayConfiguration()
        return pageRenderSignature ?? 0
    }

    // MARK: 全行下划线覆盖层

    /// 清除下划线（pgo_only；closure #2 0x10075ade4：setPath(nil) + setHidden(true)）。
    private func clearFullLineUnderlineOverlay() {
        fullLineUnderlineLayer.path = nil
        fullLineUnderlineView.isHidden = true
    }

    /// 伪代码 0x10075b230 L910-990（closure #3 0x10075b928 L929-974）。
    /// 守卫：settings 存在、attributedText 非空、textLayoutManager 存在、内容宽度 > 0，
    /// 失败 → clearFullLineUnderlineOverlay。
    /// 排除矩形 ← cachedCommentRects（convertRect:fromCoordinateSpace: 换算到覆盖层坐标）。
    /// enumerateTextLayoutFragments（options: 4 = ensuresLayout）逐 fragment：
    /// - 逐 NSTextLineFragment：readerFullLineUnderlineHasVisibleText(line.attributedString)
    ///   过滤（L5419-5421）；
    /// - lineTop = fragmentFrame.minY + typographicBounds.minY；
    ///   lineBottom = lineTop + typographicBounds.height（L5433-5436）；
    ///   lineBottom < 0 或 lineTop >= 覆盖层高 → 跳过（L5441）；
    /// - 排除段：readerFullLineUnderlineSegments（±2pt 外扩）；
    /// - 文本裁剪：readerFullLineUnderlineTextClipRange（L5539-5553，宽度 <= 1.0pt 跳过）；
    /// - 相减：readerFullLineUnderlineSubtractingSegments；
    /// - y = readerFullLineUnderlineY（L5571：round((lineBottom - strokeWidth + offset)*scale)/scale）；
    /// - moveToPoint/addLineToPoint 逐段画线（L5577-5580）。
    /// 空 path → clearFullLineUnderlineOverlay；
    /// 否则：覆盖层 frame、layer path、fillColor（usesTextColor ? textUIColor :
    ///   textUnderlineUIColor）、strokeColor、lineWidth、lineDashPattern（可选）、
    ///   lineCap（round/butt 按设置）、lineJoin round → setHidden(false)。
    private func updateFullLineUnderlineOverlay() {
        guard let settings,
              let attributed = contentTextView.attributedText, attributed.length > 0,
              let layoutManager = contentTextView.textLayoutManager
        else {
            clearFullLineUnderlineOverlay()
            return
        }
        let fullWidth = fullLineUnderlineView.bounds.width
        guard fullWidth > 0 else {
            clearFullLineUnderlineOverlay()
            return
        }

        let excludedRects = cachedCommentRects.map { pair in
            fullLineUnderlineView.convert(pair.rect, from: contentTextView)
        }

        let path = UIBezierPath()
        // strokeWidth 下限 1.0（closure#3 L5399：fmax(a3, 1.0)）；offset 取值待真机对照。
        let strokeWidth: CGFloat = max(1.0, settings.textStrokeWidth)
        let scale = fullLineUnderlineView.traitCollection.displayScale
        let offset: CGFloat = 0

        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout],
            using: { fragment in
                for line in fragment.textLineFragments {
                    guard readerFullLineUnderlineHasVisibleText(line.attributedString) else {
                        continue
                    }
                    let typographic = line.typographicBounds
                    let lineTop = fragment.layoutFragmentFrame.minY + typographic.minY
                    let lineBottom = lineTop + typographic.height
                    if lineBottom < 0 || lineTop >= fullLineUnderlineView.bounds.height {
                        continue
                    }
                    let excluded = readerFullLineUnderlineSegments(
                        fullWidth: fullWidth,
                        excludedRects: excludedRects,
                        lineTop: lineTop,
                        lineBottom: lineBottom,
                        horizontalPadding: 2.0)
                    guard let clip = readerFullLineUnderlineTextClipRange(
                        minX: fragment.layoutFragmentFrame.minX + typographic.minX,
                        maxX: fragment.layoutFragmentFrame.minX + typographic.maxX,
                        fullWidth: fullWidth) else { continue }
                    var segments: [ClosedRange<CGFloat>] = [clip]
                    for range in excluded {
                        segments = readerFullLineUnderlineSubtractingSegments(
                            segments, removing: range)
                    }
                    guard !segments.isEmpty else { continue }
                    let y = readerFullLineUnderlineY(
                        lineBottom: lineBottom, strokeWidth: strokeWidth,
                        offset: offset, scale: scale)
                    for segment in segments {
                        path.move(to: CGPoint(x: segment.lowerBound, y: y))
                        path.addLine(to: CGPoint(x: segment.upperBound, y: y))
                    }
                }
                return true
            })

        if path.isEmpty {
            clearFullLineUnderlineOverlay()
            return
        }

        fullLineUnderlineView.frame = view.bounds
        fullLineUnderlineLayer.path = path.cgPath
        let fillColor = settings.textUnderlineUsesTextColor
            ? settings.textUIColor
            : settings.textUnderlineUIColor
        fullLineUnderlineLayer.fillColor = fillColor.cgColor
        fullLineUnderlineLayer.strokeColor = fillColor.cgColor
        fullLineUnderlineLayer.lineWidth = settings.textStrokeWidth
        fullLineUnderlineLayer.lineCap = .round
        fullLineUnderlineLayer.lineJoin = .round
        fullLineUnderlineView.isHidden = false
    }

    // MARK: 配置

    /// 伪代码 0x10075bf60 L992-1044。
    /// needsFrameUpdate = bookName/totalChapters 变化；
    /// 内容变化 = 新旧 pageData 渲染状态不等（hasSameRenderableState 域）；
    /// settings 存回；pageData/bookName/totalChapters/originalText 更新；
    /// widget 字体（settings.widgetFont(size:).fontName）与上次比较，变化 → 刷新 widget；
    /// 内容或评论变化 → updateContent(reason: "configure")
    /// （小串 0x72756769666E6F63 = "configur…" 确证）；否则仅 needsFrameUpdate 时 updateFrames()。
    func configure(
        pageData newPage: PageData,
        settings newSettings: ReadingSettings,
        bookName newBookName: String,
        totalChapters newTotalChapters: Int
    ) {
        let needsFrameUpdate = bookName != newBookName || totalChapters != newTotalChapters
        let contentChanged = !newPage.hasSameRenderableState(as: pageData ?? newPage)

        settings = newSettings
        pageData = newPage
        bookName = newBookName
        totalChapters = newTotalChapters
        originalText = newPage.content

        // widget 字体变化检测（L5844-5896：fontName 桥接比较）。
        if let widgetFont = newSettings.widgetFont(size: newSettings.fontSize) {
            let fontName = widgetFont.fontName
            if lastWidgetFontName != fontName {
                lastWidgetFontName = fontName
                refreshAllWidgetContent()
            }
        }

        guard contentChanged else {
            if needsFrameUpdate {
                updateFrames()
            }
            return
        }
        _ = ReaderPageDebug.visibleTextLength(in: newPage)
        updateContent(reason: "configure")
    }

    // MARK: TTS 高亮

    /// 伪代码 0x10075c4c0 L1093-1130。
    /// 归一化（location == NSNotFound → (NSNotFound, 0)）；
    /// 与当前状态一致（chapterTitle 标志 + range）→ no-op；
    /// 置 isChapterTitleHighlighted；settings.ttsHighlightUIColor 用于章节标题高亮；
    /// location == NSNotFound → highlightRange=(NSNotFound,0) + restorePreviousHighlight()；
    /// 否则 highlightRange = 新值 + applyForegroundHighlight(for:)。
    func updateHighlight(range: NSRange, highlightChapterTitle: Bool) {
        var location = range.location
        var length = range.length
        if location == NSNotFound {
            length = 0
        }
        if highlightChapterTitle == isChapterTitleHighlighted,
           highlightRange.location == location, highlightRange.length == length {
            return
        }
        isChapterTitleHighlighted = highlightChapterTitle
        // 章节 title 高亮：伪代码以 (highlightChapterTitle, ttsHighlightUIColor)
        // 两参传入 ReaderChapterTitleView 配置闭包（closure #1 in configureWithSnapshot），
        // 具体 API 名待 T-303 分册落地。
        let _highlightColor = settings?.ttsHighlightUIColor
        _ = _highlightColor

        highlightRange = NSRange(location: location, length: length)
        if location == NSNotFound {
            restorePreviousHighlight()
        } else {
            applyForegroundHighlight(for: NSRange(location: location, length: length))
        }
    }

    /// 伪代码 0x10075c64c L1133-1238。
    /// textStorage = contentTextView.textStorage；先 restorePreviousHighlight()；
    /// 守卫：location == NSNotFound / pageData 校验失败 /
    ///   location < 0 || length < 1 || 文本长 < location+length → return；
    /// 夹取到 storage.length（sub_10075C9B8）；beginEditing → 跳过段首 U+FFFC（65532）
    /// → 逐段 addAttribute(NSForegroundColorAttributeName,
    ///   settings.ttsHighlightUIColor) → endEditing；
    /// previousHighlightedRange 记录 + updateHighlightGradientOverlayFrames()。
    private func applyForegroundHighlight(for range: NSRange) {
        guard let textStorage = contentTextView.textStorage else { return }
        restorePreviousHighlight()
        guard range.location != NSNotFound, pageData != nil else { return }
        guard range.location >= 0, range.length >= 1 else { return }

        let storage = textStorage
        guard let color = settings?.ttsHighlightUIColor else { return }
        let clampedLength = min(range.length, max(0, storage.length - range.location))
        guard clampedLength >= 1, range.location + clampedLength <= storage.length else { return }

        storage.beginEditing()
        let string = storage.string as NSString
        var cursor = range.location
        let end = range.location + clampedLength
        while cursor < end {
            // 跳过段首评论标记（U+FFFC = 65532，伪代码 L6177 精确比较）。
            if string.character(at: cursor) == 0xFFFC {
                cursor += 1
                continue
            }
            var segmentEnd = cursor + 1
            while segmentEnd < end, string.character(at: segmentEnd) != 0xFFFC {
                segmentEnd += 1
            }
            storage.addAttribute(
                .foregroundColor, value: color,
                range: NSRange(location: cursor, length: segmentEnd - cursor))
            cursor = segmentEnd
        }
        storage.endEditing()

        previousHighlightedRange = NSRange(location: range.location, length: clampedLength)
        updateHighlightGradientOverlayFrames()
    }

    /// 伪代码 0x10075ca30 L1248-1273（closure #1 0x10075ce00 L1263-1269）。
    /// previousHighlightedRange 有效（location != NSNotFound && length >= 1）→
    /// 守卫 storage.length >= location+length → enumerateAttribute(
    /// NSForegroundColorAttributeName, in: previous) 逐段恢复原色
    /// （closure：isChapterTitleHighlighted 复位 + 章节标题高亮复位）；
    /// 完成后 previousHighlightedRange = (NSNotFound, 0)。
    private func restorePreviousHighlight() {
        let previous = previousHighlightedRange
        guard previous.location != NSNotFound, previous.length >= 1 else { return }
        guard let textStorage = contentTextView.textStorage else { return }
        guard previous.location + previous.length <= textStorage.length else {
            previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
            return
        }
        guard let originalColor = settings?.textUIColor else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(
            .foregroundColor, in: previous, options: []) { value, subRange, _ in
            // closure #1（0x10075ce00）：TTS 高亮段恢复正文色，其余保持。
            if let color = value as? UIColor,
               color == self.settings?.ttsHighlightUIColor {
                textStorage.addAttribute(
                    .foregroundColor, value: originalColor, range: subRange)
            }
        }
        textStorage.endEditing()
        isChapterTitleHighlighted = false
        // 章节 title 高亮复位（同 updateHighlight 注释）。
        previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
    }

    /// 伪代码 0x10075ce60 L1280-1285。
    /// 块体为 ICF 误标嫌疑（实为评论命中检查路径）；语义按签名还原：
    /// 清除 TTS 高亮 + 待处理高亮队列。
    func clearHighlight() {
        pendingHighlightRange = nil
        pendingChapterTitleHighlight = nil
        updateHighlight(
            range: NSRange(location: NSNotFound, length: 0),
            highlightChapterTitle: false)
    }

    // MARK: 手势

    /// 伪代码 0x10075d0b8 L1289-1295：
    /// UILongPressGestureRecognizer 且其视图是 SelectableReaderTextView → true；否则 false。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let longPress = gestureRecognizer as? UILongPressGestureRecognizer else {
            return true
        }
        return longPress.view is SelectableReaderTextView
    }

    /// 伪代码 0x10075d4a8 L1299-1306。
    /// 点位转换（convertPoint:toView: 确证）后交给 blocksContainerTap 判定
    /// （pgo_only blocksContainerTap 与本函数共体）。
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let point = gestureRecognizer.location(in: contentTextView)
        return blocksContainerTap(at: point, from: gestureRecognizer.view ?? view)
    }

    /// 容器点击拦截（pgo_only，签名确证）：
    /// 点击落在评论矩形 → 拦截容器点击（交给评论 tap 处理）。
    private func blocksContainerTap(at point: CGPoint, from sourceView: UIView) -> Bool {
        let converted = contentTextView.convert(point, from: sourceView)
        return isPointOnComment(converted)
    }

    /// 点击是否落在段落评论矩形上（L182-185；closure #1 0x10075e4e4 为
    /// (comment, rect) 元组过滤闭包）。
    func isPointOnComment(_ point: CGPoint) -> Bool {
        cachedCommentRects.contains { $0.rect.contains(point) }
    }

    /// 保住文本选择的容器点击判定（伪代码 0x1008b4914 L1322-1324）。
    /// 体为候选词循环 contains 检查（7 个候选，命中即 true）；
    /// 候选集合未能从反编译恢复 —— 按最小语义还原，待真机对照。
    func shouldPreserveTextSelectionOnContainerTap(
        at point: CGPoint, from sourceView: UIView
    ) -> Bool {
        let candidates = [
            "selection", "selectionRect", "selectedText",
            "textSelection", "comment", "attachment", "highlight",
        ]
        let description = String(describing: type(of: sourceView))
        return candidates.contains { description.contains($0) }
    }

    // MARK: widget 桥

    /// widget 上下文（pgo_only makeWidgetContext(for:)）。
    func makeWidgetContext(for page: PageData) -> ReaderDisplayContext {
        ReaderDisplayContext(
            page: page,
            bookName: bookName,
            totalChapters: totalChapters)
    }
}
