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
//   - PGO 标签交错：0x100754a6c 实为 removeEmbeddedContentViewController；
//     0x100754e98 为初始化字段。Objective-C 布局入口 0x1007549c8 调用
//     0x100754884，按 bounds 更新背景图、快照和嵌入视图，不移除子控制器。
//     取证：work/logs/t1602_page_curl_probe.txt。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - configure 两个重载: high（选择子+trace 分段+contentMode 常量确证）
//   - viewDidLayoutSubviews/removeEmbeddedContentViewController: high（Objective-C 调用链确证）
// 还原: 2026-11-19

import UIKit

/// 页背衬容器：翻页过渡期间承载背景色/背景图/内容快照或嵌入式内容控制器。
/// 两个 configure 重载分别服务"图片快照"与"实时内容嵌入"两条路径。
final class PageBackViewController: UIViewController {

    // MARK: ivar（伪代码 init/清空块确证）

    /// 关联页标识（configure 写入，子控制器替换时保留）。
    private(set) var associatedPageId: String = ""
    private var backgroundImageView: UIImageView?
    private var contentImageView: UIImageView?
    private(set) var embeddedContentViewController: UIViewController?

    // MARK: 图片快照路径

    /// 伪代码 0x100753f6c，L11-52。
    /// associatedPageId 写入；view.backgroundColor = backgroundColor；
    /// backgroundImage：nil → 隐藏 backgroundImageView；否则创建/复用
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
                imageView.clipsToBounds = true
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.frame = view.bounds
                view.addSubview(imageView)
                backgroundImageView = imageView
            }
            backgroundImageView?.frame = view.bounds
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.isHidden = true
        }

        if let content = contentImage {
            if let existing = contentImageView {
                existing.image = content
            } else {
                let imageView = UIImageView(image: content)
                imageView.contentMode = .scaleToFill
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.alpha = 1.0
                imageView.frame = view.bounds
                imageView.transform = .identity
                view.addSubview(imageView)
                contentImageView = imageView
            }
            contentImageView?.alpha = 1.0
            contentImageView?.transform = .identity
            contentImageView?.frame = view.bounds
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
    /// 隐藏快照；view.backgroundColor = backgroundColor；
    /// background image 处理（同图片路径）；trace "background"；
    /// embeddedContentViewController 与新 VC 相同 → 跳过 addChild（L472-485）；
    /// 否则 removeEmbeddedContentViewController + addChild；trace "addChild"；
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
        self.associatedPageId = associatedPageId
        ReaderPerformanceTrace.log("pageId=" + associatedPageId) { true }
        contentImageView?.isHidden = true
        view.backgroundColor = backgroundColor

        if let background = backgroundImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.frame = view.bounds
                view.insertSubview(imageView, at: 0)
                backgroundImageView = imageView
            }
            backgroundImageView?.frame = view.bounds
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.isHidden = true
        }

        let isSameController = embeddedContentViewController === contentViewController
        if !isSameController {
            removeEmbeddedContentViewController()
            addChild(contentViewController)
        }

        // 嵌入实时页面时回写首页 bounds（跨类 ivar 写入确证）。
        if let pageContent = contentViewController as? PageContentViewController {
            pageContent.initialPageBounds = view.bounds
        }

        contentViewController.loadViewIfNeeded()
        contentViewController.view.frame = view.bounds
        contentViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentViewController.view.isUserInteractionEnabled = false

        if !isSameController {
            view.addSubview(contentViewController.view)
            contentViewController.didMove(toParent: self)
            embeddedContentViewController = contentViewController
        }
        ReaderPerformanceTrace.log("didMove") { true }
    }

    // MARK: 布局与清理

    /// 0x1007549c8 → 0x100754884：布局同步三类子视图，保留包含关系。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundImageView?.frame = view.bounds
        contentImageView?.frame = view.bounds
        embeddedContentViewController?.view.frame = view.bounds
    }

    /// 0x100754a6c：仅清除旧嵌入内容，不改变页标识或图片缓存。
    private func removeEmbeddedContentViewController() {
        guard let embedded = embeddedContentViewController else { return }
        embedded.willMove(toParent: nil)
        embedded.view.removeFromSuperview()
        embedded.removeFromParent()
        embeddedContentViewController = nil
    }

}
