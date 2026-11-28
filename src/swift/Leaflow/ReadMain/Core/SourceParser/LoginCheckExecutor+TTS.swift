// 原路径: ReadMain/Core/SourceParser/LoginCheckExecutor.swift
// 0x10015cce8/0x10125cf10：原响应对象；0x100160750：Base64替换、状态200、默认audio/wav。
// 原ttsSourceGuide.html的loginCheckJs章节交叉确认先处理响应、后验证音频。
import Foundation
import JavaScriptCore

extension LoginCheckExecutor {
    struct TTSCheckJsResult {
        let data: Data
        let httpResponse: HTTPURLResponse?
    }

    static func executeTTS(checkJs: String, source: HttpTts, response: HTTPURLResponse,
                           responseData: Data, request: URLRequest, runtimeStore: HttpTtsRuntimeStore,
                           speakText: String, speakSpeed: Int) throws -> TTSCheckJsResult? {
        guard let context = JSContext() else { throw AppError.parsing("无法创建朗读响应脚本上下文") }
        context.exceptionHandler = { _, _ in }
        JsBridgeTemplates.registerHttpTtsSourceBridge(in: context, source: source, runtimeStore: runtimeStore,
            mergePersistedLoginHeader: true, includeRemovalHooks: false)
        let java = JSValue(newObjectIn: context)!
        context.setObject(java, forKeyedSubscript: "java" as NSString)
        context.setObject(speakText, forKeyedSubscript: "speakText" as NSString)
        context.setObject(speakSpeed, forKeyedSubscript: "speakSpeed" as NSString)
        java.setValue(speakText, forProperty: "speakText")
        java.setValue(speakSpeed, forProperty: "speakSpeed")
        java.setValue(source.url, forProperty: "ruleUrl")
        let headers: @convention(block) () -> [String: String] = { request.allHTTPHeaderFields ?? [:] }
        java.setValue(headers, forProperty: "getHeaderMap")
        let encode: @convention(block) (String) -> String = { Data($0.utf8).base64EncodedString() }
        let decode: @convention(block) (String) -> String = {
            HttpTtsWebSocketConfiguration.decodeBase64($0).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
        java.setValue(encode, forProperty: "base64Encode")
        java.setValue(decode, forProperty: "base64Decode")
        var replacement: TTSCheckJsResult?
        let setResponse: @convention(block) (String, JSValue) -> Void = { base64, contentType in
            guard let data = HttpTtsWebSocketConfiguration.decodeBase64(base64), let url = response.url else { return }
            let type = contentType.isString ? contentType.toString() ?? "audio/wav" : "audio/wav"
            replacement = TTSCheckJsResult(data: data, httpResponse: HTTPURLResponse(url: url, statusCode: 200,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": type]))
        }
        java.setValue(setResponse, forProperty: "setResponseBase64")
        var responseHeaders: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            let name = String(describing: key), text = String(describing: value)
            responseHeaders[name] = text
            responseHeaders[name.lowercased()] = text
        }
        context.setObject(response.statusCode, forKeyedSubscript: "_rCode" as NSString)
        context.setObject(String(data: responseData, encoding: .utf8) ?? "", forKeyedSubscript: "_rBody" as NSString)
        context.setObject(responseHeaders, forKeyedSubscript: "_rHeaders" as NSString)
        context.evaluateScript("""
        var result = {
            _code: _rCode, _body: _rBody, _headers: _rHeaders,
            code: function() { return this._code; },
            body: function() {
                var body = this._body;
                return {string: function() { return body; }, bytes: function() { return body; }, byteStream: function() { return null; }};
            },
            headers: function(name) {
                if (name === undefined) return this._headers;
                return this._headers[name] || this._headers[String(name).toLowerCase()] || null;
            },
            header: function(name) { return this.headers(name); },
            message: function() { return ''; }
        };
        """)
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            if let error = context.exception { throw AppError.parsing("朗读响应脚本库失败：\(error.toString() ?? "")") }
        }
        context.exception = nil
        let script = JSScriptCompatibility.sanitizeJavaScriptForCompatibility(
            AnalyzeUrl.processJsPrefix(checkJs), convertLegadoTemplates: true)
        context.evaluateScript(script)
        if let error = context.exception { throw AppError.parsing("朗读响应脚本失败：\(error.toString() ?? "")") }
        return replacement
    }
}
