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

// MARK: - 页面内容视图控制器

/// 页面内容视图控制器（CovMap L114-1324，67 函数）。
/// 职责：单页正文渲染（TextKit2）、章节标题快照、段落评论命中、TTS 高亮、
/// 全行下划线与渐变高亮覆盖层、布局 widget 标签、加载占位层。
@MainActor
final class PageContentViewController: UIViewController, UIGestureRecognizerDelegate {

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
    var originalText: String = ""
    var bodyCache = ReaderPageBodyCache()
    var previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
    var pendingHighlightRange: NSRange?
    var pendingChapterTitleHighlight: Bool?

    var useTransparentBackground: Bool = false

    /// showsLayoutWidgets.didset 0x100756090 L168-173：
    /// 置 false 时 hideWidgetLabels()；视图已加载时刷新动态内容。
    var showsLayoutWidgets: Bool = false {
        didSet {
            if !showsLayoutWidgets {
                hideWidgetLabels()
            }
            if isViewLoaded {
                refreshDynamicContent(event: ReaderWidgetRefreshEvent(.layout))
            }
        }
    }

    private(set) var chapterTitleView = ReaderChapterTitleView()
    // wave-17：+Comments/+Widgets 分册扩展（跨文件）有访问——private 放宽
    // 到 internal（原始二进制无文件边界概念）。
    var _widgetInstances: [(id: UUID, widget: LayoutWidget)] = []
    var dynamicRefreshTimer: Timer?
    var dynamicRefreshTimerTolerance: TimeInterval = 0

    /// widget 实例桥（+Widgets 消费域 `widgetInstances` 命名确证——
    /// 存储域 _widgetInstances 的无前缀别名，wave-16）。
    var widgetInstances: [(id: UUID, widget: LayoutWidget)] {
        get { _widgetInstances }
        set { _widgetInstances = newValue }
    }
    var fullLineUnderlineView = UIView()
    var fullLineUnderlineLayer = CAShapeLayer()
    var highlightGradientBackgroundView = HighlightGradientOverlayView(renderMode: .backgroundSnapshot)
    var highlightGradientForegroundView = HighlightGradientOverlayView(renderMode: .foregroundGradient)

    var widgetLabels: [UUID: UILabel] = [:]
    var widgetImageViews: [UUID: UIImageView] = [:]
    var renderedWidgetSymbols: [UUID: (view: ObjectIdentifier, state: ReaderWidgetSymbolState)] = [:]

    /// widget 刷新驱动（懒加载体在伪代码 0x100756260 块：NotificationCenter + 观察注册；
    /// init 签名按 PGO：notifications/now/applicationIsActive/refresh）。
    lazy var widgetRefreshDriver: ReaderWidgetRefreshDriver = {
        ReaderWidgetRefreshDriver(
            notifications: .default,
            now: { Date() },
            applicationIsActive: { UIApplication.shared.applicationState == .active }
        ) { [weak self] event in
            self?.refreshDynamicContent(event: event)
        }
    }()

    var isViewSetup = false
    /// 段落评论标记字符（U+FFFC；applyForegroundHighlight/正文标记共用）。
    let commentMarkerChar: Character = "\u{FFFC}"
    var loadingOverlay: UIView?
    /// 段落评论矩形缓存 [(comment, rect)]（元素 88 字节步长确证；+Comments
    /// 分册有写入——setter 放宽，wave-17）。
    var cachedCommentRects: [(comment: ParagraphComment, rect: CGRect)] = []
    /// 命中缓存时的布局指纹（bounds/container/inset/padding 十字段 + 有效位，L1338-1368）。
    var cachedCommentRectsLayoutValid = false
    var lastLoggedViewBounds: CGRect = .zero
    var lastLoggedContentFrame: CGRect = .zero
    var lastTitleSnapshotKey: (width: CGFloat, key: String)?
    var pageRenderSignature: Int?
    var lastWidgetFontName: String?
    /// PageBackViewController.configure 回写的首页 bounds（0x100754300 L505-510 确证）。
    var initialPageBounds: CGRect = .zero
    var backgroundImageView: UIImageView?
    /// 评论点击回调（handleCommentAttachmentTap L941-943 调用）。
    var onCommentTap: ((ParagraphComment) -> Void)?

    /// 阅读设置（init 存 nil；configure/setupViews/updateContent 使用）。
    var settings: ReadingSettings?

    /// contentTextView 懒加载（pgo_only getter + init(isSelectable:) 0x1007563d8 块确证；
    /// +Comments 分册扩展跨文件访问——放宽 internal，wave-17）。
    lazy var contentTextView: SelectableReaderTextView = {
        SelectableReaderTextView(isSelectable: isInteractive)
    }()

    /// 活动选择处理器（ReaderTextSelectionHandling 协议注释域确证；
    /// Spread/Pool 双消费域确证成员名——wave-16 补桥）。
    var contentSelectionHandler: ReaderTextSelectionHandling? {
        contentTextView
    }

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
    /// 内容视图背景：transparent → clear，否则阅读背景色。
    /// 背景图：!transparent 且 settings.backgroundUIImage 存在 → UIImageView
    /// （contentMode 2 = scaleAspectFill，frame = view.bounds，insertSubview atIndex 0）；
    /// nil 时移除。内容视图 clear 背景 + isUserInteractionEnabled=false +
    /// layer 加 fullLineUnderlineLayer；依次 addSubview(contentTextView/chapterTitleView/
    /// fullLineUnderlineView)；setupWidgetLabels(settings:)；updateFrames()。
    func setupViews() {
        guard !isViewSetup, let settings else { return }
        isViewSetup = true

        view.backgroundColor = useTransparentBackground ? .clear : settings.readerBackgroundUIColor

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

}
