import Foundation

/// Full-pinyin spelling rules, shared by language detection and typo recovery.
/// This deliberately does not expand regional pronunciation (z/zh, n/l, etc.).
enum PinyinSpelling {
    private static let syllables: Set<String> = Set("""
    a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu
    ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo
    da dai dan dang dao de dei den deng di dia dian diao die ding diu dong dou du duan dui dun duo
    e ei en eng er fa fan fang fei fen feng fo fou fu
    ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo
    ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo
    ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun
    ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo
    la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu lo long lou lu luan lun luo lv lve
    ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu
    na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nou nu nuan nuo nv nve
    o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu
    qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun
    ran rang rao re ren reng ri rong rou ru ruan rui run ruo
    sa sai san sang sao se sen seng sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo
    ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo
    wa wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun
    ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun
    za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    private static let prefixes = Set(syllables.flatMap { word in (1...word.count).map { String(word.prefix($0)) } })

    static func isPinyin(_ text: String, allowIncompleteLastSyllable: Bool = true) -> Bool {
        let parts = text.lowercased().split(separator: "'", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return false }
        return parts.enumerated().allSatisfy { index, part in
            let allowPrefix = allowIncompleteLastSyllable && index == parts.count - 1
            if part.isEmpty { return allowPrefix && index > 0 }
            let chars = Array(part)
            guard chars.count <= 80 else { return false }
            var reachable = Array(repeating: false, count: chars.count + 1)
            reachable[0] = true
            for start in chars.indices where reachable[start] {
                for end in (start + 1)...min(chars.count, start + 6) {
                    let word = String(chars[start..<end])
                    if syllables.contains(word) || (allowPrefix && end == chars.count && prefixes.contains(word)) {
                        reachable[end] = true
                    }
                }
            }
            return reachable[chars.count]
        }
    }

    private static let commonInputs: Set<String> = Set("""
    nihao xiexie zaijian shijie zhongguo zhongwen yingwen shurufa shuru wenti keyi keyima
    shenme weishenme zenme zenmeyang women nimen tamen jintian mingtian xianzai yijing
    meiyou zhidao xihuan pengyou gongzuo xuexi shijian dianhua diannao shouji bangmang
    qingwen shezhi mingzi ruanjian yingyong chuangkou weizhi shanshuo zhengque zhunque
    youhua gengxin jiancha xuanze yuyan xianshi ceshi peizhi canshu jiekou daima
    baocun shanchu tianjia xiugai chongxin anzhuang chongqi xiazai shangchuan
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    static func typoCorrections(_ input: String, limit: Int = 2) -> [String] {
        let text = input.lowercased()
        let chars = Array(text)
        guard (3...32).contains(chars.count), !text.contains("'"),
              chars.allSatisfy({ $0.isASCII && $0.isLetter }),
              !isPinyin(text, allowIncompleteLastSyllable: false) else { return [] }
        var costs = [String: Int]()
        let mayBeUnfinishedSyllable = isPinyin(text)
        func add(_ value: [Character], cost: Int) {
            let word = String(value)
            guard word != text, isPinyin(word, allowIncompleteLastSyllable: false) else { return }
            let known = commonInputs.contains(word) || PersonalDictionary.technical[word] != nil
            // Normal prefixes such as "nih" are not mistakes. Only a known
            // complete expression justifies a missing-letter alternative there.
            guard !mayBeUnfinishedSyllable || known else { return }
            let score = cost - (known ? 100 : 0)
            costs[word] = min(costs[word] ?? Int.max, score)
        }
        // Adjacent swaps first; omitted letters next. No pronunciation expansion.
        for index in 0..<(chars.count - 1) where chars[index] != chars[index + 1] {
            var value = chars
            value.swapAt(index, index + 1)
            add(value, cost: 10)
        }
        for index in 0...chars.count {
            for letter in "abcdefghijklmnopqrstuvwxyz" {
                var value = chars
                value.insert(letter, at: index)
                add(value, cost: 30)
            }
        }
        // Extra letters are common too, but less certain than a transposition.
        for index in chars.indices {
            var value = chars
            value.remove(at: index)
            add(value, cost: 50)
        }
        return Array(costs.keys.sorted {
            costs[$0] == costs[$1] ? $0 < $1 : costs[$0]! < costs[$1]!
        }.prefix(limit))
    }
}
