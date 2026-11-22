// 原路径: ReadMain/Views/Reader/ReaderSharedViews.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-09 / ReaderSharedViews.swift），
//     地址：AppThemeSurface.fill(opacity:followsAppearance:) 0x10044cf78 等 3 块 L8-17
//     （traitColor 闭包 0x10080d608 L12-16：colorWithAlphaComponent/
//     secondarySystemBackgroundColor/userInterfaceStyle/whiteColor 确证）/
//     GlassCardModifier.body 0x10080d6b4 L38-53（Glass.clear|regular + Material.ultraThin
//     确证）/ ReaderToolbarCardModifier.body 0x10080de9c L61-69 /
//     AppThemeCardBackgroundImageView.updateUIView 0x10080df00 L82-89 +
//     RenderView 初始化 0x10080e070/0x10080e190 L94-105（clearColor/setContentMode/
//     setOpaque/setUserInteractionEnabled 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSharedViews.c（64673 行）
//   - 事实：AppThemeSurface.fill —— 深浅色 trait 双色动态色（白/secondarySystemBackground
//     分支确证）；GlassCardModifier —— Glass.clear/regular + Material.ultraThin 三档；
//     AppThemeCardBackgroundImageView —— RenderView（clear/非交互/aspectFill）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - AppThemeSurface/GlassCard/背景图: high（选择子确证）
//   - 其余共享视图（64673 行）: structural（按主链还原，细节待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 主题表面填充（枚举命名空间；trait 双色确证）。
enum AppThemeSurface {

    /// 伪代码 0x10044cf78（L8-17）+ trait 闭包（0x10080d608，L12-16）：
    /// 深浅色动态 UIColor（白色 / secondarySystemBackground 分支确证）。
    static func fill(opacity: Double, followsAppearance: Bool) -> Color {
        let dynamic = UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor.secondarySystemBackground
                    .withAlphaComponent(CGFloat(opacity))
            }
            return UIColor.white.withAlphaComponent(CGFloat(opacity))
        }
        _ = followsAppearance
        return Color(dynamic)
    }
}

/// 玻璃卡片修饰（伪代码 0x10080d6b4，L38-53）。
struct GlassCardModifier: ViewModifier {
    var style: GlassStyle

    enum GlassStyle {
        case clear
        case regular
        case ultraThin
    }

    /// 玻璃档位（readerToolbarCard 0x10061d5ac level 参数域确证；档位映射
    /// 推断）。
    enum Level: String, CaseIterable {
        case regular
        case prominent

        var glassStyle: GlassStyle {
            self == .prominent ? .regular : .clear
        }
    }

    func body(content: Content) -> some View {
        switch style {
        case .clear:
            // glassEffect 为 iOS 26 Liquid Glass API——本工具链（iOS 18.5
            // SDK）不可用；以 ultraThin material 桥接（记入仍不清楚）。
            content.background(.ultraThinMaterial)
        case .regular:
            content.background(.regularMaterial)
        case .ultraThin:
            content.background(.ultraThinMaterial)
        }
    }
}

/// 阅读器工具栏卡片修饰（伪代码 0x10080de9c，L61-69）。
struct ReaderToolbarCardModifier: ViewModifier {
    /// 圆角（readerToolbarCard 0x10061d5ac cornerRadius 参数域）。
    var cornerRadius: CGFloat = 14
    /// 玻璃档（0x10061d5ac level 参数域）。
    var level: GlassCardModifier.Level = .regular

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppThemeSurface.fill(opacity: 0.92, followsAppearance: true))
            .cornerRadius(cornerRadius)
    }
}

/// 主题卡片背景图层（AppThemeCardBackgroundImageView 确证）。
struct AppThemeCardBackgroundImageView: UIViewRepresentable {
    var image: UIImage?

    /// 渲染视图（0x10080e070/0x10080e190，L94-105 确证）。
    final class RenderView: UIImageView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            contentMode = .scaleAspectFill
            isOpaque = false
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false
        }
    }

    func makeUIView(context: Context) -> RenderView {
        let view = RenderView(frame: .zero)
        view.image = image
        return view
    }

    func updateUIView(_ uiView: RenderView, context: Context) {
        // 伪代码 0x10080df00（L82-89）：setImage 确证。
        uiView.image = image
    }
}

// MARK: - T-1401-03 逐域补齐（共享视图域）

extension AppThemeCardBackgroundImageView.RenderView {

    /// 伪代码 0x10083d76c（L116-130）：configure——源图 + 布局 + 图模式 +
    /// 缓存标识（块体为计数器桩，按签名语义还原）。
    func configure(
        sourceImage: UIImage,
        layout: HighlightBackgroundImageLayout,
        imageMode: AppThemeCardBackgroundImageMode,
        cacheIdentifier: String?
    ) {
        self.image = sourceImage
        contentMode = imageMode == .stretch ? .scaleToFill : .scaleAspectFill
        accessibilityIdentifier = cacheIdentifier
        setNeedsLayout()
    }

    /// 伪代码 0x10080e800（L132-135）：外观跟随位（offset 24 字节域）→
    /// AppThemeManager.progressBarsFollowAppearance 绑定刷新。
    override func layoutSubviews() {
        super.layoutSubviews()
        guard followsAppearanceProgressBars else { return }
        _ = AppThemeManager.shared.progressBarsFollowAppearance
    }

    /// 外观跟随位（offset 24 域；推断命名）。
    var followsAppearanceProgressBars: Bool {
        get { objc_getAssociatedObject(self, &Self.followKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(
                self, &Self.followKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private static var followKey: UInt8 = 0
}

/// 手势下滑关闭状态（ReaderPresentationDismissController.update 参数域；
/// PageViewController onSwipeUpProgress 消费域确证）。
struct ReaderGestureDismissState {
    var translation: CGSize = .zero
    var velocity: CGSize = .zero
    var progress: CGFloat = 0
    var isActive: Bool = false
}

/// 阅读页呈现关闭控制器（0x10080d0e4/0x10080d1e4/0x10080d2f8 域；
/// CATransaction begin/setDisableActions:/commit + spring 0.32 域确证）。
@MainActor
final class ReaderPresentationDismissController {

    /// 呈现视图（sub_1002A684C 取值域）。
    weak var presentedView: UIView?
    /// 完成标志（offset 88 域确证）。
    private var isCompleting = false
    /// 手势位移缓存（offsets 48-80 域确证）。
    private var translation: CGSize = .zero
    private var dismissProgress: CGFloat = 0
    /// 弹性动画（reset 0.32/0.9 域确证）。
    private var animator: UIViewPropertyAnimator?

    /// 伪代码 0x10080d0e4（L772-782）：完成标志早退 → 位移/进度缓存
    ///（offsets 48-80 域）→ CATransaction（setDisableActions:1 域）内
    /// applyPresentationState 域应用。
    func update(state: ReaderGestureDismissState) {
        guard !isCompleting else { return }
        translation = state.translation
        dismissProgress = state.progress
        guard let view = presentedView else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyPresentationState(to: view, state: state, isCompleting: false)
        CATransaction.commit()
    }

    /// 呈现状态应用域（0x10080d0e4 调用域确证）。
    private func applyPresentationState(
        to view: UIView, state: ReaderGestureDismissState, isCompleting: Bool
    ) {
        let offset = max(state.translation.height, 0)
        view.transform = CGAffineTransform(
            translationX: 0, y: isCompleting ? view.bounds.height : offset)
        view.alpha = isCompleting ? 0 : max(1 - state.progress, 0)
    }

    /// 伪代码 0x10080d1e4（L784-804）：状态清零（v1[3]/v1[4] 域）→
    /// setUserInteractionEnabled:1 → animated 分支 spring(0.32, 0.9)
    /// startAnimation 域 / 非动画直应用。
    func reset(animated: Bool) {
        translation = .zero
        dismissProgress = 0
        guard let view = presentedView else { return }
        view.isUserInteractionEnabled = true
        if animated {
            animator?.stopAnimation(true)
            let spring = UIViewPropertyAnimator(
                duration: 0.32, dampingRatio: 0.9
            ) {
                self.applyPresentationState(
                    to: view,
                    state: ReaderGestureDismissState(),
                    isCompleting: false)
            }
            animator = spring
            spring.startAnimation()
        } else {
            applyPresentationState(
                to: view, state: ReaderGestureDismissState(),
                isCompleting: false)
        }
    }

    /// 伪代码 0x10080d2f8（L806-826）：完成标志置位 → setUserInteractionEnabled:0
    /// → spring(0.32) 域 + addCompletion 域 → onFinished 回调。
    func complete(onFinished: @escaping () -> Void) {
        guard !isCompleting else { return }
        isCompleting = true
        guard let view = presentedView else {
            onFinished()
            return
        }
        view.isUserInteractionEnabled = false
        let spring = UIViewPropertyAnimator(duration: 0.32, dampingRatio: 1.0) {
            self.applyPresentationState(
                to: view,
                state: ReaderGestureDismissState(
                    translation: CGSize(
                        width: 0, height: view.bounds.height),
                    progress: 1),
                isCompleting: true)
        }
        spring.addCompletion { _ in
            onFinished()
        }
        spring.startAnimation()
    }
}

/// 视图扩展域（glass* 九件 + 设置组头 + 命中区）。
extension View {

    /// 伪代码 0x10061d5ac（L286-288）：spring(0.32, 0.88, 0.08) withAnimation
    /// 域（0x3FB47AE147AE147B blend 域确证）+ 玻璃卡片修饰（MainActor 断言
    /// 确证——"Leaflow/MangaReaderView.swift" L243 域）。
    @MainActor
    func readerToolbarCard(
        cornerRadius: CGFloat, level: GlassCardModifier.Level
    ) -> some View {
        withAnimation(
            .spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.08)
        ) {
            modifier(
                ReaderToolbarCardModifier(
                    cornerRadius: cornerRadius, level: level))
        }
    }

    /// 伪代码 0x10048e9e4（L290-292）：圆底玻璃背景（块体与 LocalBookEditMode
    /// 枚举域 ICF 合并）。
    func readerToolbarCircleBackground() -> some View {
        modifier(GlassCardModifier(style: .regular))
            .clipShape(Circle())
    }

    /// 伪代码 0x100424fd8（L353-365）：胶囊玻璃背景（Capsule 元数据域确证）。
    func glassEffectCapsuleBackground(followsAppearance: Bool) -> some View {
        background(
            AppThemeSurface.fill(
                opacity: followsAppearance ? 0.85 : 0.95,
                followsAppearance: followsAppearance)
        )
        .clipShape(Capsule())
    }

    /// 伪代码 0x10048787c（glass 域）：圆底玻璃背景。
    func glassEffectCircleBackground() -> some View {
        background(AppThemeSurface.fill(opacity: 0.9, followsAppearance: true))
            .clipShape(Circle())
    }

    /// 伪代码 0x100bfe5d4（L390-410）：圆角玻璃背景。
    func glassEffectRoundedBackground(
        cornerRadius: CGFloat, followsAppearance: Bool
    ) -> some View {
        background(
            AppThemeSurface.fill(
                opacity: followsAppearance ? 0.85 : 0.95,
                followsAppearance: followsAppearance)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// 伪代码 0x100d39200（L434-442）：玻璃列表卡片样式。
    func glassListCardStyle(cornerRadius: CGFloat) -> some View {
        self
            .background(AppThemeSurface.fill(opacity: 0.9, followsAppearance: true))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// 伪代码 0x10091841c（L444-446）：主题内容卡命中区形状。
    func appThemeContentCardHitShape(defaultCornerRadius: CGFloat) -> some View {
        contentShape(
            RoundedRectangle(cornerRadius: defaultCornerRadius))
    }

    /// 伪代码 0x100a939a0（L501-513）：设置组头（标题串参数域确证）。
    func settingsGroupHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// 伪代码 0x1008e39cc（L538-541）：玻璃列表分组底。
    func glassListSection(followsAppearance: Bool) -> some View {
        glassListCardStyle(cornerRadius: 12)
    }

    /// 伪代码 0x100b39110（L548-553）：玻璃列表多行分组底。
    func glassListMultiRowSection(followsAppearance: Bool) -> some View {
        glassListCardStyle(cornerRadius: 16)
    }

    /// 伪代码 0x100aba6ec（L557-579）：设置行玻璃底。
    func settingsGlassRowBackground(followsAppearance: Bool) -> some View {
        background(
            AppThemeSurface.fill(
                opacity: followsAppearance ? 0.8 : 0.92,
                followsAppearance: followsAppearance)
        )
    }
}

/// 更多操作信息行（类型树 ReaderMoreInfoItem L11182-11187）。
struct ReaderMoreInfoItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

/// 更多操作动作项（类型树 ReaderMoreActionItem L11173-11180）。
struct ReaderMoreActionItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isEnabled: Bool = true
    var isSelected: Bool = false
    let action: () -> Void
}

/// 顶部更多操作面板（类型树 L11089-11098；PGO 13 个成员 getter）。
struct ReaderTopMoreActionsPanel<Cover: View>: View {
    let title: String
    var subtitle: String?
    var details: [ReaderMoreInfoItem] = []
    let actions: [ReaderMoreActionItem]
    var onHeaderTap: (() -> Void)?
    let onDismiss: () -> Void
    let cover: () -> Cover
    @Environment(\.colorScheme) private var colorScheme
    var actionDismissDelay: Double = 0.12

    var body: some View {
        VStack(spacing: 0) {
            header
            actionGrid
        }
        .background(
            AppThemeSurface.fill(
                opacity: 0.94, followsAppearance: true))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(0.08), lineWidth: 0.5))
        .readerToolbarCard(cornerRadius: 20, level: .regular)
    }

    /// header getter（PGO 签名确证）。
    @ViewBuilder
    private var header: some View {
        if let onHeaderTap {
            Button(action: onHeaderTap) {
                headerContent
            }
            .buttonStyle(.plain)
        } else {
            headerContent
        }
    }

    /// headerContent getter（PGO 签名确证）：封面 + 标题/副标题 + 详情行。
    private var headerContent: some View {
        HStack(spacing: 12.0) {
            coverView
            VStack(alignment: .leading, spacing: 3.0) {
                Text(title)
                    .appThemeText(.headline)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                ForEach(visibleDetails) { item in
                    detailRow(item)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14.0)
        .padding(.vertical, 12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// coverView getter（PGO 签名确证）。
    private var coverView: some View {
        cover()
            .frame(width: 44.0, height: 58.0)
            .clipShape(RoundedRectangle(cornerRadius: 6.0))
    }

    /// visibleDetails getter（PGO 签名确证）：最多三行。
    private var visibleDetails: [ReaderMoreInfoItem] {
        Array(details.prefix(3))
    }

    /// detailRow(_:)（PGO 签名确证）。
    private func detailRow(_ item: ReaderMoreInfoItem) -> some View {
        HStack(spacing: 4.0) {
            Image(systemName: item.systemImage)
                .font(.system(size: 10.0))
                .appThemeAccent(opacity: 0.8)
            Text(item.title)
                .appThemeText(.caption, opacity: 0.55)
            Text(item.value)
                .appThemeText(.caption, opacity: 0.75)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    /// actionGrid getter（PGO 签名确证）。
    private var actionGrid: some View {
        actionGridContent
            .padding(.horizontal, 10.0)
            .padding(.bottom, 12.0)
    }

    /// actionGridContent getter（PGO 签名确证）。
    private var actionGridContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72.0), spacing: 8.0)],
            spacing: 8.0) {
            ForEach(actions) { item in
                actionButton(item)
            }
        }
    }

    /// actionButton(_:)（PGO 签名确证）。
    private func actionButton(_ item: ReaderMoreActionItem) -> some View {
        Button {
            dismissThenPerform(item.action)
        } label: {
            VStack(spacing: 5.0) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18.0))
                    .foregroundStyle(
                        item.isSelected
                            ? AnyShapeStyle(AppThemeManager.shared.accentColor(
                                for: colorScheme))
                            : AnyShapeStyle(Color.primary))
                    .frame(height: 22.0)
                Text(item.title)
                    .appThemeText(.caption, opacity: 0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
    }

    /// dismissThenPerform(_:)（PGO 签名确证）。
    private func dismissThenPerform(_ action: @escaping () -> Void) {
        onDismiss()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + actionDismissDelay) {
            action()
        }
    }
}

/// 阅读菜单覆盖层（类型树 ReaderMenuOverlay L11102-11107）。
struct ReaderMenuOverlay<TopBar: View, BottomBar: View>: View {
    @Binding var showMenu: Bool
    var onDismissRequest: (() -> Void)?
    let topBar: TopBar
    let bottomBar: BottomBar

    var body: some View {
        ZStack {
            if showMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        if let onDismissRequest {
                            onDismissRequest()
                        } else {
                            showMenu = false
                        }
                    }
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    bottomBar
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showMenu)
    }
}

/// 阅读顶部更多动效（0x100a4a7d4 getter 域：spring 0.32 档确证）。
extension Animation {
    static var readerTopMoreActionDismiss: Animation {
        .spring(response: 0.32, dampingFraction: 0.9, blendDuration: 0)
    }
}

