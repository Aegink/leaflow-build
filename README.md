# leaflow-build（构建子树仓库）

栖阅（Leaflow）**构建专用子树仓库**——只含应用源码 + XcodeGen 工程描述 +
GitHub Actions 工作流。来自本地主仓 `F:/qiyue`（`src/swift/Leaflow`），
不含反编译材料/索引/证据文件。主仓保持仅限本地（禁 push 红线不变）。

## 构建链路

1. macOS runner 上 `xcodegen generate` 生成 `Leaflow.xcodeproj`
   （Windows 侧无法生成/编译 iOS 工程 —— docs/09）；
2. `xcodebuild` 对 generic iOS Simulator 目标做 Debug 编译
   （`CODE_SIGNING_ALLOWED=NO`，不签名不运行）；
3. 错误清单（`errors.txt`/`build.log`）上传为 Actions artifact。

## 依赖（与原应用 SPM 集对齐，docs/10 P-006）

- SwiftSoup（scinfu/SwiftSoup）
- Kanna（tid-kijyu/Kanna）

其余 6 个 SPM 包（Hitch/Sextant/Spanker/Chronometer/SwiftyJSON/ZIPFoundation）
源码级零引用，暂不入工程。

## 预期

本还原为**语义级**且从未编译过（docs/09）——首轮构建预期产出
编译误差清单，而非成功产物。误差将在主仓修复后同步回本仓迭代。
