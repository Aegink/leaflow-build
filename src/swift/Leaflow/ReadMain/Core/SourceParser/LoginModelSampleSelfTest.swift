// T-1602：直接解码原版字段/混合选项/布局样式，尚不代表登录执行链完成。
import Foundation

enum LoginModelSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        do {
            let original = Data(#"{"name":"account","type":"text","placeholder":"账号","value":"临时值","defaultValue":"默认值","viewName":"'账户'","action":"java.put('ok','1')","style":{"layoutFlexGrow":" 2.5 ","layoutFlexShrink":0,"layoutFlexBasisPercent":50,"layoutWrapBefore":" YES ","layoutJustifySelf":"flex_end"}}"#.utf8)
            let item = try JSONDecoder().decode(LoginUiItem.self, from: original)
            emit("login_model_original_fields", ["account", "账号", "临时值", "默认值", "java.put('ok','1')"],
                [item.name, item.placeholder ?? "", item.value ?? "", item.resolvedDefaultValue, item.action ?? ""])
            emit("login_model_style_flexible_values", ["2.5", "0.0", "50.0", "true", "flex_end"],
                [String(item.style?.layoutFlexGrow ?? -1), String(item.style?.layoutFlexShrink ?? -1),
                 String(item.style?.layoutFlexBasisPercent ?? -1), String(item.style?.layoutWrapBefore ?? false), item.style?.layoutJustifySelf ?? ""])
            let roundtrip = try JSONDecoder().decode(LoginUiItem.self, from: JSONEncoder().encode(item))
            emit("login_model_roundtrip", ["true"], [String(roundtrip == item)])
            let mixed = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":42,"type":"select","chars":[null,1,2.5,true,"末项",{"nested":[1]},["ignore"],"后项"]}"#.utf8))
            emit("login_model_mixed_options_keep_positions", ["42", "nil,1,2.5,true,末项,nil,nil,后项", "1"],
                [mixed.name, mixed.chars?.map { $0 ?? "nil" }.joined(separator: ",") ?? "", mixed.resolvedDefaultValue])
            let explicit = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":"option","type":"select","defaultValue":"","chars":["A","B"]}"#.utf8))
            emit("login_model_explicit_empty_default", [""], [explicit.resolvedDefaultValue])
            let toggle = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":"enabled","type":" toggle ","chars":[null,false,true]}"#.utf8))
            emit("login_model_toggle_default", ["false"], [toggle.resolvedDefaultValue])
            let legacy = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":"old","type":"checkbox","label":"旧标签","values":["off","on"]}"#.utf8))
            emit("login_model_legacy_values", ["旧标签", "off,on"], [legacy.label ?? "", legacy.values?.joined(separator: ",") ?? ""])
            let no = try JSONDecoder().decode(LoginUiStyle.self, from: Data(#"{"layoutWrapBefore":" no ","layoutFlexGrow":"bad","layoutFlexShrink":true}"#.utf8))
            emit("login_model_invalid_style_members", ["false", "true", "true"],
                [String(no.layoutWrapBefore ?? true), String(no.layoutFlexGrow == nil), String(no.layoutFlexShrink == nil)])
        } catch { emit("login_model_original_fields", ["通过"], [error.localizedDescription]) }
    }
}
