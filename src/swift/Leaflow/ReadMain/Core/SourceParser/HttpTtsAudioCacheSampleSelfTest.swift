// T-1602：原版音频键、分源清除、替换计数与并发访问，纯内存样本。
import Foundation

enum HttpTtsAudioCacheSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let cache = HttpTtsAudioCache()
        var source = HttpTts(numericId: 42, name: "固定缓存", url: "https://sample.invalid/tts")
        let data = Data([1, 2, 3])
        emit("tts_cache_original_sha256", ["1c8c8256fd25360e11785d3a401b896240bcf0cdafaf497d2a3648571abbaf44"],
            [cache.key(source: source, text: "固定正文", speechRate: 1)])
        cache.insert(data, source: source, text: "固定正文", speechRate: 1)
        source.lastUpdateTime = 1
        let updatedMiss = cache.data(source: source, text: "固定正文", speechRate: 1) == nil
        source.lastUpdateTime = nil
        source.url = "https://sample.invalid/changed"
        let urlMiss = cache.data(source: source, text: "固定正文", speechRate: 1) == nil
        source.url = "https://sample.invalid/tts"
        emit("tts_cache_source_revision_url_invalidation", ["true", "true", "true"],
            [String(updatedMiss), String(urlMiss), String(cache.data(source: source, text: "固定正文", speechRate: 1) == data)])
        emit("tts_cache_text_rate_isolation", ["true", "true"],
            [String(cache.data(source: source, text: "另一正文", speechRate: 1) == nil),
             String(cache.data(source: source, text: "固定正文", speechRate: 2) == nil)])
        cache.insert(Data([4]), source: source, text: "固定正文", speechRate: 1)
        emit("tts_cache_replacement_count", ["1", "true"],
            [String(cache.count), String(cache.data(source: source, text: "固定正文", speechRate: 1) == Data([4]))])
        let other = HttpTts(numericId: 420, name: "另一个源", url: source.url)
        cache.insert(data, source: other, text: "固定正文", speechRate: 1)
        cache.insert(data, source: source, text: "另一正文", speechRate: 1)
        cache.remove(sourceID: 42)
        emit("tts_cache_remove_source_boundary", ["1", "true", "true"],
            [String(cache.count), String(cache.data(source: source, text: "另一正文", speechRate: 1) == nil),
             String(cache.data(source: other, text: "固定正文", speechRate: 1) == data)])
        cache.remove(source: other, text: "固定正文", speechRate: 1)
        emit("tts_cache_remove_exact_entry", ["0"], [String(cache.count)])
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            cache.insert(Data([UInt8(index)]), source: other, text: "段\(index)", speechRate: 1)
        }
        emit("tts_cache_parallel_entries_preserved", ["100", "true"],
            [String(cache.count), String((0..<100).allSatisfy {
                cache.data(source: other, text: "段\($0)", speechRate: 1) == Data([UInt8($0)])
            })])
        cache.clear()
        emit("tts_cache_clear_all", ["0"], [String(cache.count)])
    }
}
