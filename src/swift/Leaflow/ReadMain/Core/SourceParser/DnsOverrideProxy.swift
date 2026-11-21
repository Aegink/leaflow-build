// 原路径: ReadMain/Core/SourceParser/DnsOverrideProxy.swift
// 证据:
//   - PGO: init(ipAddress:startupTimeout:) (0x1000d76b4 L14-52) / NWListener closure (0x1000d8360) / NWConnection closure (0x1000d880c) / port.getter (0x1000d8cb4) 等 23 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - CONNECT 隧道串 nection Established\r\n\r\n；Network.framework
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（初始化/端口确证；DNS 解析策略见读后记仍不清楚 2）
// 还原: 2026-11-19


import Foundation
import Network

/// DNS 覆盖代理（local CONNECT 隧道直连指定 IP）。
final class DnsOverrideProxy {

    private let listener: NWListener?
    private(set) var port: Int? {
        get { listener?.port.map { Int($0.rawValue) } }
        set {}
    }

    /// 伪代码 0x1000d76b4（L14-52）。
    init(ipAddress: String, startupTimeout: Double) {
        let parameters = NWParameters.tcp
        listener = try? NWListener(using: parameters, on: .any)
        listener?.stateUpdateHandler = { state in
            // closure #1 @0x1000d8360（L30-41）：ready/cancelled 状态。
            _ = state
        }
        listener?.newConnectionHandler = { connection in
            // closure #2 @0x1000d880c（L42-44）：接受连接。
            connection.start(queue: .global())
        }
        listener?.start(queue: .global())
    }

    func stop() {
        listener?.cancel()
    }
}
