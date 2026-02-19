//
//  OCRService.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import Foundation
import Vision
import UIKit

/// 东方财富持仓截图 OCR 解析器
///
/// 东方财富持仓截图格式（每只股票两行）：
/// 第一行：股票名称    持仓    现价      盈亏金额
/// 第二行：市值        可用    成本      盈亏%
struct OCRService {

    // MARK: - 公开接口

    /// 从图片中识别持仓信息和账户汇总
    static func recognizeHoldings(from image: UIImage) async throws -> (holdings: [OCRHoldingResult], summary: OCRPortfolioSummary) {
        let lines = try await extractTextLines(from: image)
        let holdings = parseEastMoneyHoldings(from: lines)
        let summary = parsePortfolioSummary(from: lines)
        return (holdings, summary)
    }

    // MARK: - VisionKit OCR

    private static func extractTextLines(from image: UIImage) async throws -> [(String, CGRect, Float)] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines = observations.compactMap { obs -> (String, CGRect, Float)? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return (candidate.string, obs.boundingBox, candidate.confidence)
                }

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - 账户汇总解析

    /// 解析总资产、证券市值、可用余额等汇总信息
    private static func parsePortfolioSummary(from lines: [(String, CGRect, Float)]) -> OCRPortfolioSummary {
        var summary = OCRPortfolioSummary()
        let allTexts = lines.map { $0.0 }

        for (i, text) in allTexts.enumerated() {
            let cleaned = text.replacingOccurrences(of: ",", with: "")

            // 总资产：通常是一个大数字，在"总资产"文字附近
            if text.contains("总资产") {
                // 下一个纯数字行可能就是总资产值
                if i + 1 < allTexts.count, let val = parseAmount(allTexts[i + 1]) {
                    summary.totalAssets = val
                }
            }

            // 证券市值
            if text.contains("证券市值") {
                if i + 1 < allTexts.count, let val = parseAmount(allTexts[i + 1]) {
                    summary.marketValue = val
                }
            }

            // 可用
            if text.contains("可用") && !text.contains("持仓") && !text.contains("可用=") {
                if i + 1 < allTexts.count, let val = parseAmount(allTexts[i + 1]) {
                    summary.cashBalance = val
                }
            }

            // 持仓盈亏
            if text.contains("持仓盈亏") {
                if i + 1 < allTexts.count, let val = parseAmount(allTexts[i + 1]) {
                    summary.totalProfitLoss = val
                }
            }

            // 有时数字就在同一行
            if let val = parseAmount(cleaned) {
                // 检查前面的文字来确定含义
                if i > 0 {
                    let prev = allTexts[i - 1]
                    if prev.contains("总资产") && summary.totalAssets == nil {
                        summary.totalAssets = val
                    } else if prev.contains("证券市值") && summary.marketValue == nil {
                        summary.marketValue = val
                    } else if prev.contains("可用") && summary.cashBalance == nil {
                        summary.cashBalance = val
                    }
                }
            }
        }

        return summary
    }

    // MARK: - 持仓解析（双行格式）

    /// 东方财富持仓双行格式：
    /// 行1：名称    持仓数    现价      盈亏金额
    /// 行2：市值    可用数    成本价    盈亏百分比
    private static func parseEastMoneyHoldings(from lines: [(String, CGRect, Float)]) -> [OCRHoldingResult] {
        // 按 y 坐标分组到行（Vision 坐标 y 从下到上）
        let sortedLines = lines.sorted { $0.1.midY > $1.1.midY }
        let rows = groupByRow(sortedLines, tolerance: 0.012)

        var results: [OCRHoldingResult] = []
        var i = 0

        while i < rows.count {
            let row = rows[i]
            let texts = row.map { $0.0 }
            let joined = texts.joined(separator: " ")

            // 找包含中文股票名称的行（持仓行的第一行）
            // 判断条件：包含中文 + 包含数字 + 不是表头/汇总行
            if containsStockName(joined) && !isHeaderOrSummary(joined) {
                let row1Numbers = extractNumbers(from: joined)
                let stockName = extractStockName(from: texts)

                // 尝试读取下一行（第二行：市值、可用、成本、盈亏%）
                var row2Numbers: [Double] = []
                if i + 1 < rows.count {
                    let nextRow = rows[i + 1]
                    let nextJoined = nextRow.map { $0.0 }.joined(separator: " ")
                    // 第二行通常全是数字，没有中文名称
                    if !containsStockName(nextJoined) || nextJoined.contains("%") {
                        row2Numbers = extractNumbers(from: nextJoined)
                        i += 1 // 跳过第二行
                    }
                }

                // 解析数字
                // 行1: [持仓数, 现价, 盈亏金额]（可能有更多）
                // 行2: [市值, 可用数, 成本价, 盈亏百分比]
                let shares = row1Numbers.first { $0 > 0 && $0 == $0.rounded() }.map { Int($0) } ?? 0
                let currentPrice = row1Numbers.count >= 2 ? row1Numbers[1] : nil

                let marketValue = row2Numbers.first
                let costPrice: Double = {
                    // 成本通常是第二行的第三个数（跳过市值和可用数）
                    if row2Numbers.count >= 3 {
                        return row2Numbers[2]
                    }
                    return 0
                }()

                let profitLoss = row1Numbers.last { $0 < 0 }
                let profitLossPercent = row2Numbers.last { abs($0) < 100 && $0 != costPrice }

                guard shares > 0, costPrice > 0, !stockName.isEmpty else {
                    i += 1
                    continue
                }

                let avgConfidence = Double(row.map { $0.2 }.reduce(0, +)) / Double(row.count)

                results.append(OCRHoldingResult(
                    stockName: stockName,
                    shares: shares,
                    costPrice: costPrice,
                    currentPrice: currentPrice,
                    marketValue: marketValue,
                    profitLoss: profitLoss,
                    profitLossPercent: profitLossPercent,
                    confidence: avgConfidence
                ))
            }

            i += 1
        }

        return results
    }

    // MARK: - 辅助方法

    /// 按 y 坐标将文字分组到同一行
    private static func groupByRow(_ lines: [(String, CGRect, Float)], tolerance: CGFloat) -> [[(String, CGRect, Float)]] {
        guard !lines.isEmpty else { return [] }

        var rows: [[(String, CGRect, Float)]] = []
        var currentRow: [(String, CGRect, Float)] = [lines[0]]
        var currentY = lines[0].1.midY

        for i in 1..<lines.count {
            let line = lines[i]
            if abs(line.1.midY - currentY) < tolerance {
                currentRow.append(line)
            } else {
                rows.append(currentRow.sorted { $0.1.minX < $1.1.minX })
                currentRow = [line]
                currentY = line.1.midY
            }
        }
        rows.append(currentRow.sorted { $0.1.minX < $1.1.minX })

        return rows
    }

    /// 判断是否包含股票名称（2-4个中文字符，非功能性词汇）
    private static func containsStockName(_ text: String) -> Bool {
        let ignoreKeywords = ["总资产", "证券市值", "持仓盈亏", "当日盈亏", "股票", "市值",
                              "持仓", "可用", "现价", "成本", "盈亏", "委托", "成交",
                              "买入", "卖出", "撤单", "银证", "首页", "社区", "自选",
                              "行情", "理财", "交易", "分时", "优优投顾", "打新专区",
                              "条件单", "国债", "账户分析", "港股通", "新三板", "天天宝",
                              "超级", "更多", "信用", "期权", "模拟", "期货", "普通"]
        // 包含中文且不是纯功能词
        let hasChinese = text.range(of: #"[\u4e00-\u9fff]{2,}"#, options: .regularExpression) != nil
        let isIgnored = ignoreKeywords.contains { text.contains($0) } && !text.contains("资源") && !text.contains("黄金") && !text.contains("发展")

        // 更好的判断：如果同时有中文名称和数字，大概率是持仓行
        let hasNumbers = text.range(of: #"\d{2,}"#, options: .regularExpression) != nil
        return hasChinese && hasNumbers && !isIgnored
    }

    /// 判断是否为表头或汇总行
    private static func isHeaderOrSummary(_ text: String) -> Bool {
        let headers = ["股票/市值", "持仓/可用", "现价/成本", "持仓盈亏"]
        return headers.contains { text.contains($0) }
    }

    /// 从文字中提取股票名称（第一个2-4字的中文词）
    private static func extractStockName(from texts: [String]) -> String {
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            // 纯中文，2-4个字
            if trimmed.range(of: #"^[\u4e00-\u9fff]{2,4}$"#, options: .regularExpression) != nil {
                return trimmed
            }
        }
        // fallback：第一个包含中文的片段
        for text in texts {
            if let match = text.range(of: #"[\u4e00-\u9fff]{2,4}"#, options: .regularExpression) {
                return String(text[match])
            }
        }
        return ""
    }

    /// 从文本中提取数字（含负数和小数）
    private static func extractNumbers(from text: String) -> [Double] {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        let pattern = #"-?\d+\.?\d*"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let matches = regex?.matches(in: cleaned, range: range) ?? []

        return matches.compactMap { match in
            guard let range = Range(match.range, in: cleaned) else { return nil }
            return Double(cleaned[range])
        }
    }

    /// 解析金额字符串（去逗号）
    private static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Double(cleaned)
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法读取图片"
        case .recognitionFailed: return "文字识别失败"
        }
    }
}
