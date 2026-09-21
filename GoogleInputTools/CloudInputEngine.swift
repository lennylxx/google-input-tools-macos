//
//  CloudInputEngine.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/22/21.
//

import Foundation

enum InputTool: String, CaseIterable {
    case Pinyin = "zh-t-i0-pinyin"
    case Shuangpin_ABC = "zh-t-i0-pinyin-x0-shuangpin-abc"
    case Shuangpin_Microsoft = "zh-t-i0-pinyin-x0-shuangpin-ms"
    case Shuangpin_Xiaohe = "zh-t-i0-pinyin-x0-shuangpin-flypy"
    case Shuangpin_Jiajia = "zh-t-i0-pinyin-x0-shuangpin-jiajia"
    case Shuangpin_Ziguang = "zh-t-i0-pinyin-x0-shuangpin-ziguang"
    case Shuangpin_Ziranma = "zh-t-i0-pinyin-x0-shuangpin-ziranma"
    case Wubi = "zh-t-i0-wubi-1986"

    var displayName: String {
        switch self {
        case .Pinyin: return "全拼"
        case .Shuangpin_ABC: return "智能 ABC 双拼"
        case .Shuangpin_Microsoft: return "微软双拼"
        case .Shuangpin_Xiaohe: return "小鹤双拼"
        case .Shuangpin_Jiajia: return "拼音加加双拼"
        case .Shuangpin_Ziguang: return "紫光双拼"
        case .Shuangpin_Ziranma: return "自然码双拼"
        case .Wubi: return "五笔 86"
        }
    }
}

class CloudInputEngine {

    static let shared = CloudInputEngine()

    var inputTool: InputTool { UISettings.inputTool }
    private let cache: CandidateCache
    private let sessionOverride: URLSession?
    private var requestID = UUID()

    init(cache: CandidateCache = .shared, session: URLSession? = nil) {
        self.cache = cache
        self.sessionOverride = session
    }

    private var currentTask: URLSessionDataTask?
    private let taskLock = NSLock()

    private class ProxyAuthDelegate: NSObject, URLSessionTaskDelegate {
        let credential: URLCredential

        init(username: String, password: String) {
            self.credential = URLCredential(
                user: username, password: password, persistence: .none)
        }

        func urlSession(
            _ session: URLSession, task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?)
                -> Void
        ) {
            if challenge.protectionSpace.proxyType != nil
                && challenge.previousFailureCount == 0
            {
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    private func makeSession() -> (session: URLSession, invalidateWhenDone: Bool) {
        if let session = sessionOverride { return (session, false) }
        guard let proxyConfiguration = ProxySettings.configuration else {
            return (.shared, false)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = proxyConfiguration.connectionProxyDictionary

        if proxyConfiguration.hasCredentials {
            let delegate = ProxyAuthDelegate(
                username: proxyConfiguration.username,
                password: proxyConfiguration.password)
            return (
                URLSession(
                    configuration: configuration, delegate: delegate, delegateQueue: nil),
                true
            )
        }

        return (URLSession(configuration: configuration), true)
    }

    // MARK: - Network fetch

    static func makeRequest(_ text: String, scheme: InputTool, candidateCount: Int) -> URLRequest {
        var url = URLComponents(string: "https://inputtools.google.com/request")!
        url.queryItems = ["text": text, "itc": scheme.rawValue, "num": String(candidateCount),
            "cp": "0", "cs": "1", "ie": "utf-8", "oe": "utf-8", "app": "demopage"]
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 5
        return request
    }

    private func isCurrent(_ id: UUID) -> Bool {
        taskLock.lock()
        defer { taskLock.unlock() }
        return requestID == id
    }

    func cancelPendingRequest() {
        taskLock.lock()
        requestID = UUID()
        currentTask?.cancel()
        currentTask = nil
        taskLock.unlock()
    }

    /// The same merge and ranking pipeline is used for network, cache, and offline data.
    func prepareCandidates(_ text: String, candidates: [String], matchedLength: [Int]?,
                           scheme: InputTool, options: AccuracyOptions) -> ([String], [Int]?) {
        let local = PersonalDictionary.candidates(for: text, scheme: scheme, options: options)
        let (words, lengths) = PersonalDictionary.merge(text: text, cloud: candidates,
            matchedLength: matchedLength, local: local)
        let ranked = cache.rerank(pinyin: text, candidates: words, matchedLength: lengths,
            scheme: scheme, options: options)
        return (Array(ranked.0.prefix(options.candidateCount)),
                ranked.1.map { Array($0.prefix(options.candidateCount)) })
    }

    func requestCandidates(
        _ text: String, scheme selectedScheme: InputTool? = nil, options selectedOptions: AccuracyOptions? = nil,
        complete: @escaping (_ candidates: [String], _ matchedLength: [Int]?, _ source: CandidateSource) -> Void
    ) {
        let scheme = selectedScheme ?? UISettings.inputTool
        let options = selectedOptions ?? UISettings.accuracyOptions
        let id = UUID()
        taskLock.lock()
        requestID = id
        currentTask?.cancel()
        currentTask = nil
        taskLock.unlock()

        func deliver(_ words: [String], _ lengths: [Int]?, _ source: CandidateSource) {
            guard self.isCurrent(id) else { return }
            let ranked = self.prepareCandidates(text, candidates: words, matchedLength: lengths,
                scheme: scheme, options: options)
            complete(ranked.0, ranked.1, source)
        }

        if let cached = cache.lookup(text, scheme: scheme, candidateCount: options.candidateCount) {
            deliver(cached.candidates, cached.matchedLength, .cache)
            prefetch(text, scheme: scheme, options: options)
            return
        }

        let request = Self.makeRequest(text, scheme: scheme, candidateCount: options.candidateCount)
        let (session, invalidateWhenDone) = makeSession()
        let task = session.dataTask(with: request) { data, response, error in
            defer { if invalidateWhenDone { session.finishTasksAndInvalidate() } }
            guard self.isCurrent(id), (error as NSError?)?.code != NSURLErrorCancelled else { return }
            if error == nil, let response = response as? HTTPURLResponse,
               (200..<300).contains(response.statusCode), let data = data,
               let parsed = Self.parseResponse(try? JSONSerialization.jsonObject(with: data)) {
                self.cache.store(text, candidates: parsed.0, metadata: parsed.1,
                    scheme: scheme, candidateCount: options.candidateCount)
                deliver(parsed.0, parsed.1?["matched_length"] as? [Int], .network)
                self.prefetch(text, scheme: scheme, options: options)
            } else {
                let cached = self.cache.lookup(text, scheme: scheme, candidateCount: options.candidateCount, allowExpired: true)
                    ?? self.cache.lookupLongestPrefix(text, scheme: scheme, candidateCount: options.candidateCount)
                deliver(cached?.candidates ?? [], cached?.matchedLength, .cache)
            }
        }
        taskLock.lock()
        if requestID == id { currentTask = task } else { task.cancel() }
        taskLock.unlock()
        task.resume()
    }

    static func parseResponse(_ json: Any?) -> ([String], [String: Any]?)? {
        guard let response = json as? [Any], response.count >= 2,
              response[0] as? String == "SUCCESS",
              let results = response[1] as? [Any],
              let item = results.first as? [Any], item.count >= 4,
              let input = item[0] as? String,
              let candidates = item[1] as? [String],
              let metadata = item[3] as? [String: Any] else { return nil }
        if let value = metadata["matched_length"] {
            guard let lengths = value as? [Int], lengths.count == candidates.count,
                  lengths.allSatisfy({ $0 > 0 && $0 <= input.count }) else { return nil }
        }
        return (candidates, metadata)
    }

    private func prefetch(_ text: String, scheme: InputTool, options: AccuracyOptions) {
        for prediction in cache.predictNextInputs(prefix: text, scheme: scheme, candidateCount: options.candidateCount) {
            let request = Self.makeRequest(prediction, scheme: scheme, candidateCount: options.candidateCount)
            let (session, invalidateWhenDone) = makeSession()
            session.dataTask(with: request) { data, response, error in
                defer { if invalidateWhenDone { session.finishTasksAndInvalidate() } }
                guard error == nil, let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode), let data = data,
                      let parsed = Self.parseResponse(try? JSONSerialization.jsonObject(with: data)) else { return }
                self.cache.store(prediction, candidates: parsed.0, metadata: parsed.1,
                    scheme: scheme, candidateCount: options.candidateCount)
            }.resume()
        }
    }
}
