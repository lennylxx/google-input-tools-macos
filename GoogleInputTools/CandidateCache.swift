import Foundation
import SQLite3

struct CachedResult {
    let candidates: [String]
    let metadata: [String: Any]?
    var fetchedAt: Date = Date()

    var matchedLength: [Int]? { metadata?["matched_length"] as? [Int] }
    var annotation: [String]? { metadata?["annotation"] as? [String] }
}

/// Serializes memory and SQLite access, including reads made by network callbacks.
class CandidateCache {
    static let shared = CandidateCache()
    private let queue = DispatchQueue(label: "CandidateCache.storage")
    private var db: OpaquePointer?
    private var memory = [String: CachedResult]()
    private var accessOrder = [String]()
    private let now: () -> Date
    private let maxMemoryEntries = 2000
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(databasePath: String? = nil, now: @escaping () -> Date = Date.init) {
        self.now = now
        let path = databasePath ?? Self.defaultDatabasePath()
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            if let db = db { sqlite3_close(db) }
            db = nil
            return
        }
        sqlite3_busy_timeout(db, 1000)
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        // Retain legacy tables, but do not reuse unscoped caches or ambiguous old learning.
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS candidate_cache_v2 (
                key TEXT PRIMARY KEY, candidates TEXT NOT NULL, metadata TEXT,
                fetched_at REAL NOT NULL, hit_count INTEGER DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS selection_frequency_v2 (
                scheme TEXT NOT NULL, pinyin TEXT NOT NULL, candidate TEXT NOT NULL,
                explicit INTEGER NOT NULL, selections INTEGER NOT NULL,
                weight REAL NOT NULL, last_used REAL NOT NULL,
                PRIMARY KEY (scheme, pinyin, candidate, explicit)
            );
            """, nil, nil, nil)
    }

    deinit { close() }

    func close() {
        queue.sync {
            if let db = db { sqlite3_close(db) }
            db = nil
        }
    }

    private static func defaultDatabasePath() -> String {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoogleInputTools")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("cache.db").path
    }

    private func key(_ text: String, _ scheme: InputTool, _ count: Int) -> String {
        "\(scheme.rawValue)|\(count)|\(text)"
    }

    private func statement(_ sql: String, strings: [String] = []) -> OpaquePointer? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else { return nil }
        for (index, value) in strings.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), value, -1, transient)
        }
        return stmt
    }

    private func remember(_ key: String, _ result: CachedResult) {
        memory[key] = result
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        while accessOrder.count > maxMemoryEntries {
            memory.removeValue(forKey: accessOrder.removeFirst())
        }
    }

    func lookup(_ text: String, scheme: InputTool = .Pinyin, candidateCount: Int = 20,
                allowExpired: Bool = false) -> CachedResult? {
        queue.sync {
            let cacheKey = key(text, scheme, candidateCount)
            var result = memory[cacheKey]
            if result == nil, let stmt = statement(
                "SELECT candidates, metadata, fetched_at FROM candidate_cache_v2 WHERE key = ?", strings: [cacheKey]) {
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW,
                   let ptr = sqlite3_column_text(stmt, 0),
                   let candidates = Self.decodeJSONArray(String(cString: ptr)) {
                    let metadata = sqlite3_column_text(stmt, 1).flatMap { Self.decodeJSONObject(String(cString: $0)) }
                    result = CachedResult(candidates: candidates, metadata: metadata,
                        fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)))
                }
            }
            guard let cached = result else { return nil }
            // last_used must not reset freshness; stale data is reserved for offline fallback.
            guard allowExpired || now().timeIntervalSince(cached.fetchedAt) < 86400 else { return nil }
            remember(cacheKey, cached)
            if let stmt = statement("UPDATE candidate_cache_v2 SET hit_count = hit_count + 1 WHERE key = ?", strings: [cacheKey]) {
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
            return cached
        }
    }

    func lookupLongestPrefix(_ text: String, scheme: InputTool = .Pinyin,
                             candidateCount: Int = 20) -> CachedResult? {
        var prefix = text
        while prefix.count > 1 {
            prefix.removeLast()
            if var result = lookup(prefix, scheme: scheme, candidateCount: candidateCount, allowExpired: true) {
                var metadata = result.metadata ?? [:]
                let lengths = result.matchedLength ?? []
                metadata["matched_length"] = result.candidates.indices.map { i in
                    i < lengths.count && lengths[i] > 0 ? min(lengths[i], prefix.count) : prefix.count
                }
                result = CachedResult(candidates: result.candidates, metadata: metadata, fetchedAt: result.fetchedAt)
                return result
            }
        }
        return nil
    }

    func store(_ text: String, candidates: [String], metadata: [String: Any]?,
               scheme: InputTool = .Pinyin, candidateCount: Int = 20) {
        guard !candidates.isEmpty else { return }
        queue.sync {
            let cacheKey = key(text, scheme, candidateCount)
            let date = now()
            remember(cacheKey, CachedResult(candidates: candidates, metadata: metadata, fetchedAt: date))
            guard let stmt = statement("""
                INSERT INTO candidate_cache_v2(key, candidates, metadata, fetched_at) VALUES (?, ?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET candidates=excluded.candidates,
                metadata=excluded.metadata, fetched_at=excluded.fetched_at
                """, strings: [cacheKey, Self.encodeJSONArray(candidates)]) else { return }
            defer { sqlite3_finalize(stmt) }
            if let json = metadata.flatMap(Self.encodeJSONObject) {
                sqlite3_bind_text(stmt, 3, json, -1, transient)
            } else { sqlite3_bind_null(stmt, 3) }
            sqlite3_bind_double(stmt, 4, date.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
    }

    private func decay(_ weight: Double, lastUsed: Double, at time: Double, days: Int) -> Double {
        days > 0 ? weight * pow(0.5, max(0, time - lastUsed) / (Double(days) * 86400)) : weight
    }

    func recordSelection(pinyin: String, candidate: String, scheme: InputTool = .Pinyin,
                         explicit: Bool = true, options: AccuracyOptions = AccuracyOptions()) {
        guard !pinyin.isEmpty, !candidate.isEmpty, !options.explicitOnly || explicit else { return }
        queue.sync {
            let values = [scheme.rawValue, pinyin, candidate, explicit ? "1" : "0"]
            let time = now().timeIntervalSince1970
            var weight = 0.0
            var count = 0
            if let stmt = statement("SELECT weight, selections, last_used FROM selection_frequency_v2 WHERE scheme=? AND pinyin=? AND candidate=? AND explicit=?", strings: values) {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    weight = decay(sqlite3_column_double(stmt, 0), lastUsed: sqlite3_column_double(stmt, 2),
                        at: time, days: options.halfLifeDays)
                    count = Int(sqlite3_column_int64(stmt, 1))
                }
                sqlite3_finalize(stmt)
            }
            guard let stmt = statement("""
                INSERT INTO selection_frequency_v2(scheme,pinyin,candidate,explicit,selections,weight,last_used)
                VALUES (?,?,?,?,?,?,?) ON CONFLICT(scheme,pinyin,candidate,explicit)
                DO UPDATE SET selections=excluded.selections, weight=excluded.weight, last_used=excluded.last_used
                """, strings: values) else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 5, sqlite3_int64(count + 1))
            sqlite3_bind_double(stmt, 6, weight + 1)
            sqlite3_bind_double(stmt, 7, time)
            sqlite3_step(stmt)
        }
    }

    func predictNextInputs(prefix: String, scheme: InputTool = .Pinyin,
                           candidateCount: Int = 20, limit: Int = 3) -> [String] {
        queue.sync {
            let namespace = "\(scheme.rawValue)|\(candidateCount)|"
            guard let stmt = statement("SELECT key FROM candidate_cache_v2 WHERE key LIKE ? AND key != ? AND fetched_at < ? ORDER BY hit_count DESC LIMIT ?",
                strings: [namespace + prefix + "%", namespace + prefix]) else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 3, now().timeIntervalSince1970 - 86400)
            sqlite3_bind_int(stmt, 4, Int32(limit))
            var values = [String]()
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    values.append(String(String(cString: ptr).dropFirst(namespace.count)))
                }
            }
            return values
        }
    }

    func clearFrequencies() {
        queue.sync {
            sqlite3_exec(db, "DELETE FROM selection_frequency_v2", nil, nil, nil)
            // Also honor Clear for the preserved legacy table, if present.
            sqlite3_exec(db, "DELETE FROM user_freq", nil, nil, nil)
        }
    }

    func rerank(pinyin: String, candidates: [String], matchedLength: [Int]?,
                scheme: InputTool = .Pinyin, options: AccuracyOptions = AccuracyOptions()) -> ([String], [Int]?) {
        guard options.ranking != .cloud else { return (candidates, matchedLength) }
        let frequencies: [String: (count: Int, weight: Double)] = queue.sync {
            guard let stmt = statement("SELECT candidate, selections, weight, last_used FROM selection_frequency_v2 WHERE scheme=? AND pinyin=?" + (options.explicitOnly ? " AND explicit=1" : ""),
                strings: [scheme.rawValue, pinyin]) else { return [:] }
            defer { sqlite3_finalize(stmt) }
            var values = [String: (count: Int, weight: Double)]()
            let time = now().timeIntervalSince1970
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let ptr = sqlite3_column_text(stmt, 0) else { continue }
                let word = String(cString: ptr)
                let previous = values[word] ?? (0, 0)
                values[word] = (previous.count + Int(sqlite3_column_int64(stmt, 1)),
                    previous.weight + decay(sqlite3_column_double(stmt, 2), lastUsed: sqlite3_column_double(stmt, 3),
                        at: time, days: options.halfLifeDays))
            }
            return values
        }
        guard !frequencies.isEmpty else { return (candidates, matchedLength) }
        let lengths = candidates.indices.map { index in
            matchedLength.flatMap { index < $0.count ? $0[index] : nil } ?? pinyin.count
        }
        let scores = candidates.indices.map { index -> Double in
            guard lengths[index] == pinyin.count,
                  let entry = frequencies[candidates[index]], entry.count >= options.minimumSelections else {
                return Double(index)
            }
            // Balanced mode moves a word by at most three positions, preserving cloud relevance.
            let cap = options.ranking == .balanced ? 2.5 : Double(candidates.count)
            let boost = min(cap, 1.25 * entry.weight / Double(max(1, options.minimumSelections)))
            return Double(index) - boost
        }
        let indices = candidates.indices.sorted { a, b in
            scores[a] == scores[b] ? a < b : scores[a] < scores[b]
        }
        return (indices.map { candidates[$0] }, matchedLength == nil ? nil : indices.map { lengths[$0] })
    }

    static func encodeJSONArray(_ array: [String]) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: array), encoding: .utf8)!
    }
    static func decodeJSONArray(_ text: String) -> [String]? {
        text.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String]
    }
    static func encodeJSONObject(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func decodeJSONObject(_ text: String) -> [String: Any]? {
        text.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
    }
}
