//
//  TradingModels.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//  Redesigned: 2/24/26 — 极简指令式设计
//

import Foundation
import SwiftUI

// MARK: - 持仓记录

struct Holding: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stockName: String
    var shares: Int
    var costPrice: Double
    var addedAt: Date = Date()
    var currentPrice: Double?
    var marketValue: Double?

    var totalCost: Double { Double(shares) * costPrice }
    var displayMarketValue: Double { marketValue ?? totalCost }
}

// MARK: - 每日快照

struct DailySnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: String
    var holdings: [HoldingSnapshot]
    var totalCapital: Double
    var cashBalance: Double

    var totalMarketValue: Double {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    var totalAssets: Double {
        totalMarketValue + cashBalance
    }
}

struct HoldingSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stockName: String
    var shares: Int
    var costPrice: Double
    var closePrice: Double?

    var marketValue: Double {
        Double(shares) * (closePrice ?? costPrice)
    }

    var profitLoss: Double? {
        guard let close = closePrice else { return nil }
        return Double(shares) * (close - costPrice)
    }

    var profitLossPercent: Double? {
        guard let close = closePrice, costPrice > 0 else { return nil }
        return (close - costPrice) / costPrice
    }
}

// MARK: - 持仓操作建议标签

enum HoldingAction: String, Codable, CaseIterable {
    case hold = "持有"
    case buy = "买入"
    case sell = "卖出"
    case add = "加仓"
    case reduce = "减仓"
    case match = "符合"
    case adjust = "调仓"

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
    var strategyPercent: Double = 0.8
    var freePlayPercent: Double = 0.0
    var cashPercent: Double = 0.2

    static let minStrategyPercent: Double = 0.5
}

// MARK: - 持仓分类

enum HoldingCategory: String, Codable {
    case strategy = "策略仓"
    case freePlay = "自选仓"
    case mixed = "混合"
}

struct ClassifiedHolding: Identifiable {
    var id: UUID { holding.id }
    var holding: Holding
    var category: HoldingCategory
    var strategyShares: Int
    var freePlayShares: Int
    var action: HoldingAction?
    var suggestedReduceShares: Int?
}

// MARK: - 投资组合

struct Portfolio: Codable {
    var holdings: [Holding] = []
    var totalCapital: Double = 0
    var cashBalance: Double = 0
    var snapshots: [DailySnapshot] = []
    var strategyConfig: StrategyConfig = StrategyConfig()
    var lastUpdated: Date?

    var strategyBudget: Double { totalCapital * strategyConfig.strategyPercent }
    var freePlayBudget: Double { totalCapital * strategyConfig.freePlayPercent }
    var cashBudget: Double { totalCapital * strategyConfig.cashPercent }
}

// MARK: - 策略信号模型（简化版）

/// 操作类型
enum OperationType: String, Codable {
    case hold = "HOLD"      // 持有
    case buy = "BUY"        // 买入
    case sell = "SELL"      // 卖出
    case rotate = "ROTATE"  // 换仓

    var emoji: String {
        switch self {
        case .hold: return "🔵"
        case .buy: return "🟢"
        case .sell: return "🔴"
        case .rotate: return "🔄"
        }
    }

    var label: String {
        switch self {
        case .hold: return "持有"
        case .buy: return "买入"
        case .sell: return "卖出"
        case .rotate: return "换仓"
        }
    }

    var tintColor: Color {
        switch self {
        case .hold: return .blue
        case .buy: return .green
        case .sell: return .red
        case .rotate: return .orange
        }
    }
}

/// 目标持仓
struct TargetHolding: Codable, Identifiable {
    var id: UUID = UUID()
    var etfName: String
    var currentPrice: Double
    var momentumRank: Int?

    enum CodingKeys: String, CodingKey {
        case etfName = "etf_name"
        case currentPrice = "current_price"
        case momentumRank = "momentum_rank"
    }
}

/// 策略信号（极简版）
struct TradingSignal: Codable {
    var date: String
    var recommendation: String  // "HOLD" / "BUY" / "SELL" / "ROTATE"
    var targetHoldings: [TargetHolding]
    var message: String
    var sellTarget: TargetHolding?  // 换仓时的卖出标的
    var buyTarget: TargetHolding?   // 换仓时的买入标的

    enum CodingKeys: String, CodingKey {
        case date, recommendation, message
        case targetHoldings = "target_holdings"
        case sellTarget = "sell_target"
        case buyTarget = "buy_target"
    }

    /// 操作类型枚举
    var operation: OperationType {
        OperationType(rawValue: recommendation) ?? .hold
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
    var confidence: Double
}

struct OCRPortfolioSummary {
    var totalAssets: Double?
    var marketValue: Double?
    var cashBalance: Double?
    var totalProfitLoss: Double?
}

// MARK: - 兼容旧版本信号格式

struct StrategySignal: Codable {
    var date: String
    var status: String
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
