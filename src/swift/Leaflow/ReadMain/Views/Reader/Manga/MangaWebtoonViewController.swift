// 原路径: ReadMain/Views/Reader/Manga/MangaWebtoonViewController.swift
// 证据:
//   - PGO: 27 个主函数（index/task_functions.csv T-304-05 /
//     MangaWebtoonViewController.swift），
//     地址：viewDidLayoutSubviews 0x1006373e4 L45-54 / reloadData(pages:)
//     0x1006376dc L56-64 / appendPages 0x100637ba0 L66-80 / scrollToPage(_:animated:)
//     0x100637fe8 L82-86 / setupCollectionView 0x1006383a0 L90-102 /
//     createLayout 0x10063843c L104-111 / handleTap 0x100638580 L119-125
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaWebtoonViewController.c
//   - 事实：webtoon 竖排控制器（UICollectionView + 组合布局 + tap 菜单）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（生命周期/setup/tap 确证）
// 还原: 2026-11-19

import UIKit

/// webtoon 竖排控制器（UICollectionViewCompositionalLayout）。
final class MangaWebtoonViewController: UIViewController {

    var onCenterTap: (() -> Void)?
    var onVisiblePageChange: ((Int) -> Void)?
    /// 页变化回调（onPageChange ivar 域确证）。
    var onPageChange: ((Int) -> Void)?

    /// 伪代码 0x10063c6e8（L19）：初始页 varinit（计数器桩）。
    var initialPageIndex: Int = 0
    /// 伪代码 0x10063c61c（L21）：滚动中标志 varinit——块体确证伴随域初始化
    ///（lastReportedPage=-1 / hasPerformedInitialScroll=0 / hasReportedEnd=0 /
    /// hasReportedNearEnd=0 四 ivar 域确证）。
    var isUserScrolling: Bool = false
    private var lastReportedPage: Int = -1
    private var hasPerformedInitialScroll: Bool = false
    private var hasReportedEnd: Bool = false
    private var hasReportedNearEnd: Bool = false

    private var collectionView: UICollectionView?
    private var pages: [MangaPage] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView?.frame = view.bounds
    }

    /// 伪代码 0x1006383a0（L90-102）：集合视图装配。
    private func setupCollectionView() {
        let collectionView = UICollectionView(
            frame: view.bounds,
            collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Page")
        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleTap(_:)))
        collectionView.addGestureRecognizer(tap)
        view.addSubview(collectionView)
        self.collectionView = collectionView
    }

    /// 伪代码 0x10063843c（L104-111）：竖排布局。
    private func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(300))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0
        return UICollectionViewCompositionalLayout(section: section)
    }

    /// 伪代码 0x1006376dc（L56-64）：全量刷新。
    func reloadData(pages newPages: [MangaPage]) {
        pages = newPages
        collectionView?.reloadData()
    }

    /// 伪代码 0x100637ba0（L66-80）：追加页。
    func appendPages(_ newPages: [MangaPage]) {
        let first = pages.count
        pages.append(contentsOf: newPages)
        let inserted = (first..<pages.count).map { IndexPath(item: $0, section: 0) }
        collectionView?.insertItems(at: inserted)
    }

    /// 伪代码 0x100637fe8（L82-86）：滚动定位。
    func scrollToPage(_ index: Int, animated: Bool) {
        guard pages.indices.contains(index) else { return }
        collectionView?.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .top, animated: animated)
    }

    /// 伪代码 0x100638580（L119-125）：单击菜单。
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onCenterTap?()
    }
}

extension MangaWebtoonViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    func collectionView(
        _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "Page", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let imageView = UIImageView()
        imageView.tag = 100
        imageView.contentMode = .scaleAspectFit
        imageView.frame = cell.contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cell.contentView.addSubview(imageView)
        if let context = pages[indexPath.item].imageRequestContext {
            let pageURL = pages[indexPath.item].imageURL
            Task { @MainActor in
                let result = await MangaImageCacheService.shared.getImage(
                    url: pageURL, headers: [:], requestContext: context)
                if case .image(let image) = result,
                   cell.contentView.viewWithTag(100) as? UIImageView != nil {
                    imageView.image = image
                }
            }
        }
        return cell
    }
}

// MARK: - UIScrollViewDelegate（T-1401-04 逐域补齐）

extension MangaWebtoonViewController: UIScrollViewDelegate {

    /// 伪代码 0x1006390ec（L165-196）：滚动驱动——hasPerformedInitialScroll
    /// 门控 → contentSize > 0 → collectionView bounds.midX + height*0.3 →
    /// indexPathForItemAtPoint → item != lastReportedPage → onPageChange
    /// 回调；nearEnd 域：!hasReportedNearEnd && offsetY+height ≥
    /// contentSize-400 → 标志 + "[webtoon] nearEnd contentHeight="/"update
    /// APPEND +" 日志域确证。
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard hasPerformedInitialScroll else { return }
        let contentHeight = scrollView.contentSize.height
        guard contentHeight > 0 else { return }
        if let collection = collectionView {
            let probe = CGPoint(
                x: collection.bounds.midX,
                y: collection.contentOffset.y + collection.bounds.height * 0.3)
            if let indexPath = collection.indexPathForItem(at: probe) {
                let item = indexPath.item
                if item != lastReportedPage {
                    lastReportedPage = item
                    onPageChange?(item)
                }
            }
        }
        let bottomY = scrollView.contentOffset.y + scrollView.bounds.height
        if !hasReportedNearEnd, bottomY >= contentHeight - 400.0 {
            hasReportedNearEnd = true
            Logger.log(
                "[webtoon] nearEnd contentHeight=\(Int(contentHeight))",
                level: .debug, module: .reader,
                file: "MangaWebtoonViewController", line: 185)
            Logger.log(
                "[webtoon] update APPEND +", level: .debug, module: .reader,
                file: "MangaWebtoonViewController", line: 188)
        }
    }

    /// 伪代码 0x100639614（L198-201）：开始拖动——isUserScrolling 置位域。
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }

    /// 伪代码 0x1006397a4（L203-210）：结束拖动——decelerate 分支域
    ///（isUserScrolling 复位域）。
    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView, willDecelerate decelerate: Bool
    ) {
        if !decelerate {
            isUserScrolling = false
            hasReportedEnd = true
        }
    }

    /// 伪代码 0x100639cb4（L212-217）：减速结束——isUserScrolling 复位 +
    /// hasReportedEnd 域。
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
        hasReportedEnd = true
    }
}

