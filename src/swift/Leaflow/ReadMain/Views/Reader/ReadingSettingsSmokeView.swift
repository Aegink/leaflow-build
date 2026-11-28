// 仅-smokeReadingSettings：实际设置面板与持久化实例，固定独立偏好域可冷启动复算。
import SwiftUI

struct ReadingSettingsSmokeView: View {
    @State private var settings = ReadingSettings.load(from: UserDefaults(suiteName: "t1602-reading-settings-ui")!)
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置保存后正文仍使用同一字号与行距。")
                    .font(settings.textFont)
                    .lineSpacing(settings.lineSpacing)
                Text(String(Double(settings.fontSize))).accessibilityIdentifier("settings-saved-font-size")
                Text(String(Double(settings.lineSpacing))).accessibilityIdentifier("settings-saved-line-spacing")
                Button("打开阅读设置") { showSettings = true }.accessibilityIdentifier("settings-open-editor")
            }
            .padding()
            .navigationTitle("阅读设置验证")
            .sheet(isPresented: $showSettings) {
                ReaderSettingsView(settings: $settings, onDismiss: { showSettings = false }, initialTab: 1)
            }
        }
    }
}
