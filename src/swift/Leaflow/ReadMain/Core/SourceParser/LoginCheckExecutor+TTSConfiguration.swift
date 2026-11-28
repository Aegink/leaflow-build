// 原路径: ReadMain/Core/SourceParser/LoginCheckExecutor.swift
// 0x100160b88及原指南：loginUrl函数定义、当前result表单、源状态、toast与清缓存。
import Foundation
import JavaScriptCore

extension LoginCheckExecutor {
    static func executeTTSConfigurationAction(_ action: String, source: HttpTts, values: [String: String],
        runtimeStore: HttpTtsRuntimeStore, audioCache: HttpTtsAudioCache) throws -> String? {
        runtimeStore.setLoginInfoMap(values, sourceID: source.id)
        guard let context = JSContext() else { throw AppError.parsing("无法创建朗读配置上下文") }
        var scriptError: String?, message: String?
        context.exceptionHandler = { _, error in scriptError = error?.toString() ?? "脚本异常" }
        JsBridgeTemplates.registerHttpTtsSourceBridge(in: context, source: source, runtimeStore: runtimeStore)
        context.setObject(values, forKeyedSubscript: "result" as NSString)
        let java = JSValue(newObjectIn: context)!
        let toast: @convention(block) (String) -> Void = { message = $0 }
        let clear: @convention(block) () -> Void = { audioCache.remove(sourceID: source.id) }
        java.setValue(toast, forProperty: "toast")
        java.setValue(toast, forProperty: "longToast")
        java.setValue(clear, forProperty: "clearTtsCache")
        context.setObject(java, forKeyedSubscript: "java" as NSString)
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            if let scriptError { throw AppError.parsing(scriptError) }
        }
        let script = AnalyzeUrl.processJsPrefix(source.loginUrl ?? "") + "\n" + AnalyzeUrl.processJsPrefix(action)
        context.evaluateScript(script)
        if let scriptError { throw AppError.parsing(scriptError) }
        return message
    }
}
