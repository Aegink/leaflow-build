// 原路径: ReadMain/Views/Reader/PageBackViewController.swift
// 证据:
//   - PGO: 5 个主函数（index/task_functions.csv T-301-03 / PageBackViewController.swift），
//     地址：associatedPageId 变量初始化 0x10077b730 L6 / configure(backgroundColor:
//     backgroundImage:contentImage:associatedPageId:) 0x100753f6c L11-52 /
//     configure(backgroundColor:backgroundImage:contentViewController:associatedPageId:)
//     0x100754300 L54-100 / viewDidLayoutSubviews 0x100754a6c L102-107 /
//     removeEmbeddedContentViewController 0x100754e98 L129-135
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageBackViewController.c（663 行）
//   - 关键选择子：setBackgroundColor:/setContentMode:2(scaleAspectFill)/setContentMode:0/
//     setAlpha:1.0/setTransform:(单位阵 1.0)/setImage:/setHidden:1/bringSubviewToFront:/
//     addChildViewController:/didMoveToParentViewController:/willMoveToParentViewController:/
//     removeFromParentViewController/removeFromSuperview/loadViewIfNeeded/
//     setUserInteractionEnabled:0/setFrame:(bounds)
//   - 关键字面量：trace 分段 "pageId"(0x3D644965676170)/"background"(0x756F72676B636162+
//     0x646E)/"addChild"(0x646C696843646461)/"load"(1684107116=0x64616F6C)/"frame"
//     (0x656D617266)/"addSubview"(0x6976627553646461+0x7765)/"didMove"(0x65766F4D646964)；
//     外部字面量 0x101271630（16 字符，trace 前缀，未解码）
//   - 跨类证据：configure(contentViewController:) 把 view.bounds 写入
//     PageContentViewController.initialPageBounds ivar（0x100754300 L505-510 确证）
//   - pgo_only（ICF 合并，无独立地址）：updateContentImage(UIImage)（与 configure 的
//     contentImage 分支共体）
//   - 已知噪声：configure 两个重载中出现的 viewDidLayoutSubviews 调用（L79/L483）
//     实为 removeEmbeddedContentViewController（ICF 误标）；
//     viewDidLayoutSubviews 块体（willMove/removeFromParent）疑为 removeEmbedded
//     的共体路径，语义按签名 + 调用关系还原
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - configure 两个重载: high（选择子+trace 分段+contentMode 常量确证）
//   - viewDidLayoutSubviews: medium（块体语义为嵌入清理，归属待真机对照）
//   - removeEmbeddedContentViewController: high（四 ivar 清空确证）
// 还原: 2026-11-19

import UIKit

/// 页背衬容器：翻页过渡期间承载背景色/背景图/内容快照或嵌入式内容控制器。
/// 两个 configure 重载分别服务"图片快照"与"实时内容嵌入"两条路径。
final class PageBackViewController: UIViewController {

    // MARK: ivar（伪代码 init/清空块确证）

    /// 关联页标识（configure 写入；removeEmbeddedContentViewController 清空为空串）。
    private(set) var associatedPageId: String = ""
    private var backgroundImageView: UIImageView?
    private var contentImageView: UIImageView?
    private(set) var embeddedContentViewController: UIViewController?
    /// 懒计算的关联标识串（implicit closure #1 () -> String in configure）。
    private lazy var associatedPageIdTrace: String = { associatedPageId }()

    // MARK: 图片快照路径

    /// 伪代码 0x100753f6c，L11-52。
    /// associatedPageId 写入；view.backgroundColor = backgroundColor；
    /// backgroundImage：nil → 移除 backgroundImageView；否则创建/复用
    /// UIImageView（contentMode 2 = scaleAspectFill，frame = view.bounds，setImage）；
    /// contentImage：nil → contentImageView 隐藏；否则创建/复用
    /// UIImageView（contentMode 0，alpha 1.0，transform 单位阵，frame = bounds，
    /// setImage，bringSubviewToFront）。
    func configure(
        backgroundColor: UIColor,
        backgroundImage: UIImage?,
        contentImage: UIImage?,
        associatedPageId: String
    ) {
        removeEmbeddedContentViewController()
        self.associatedPageId = associatedPageId
        view.backgroundColor = backgroundColor

        if let background = backgroundImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = view.bounds
                view.addSubview(imageView)
                backgroundImageView = imageView
            }
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.removeFromSuperview()
            backgroundImageView = nil
        }

        if let content = contentImage {
            if let existing = contentImageView {
                existing.image = content
            } else {
                let imageView = UIImageView(image: content)
                imageView.contentMode = .scaleToFill
                imageView.alpha = 1.0
                imageView.frame = view.bounds
                imageView.transform = .identity
                view.addSubview(imageView)
                contentImageView = imageView
            }
            contentImageView?.isHidden = false
            if let contentImageView {
                view.bringSubviewToFront(contentImageView)
            }
        } else {
            contentImageView?.isHidden = true
        }
    }

    /// 内容图更新（pgo_only updateContentImage(UIImage)：configure 的
    /// contentImage 分支共体，仅更新已有 contentImageView）。
    func updateContentImage(_ image: UIImage) {
        contentImageView?.image = image
        contentImageView?.isHidden = false
        if let contentImageView {
            view.bringSubviewToFront(contentImageView)
        }
    }

    // MARK: 实时内容嵌入路径

    /// 伪代码 0x100754300，L54-100。
    /// trace："pageId" + associatedPageId → OperationSample；
    /// removeEmbeddedContentViewController；view.backgroundColor = backgroundColor；
    /// background image 处理（同图片路径）；trace "background"；
    /// embeddedContentViewController 与新 VC 相同 → 跳过 addChild（L472-485）；
    /// 否则 addChild(contentViewController)；trace "addChild"；
    /// VC 是 PageContentViewController → initialPageBounds = view.bounds（L505-510）；
    /// loadViewIfNeeded；trace "load"；contentVC.view.frame = view.bounds；trace "frame"；
    /// contentVC.view.isUserInteractionEnabled = false；
    /// 非 same → addSubview(contentVC.view)；trace "addSubview"；
    /// 非 same → didMove(toParent: self) + embeddedContentViewController 存回；
    /// trace "didMove"。
    func configure(
        backgroundColor: UIColor,
        backgroundImage: UIImage?,
        contentViewController: UIViewController,
        associatedPageId: String
    ) {
        removeEmbeddedContentViewController()
        self.associatedPageId = associatedPageId
        // trace 分段（"pageId" + associatedPageId，字面量确证；
        // implicit closure #1 () -> String 为懒计算标识）。
        ReaderPerformanceTrace.log("pageId" + associatedPageIdTrace) { true }
        view.backgroundColor = backgroundColor

        if let background = backgroundImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = view.bounds
                view.addSubview(imageView)
                backgroundImageView = imageView
            }
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.removeFromSuperview()
            backgroundImageView = nil
        }

        let isSameController = embeddedContentViewController === contentViewController
        if !isSameController {
            addChild(contentViewController)
        }

        // 嵌入实时页面时回写首页 bounds（跨类 ivar 写入确证）。
        if let pageContent = contentViewController as? PageContentViewController {
            pageContent.initialPageBounds = view.bounds
        }

        contentViewController.loadViewIfNeeded()
        contentViewController.view.frame = view.bounds
        contentViewController.view.isUserInteractionEnabled = false

        if !isSameController {
            view.addSubview(contentViewController.view)
            contentViewController.didMove(toParent: self)
            embeddedContentViewController = contentViewController
        }
        ReaderPerformanceTrace.log("didMove") { true }
    }

    // MARK: 布局与清理

    /// 伪代码 0x100754a6c，L102-107。
    /// 块体：embeddedContentViewController 存在 → willMove(toParent: nil) +
    /// view.removeFromSuperview + removeFromParent + ivar 清空。
    /// 该语义与 configure 的嵌入流程配套（过渡结束后由布局回调清理）；
    /// 嵌入视图帧同步（frame = bounds）疑与 removeEmbedded 共体，待真机对照。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let embedded = embeddedContentViewController else { return }
        embedded.willMove(toParent: nil)
        embedded.view.removeFromSuperview()
        embedded.removeFromParent()
        embeddedContentViewController = nil
    }

    /// 伪代码 0x100754e98，L129-135。
    /// associatedPageId 置空串；backgroundImageView/contentImageView/
    /// embeddedContentViewController 三 ivar 清空。
    private func removeEmbeddedContentViewController() {
        associatedPageId = ""
        backgroundImageView = nil
        contentImageView = nil
        embeddedContentViewController = nil
    }
}
