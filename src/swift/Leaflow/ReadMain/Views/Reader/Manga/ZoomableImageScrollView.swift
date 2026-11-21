// 原路径: ReadMain/Views/Reader/Manga/ZoomableImageScrollView.swift
// 证据:
//   - PGO: 9 个主函数（index/task_functions.csv T-304-05 / ZoomableImageScrollView.swift），
//     地址：doubleTapGesture 懒加载 0x10063f190 L12-16 / init(frame:)
//     0x10063fdb8 L18-21 / setImage 0x10063f608 L43-69（setZoomScale:1.0 确证）/
//     viewForZooming 0x10063f8e8 L78-80（zoomScale/minimumZoomScale/
//     maximumZoomScale 确证）/ centerImageView 0x10063faa8 L108-125 /
//     resetZoom(animated:) 0x100614b64 L72-74 / layoutSubviews 0x10063f2a4
//     L127-132
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/ZoomableImageScrollView.c
//   - 事实：双击缩放（懒加载双击手势确证）+ 单指平移 + 居中复位（centerImageView 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（缩放/双击/居中链确证）
// 还原: 2026-11-19

import UIKit

/// 可缩放图片滚动容器。
/// UIScrollViewDelegate：delegate = self 装配域（viewForZooming 消费域，
/// wave-16 补一致）。
final class ZoomableImageScrollView: UIScrollView, UIScrollViewDelegate {

    private let imageView = UIImageView()
    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        // 伪代码 0x10063f190（L12-16）：双击手势懒加载。
        let gesture = UITapGestureRecognizer(
            target: self, action: #selector(handleDoubleTap(_:)))
        gesture.numberOfTapsRequired = 2
        return gesture
    }()

    /// 伪代码 0x10063fdb8（L18-21）：装配。
    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        delegate = self
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        addGestureRecognizer(doubleTapGesture)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(imageView)
    }

    /// 伪代码 0x10063f608（L43-69）：设置图片（setZoomScale:1.0 复位确证）。
    func setImage(_ image: UIImage?) {
        imageView.image = image
        zoomScale = 1.0
        centerImageView()
    }

    /// 伪代码 0x10063f8e8（L78-80）：缩放目标。
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    /// 伪代码 0x10063faa8（L108-125）：图片居中。
    private func centerImageView() {
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0 else {
            imageView.frame = bounds
            return
        }
        let widthScale = bounds.width / image.size.width
        let heightScale = bounds.height / image.size.height
        let scale = min(widthScale, heightScale)
        let size = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale)
        imageView.frame = CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width, height: size.height)
        contentSize = size
    }

    /// 伪代码 0x100614b64（L72-74）：缩放复位。
    func resetZoom(animated: Bool) {
        setZoomScale(1.0, animated: animated)
        centerImageView()
    }

    override func layoutSubviews() {
        // 伪代码 0x10063f2a4（L127-132）。
        super.layoutSubviews()
        centerImageView()
    }

    /// 双击缩放切换。
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            resetZoom(animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let targetScale = maximumZoomScale
            let size = CGSize(
                width: bounds.width / targetScale,
                height: bounds.height / targetScale)
            let origin = CGPoint(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2)
            zoom(
                to: CGRect(origin: origin, size: size), animated: true)
        }
    }
}
