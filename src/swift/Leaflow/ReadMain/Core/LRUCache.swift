// 原路径: ReadMain/Core/LRUCache.swift
// 证据:
//   - PGO: 18 个主函数（index/task_functions.csv T-101-02 / LRUCache.swift），
//     地址：moveToTail 0x100015628 L60-63 / put 0x100007a18 L79-104
//     (+closure 0x100013e14 L80-103，9 个 ICF 共体块)/ getOrPut 0x1000078f0
//     L108-121（+9 共体块）/ remove 0x100335934 L133-138 / count 闭包 0x1001545f8
//     L142；pgo_only：Node.init(key:value:)/removeNode/appendToTail/get/clear/
//     init(maxSize:)/deinit/Storage.init()
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/LRUCache.c（1752 行）
//   - 事实：Storage —— map [A: Node] + head/tail 哨兵（variable init 0x10016605c/
//     0x1001671c0 L23-25 确证）；Node 双向链（init(key:value:)）；put —— 闭包内
//     （inout Storage）：存在 → 更新 + moveToTail；不存在 → appendToTail +
//     count > maxSize → 驱逐 head（9 个共体块 = 模板特化实例）；
//     getOrPut —— 命中 → moveToTail 返回；未命中 → factory → put；
//     remove/clear/count；注意 0x10016605c 块体实为 SharedJsScope cacheFolder
//     逻辑（ICF 误标，不冒充）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（链表结构/驱逐语义/共体模式确证）
// 还原: 2026-11-19

import Foundation

/// LRU 缓存（字典 + 双向链表；容量驱逐）。
final class LRUCache<A: Hashable, B> {

    /// 双向链表节点。
    final class Node {
        let key: A
        var value: B
        var prev: Node?
        var next: Node?

        /// pgo_only Node.init(key:value:)。
        init(key: A?, value: B?) {
            self.key = key!
            self.value = value!
        }
    }

    /// 存储域（map + head/tail 哨兵确证）。
    private final class Storage {
        var map: [A: Node] = [:]
        var head: Node?
        var tail: Node?

        init() {}

        var count: Int {
            map.count
        }

        /// pgo_only appendToTail（签名确证）。
        func appendToTail(_ node: Node) {
            if let tail {
                tail.next = node
                node.prev = tail
                self.tail = node
            } else {
                head = node
                tail = node
            }
            map[node.key] = node
        }

        /// pgo_only removeNode（签名确证）。
        func removeNode(_ node: Node) {
            node.prev?.next = node.next
            node.next?.prev = node.prev
            if head === node {
                head = node.next
            }
            if tail === node {
                tail = node.prev
            }
            map.removeValue(forKey: node.key)
        }

        /// 伪代码 0x100015628（L60-63）：移到尾部（最近使用端）。
        func moveToTail(_ node: Node) {
            guard tail !== node else { return }
            removeNode(node)
            appendToTail(node)
        }

        /// 驱逐最久未用（put 闭包确证）。
        func evictHeadIfOverCapacity(_ maxSize: Int) {
            while count > maxSize, let oldest = head {
                removeNode(oldest)
            }
        }
    }

    private var storage = Storage()
    private let maxSize: Int

    /// pgo_only init(maxSize:)。
    init(maxSize: Int) {
        self.maxSize = max(1, maxSize)
    }

    deinit {
        // deinit（骨架签名确证）。
    }

    var count: Int {
        // 伪代码 0x1001545f8（L142）：storage.count。
        storage.count
    }

    /// pgo_only get（签名确证）：命中 → moveToTail。
    func get(_ key: A) -> B? {
        guard let node = storage.map[key] else { return nil }
        storage.moveToTail(node)
        return node.value
    }

    /// 伪代码 0x100007a18（L79-104 + closure 共体）：写入 + 容量驱逐。
    func put(_ key: A, value: B) {
        if let node = storage.map[key] {
            node.value = value
            storage.moveToTail(node)
        } else {
            let node = Node(key: key, value: value)
            storage.appendToTail(node)
            storage.evictHeadIfOverCapacity(maxSize)
        }
    }

    /// 伪代码 0x1000078f0（L108-121 + closure 共体）：
    /// 命中 → moveToTail 返回；未命中 → factory 结果非空才放入。
    func getOrPut(_ key: A, factory: () -> B?) -> B? {
        if let existing = storage.map[key] {
            storage.moveToTail(existing)
            return existing.value
        }
        guard let value = factory() else { return nil }
        put(key, value: value)
        return value
    }

    /// 伪代码 0x100335934（L133-138）：按键移除。
    func remove(_ key: A) {
        if let node = storage.map[key] {
            storage.removeNode(node)
        }
    }

    /// pgo_only clear()。
    func clear() {
        storage.map.removeAll()
        storage.head = nil
        storage.tail = nil
    }
}
