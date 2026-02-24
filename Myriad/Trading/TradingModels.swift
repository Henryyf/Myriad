//
//  TradingModels.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import Foundation

// MARK: - 持仓记录

struct Holding: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stockName: String       // 股票名称，如 "贵州茅台"
    var shares: Int             // 持仓股数
    var costPrice: Double       // 成本价
    var addedAt: Date = Date()  // 录入时间
    
    // OCR 扫描数据（可选）
    var currentPrice: Double?   // 现价（来自 OCR 扫描）
    var marketValue: Double?    // 市值（来自 OCR 扫描）

    /// 持仓成本 = 股数 × 成本价
    var totalCost: Double { Double(shares) * costPrice }
    
    /// 显示用市值（优先用 OCR 的 marketValue，否则用 totalCost）
    var displayMarketValue: Double {
        marketValue ?? totalCost
    }
}

// MARK: - 每日快照

struct DailySnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: String            // "yyyy-MM-dd" 格式
    var holdings: [HoldingSnapshot]
    var totalCapital: Double    // 当日总本金（含现金）
    var cashBalance: Double     // 现金余额

    /// 当日总市值
    var totalMarketValue: Double {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    /// 当日总资产 = 市值 + 现金
    var totalAssets: Double {
        totalMarketValue + cashBalance
    }
}

/// 快照中的单只持仓
struct HoldingSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stockName: String
    var shares: Int
    var costPrice: Double
    var closePrice: Double?     // 当日收盘价，nil 表示未收盘（显示为 "—"）

    /// 当前市值（未收盘时按成本算）
    var marketValue: Double {
        Double(shares) * (closePrice ?? costPrice)
    }

    /// 盈亏金额
    var profitLoss: Double? {
        guard let close = closePrice else { return nil }
        return Double(shares) * (close - costPrice)
    }

    /// 盈亏比例
    var profitLossPercent: Double? {
        guard let close = closePrice, costPrice > 0 else { return nil }
        return (close - costPrice) / costPrice
    }
}

// MARK: - 持仓操作建议标签

enum HoldingAction: String, Codable, CaseIterable {
    case hold = "持有"        // 灰色
    case buy = "买入"         // 红色
    case sell = "卖出"        // 绿色
    case add = "加仓"         // 橙色
    case reduce = "减仓"      // 蓝色
    case match = "符合"       // 绿色
    case adjust = "调仓"      // 黄色（自选仓超出预算）

    var color: String {
        switch self {
        case .hold: return "gray"
        case .buy: return "red"
        case .sell: return "green"
        case .add: return "orange"
        case .reduce: return "blue"
        case .match: return "green"
        case .adjust: return "yellow"
        }
    }
}

// MARK: - 策略配置

struct StrategyConfig: Codable {
    var strategyPercent: Double = 0.8    // 策略仓占比
    var freePlayPercent: Double = 0.0    // 自选仓占比
    var cashPercent: Double = 0.2        // 现金仓占比
    // 三者之和必须为 1.0

    /// 策略仓最低建议比例
    static let minStrategyPercent: Double = 0.5
}

// MARK: - 持仓分类

enum HoldingCategory: String, Codable {
    case strategy = "策略仓"    // 匹配策略信号
    case freePlay = "自选仓"    // 用户自己买的
    case mixed = "混合"         // 部分匹配
}

/// 持仓分类结果
struct ClassifiedHolding: Identifiable {
    var id: UUID { holding.id }
    var holding: Holding
    var category: HoldingCategory
    var strategyShares: Int     // 属于策略仓的股数
    var freePlayShares: Int     // 属于自选仓的股数
    var action: HoldingAction?  // 操作建议
    var suggestedReduceShares: Int? // 调仓建议：应减持股数（仅 action = .adjust 时使用）
}

// MARK: - 投资组合

struct Portfolio: Codable {
    var holdings: [Holding] = []        // 当前全部持仓
    var totalCapital: Double = 0        // 总本金
    var cashBalance: Double = 0         // 现金余额
    var snapshots: [DailySnapshot] = [] // 历史快照
    var strategyConfig: StrategyConfig = StrategyConfig()  // 策略配置
    var lastUpdated: Date?              // 最后一次更新持仓的时间

    /// 策略仓分配金额
    var strategyBudget: Double { totalCapital * strategyConfig.strategyPercent }
    /// 自选仓分配金额
    var freePlayBudget: Double { totalCapital * strategyConfig.freePlayPercent }
    /// 现金仓分配金额
    var cashBudget: Double { totalCapital * strategyConfig.cashPercent }
}

// MARK: - 策略信号模型

struct StrategySignal: Codable {
    var date: String
    var status: String  // "signal" or "defensive"
    var targetHoldings: [SignalHolding]
    var defensiveEtf: String?
    var generatedAt: String?
    var message: String?

    enum CodingKeys: String, CodingKey {
        case date, status, message
        case targetHoldings = "target_holdings"
        case defensiveEtf = "defensive_etf"
        case generatedAt = "generated_at"
    }
}

struct SignalHolding: Codable {
    var etf: String?
    var etfName: String
    var score: Double?
    var currentPrice: Double?

    enum CodingKeys: String, CodingKey {
        case etf, score
        case etfName = "etf_name"
        case currentPrice = "current_price"
    }
}

// MARK: - 持仓对比建议

struct HoldingAdvice {
    var stockName: String
    var action: HoldingAction
    var currentShares: Int
    var targetShares: Int
    var currentValue: Double
    var targetValue: Double
    var reason: String
}

// MARK: - OCR 扫描结果

struct OCRHoldingResult: Identifiable {
    var id: UUID = UUID()
    var stockName: String
    var shares: Int
    var costPrice: Double
    var currentPrice: Double?
    var marketValue: Double?
    var profitLoss: Double?
    var profitLossPercent: Double?
    var confidence: Double      // OCR 识别置信度 0-1
}

/// OCR 识别出的账户汇总信息
struct OCRPortfolioSummary {
    var totalAssets: Double?
    var marketValue: Double?
    var cashBalance: Double?
    var totalProfitLoss: Double?
}
