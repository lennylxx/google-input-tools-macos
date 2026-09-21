import Foundation

enum RankingMode: String, CaseIterable {
    case cloud, balanced, personal

    var title: String {
        switch self {
        case .cloud: return "保持云端排序"
        case .balanced: return "云端优先，适度提升个人常用词"
        case .personal: return "个人常用词优先"
        }
    }
}

/// Snapshot once per request so an in-flight response keeps its original settings.
struct AccuracyOptions {
    var ranking: RankingMode = .balanced
    var explicitOnly = true
    var minimumSelections = 5
    var halfLifeDays = 90
    var candidateCount = 20
    var technicalDictionary = true
    var customPhrases = ""
}
