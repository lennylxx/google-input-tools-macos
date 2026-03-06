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
        case .Pinyin: return "Pinyin"
        case .Shuangpin_ABC: return "Shuangpin (ABC)"
        case .Shuangpin_Microsoft: return "Shuangpin (Microsoft)"
        case .Shuangpin_Xiaohe: return "Shuangpin (Xiaohe)"
        case .Shuangpin_Jiajia: return "Shuangpin (Jiajia)"
        case .Shuangpin_Ziguang: return "Shuangpin (Ziguang)"
        case .Shuangpin_Ziranma: return "Shuangpin (Ziranma)"
        case .Wubi: return "Wubi 86"
        }
    }
}

class CloudInputEngine {

    static let shared = CloudInputEngine()

    var inputTool: InputTool { UISettings.inputTool }
    let _candidateNum = 11

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

    func requestCandidates(
        _ text: String,
        complete: @escaping (_ candidates: [String], _ matchedLength: [Int]?) -> Void
    ) {
        // Check cache first
        if let cached = CandidateCache.shared.lookup(text) {
            NSLog("Cache hit: \(text)")
            if UISettings.frequencyRerank {
                let (reranked, rerankedML) = CandidateCache.shared.rerank(
                    pinyin: text, candidates: cached.candidates,
                    matchedLength: cached.matchedLength)
                complete(reranked, rerankedML)
            } else {
                complete(cached.candidates, cached.matchedLength)
            }
            return
        }

        let url = URL(
            string:
                "https://inputtools.google.com/request?text=\(text)&itc=\(inputTool.rawValue)&num=\(_candidateNum)&cp=0&cs=1&ie=utf-8&oe=utf-8&app=demopage"
        )!

        NSLog("%@", url.absoluteString)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let startTime = CFAbsoluteTimeGetCurrent()
        let (session, invalidateWhenDone) = makeSession()

        taskLock.lock()
        currentTask?.cancel()
        let task = session.dataTask(with: request) { data, response, error in
            defer {
                if invalidateWhenDone {
                    session.finishTasksAndInvalidate()
                }
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                NSLog("Request cancelled: \(text)")
                return
            }

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            NSLog("Request completed: \(text) in %.0fms", elapsed)

            guard let data = data else { return }

            /*
            [
              "SUCCESS",
              [[
                "abc",
                ["ABC","啊","阿","A","吖","腌","呵","阿布","嗄","啊不","锕"],
                [],
                {
                    "annotation":["a b c","a","a","a","a","a","a","a bu","a","a bu","a"],
                    "candidate_type":[0,0,0,0,0,0,0,0,0,0,0],
                    "lc":["0 0 0","16","16","0","16","16","16","16 16","16","16 16","16"],
                    "matched_length":[3,1,1,1,1,1,1,2,1,2,1]
                }
              ]]
             ]
            */

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            if let (candidateArray, metadata) = CloudInputEngine.parseResponse(json) {
                CandidateCache.shared.store(
                    text, candidates: candidateArray, metadata: metadata)
                let matchedLength = metadata?["matched_length"] as? [Int]
                complete(candidateArray, matchedLength)
            }
        }
        currentTask = task
        taskLock.unlock()

        task.resume()
    }

    static func parseResponse(_ json: Any?) -> ([String], [String: Any]?)? {
        guard let response = json as? [Any],
            let status = response[0] as? String,
            status == "SUCCESS",
            let resultArray = response[1] as? [Any],
            let candidateObject = resultArray.first as? [Any],
            let candidateArray = candidateObject[1] as? [String],
            let candidateMeta = candidateObject[3] as? [String: Any]
        else {
            return nil
        }

        return (candidateArray, candidateMeta)
    }

}
