//
//  SevenStarStrategy.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/19/26.
//
//  七星高照 ETF 轮动策略 — 从 seven_star_local.py 1:1 移植
//  调用 TradingIndicators 计算指标，TushareService 拉取数据
//  数据本地缓存，增量更新（每次只拉缺失的天数）

import Foundation
import Observation

// MARK: - 策略配置

struct SevenStarConfig {
    // ETF 池（Tushare 代码格式）— 与聚宽回测版保持同步，回测验证后再更新
    static let etfPool: [(code: String, name: String)] = [
        ("518880.SH", "黄金ETF"),
        ("159985.SZ", "豆粕ETF"),
        ("501018.SH", "南方原油"),
        ("161226.SZ", "白银LOF"),
        ("513100.SH", "纳指ETF"),
        ("159915.SZ", "创业板ETF"),
        ("511220.SH", "城投债ETF"),
    ]

    // 防御性 ETF
    static let defensiveETF = (code: "511880.SH", name: "银华日利")

    // 核心参数
    static let lookbackDays = 25        // 长期动量回看天数
    static let holdingsNum = 1          // 持仓 ETF 数量
    static let minScoreThreshold = 0.0  // 最低得分
    static let maxScoreThreshold = 500.0 // 最高得分
    static let stopLossRatio = 0.97     // 近3日单日跌幅止损线

    // RSI 过滤
    static let useRSIFilter = true
    static let rsiPeriod = 6
    static let rsiLookbackDays = 1
    static let rsiThreshold = 98.0

    // 短期动量过滤
    static let useShortMomentumFilter = true
    static let shortLookbackDays = 10
    static let shortMomentumThreshold = 0.0

    // 成交额放量检测（使用日线amount字段）
    static let enableVolumeCheck = true  // 开启成交额放量检测
    static let volumeLookback = 5
    static let volumeThreshold = 2.0
    static let volumeReturnLimit = 1.0

    // 滚动窗口大小（保留天数）
    static let cacheWindowDays = 50

    // 数据需求：最长回看天数 + 缓冲
    static var dataLookbackDays: Int {
        max(lookbackDays, shortLookbackDays, rsiPeriod + rsiLookbackDays) + 20
    }
}

// MARK: - 策略计算结果

struct ETFScore {
    let code: String
    let name: String
    let score: Double
    let annualizedReturn: Double
    let rSquared: Double
    let currentPrice: Double
}

// MARK: - 缓存数据模型（可持久化）

struct ETFBarCache: Codable {
    var bars: [CachedBar]

    struct CachedBar: Codable {
        let tradeDate: String   // "YYYYMMDD"
        let open: Double
        let high: Double
        let low: Double
        let close: Double
        let vol: Double
        let amount: Double
    }

    /// 缓存中最后一天的日期
    var lastDate: String? { bars.last?.tradeDate }

    /// 追加新数据 + 裁剪到窗口大小
    mutating func append(_ newBars: [CachedBar], windowSize: Int) {
        let existingDates = Set(bars.map(\.tradeDate))
        let unique = newBars.filter { !existingDates.contains($0.tradeDate) }
        bars.append(contentsOf: unique)
        bars.sort { $0.tradeDate < $1.tradeDate }
        if bars.count > windowSize {
            bars = Array(bars.suffix(windowSize))
        }
    }
}

// MARK: - 七星策略引擎

@MainActor @Observable
class SevenStarStrategy {

    var lastSignal: StrategySignal?
    var isLoading = false
    var errorMessage: String?
    var lastRefreshTime: Date?

    /// ETF 日线缓存，key = tsCode
    private var cache: [String: ETFBarCache] = [:]

    /// 缓存是否已从磁盘加载
    private var cacheLoaded = false

    // MARK: - 本地缓存路径

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("seven_star_cache.json")
    }

    // MARK: - 主入口：计算今日信号

    func computeSignal(totalCapital: Double) async throws -> StrategySignal {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. 加载本地缓存（首次）
            if !cacheLoaded {
                loadCache()
                cacheLoaded = true
            }

            // 2. 增量拉取数据
            let allCodes = SevenStarConfig.etfPool.map(\.code) + [SevenStarConfig.defensiveETF.code]
            try await fetchIncremental(codes: allCodes)

            // 3. 计算每只 ETF 的动量得分
            var scores: [ETFScore] = []
            for (code, name) in SevenStarConfig.etfPool {
                guard let cached = cache[code], cached.bars.count >= SevenStarConfig.lookbackDays else {
                    continue
                }
                if let score = calculateScore(bars: cached.bars, code: code, name: name) {
                    scores.append(score)
                }
            }

            // 4. 按得分降序排列
            scores.sort { $0.score > $1.score }

            // 5. 生成信号
            let signal = buildSignal(ranked: scores, totalCapital: totalCapital)
            lastSignal = signal
            lastRefreshTime = Date()

            // 6. 保存缓存到磁盘
            saveCache()

            return signal
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - 增量数据拉取

    /// 只拉取缓存中缺失的数据
    private func fetchIncremental(codes: [String]) async throws {
        let today = todayDateString()

        for code in codes {
            let existing = cache[code]
            let lastCachedDate = existing?.lastDate

            // 确定起始日期：有缓存则从缓存末尾拉（含当天以获取实时更新），无缓存则全量
            let startDate: String
            if let last = lastCachedDate, last == today {
                // 今天已经拉过了，重新拉今天的（可能盘中数据更新了）
                startDate = today
            } else if let last = lastCachedDate {
                // 从上次缓存的日期开始（包含，以更新最后一天）
                startDate = last
            } else {
                // 无缓存，全量拉
                startDate = dateStringByOffset(days: -SevenStarConfig.cacheWindowDays)
            }

            do {
                let bars = try await TushareService.fetchETFDaily(
                    tsCode: code,
                    startDate: startDate,
                    endDate: today
                )

                let cachedBars = bars.map { bar in
                    ETFBarCache.CachedBar(
                        tradeDate: bar.tradeDate,
                        open: bar.open,
                        high: bar.high,
                        low: bar.low,
                        close: bar.close,
                        vol: bar.vol,
                        amount: bar.amount
                    )
                }

                if var existing = cache[code] {
                    // 增量追加：如果 startDate == lastCachedDate，先删掉旧的那天再追加
                    if let last = lastCachedDate, startDate == last {
                        existing.bars.removeAll { $0.tradeDate == last }
                    }
                    existing.append(cachedBars, windowSize: SevenStarConfig.cacheWindowDays)
                    cache[code] = existing
                } else {
                    var newCache = ETFBarCache(bars: [])
                    newCache.append(cachedBars, windowSize: SevenStarConfig.cacheWindowDays)
                    cache[code] = newCache
                }
            } catch {
                // 单只 ETF 拉取失败不中断整体
                print("[SevenStar] \(code) 增量拉取失败: \(error.localizedDescription)")
                // 如果有缓存就用缓存继续算
                if cache[code] == nil {
                    throw error  // 无缓存则无法计算，抛出
                }
            }

            // 限频
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - 单只 ETF 动量得分计算

    private func calculateScore(
        bars: [ETFBarCache.CachedBar],
        code: String,
        name: String
    ) -> ETFScore? {
        let closes = bars.map(\.close)
        guard closes.count >= SevenStarConfig.lookbackDays + 1 else { return nil }

        let currentPrice = closes.last!

        // ── 成交量过滤 ──
        if SevenStarConfig.enableVolumeCheck {
            let amounts = bars.map(\.amount)
            if amounts.count > SevenStarConfig.volumeLookback + 1 {
                let todayAmount = amounts.last!
                let historyAmounts = Array(amounts.suffix(SevenStarConfig.volumeLookback + 1).dropLast())
                let volRatio = TradingIndicators.volumeRatio(todayValue: todayAmount, history: historyAmounts)
                if volRatio > SevenStarConfig.volumeThreshold {
                    let annRet = TradingIndicators.annualizedReturn(closes, lookbackDays: SevenStarConfig.lookbackDays)
                    if annRet > SevenStarConfig.volumeReturnLimit {
                        return nil
                    }
                }
            }
        }

        // ── RSI 过滤 ──
        if SevenStarConfig.useRSIFilter {
            let rsiValues = TradingIndicators.rsi(closes, period: SevenStarConfig.rsiPeriod)
            if rsiValues.count >= SevenStarConfig.rsiLookbackDays {
                let recentRSI = Array(rsiValues.suffix(SevenStarConfig.rsiLookbackDays))
                let rsiAbove = recentRSI.contains { $0 > SevenStarConfig.rsiThreshold }
                let ma5 = TradingIndicators.sma(closes, period: 5) ?? currentPrice
                if rsiAbove && currentPrice < ma5 {
                    return nil
                }
            }
        }

        // ── 短期动量过滤 ──
        if SevenStarConfig.useShortMomentumFilter && closes.count >= SevenStarConfig.shortLookbackDays + 1 {
            let shortReturn = closes.last! / closes[closes.count - SevenStarConfig.shortLookbackDays - 1] - 1
            let shortAnnualized = pow(1 + shortReturn, 250.0 / Double(SevenStarConfig.shortLookbackDays)) - 1
            if shortAnnualized < SevenStarConfig.shortMomentumThreshold {
                return nil
            }
        }

        // ── 长期动量计算（加权回归）──
        let recentPrices = Array(closes.suffix(SevenStarConfig.lookbackDays + 1))
        let logPrices = recentPrices.map { log($0) }
        let weights = (0..<logPrices.count).map { 1.0 + Double($0) / Double(logPrices.count - 1) }
        let reg = TradingIndicators.weightedLinearRegression(logPrices, weights: weights)
        let annualizedReturn = exp(reg.slope * 250) - 1
        let score = annualizedReturn * reg.rSquared

        // ── 近3日止损检查 ──
        if TradingIndicators.hasRecentDrop(closes, days: 3, threshold: SevenStarConfig.stopLossRatio) {
            return nil
        }

        // ── 得分有效范围 ──
        guard score > SevenStarConfig.minScoreThreshold,
              score < SevenStarConfig.maxScoreThreshold else {
            return nil
        }

        return ETFScore(
            code: code,
            name: name,
            score: score,
            annualizedReturn: annualizedReturn,
            rSquared: reg.rSquared,
            currentPrice: currentPrice
        )
    }

    // MARK: - 生成策略信号

    private func buildSignal(ranked: [ETFScore], totalCapital: Double) -> StrategySignal {
        let today = todayDateString()

        let selected = Array(ranked.prefix(SevenStarConfig.holdingsNum))
            .filter { $0.score > SevenStarConfig.minScoreThreshold }

        if selected.isEmpty {
            return StrategySignal(
                date: today,
                status: "defensive",
                targetHoldings: [],
                defensiveEtf: SevenStarConfig.defensiveETF.name,
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                message: "无符合条件的ETF，建议持有 \(SevenStarConfig.defensiveETF.name)"
            )
        }

        let holdings = selected.map { etf in
            return SignalHolding(
                etf: etf.code,
                etfName: etf.name,
                score: etf.score,
                currentPrice: etf.currentPrice
            )
        }

        return StrategySignal(
            date: today,
            status: "signal",
            targetHoldings: holdings,
            defensiveEtf: SevenStarConfig.defensiveETF.name,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            message: nil
        )
    }

    // MARK: - 持仓对比

    // MARK: - 本地缓存持久化

    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: Self.cacheFileURL, options: .atomic)
        } catch {
            print("[SevenStar] 缓存保存失败: \(error)")
        }
    }

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: Self.cacheFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.cacheFileURL)
            cache = try JSONDecoder().decode([String: ETFBarCache].self, from: data)
            print("[SevenStar] 缓存加载成功，\(cache.count) 只ETF")
        } catch {
            print("[SevenStar] 缓存加载失败: \(error)")
            cache = [:]
        }
    }

    // MARK: - 日期工具

    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: Date())
    }

    private func dateStringByOffset(days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: date)
    }
}
