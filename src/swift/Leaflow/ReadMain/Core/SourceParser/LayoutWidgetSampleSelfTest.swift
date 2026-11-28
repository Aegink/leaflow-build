// T-1602：原版组件配置往返、旧格式迁移、页面域及真实UIKit布局。
import UIKit

@MainActor
enum LayoutWidgetSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "T1602.Widget." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        do {
            let raw = ##"{"id":"00000000-0000-0000-0000-000000000001","item":"customText","xPercent":0.75,"yPercent":0.9,"fontSize":13,"opacity":0.4,"customColorHex":"#112233","customText":"固定页脚","customDateFormat":"HH:mm","pageScope":"normalPageOnly","textAlignment":"right"}"##
            let widget = try JSONDecoder().decode(LayoutWidget.self, from: Data(raw.utf8))
            emit("widget_original_fields", ["customText", "0.75", "0.9", "13.0", "0.4", "固定页脚", "right"],
                [widget.item, String(describing: widget.xPercent), String(describing: widget.yPercent),
                 String(describing: widget.fontSize), String(describing: widget.opacity), widget.customText ?? "", widget.textAlignment.rawValue])
            let restored = try JSONDecoder().decode(LayoutWidget.self, from: JSONEncoder().encode(widget))
            emit("widget_original_roundtrip", ["true"], [String(restored == widget)])
            let originalKeys = try JSONSerialization.jsonObject(with: JSONEncoder().encode(widget)) as! [String: Any]
            emit("widget_original_schema_no_legacy_fields", ["11", "true", "true"],
                [String(originalKeys.count), String(originalKeys["type"] == nil), String(originalKeys["showOnFirstPage"] == nil)])
            let legacy = try JSONDecoder().decode(LayoutWidget.self,
                from: Data(#"{"type":"time","alignment":"trailing","showOnFirstPage":false}"#.utf8))
            emit("widget_legacy_migration", ["currentTime", "time", "right", "normalPageOnly"],
                [legacy.item, legacy.type, legacy.textAlignment.rawValue, legacy.pageScope.rawValue])
            let settings = ReadingSettings.load(from: defaults)
            settings.layoutWidgets = [widget, legacy]
            settings.save()
            let cold = ReadingSettings.load(from: defaults)
            emit("widget_cold_storage_preserves_ids", ["true"], [String(cold.layoutWidgets == settings.layoutWidgets)])
            emit("widget_page_scope_rules", ["true", "true", "true", "false", "false", "true"],
                WidgetPageScope.allCases.flatMap { [String($0.shouldShow(isFirstPage: true)), String($0.shouldShow(isFirstPage: false))] })
            let frame = widget.frame(contentSize: CGSize(width: 80, height: 20), pageSize: CGSize(width: 320, height: 480))
            emit("widget_original_anchor_geometry", ["160.0", "422.0", "80.0", "20.0"],
                [String(describing: frame.minX), String(describing: frame.minY), String(describing: frame.width), String(describing: frame.height)])
            var oversized = widget
            oversized.xPercent = -0.5
            let clipped = oversized.frame(contentSize: CGSize(width: 500, height: 20), pageSize: CGSize(width: 320, height: 480))
            emit("widget_horizontal_boundary_clamp", ["0.0", "320.0"], [String(describing: clipped.minX), String(describing: clipped.width)])
            let controller = PageContentViewController(isInteractive: true)
            controller.loadViewIfNeeded()
            controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
            settings.layoutWidgets = [widget]
            controller.setupWidgetLabels(settings: settings)
            controller.updateWidgetLabels(context: ReaderDisplayContext(bookName: "书名"), settings: settings, isFirstPage: false)
            let label = controller.widgetLabels[widget.id]
            emit("widget_custom_text_real_label", ["固定页脚", "false", "13.0", "true"],
                [label?.text ?? "", String(label?.isHidden ?? true), String(describing: label?.font.pointSize ?? 0),
                 String(label.map { abs($0.textColor.cgColor.alpha - 0.4) < 0.001 } ?? false)])
            controller.updateWidgetLabels(context: ReaderDisplayContext(), settings: settings, isFirstPage: true)
            emit("widget_first_page_hidden", ["true"], [String(label?.isHidden ?? false)])
        } catch { emit("widget_original_fields", ["通过"], [error.localizedDescription]) }
    }
}
