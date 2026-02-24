//
//  TradingIndicators.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/19/26.
//
//  通用技术指标计算库 — 纯函数，无状态，任何策略可复用

import Foundation

enum TradingIndicators {

    // MARK: - RSI（相对强弱指标）

    /// 计算 RSI 序列（Wilder 平滑法）
    /// - Parameters:
    ///   - prices: 收盘价序列（至少 period+1 个）
    ///   - period: 计算周期，默认 6
    /// - Returns: RSI 值数组，长度 = prices.count - period
    static func rsi(_ prices: [Double], period: Int = 6) -> [Double] {
        guard prices.count >= period + 1 else { return [] }

        let deltas = zip(prices.dropFirst(), prices).map { $0 - $1 }
        let gains = deltas.map { max($0, 0) }
        let losses = deltas.map { max(-$0, 0) }

        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)

        var result: [Double] = []
        // 第 period 个点的 RSI
        if avgLoss == 0 {
            result.append(100)
        } else {
            result.append(100 - 100 / (1 + avgGain / avgLoss))
        }

        for i in period..<deltas.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            if avgLoss == 0 {
                result.append(100)
            } else {
                let rs = avgGain / avgLoss
                result.append(100 - 100 / (1 + rs))
            }
        }
        return result
    }

    // MARK: - 简单移动平均

    /// 计算 MA（简单移动平均）
    static func sma(_ prices: [Double], period: Int) -> Double? {
        guard prices.count >= period else { return nil }
        let slice = prices.suffix(period)
        return slice.reduce(0, +) / Double(period)
    }

    // MARK: - 加权线性回归（动量评分核心）

    /// 加权线性回归，返回 (slope, intercept, rSquared)
    /// - Parameters:
    ///   - values: Y 值序列（通常是 log(price)）
    ///   - weights: 权重序列，nil 则等权
    /// - Returns: (斜率, 截距, R²)
    static func weightedLinearRegression(
        _ values: [Double],
        weights: [Double]? = nil
    ) -> (slope: Double, intercept: Double, rSquared: Double) {
        let n = values.count
        guard n >= 2 else { return (0, 0, 0) }

        let x = (0..<n).map { Double($0) }
        let w = weights ?? Array(repeating: 1.0, count: n)

        let sumW = w.reduce(0, +)
        let sumWX = zip(w, x).map(*).reduce(0, +)
        let sumWY = zip(w, values).map(*).reduce(0, +)
        let sumWXX = zip(w, x).map { $0 * $1 * $1 }.reduce(0, +)
        let sumWXY = (0..<n).map { w[$0] * x[$0] * values[$0] }.reduce(0, +)

        let denom = sumW * sumWXX - sumWX * sumWX
        guard denom != 0 else { return (0, 0, 0) }

        let slope = (sumW * sumWXY - sumWX * sumWY) / denom
        let intercept = (sumWY - slope * sumWX) / sumW

        // R²
        let meanY = sumWY / sumW
        let ssRes = (0..<n).map { w[$0] * pow(values[$0] - (slope * x[$0] + intercept), 2) }.reduce(0, +)
        let ssTot = (0..<n).map { w[$0] * pow(values[$0] - meanY, 2) }.reduce(0, +)
        let r2 = ssTot > 0 ? 1 - ssRes / ssTot : 0

        return (slope, intercept, r2)
    }

    // MARK: - 年化收益率（加权回归法）

    /// 通过加权回归计算年化收益率
    /// - Parameters:
    ///   - prices: 收盘价序列（lookbackDays+1 个数据点）
    ///   - lookbackDays: 回看天数
    /// - Returns: 年化收益率
    static func annualizedReturn(_ prices: [Double], lookbackDays: Int) -> Double {
        let recent = Array(prices.suffix(lookbackDays + 1))
        guard recent.count >= 2 else { return 0 }

        let logPrices = recent.map { log($0) }
        let weights = (0..<logPrices.count).map { 1.0 + Double($0) / Double(logPrices.count - 1) }

        let reg = weightedLinearRegression(logPrices, weights: weights)
        return exp(reg.slope * 250) - 1
    }

    // MARK: - 量比（成交量/额比较）

    /// 计算量比：今日值 / 过去N日均值
    /// - Parameters:
    ///   - todayValue: 今日成交量或成交额
    ///   - history: 历史成交量/额序列（最近N日）
    /// - Returns: 量比
    static func volumeRatio(todayValue: Double, history: [Double]) -> Double {
        guard !history.isEmpty else { return 0 }
        let avg = history.reduce(0, +) / Double(history.count)
        guard avg > 0 else { return 0 }
        return todayValue / avg
    }

    // MARK: - 近N日最大单日跌幅

    /// 检查近N日是否有单日跌幅超过阈值
    /// - Parameters:
    ///   - prices: 收盘价序列（至少 days+1 个）
    ///   - days: 检查天数，默认 3
    ///   - threshold: 止损线，如 0.97 表示跌超3%
    /// - Returns: true = 有触发止损的跌幅
    static func hasRecentDrop(_ prices: [Double], days: Int = 3, threshold: Double = 0.97) -> Bool {
        guard prices.count >= days + 1 else { return false }
        let tail = Array(prices.suffix(days + 1))
        for i in 1..<tail.count {
            if tail[i] / tail[i - 1] < threshold {
                return true
            }
        }
        return false
    }
}
