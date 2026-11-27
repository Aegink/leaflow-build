// 原路径: ReadMain/Models/Book.swift
// 0x10022a1d8：书名+"@"+作者的MD5前5字节；0x10022a5c0：内容身份。
// 0x10022a890/0x10022aabc的PGO名称交错，按指令和字段偏移恢复源范围及书架身份。
import Foundation
import CryptoKit

extension Book {
    var legacyId: String {
        Insecure.MD5.hash(data: Data((name + "@" + (author ?? "")).utf8))
            .prefix(5).map { String(format: "%02x", $0) }.joined()
    }

    /// normalizedIdentifier（static ×4 ICF 副本签名确证）。
    static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    /// resolvedBookId（0x100229e34 L51-63 域确证）。
    static func resolvedBookId(
        savedId: String?, bookUrl: String, bookSourceUrl: String?
    ) -> String {
        if let savedId, !savedId.isEmpty {
            return savedId
        }
        return normalizedKey(
            bookUrl: bookUrl, bookSourceUrl: bookSourceUrl) ?? bookUrl
    }

    static func normalizedKey(
        bookUrl: String, bookSourceUrl: String?
    ) -> String? {
        guard !bookUrl.isEmpty else { return nil }
        return "\(bookSourceUrl ?? "")::\(bookUrl)"
    }

    /// normalizeBookIdIfNeeded（0x10022a144 L66-71 域确证）。
    mutating func normalizeBookIdIfNeeded() -> Bool {
        let resolved = Self.resolvedBookId(
            savedId: id_, bookUrl: bookUrl ?? "",
            bookSourceUrl: bookSourceUrl)
        if id_ != resolved {
            id_ = resolved
            return true
        }
        return false
    }

    // MARK: 内容指纹域（0x10022a5c0 L92-102 域确证）

    /// contentFingerprint getter（签名确证）。
    var contentFingerprint: String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAuthor = (author ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(normalizedAuthor)"
    }

    /// isSameContent(as:)（0x10022a5c0 L92-102 域确证）。
    func isSameContent(as other: Book) -> Bool {
        if legacyId == other.legacyId { return true }
        guard let title = Self.normalizedIdentifier(name),
              let otherTitle = Self.normalizedIdentifier(other.name) else { return false }
        return title.lowercased() == otherTitle.lowercased()
            && (Self.normalizedIdentifier(author) ?? "").lowercased()
                == (Self.normalizedIdentifier(other.author) ?? "").lowercased()
    }

    /// 0x10022a890：源URL去空白，可选存储域nil与local等价。
    func matchesSourceScope(as other: Book) -> Bool {
        Self.normalizedIdentifier(bookSourceUrl) == Self.normalizedIdentifier(other.bookSourceUrl)
            && (sourceStorageKind ?? .local) == (other.sourceStorageKind ?? .local)
    }

    /// 0x10022aabc读取偏移0x10的bookUrl，并调用0x10022a890比较来源。
    func matchesBookshelfIdentity(as other: Book) -> Bool {
        Self.normalizedIdentifier(bookUrl) == Self.normalizedIdentifier(other.bookUrl)
            && matchesSourceScope(as: other)
    }

    /// sourceStateKey getter（0x10022ad10 L145-149 域确证）。
    var sourceStateKey: String? {
        guard let url = bookSourceUrl, !url.isEmpty else { return nil }
        return url
    }

}
