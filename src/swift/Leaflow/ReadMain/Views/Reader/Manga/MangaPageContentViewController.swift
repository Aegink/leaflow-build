// 原路径: ReadMain/Views/Reader/Manga/MangaPageContentViewController.swift
// 证据:
//   - PGO: 17 个主函数（index/task_functions.csv T-304-04 /
//     MangaPageContentViewController.swift），
//     地址：viewDidLoad 0x100612798 L28-37 / viewWillAppear 0x100612820 L39-44 /
//     viewDidDisappear 0x100612a78 L46-49 / deinit 0x100612c5c L51-53 /
//     setupZoomView 0x100612dbc L57-66 / setupActivityIndicator 0x100612fa8
//     L68-77 / setupPageLabel 0x100613184 L79-89 / setupRetryButton 0x1006133f0
//     L91-103 / configure(page:totalPages:) 0x1006135d0 L115-131 / loadImage
//     0x1006138b0 L135-161 / handleSingleTap 0x100613d38 L169-187
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaPageContentViewController.c
//   - 事实：单页控制器 —— 缩放视图 + 活动指示 + 页码标签 + 重试按钮 +
//     图片加载（MangaImageCacheService.getImage 消费确证）+ 单击回调
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（生命周期/setup/加载链确证）
// 还原: 2026-11-19

import UIKit

/// 漫画单页控制器。
final class MangaPageContentViewController: UIViewController {

    var page: MangaPage?
    var onCenterTap: (() -> Void)?

    private let zoomView = UIScrollView()
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let pageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var imageTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // 伪代码 0x100612798（L28-37）：装配三件。
        setupZoomView()
        setupActivityIndicator()
        setupPageLabel()
        setupRetryButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 伪代码 0x100612820（L39-44）：懒加载触发。
        loadImage()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageTask?.cancel()
        imageTask = nil
    }

    deinit {
        imageTask?.cancel()
    }

    /// 伪代码 0x100612dbc（L57-66）：缩放容器。
    private func setupZoomView() {
        zoomView.delegate = self
        zoomView.minimumZoomScale = 1.0
        zoomView.maximumZoomScale = 4.0
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        zoomView.bounces = false
        zoomView.alwaysBounceHorizontal = false
        zoomView.alwaysBounceVertical = false
        zoomView.addSubview(imageView)
        view.addSubview(zoomView)
        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleSingleTap(_:)))
        zoomView.addGestureRecognizer(tap)
    }

    /// 伪代码 0x100612fa8（L68-77）：活动指示。
    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }

    /// 伪代码 0x100613184（L79-89）：页码标签。
    private func setupPageLabel() {
        pageLabel.font = UIFont.systemFont(ofSize: 12)
        pageLabel.textColor = .secondaryLabel
        view.addSubview(pageLabel)
    }

    /// 伪代码 0x1006133f0（L91-103）：重试按钮。
    private func setupRetryButton() {
        retryButton.setTitle("重试", for: .normal)
        retryButton.isHidden = true
        retryButton.addAction(
            UIAction { [weak self] _ in self?.loadImage() },
            for: .touchUpInside)
        view.addSubview(retryButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        zoomView.frame = view.bounds
        imageView.frame = zoomView.bounds
        activityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        pageLabel.frame = CGRect(
            x: 0, y: view.bounds.maxY - 30,
            width: view.bounds.width, height: 20)
        retryButton.sizeToFit()
        retryButton.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    /// 伪代码 0x1006135d0（L115-131）：页配置。
    func configure(page: MangaPage, totalPages: Int) {
        imageTask?.cancel()
        self.page = page
        imageView.image = nil
        imageView.accessibilityValue = "加载中"
        imageView.accessibilityIdentifier = PDFPageImageSource.parse(page.imageURL) == nil
            ? "manga-page-\(page.pageIndex)" : "pdf-page-\(page.pageIndex)"
        imageView.accessibilityLabel = "第\(page.pageIndex + 1)页"
        pageLabel.text = "\(page.pageIndex + 1) / \(totalPages)"
        retryButton.isHidden = true
        if isViewLoaded { loadImage() }
    }

    /// 伪代码 0x1006138b0（L135-161）：图片加载
    ///（MangaImageCacheService.getImage 消费确证）。
    private func loadImage() {
        guard let page, imageView.image == nil else { return }
        imageTask?.cancel()
        activityIndicator.startAnimating()
        imageTask = Task { @MainActor [weak self] in
            let result = await MangaImageCacheService.shared.getImage(
                url: page.imageURL, headers: [:], requestContext: page.imageRequestContext)
            guard let self, !Task.isCancelled, self.page == page else { return }
            self.activityIndicator.stopAnimating()
            switch result {
            case .image(let image):
                self.imageView.image = image
                self.imageView.accessibilityValue = "已加载"
                self.retryButton.isHidden = true
            case .failure:
                self.retryButton.isHidden = false
                self.imageView.accessibilityValue = "加载失败"
            }
        }
    }

    /// 伪代码 0x100613d38（L169-187）：单击回调（菜单唤起确证）。
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        onCenterTap?()
    }
}

extension MangaPageContentViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
