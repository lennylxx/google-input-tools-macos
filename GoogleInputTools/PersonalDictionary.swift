import Foundation

/// Exact full-pinyin entries only. No private conversation text is bundled.
enum PersonalDictionary {
    enum ImportError: LocalizedError {
        case invalidLine(Int)
        var errorDescription: String? {
            switch self {
            case .invalidLine(let line): return "第 \(line) 行格式有误。请填写“拼音＋制表符＋词语”，例如：jiekou\t接口。"
            }
        }
    }

    static let technical: [String: [String]] = [
        "jiekou": ["接口"], "canshu": ["参数"], "peizhi": ["配置"],
        "bushu": ["部署"], "tijiao": ["提交"], "banben": ["版本"],
        "ceshi": ["测试"], "rizhi": ["日志"], "fuwu": ["服务"],
        "fuwuqi": ["服务器"], "wendang": ["文档"], "chushihua": ["初始化"],
        "goujian": ["构建"], "bianyi": ["编译"], "huidiao": ["回调"],
        "huancun": ["缓存"], "xiancheng": ["线程"], "jincheng": ["进程"],
        "bingfa": ["并发"], "yibu": ["异步"],
        "tongbu": ["同步"], "quanxian": ["权限"], "daima": ["代码"],
        "cangku": ["仓库"], "fenzhi": ["分支"],
        "shujuku": ["数据库"], "zhiling": ["指令"], "zhongduan": ["终端"],
        "daili": ["代理"], "chajian": ["插件"], "shengji": ["升级"],
        "wangluo": ["网络"], "yanchi": ["延迟"], "daikuan": ["带宽"],
        "yinpin": ["音频"], "shipin": ["视频"], "maliu": ["码流"],
        "malv": ["码率"], "tuiliu": ["推流"], "laliu": ["拉流"],
        "codex": ["Codex"], "claude": ["Claude"], "gitea": ["Gitea"],
        "github": ["GitHub"], "openviking": ["OpenViking"], "swift": ["Swift"],
        "macos": ["macOS"], "webrtc": ["WebRTC"], "sdk": ["SDK"], "api": ["API"]
    ]

    static func parse(_ text: String) throws -> [String: [String]] {
        var result = [String: [String]]()
        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == "\t" || $0 == " " })
            guard parts.count == 2 else { throw ImportError.invalidLine(index + 1) }
            let key = String(parts[0]).lowercased()
            let phrase = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, key.count <= 80, !phrase.isEmpty, phrase.count <= 80,
                  key.unicodeScalars.allSatisfy({ (97...122).contains($0.value) || $0.value == 39 }) else {
                throw ImportError.invalidLine(index + 1)
            }
            if !(result[key] ?? []).contains(phrase) { result[key, default: []].append(phrase) }
        }
        return result
    }

    static func candidates(for text: String, scheme: InputTool, options: AccuracyOptions) -> [String] {
        guard scheme == .Pinyin else { return [] }
        let key = text.lowercased()
        let custom = (try? parse(options.customPhrases)) ?? [:]
        let values = (custom[key] ?? []) + (options.technicalDictionary ? technical[key] ?? [] : [])
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    static func merge(text: String, cloud: [String], matchedLength: [Int]?,
                      local: [String]) -> ([String], [Int]) {
        var result = [String]()
        var lengths = [Int]()
        var seen = Set<String>()
        func append(_ word: String, _ matched: Int) {
            if seen.insert(word).inserted { result.append(word); lengths.append(matched) }
        }
        // Keep Google's first choice, then make exact local phrases readily selectable.
        for (i, word) in cloud.enumerated() {
            let length = matchedLength.flatMap { i < $0.count ? $0[i] : nil } ?? text.count
            append(word, length)
            if i == 0 {
                for word in local where !cloud.contains(word) { append(word, text.count) }
            }
        }
        if cloud.isEmpty { for word in local { append(word, text.count) } }
        return (result, lengths)
    }
}
