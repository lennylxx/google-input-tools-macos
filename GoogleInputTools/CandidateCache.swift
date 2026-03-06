//
//  CandidateCache.swift
//  GoogleInputTools
//

import Foundation
import SQLite3

struct CachedResult {
    let candidates: [String]
    let metadata: [String: Any]?

    var matchedLength: [Int]? {
        return metadata?["matched_length"] as? [Int]
    }

    var annotation: [String]? {
        return metadata?["annotation"] as? [String]
    }
}

class CandidateCache {

    static let shared = CandidateCache()

    private let maxMemoryEntries = 2000

    // MARK: - In-memory LRU cache

    private var memoryCache = [String: CachedResult]()
    private var accessOrder = [String]()
    private let memoryLock = NSLock()

    // MARK: - SQLite

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "CandidateCache.db")

    init(databasePath: String? = nil) {
        let path = databasePath ?? CandidateCache.defaultDatabasePath()
        openDatabase(at: path)
        warmUpFromDisk()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Public API

    func lookup(_ pinyin: String) -> CachedResult? {
        memoryLock.lock()
        defer { memoryLock.unlock() }

        if let result = memoryCache[pinyin] {
            if let index = accessOrder.firstIndex(of: pinyin) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(pinyin)

            dbQueue.async { [weak self] in
                self?.touchInDatabase(pinyin)
            }
            return result
        }

        // Fall back to SQLite for entries evicted from memory
        if let result = lookupInDatabase(pinyin) {
            memoryCache[pinyin] = result
            accessOrder.append(pinyin)
            evictIfNeeded()

            dbQueue.async { [weak self] in
                self?.touchInDatabase(pinyin)
            }
            return result
        }

        return nil
    }

    func store(_ pinyin: String, candidates: [String], metadata: [String: Any]?) {
        let result = CachedResult(candidates: candidates, metadata: metadata)

        memoryLock.lock()
        memoryCache[pinyin] = result

        if let index = accessOrder.firstIndex(of: pinyin) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(pinyin)
        evictIfNeeded()
        memoryLock.unlock()

        // Persist to SQLite asynchronously
        dbQueue.async { [weak self] in
            self?.insertIntoDatabase(pinyin, candidates: candidates, metadata: metadata)
        }
    }

    // MARK: - Memory management

    private func evictIfNeeded() {
        while memoryCache.count > maxMemoryEntries {
            let evicted = accessOrder.removeFirst()
            memoryCache.removeValue(forKey: evicted)
        }
    }

    // MARK: - SQLite operations

    private static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("GoogleInputTools")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache.db").path
    }

    private func openDatabase(at path: String) {
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            NSLog("Failed to open cache database at \(path)")
            db = nil
            return
        }

        let createSQL = """
            CREATE TABLE IF NOT EXISTS cache (
                pinyin TEXT PRIMARY KEY,
                candidates TEXT NOT NULL,
                metadata TEXT,
                hit_count INTEGER DEFAULT 1,
                created_at REAL DEFAULT (julianday('now')),
                last_used REAL DEFAULT (julianday('now'))
            )
            """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            NSLog("Failed to create cache table: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func warmUpFromDisk() {
        guard db != nil else { return }

        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }

            let sql =
                "SELECT pinyin, candidates, metadata FROM cache ORDER BY last_used DESC LIMIT \(self.maxMemoryEntries)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            var entries = [(String, CachedResult)]()
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let pinyinPtr = sqlite3_column_text(stmt, 0),
                    let candidatesPtr = sqlite3_column_text(stmt, 1)
                else { continue }

                let pinyin = String(cString: pinyinPtr)
                guard let candidates = Self.decodeJSONArray(String(cString: candidatesPtr))
                else { continue }

                var metadata: [String: Any]?
                if let metaPtr = sqlite3_column_text(stmt, 2) {
                    metadata = Self.decodeJSONObject(String(cString: metaPtr))
                }

                entries.append(
                    (pinyin, CachedResult(candidates: candidates, metadata: metadata)))
            }

            self.memoryLock.lock()
            // Reverse so most-recently-used ends up at the end of accessOrder
            for (pinyin, result) in entries.reversed() {
                self.memoryCache[pinyin] = result
                self.accessOrder.append(pinyin)
            }
            self.memoryLock.unlock()

            NSLog("Cache warmed up with \(entries.count) entries from disk")
        }
    }

    private func insertIntoDatabase(
        _ pinyin: String, candidates: [String], metadata: [String: Any]?
    ) {
        guard let db = db else { return }

        let candidatesJSON = Self.encodeJSONArray(candidates)
        let metadataJSON = metadata.flatMap { Self.encodeJSONObject($0) }

        let sql = """
            INSERT INTO cache (pinyin, candidates, metadata, hit_count, created_at, last_used)
            VALUES (?, ?, ?, 1, julianday('now'), julianday('now'))
            ON CONFLICT(pinyin) DO UPDATE SET
                candidates = excluded.candidates,
                metadata = excluded.metadata,
                last_used = julianday('now')
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (pinyin as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (candidatesJSON as NSString).utf8String, -1, nil)
        if let metadataJSON = metadataJSON {
            sqlite3_bind_text(stmt, 3, (metadataJSON as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            NSLog("Failed to insert cache entry: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func touchInDatabase(_ pinyin: String) {
        guard let db = db else { return }

        let sql =
            "UPDATE cache SET hit_count = hit_count + 1, last_used = julianday('now') WHERE pinyin = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (pinyin as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    private func lookupInDatabase(_ pinyin: String) -> CachedResult? {
        guard let db = db else { return nil }

        let sql = "SELECT candidates, metadata FROM cache WHERE pinyin = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (pinyin as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW,
            let candidatesPtr = sqlite3_column_text(stmt, 0)
        else { return nil }

        guard let candidates = Self.decodeJSONArray(String(cString: candidatesPtr))
        else { return nil }

        var metadata: [String: Any]?
        if let metaPtr = sqlite3_column_text(stmt, 1) {
            metadata = Self.decodeJSONObject(String(cString: metaPtr))
        }

        return CachedResult(candidates: candidates, metadata: metadata)
    }

    // MARK: - JSON helpers

    static func encodeJSONArray(_ array: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decodeJSONArray(_ json: String) -> [String]? {
        guard let data = json.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return nil }
        return array
    }

    static func encodeJSONObject(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeJSONObject(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }
}
