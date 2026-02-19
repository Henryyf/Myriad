//
//  TradingStore.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import Foundation
import Observation

@Observable
final class TradingStore {

    private(set) var portfolio = Portfolio()

    // MARK: - iCloud 存储

    private static let dataFileName = "trading_data.json"

    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent(Self.dataFileName)
    }

    private var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.dataFileName)
    }

    init() {
        loadData()
    }

    // MARK: - 持仓管理

    /// 添加持仓（手动或 OCR 导入）
    func addHolding(stockName: String, shares: Int, costPrice: Double) {
        // 如果已有同名股票，合并（加权平均成本）
        if let idx = portfolio.holdings.firstIndex(where: { $0.stockName == stockName }) {
            let existing = portfolio.holdings[idx]
            let totalShares = existing.shares + shares
            let avgCost = (existing.totalCost + Double(shares) * costPrice) / Double(totalShares)
            portfolio.holdings[idx].shares = totalShares
            portfolio.holdings[idx].costPrice = avgCost
        } else {
            let holding = Holding(
                stockName: stockName,
                shares: shares,
                costPrice: costPrice
            )
            portfolio.holdings.append(holding)
        }
        saveData()
    }

    /// 更新持仓
    func updateHolding(id: UUID, shares: Int, costPrice: Double) {
        guard let idx = portfolio.holdings.firstIndex(where: { $0.id == id }) else { return }
        portfolio.holdings[idx].shares = shares
        portfolio.holdings[idx].costPrice = costPrice
        saveData()
    }

    /// 删除持仓
    func removeHolding(id: UUID) {
        portfolio.holdings.removeAll { $0.id == id }
        saveData()
    }

    /// 设置总本金
    func setTotalCapital(_ amount: Double) {
        portfolio.totalCapital = amount
        saveData()
    }

    /// 设置现金余额
    func setCashBalance(_ amount: Double) {
        portfolio.cashBalance = amount
        saveData()
    }

    /// 更新策略配置
    func updateStrategyConfig(_ config: StrategyConfig) {
        portfolio.strategyConfig = config
        saveData()
    }

    /// 标记持仓已更新
    func markUpdated() {
        portfolio.lastUpdated = Date()
        saveData()
    }

    /// 今天是否已更新持仓
    var isUpdatedToday: Bool {
        guard let lastUpdated = portfolio.lastUpdated else { return false }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: lastUpdated) == todayString
    }

    /// 根据策略信号分类所有持仓（策略仓 vs 自选仓）
    func classifyHoldings(signal: StrategySignal?) -> [ClassifiedHolding] {
        guard let signal = signal else {
            // 无信号时全部归为自选仓
            return portfolio.holdings.map {
                ClassifiedHolding(holding: $0, category: .freePlay, strategyShares: 0, freePlayShares: $0.shares, action: nil)
            }
        }

        let targetMap = Dictionary(uniqueKeysWithValues: signal.targetHoldings.map { ($0.etfName, $0) })
        // 防御性 ETF 也算策略仓
        let defensiveNames: Set<String> = {
            if let d = signal.defensiveEtf { return [d] }
            return []
        }()

        var result: [ClassifiedHolding] = []
        for holding in portfolio.holdings {
            if let target = targetMap[holding.stockName] {
                // 匹配策略信号
                let stratShares = min(holding.shares, target.targetShares)
                let freeShares = max(0, holding.shares - target.targetShares)
                let category: HoldingCategory = freeShares > 0 ? .mixed : .strategy
                let diff = Double(target.targetShares - holding.shares) / max(Double(holding.shares), 1)
                let action: HoldingAction = {
                    if abs(diff) < 0.05 { return .match }
                    return diff > 0 ? .add : .reduce
                }()
                result.append(ClassifiedHolding(holding: holding, category: category, strategyShares: stratShares, freePlayShares: freeShares, action: action))
            } else if defensiveNames.contains(holding.stockName) {
                result.append(ClassifiedHolding(holding: holding, category: .strategy, strategyShares: holding.shares, freePlayShares: 0, action: .hold))
            } else {
                // 不在信号中 → 自选仓
                result.append(ClassifiedHolding(holding: holding, category: .freePlay, strategyShares: 0, freePlayShares: holding.shares, action: nil))
            }
        }
        return result
    }

    /// 计算策略仓和自选仓各自的总市值
    func portfolioBreakdown(classified: [ClassifiedHolding]) -> (strategyValue: Double, freePlayValue: Double) {
        var sv: Double = 0
        var fv: Double = 0
        for c in classified {
            sv += Double(c.strategyShares) * c.holding.costPrice
            fv += Double(c.freePlayShares) * c.holding.costPrice
        }
        return (sv, fv)
    }

    /// 对比当前持仓和策略推荐，生成操作建议
    func compareWithSignal(_ signal: StrategySignal) -> [HoldingAdvice] {
        var advices: [HoldingAdvice] = []
        let currentHoldings = portfolio.holdings
        let targetHoldings = signal.targetHoldings

        // 构建当前持仓字典（按名称）
        var currentMap: [String: Holding] = [:]
        for h in currentHoldings {
            currentMap[h.stockName] = h
        }

        // 构建目标持仓字典（按名称）
        var targetMap: [String: SignalHolding] = [:]
        for t in targetHoldings {
            targetMap[t.etfName] = t
        }

        // 检查目标中有的
        for target in targetHoldings {
            let name = target.etfName
            if let current = currentMap[name] {
                // 都有，比较数量
                let diff = Double(target.targetShares - current.shares) / max(Double(current.shares), 1)
                let action: HoldingAction
                let reason: String
                if abs(diff) < 0.05 {
                    action = .match
                    reason = "持仓数量与目标接近"
                } else if diff > 0 {
                    action = .add
                    reason = "需加仓 \(target.targetShares - current.shares) 股"
                } else {
                    action = .reduce
                    reason = "需减仓 \(current.shares - target.targetShares) 股"
                }
                advices.append(HoldingAdvice(
                    stockName: name,
                    action: action,
                    currentShares: current.shares,
                    targetShares: target.targetShares,
                    currentValue: current.totalCost,
                    targetValue: target.targetValue,
                    reason: reason
                ))
                currentMap.removeValue(forKey: name)
            } else {
                // 目标有但当前没有 → 买入
                advices.append(HoldingAdvice(
                    stockName: name,
                    action: .buy,
                    currentShares: 0,
                    targetShares: target.targetShares,
                    currentValue: 0,
                    targetValue: target.targetValue,
                    reason: "策略推荐买入"
                ))
            }
        }

        // 当前有但目标没有 → 卖出
        for (name, holding) in currentMap {
            advices.append(HoldingAdvice(
                stockName: name,
                action: .sell,
                currentShares: holding.shares,
                targetShares: 0,
                currentValue: holding.totalCost,
                targetValue: 0,
                reason: "不在策略推荐中，建议卖出"
            ))
        }

        return advices
    }

    /// 从 OCR 结果批量导入（覆盖当前持仓）
    func importFromOCR(results: [OCRHoldingResult], summary: OCRPortfolioSummary) {
        portfolio.holdings = results.map { result in
            Holding(
                stockName: result.stockName,
                shares: result.shares,
                costPrice: result.costPrice
            )
        }
        if let assets = summary.totalAssets {
            portfolio.totalCapital = assets
        }
        if let cash = summary.cashBalance {
            portfolio.cashBalance = cash
        }
        portfolio.lastUpdated = Date()
        saveData()
    }

    // MARK: - 每日快照

    /// 生成今日快照
    func takeSnapshot(date: String, closePrices: [String: Double] = [:]) {
        let holdingSnapshots = portfolio.holdings.map { h in
            HoldingSnapshot(
                stockName: h.stockName,
                shares: h.shares,
                costPrice: h.costPrice,
                closePrice: closePrices[h.stockName]
            )
        }

        let snapshot = DailySnapshot(
            date: date,
            holdings: holdingSnapshots,
            totalCapital: portfolio.totalCapital,
            cashBalance: portfolio.cashBalance
        )

        // 如果同一天已有快照，替换
        if let idx = portfolio.snapshots.firstIndex(where: { $0.date == date }) {
            portfolio.snapshots[idx] = snapshot
        } else {
            portfolio.snapshots.append(snapshot)
            portfolio.snapshots.sort { $0.date > $1.date }
        }
        saveData()
    }

    /// 今日日期字符串
    var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return fmt.string(from: Date())
    }

    // MARK: - 持久化

    private func saveData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(portfolio)

            if let iCloudURL = iCloudURL {
                let dir = iCloudURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                try data.write(to: iCloudURL, options: .atomic)
            }

            try data.write(to: localURL, options: .atomic)
        } catch {
            print("❌ Trading 数据保存失败: \(error.localizedDescription)")
        }
    }

    private func loadData() {
        if let iCloudURL = iCloudURL,
           FileManager.default.fileExists(atPath: iCloudURL.path),
           let data = try? Data(contentsOf: iCloudURL),
           let loaded = decode(from: data) {
            portfolio = loaded
            return
        }

        if FileManager.default.fileExists(atPath: localURL.path),
           let data = try? Data(contentsOf: localURL),
           let loaded = decode(from: data) {
            portfolio = loaded
        }
    }

    private func decode(from data: Data) -> Portfolio? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Portfolio.self, from: data)
    }
}
