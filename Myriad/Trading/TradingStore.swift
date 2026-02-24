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

    /// 根据用户资产和策略配置，计算目标股数
    func calculateTargetShares(currentPrice: Double) -> Int {
        let strategyValue = portfolio.totalCapital * portfolio.strategyConfig.strategyPercent
        let targetShares = Int(strategyValue / currentPrice / 100) * 100  // 取整到100股
        return targetShares
    }
    
    /// 根据策略信号分类所有持仓（策略仓 vs 自选仓）
    func classifyHoldings(signal: StrategySignal?) -> [ClassifiedHolding] {
        guard let signal = signal else {
            // 无信号时全部归为自选仓
            return portfolio.holdings.map {
                ClassifiedHolding(holding: $0, category: .freePlay, strategyShares: 0, freePlayShares: $0.shares, action: nil, suggestedReduceShares: nil)
            }
        }

        let targetMap = Dictionary(uniqueKeysWithValues: signal.targetHoldings.map { ($0.etfName, $0) })
        // 防御性 ETF 也算策略仓
        let defensiveNames: Set<String> = {
            if let d = signal.defensiveEtf { return [d] }
            return []
        }()

        var result: [ClassifiedHolding] = []
        
        // 第一遍：分类
        for holding in portfolio.holdings {
            if let target = targetMap[holding.stockName] {
                // ✅ 根据用户资产计算目标股数
                guard let currentPrice = target.currentPrice else {
                    // 无价格信息 → 归为自选仓
                    result.append(ClassifiedHolding(holding: holding, category: .freePlay, strategyShares: 0, freePlayShares: holding.shares, action: nil, suggestedReduceShares: nil))
                    continue
                }
                let targetShares = calculateTargetShares(currentPrice: currentPrice)
                
                // ✅ 使用市值占比而非股数差异来判断（避免价格波动误导）
                let currentMarketValue = Double(holding.shares) * (holding.currentPrice ?? currentPrice)
                let targetValue = portfolio.totalCapital * portfolio.strategyConfig.strategyPercent
                let currentRatio = currentMarketValue / portfolio.totalCapital
                let targetRatio = portfolio.strategyConfig.strategyPercent
                let ratioDiff = abs(currentRatio - targetRatio)
                
                // 匹配策略信号
                let stratShares = min(holding.shares, targetShares)
                let freeShares = max(0, holding.shares - targetShares)
                let category: HoldingCategory = freeShares > 0 ? .mixed : .strategy
                
                // ✅ 判断标准：市值占比偏差 < 3% 视为符合
                let action: HoldingAction = {
                    if ratioDiff < 0.03 { 
                        return .match  // 市值占比接近目标，无需操作
                    }
                    // 市值占比偏离 > 3%，检查是否需要调仓
                    if currentMarketValue < targetValue {
                        // 现金不足检查
                        let neededCash = targetValue - currentMarketValue
                        if portfolio.cashBalance < neededCash * 0.1 {  // 连10%都买不起
                            return .match  // 现金不足，保持现状
                        }
                        return .add
                    }
                    return .reduce
                }()
                result.append(ClassifiedHolding(holding: holding, category: category, strategyShares: stratShares, freePlayShares: freeShares, action: action, suggestedReduceShares: nil))
            } else if defensiveNames.contains(holding.stockName) {
                result.append(ClassifiedHolding(holding: holding, category: .strategy, strategyShares: holding.shares, freePlayShares: 0, action: .hold, suggestedReduceShares: nil))
            } else {
                // 不在信号中 → 自选仓
                result.append(ClassifiedHolding(holding: holding, category: .freePlay, strategyShares: 0, freePlayShares: holding.shares, action: nil, suggestedReduceShares: nil))
            }
        }
        
        // 第二遍：检查自选仓是否超出预算
        let freePlayBudget = portfolio.totalCapital * portfolio.strategyConfig.freePlayPercent
        var freePlayActualValue: Double = 0
        
        for item in result where item.category == .freePlay {
            // 优先使用 OCR 扫描的市值，否则用成本计算
            let marketValue = item.holding.displayMarketValue
            freePlayActualValue += marketValue
        }
        
        // 如果自选仓超出预算 > 5%，给出调仓建议
        if freePlayActualValue > freePlayBudget * 1.05 {
            let excess = freePlayActualValue - freePlayBudget
            print("⚠️ 自选仓超出预算：实际 ¥\(freePlayActualValue)，预算 ¥\(freePlayBudget)，超出 ¥\(excess)")
            
            // 更新每只自选仓股票的 action
            for i in 0..<result.count {
                guard result[i].category == .freePlay else { continue }
                let holding = result[i].holding
                
                // 计算这只股票应该减持的比例（按市值占比）
                let holdingMarketValue = holding.displayMarketValue
                let holdingRatio = holdingMarketValue / freePlayActualValue
                let shouldReduceValue = excess * holdingRatio
                
                // 使用实时价格计算应减持股数
                let currentPrice = holding.currentPrice ?? holding.costPrice
                let shouldReduceShares = Int(shouldReduceValue / currentPrice / 100) * 100 // 取整到100股
                
                if shouldReduceShares > 0 {
                    result[i].action = .adjust
                    result[i].suggestedReduceShares = shouldReduceShares
                }
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
            guard let currentPrice = target.currentPrice else {
                // 无价格信息，跳过
                continue
            }
            
            // ✅ 根据用户资产计算目标股数
            let targetShares = calculateTargetShares(currentPrice: currentPrice)
            let targetValue = Double(targetShares) * currentPrice
            
            if let current = currentMap[name] {
                // ✅ 使用市值占比而非股数差异来判断（与 classifyHoldings 保持一致）
                let currentMarketValue = Double(current.shares) * (current.currentPrice ?? currentPrice)
                let targetValueIdeal = portfolio.totalCapital * portfolio.strategyConfig.strategyPercent
                let currentRatio = currentMarketValue / portfolio.totalCapital
                let targetRatio = portfolio.strategyConfig.strategyPercent
                let ratioDiff = abs(currentRatio - targetRatio)
                
                let action: HoldingAction
                let reason: String
                
                // ✅ 判断标准：市值占比偏差 < 3% 视为符合
                if ratioDiff < 0.03 {
                    action = .match
                    reason = "持仓比例符合目标（\(String(format: "%.1f", currentRatio*100))% vs \(String(format: "%.1f", targetRatio*100))%）"
                } else if currentMarketValue < targetValueIdeal {
                    // 现金不足检查
                    let neededCash = targetValueIdeal - currentMarketValue
                    if portfolio.cashBalance < neededCash * 0.1 {  // 连10%都买不起
                        action = .match
                        reason = "现金不足，保持当前持仓"
                    } else {
                        action = .add
                        reason = "需加仓 \(targetShares - current.shares) 股"
                    }
                } else {
                    action = .reduce
                    reason = "需减仓 \(current.shares - targetShares) 股"
                }
                advices.append(HoldingAdvice(
                    stockName: name,
                    action: action,
                    currentShares: current.shares,
                    targetShares: targetShares,
                    currentValue: current.totalCost,
                    targetValue: targetValue,
                    reason: reason
                ))
                currentMap.removeValue(forKey: name)
            } else {
                // 目标有但当前没有 → 买入
                advices.append(HoldingAdvice(
                    stockName: name,
                    action: .buy,
                    currentShares: 0,
                    targetShares: targetShares,
                    currentValue: 0,
                    targetValue: targetValue,
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
                costPrice: result.costPrice,
                currentPrice: result.currentPrice,
                marketValue: result.marketValue
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
