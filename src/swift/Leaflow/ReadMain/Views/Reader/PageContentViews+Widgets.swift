// 原路径: ReadMain/Views/Reader/PageContentViews+Widgets.swift
// 证据:
//   - PGO: 14 个主函数（index/task_functions.csv T-301-03 / PageContentViews+Widgets.swift），
//     地址：updateDynamicRefreshRequirements 0x10076268c L38-46 / refreshAllWidgetContent
//     0x100762bc8 L67-74 / refreshDynamicContent(event:) closure#1 0x10076680c L88-90 /
//     setupWidgetLabels 0x100762dbc L97-142 / updateWidgetLabels 0x100763f18 L147-203 /
//     refreshWidgetLabels 0x100764a14 L206-247 / hideWidgetLabels 0x100762198 L249-252 /
//     applyWidgetLayout 0x1007655ec L256-284 / preferredWidgetSize 0x1007657ac L286-295 /
//     configureWidgetView 0x100765184 L298-325 / makeWidgetSymbolImage 0x100765928 L327-364
//     (+renderer 闭包 0x100762530 L338-352) / ReaderWidgetConfiguration.init(settings:)；
//     另有 implicit closure（refreshWidgetLabels UIColor ×3 / configureWidgetView Bool ×3 /
//     makeWidgetSymbolImage CGFloat ×1，见骨架清单）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageContentViews+Widgets.c（3392 行）
//   - 关键选择子：removeFromSuperview/setNumberOfLines:/setLineBreakMode:/addSubview:/
//     setContentMode:/colorWithAlphaComponent:/setFont:/setTextColor:/setTextAlignment:
//     (1/2/0 三分支确证)/setFrame:(y = pageHeight * 比例 + height * -0.5)/isHidden/image/
//     size/font.lineHeight(两处)/sizeThatFits:/intrinsicContentSize/setText:/setImage:/
//     setAttributedText:/configurationWithPointSize:weight:/setScale:/initWithSize:format:/
//     imageWithActions:/imageWithAlignmentRectInsets:/imageWithBaselineOffsetFromBottom:/
//     imageWithRenderingMode:
//   - 关键字面量："battery.0"（0x2E79726574746162 + 0x30，9 字符，电量符号模板）、
//     外部字面量 0x101260220（22 字符，符号名模板，未解码）
//   - pgo_only（ICF 合并，无独立地址）：startDynamicRefreshTimer/stopDynamicRefreshTimer/
//     makeWidgetContext（体在主文件 PageContentViews.swift）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - setupWidgetLabels/hideWidgetLabels/applyWidgetLayout/preferredWidgetSize/
//     configureWidgetView: high（选择子+常量确证）
//   - makeWidgetSymbolImage: medium-high（battery.0 模板 + 渲染管线选择子确证）
//   - updateWidgetLabels/refreshWidgetLabels/updateDynamicRefreshRequirements: medium
//     （选择子确证；日期格式/刷新节流细节待真机对照）
//   - refreshAllWidgetContent: medium（fontName 比较确证，剩余逻辑为骨架）
// 还原: 2026-11-19
// 依赖: LayoutWidget(type:alignment:showOnFirstPage:)/refreshCadence getter 与
//   ReaderWidgetRefreshEvent.includes(LayoutWidget:) 按 PGO/已还原 ReaderLayoutConfig.swift
//   与 ReaderWidgetRefreshDriver.swift 签名引用；ReaderWidgetConfiguration.init(settings:)、
//   ReaderDisplayItem.dateFormatter、LayoutWidget.defaultWidgets/static dateCadence(for:)
//   按 PGO 签名（实现落在 T-301-11 分册）。

import UIKit

// MARK: - widget 装配与布局（PageContentViewController 扩展）

extension PageContentViewController {

    /// widget 实例清单（ReaderWidgetConfiguration 输出 + 实例标识；
    /// widgetLabels 的 [UUID: UILabel] 键由此而来）。
    private var widgetInstances: [(id: UUID, widget: LayoutWidget)] {
        get { _widgetInstances }
        set { _widgetInstances = newValue }
    }
    private var _widgetInstances: [(id: UUID, widget: LayoutWidget)] = []

    // MARK: 动态刷新需求

    /// 伪代码 0x10076268c L38-46。
    /// 按 refreshCadence（LayoutWidget.refreshCadence getter，PGO 确证）判断是否存在
    /// 需要动态刷新的 widget：有 → startDynamicRefreshTimer，无 → stopDynamicRefreshTimer。
    /// 两个 timer 方法为 pgo_only（与本函数共体）。
    func updateDynamicRefreshRequirements() {
        let hasDynamicWidgets = widgetInstances.contains { $0.widget.refreshCadence != nil }
        if hasDynamicWidgets {
            startDynamicRefreshTimer()
        } else {
            stopDynamicRefreshTimer()
        }
    }

    private var dynamicRefreshTimer: Timer?
    private var dynamicRefreshTimerTolerance: TimeInterval = 0

    private func startDynamicRefreshTimer() {
        // pgo_only（签名确证）：Timer 容差按 cadence.tolerance（PGO 确证该属性存在）。
        guard dynamicRefreshTimer == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAllWidgetContent()
            }
        }
        timer.tolerance = dynamicRefreshTimerTolerance
        RunLoop.main.add(timer, forMode: .common)
        dynamicRefreshTimer = timer
    }

    private func stopDynamicRefreshTimer() {
        dynamicRefreshTimer?.invalidate()
        dynamicRefreshTimer = nil
    }

    /// 全量刷新（伪代码 0x100762bc8 L67-74）。
    /// 字体名比较确证：ReadingSettings.widgetFont(size:).fontName 变化时重建标签；
    /// 其余为刷新当前页 widget 内容 + 刷新需求重算。
    func refreshAllWidgetContent() {
        guard let settings, let page = pageData else { return }
        if let widgetFont = settings.widgetFont(size: settings.fontSize) {
            if lastWidgetFontName != widgetFont.fontName {
                lastWidgetFontName = widgetFont.fontName
                setupWidgetLabels(settings: settings)
            }
        }
        refreshWidgetLabels(
            context: makeWidgetContext(for: page),
            settings: settings,
            event: .refreshAll)
        updateDynamicRefreshRequirements()
    }

    /// 事件过滤刷新（closure #1 0x10076680c L88-90：(LayoutWidget) -> Bool）。
    /// ReaderWidgetRefreshEvent.includes(LayoutWidget:)（PGO 确证）命中任一 widget
    /// 才重刷；否则跳过。
    func refreshDynamicContent(event: ReaderWidgetRefreshEvent) {
        guard showsLayoutWidgets, let settings, let page = pageData else { return }
        let affected = widgetInstances.contains { event.includes($0.widget) }
        guard affected else { return }
        refreshWidgetLabels(
            context: makeWidgetContext(for: page),
            settings: settings,
            event: event)
    }

    // MARK: 标签装配

    /// 伪代码 0x100762dbc L97-142。
    /// 旧标签/图先 removeFromSuperview；按 ReaderWidgetConfiguration(settings:) 生成
    /// widget 列表，为每个创建 UILabel（numberOfLines/lineBreakMode 设置确证）与
    /// UIImageView（contentMode 设置确证），addSubview 到 view。
    func setupWidgetLabels(settings: ReadingSettings) {
        for (_, label) in widgetLabels { label.removeFromSuperview() }
        for (_, imageView) in widgetImageViews { imageView.removeFromSuperview() }
        widgetLabels.removeAll()
        widgetImageViews.removeAll()
        renderedWidgetSymbols.removeAll()

        let configuration = ReaderWidgetConfiguration(settings: settings)
        var instances: [(id: UUID, widget: LayoutWidget)] = []
        for widget in configuration.widgets {
            let label = UILabel()
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            view.addSubview(label)
            let id = UUID()
            widgetLabels[id] = label

            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
            widgetImageViews[id] = imageView
            instances.append((id, widget))
        }
        widgetInstances = instances
        updateDynamicRefreshRequirements()
    }

    /// widget 展示文本。
    /// 日期类 widget（type 含 date）→ ReaderDisplayItem.dateFormatter（PGO 确证）；
    /// 其余文本内容由 ReaderDisplayItem 提供（具体 API 待 T-301-11 落地，此处留空注释）。
    private func widgetContent(
        for widget: LayoutWidget,
        context: ReaderDisplayContext,
        isFirstPage: Bool
    ) -> String {
        _ = context
        if widget.type.lowercased().contains("date") {
            return ReaderDisplayItem.dateFormatter.string(from: Date())
        }
        // 非 date widget 的文本来源待真机对照（电量和进度类由驱动推送）。
        _ = isFirstPage
        return ""
    }

    /// 内容刷新（伪代码 0x100763f18 L147-203）。
    /// 逐 widget：configureWidgetView 装配文本/符号；颜色带 alpha
    /// （colorWithAlphaComponent: 确证）；字体/文字色设置；isFirstPage 差异分支
    /// （签名确证）；applyWidgetLayout 布局。
    /// 深层分支（占位/错误态文案、implicit closure ×3）待真机对照。
    func updateWidgetLabels(
        context: ReaderDisplayContext,
        settings: ReadingSettings,
        isFirstPage: Bool
    ) {
        for (id, widget) in widgetInstances {
            guard let label = widgetLabels[id],
                  let imageView = widgetImageViews[id] else { continue }
            // WidgetPageScope.shouldShow（已还原 ReaderLayoutConfig.swift）。
            guard WidgetPageScope.shouldShow(isFirstPage: isFirstPage)
                || widget.showOnFirstPage else {
                label.isHidden = true
                imageView.isHidden = true
                continue
            }
            let content = widgetContent(for: widget, context: context, isFirstPage: isFirstPage)
            let tintColor = settings.textUIColor.withAlphaComponent(0.85)
            if let font = settings.widgetFont(size: settings.fontSize) {
                label.font = font
            }
            label.textColor = tintColor
            let configured = configureWidgetView(
                label: label,
                imageView: imageView,
                widget: widget,
                context: context,
                content: content,
                tintColor: tintColor)
            if configured {
                applyWidgetLayout(
                    label: label,
                    imageView: imageView,
                    widget: widget,
                    pageWidth: view.bounds.width,
                    pageHeight: view.bounds.height)
            }
        }
    }

    /// 事件刷新（伪代码 0x100764a14 L206-247）。
    /// bounds/textColor 参与确证；经 updateWidgetLabels 走全量装配。
    func refreshWidgetLabels(
        context: ReaderDisplayContext,
        settings: ReadingSettings,
        event: ReaderWidgetRefreshEvent
    ) {
        _ = event
        guard isViewLoaded else { return }
        updateWidgetLabels(
            context: context,
            settings: settings,
            isFirstPage: pageData?.isFirstPageOfChapter == true)
    }

    /// 隐藏全部 widget（伪代码 0x100762198 L249-252）。
    func hideWidgetLabels() {
        for (_, label) in widgetLabels { label.isHidden = true }
        for (_, imageView) in widgetImageViews { imageView.isHidden = true }
    }

    // MARK: 布局与尺寸

    /// 垂直锚点比例（伪代码 L2757：y = pageHeight * 比例 + height * -0.5）。
    /// 类型→比例映射未从反编译恢复，待真机对照；顶部/底部两档近似。
    private func verticalAnchor(for widget: LayoutWidget) -> CGFloat {
        switch widget.type.lowercased() {
        case "battery", "progress", "chapter", "time":
            return 1.0
        default:
            return 0.0
        }
    }

    /// 伪代码 0x1007655ec L256-284。
    /// 对齐分支 setTextAlignment:（1/2/0 三分支确证，对应 center/right/left）；
    /// frame：y = pageHeight * 比例锚点 + height * -0.5（L2757 确证），
    /// 宽高取 preferredWidgetSize；imageView isHidden 参与。
    func applyWidgetLayout(
        label: UILabel,
        imageView: UIImageView,
        widget: LayoutWidget,
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) {
        _ = pageWidth
        let size = preferredWidgetSize(label: label, imageView: imageView, widget: widget)
        // setTextAlignment 三分支（伪代码 L2722=1(center)/L2735=2(right)/L2746=0(left)）。
        switch widget.alignment {
        case .center: label.textAlignment = .center
        case .trailing: label.textAlignment = .right
        case .leading: label.textAlignment = .left
        }
        let y = pageHeight * verticalAnchor(for: widget) + size.height * -0.5
        label.frame = CGRect(x: 0, y: y, width: size.width, height: size.height)
        imageView.isHidden = imageView.image == nil
    }

    /// 伪代码 0x1007657ac L286-295。
    /// imageView 未隐藏且 image 存在 → image.size 参与宽度（L2783-2790）；
    /// font.lineHeight 两处确证；sizeThatFits(width: ∞) 与 intrinsicContentSize 取大。
    func preferredWidgetSize(
        label: UILabel,
        imageView: UIImageView,
        widget: LayoutWidget
    ) -> CGSize {
        _ = widget
        var width: CGFloat = 0
        if !imageView.isHidden, let image = imageView.image {
            width += image.size.width
        }
        let lineHeight = label.font?.lineHeight ?? 0
        let fitted = label.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: ceil(lineHeight)))
        let intrinsic = label.intrinsicContentSize
        width += max(fitted.width, intrinsic.width)
        let height = max(ceil(lineHeight), max(fitted.height, intrinsic.height))
        return CGSize(width: width, height: height)
    }

    // MARK: 内容装配

    /// 伪代码 0x100765184 L298-325。
    /// content 为空 → 双隐藏返回 false；有符号名 → setImage(makeWidgetSymbolImage(...))；
    /// 有富文本 → setAttributedText:（选择子确证）；纯文本 → setText:。
    /// implicit closure ×3（Bool 判定）细节待真机对照。返回是否成功装配。
    @discardableResult
    func configureWidgetView(
        label: UILabel,
        imageView: UIImageView,
        widget: LayoutWidget,
        context: ReaderDisplayContext,
        content: String,
        tintColor: UIColor
    ) -> Bool {
        _ = context
        if content.isEmpty {
            label.isHidden = true
            imageView.isHidden = true
            return false
        }
        // 符号名来源：电量/进度类按 type 推导（"battery." 模板字面量确证）。
        if widget.type.lowercased().contains("battery"),
           let image = makeWidgetSymbolImage(
            symbolName: "battery",
            variableValue: nil,
            widget: widget,
            tintColor: tintColor) {
            imageView.image = image
            imageView.isHidden = false
        } else {
            imageView.isHidden = true
        }
        label.text = content
        label.isHidden = false
        return true
    }

    // MARK: 符号渲染

    /// 伪代码 0x100765928 L327-364（renderer 闭包 0x100762530 L338-352）。
    /// "battery.0" 模板（字面量确证）：variableValue 参与档位（battery.0..battery.100）；
    /// UIImage.SymbolConfiguration(configurationWithPointSize:weight:) 配置；
    /// UIGraphicsImageRendererFormat scale 设置确证；alignmentRectInsets/
    /// baselineOffset/renderingMode 修饰（选择子确证，具体值待真机对照）。
    func makeWidgetSymbolImage(
        symbolName: String,
        variableValue: Double?,
        widget: LayoutWidget,
        tintColor: UIColor
    ) -> UIImage? {
        _ = widget
        let resolvedName: String
        if symbolName.hasPrefix("battery"), let value = variableValue {
            let bucket = Int(value.rounded(.toNearestOrEven)) / 25 * 25
            resolvedName = "battery.\(bucket)"
        } else if symbolName.hasPrefix("battery") {
            resolvedName = "battery.0"
        } else {
            resolvedName = symbolName
        }
        guard let base = UIImage(systemName: resolvedName) else { return nil }
        let configured = base.applyingSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .regular))
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let size = configured?.size ?? base.size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            // 渲染闭包（0x100762530）：tint 绘制，细节待真机对照。
        }
        return rendered.withTintColor(tintColor, renderingMode: .alwaysTemplate)
    }
}
