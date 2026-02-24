//
//  TradingSignalService.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/18/26.
//
//  Tushare HTTP API 数据服务 — 直接从 Tushare Pro 拉取 ETF 日线数据
//  替代原 Cloudflare Worker 方案，全部本地计算

import Foundation

// MARK: - Tushare 数据服务

struct TushareService {

    static let apiURL = "https://api.tushare.pro"
    static let token = "d79cc75c4a7a2b8b8694f75618d572ac37690656491e16f2dfadb697"

    enum ServiceError: LocalizedError {
        case requestFailed(String)
        case noData
        case decodingFailed(String)
        case apiError(Int, String)

        var errorDescription: String? {
            switch self {
            case .requestFailed(let msg): return "请求失败: \(msg)"
            case .noData: return "没有获取到数据"
            case .decodingFailed(let msg): return "数据解析失败: \(msg)"
            case .apiError(let code, let msg): return "Tushare 错误 (\(code)): \(msg)"
            }
        }
    }

    // MARK: - Tushare API 通用调用

    /// Tushare API 响应结构
    private struct TushareResponse: Decodable {
        let code: Int
        let msg: String?
        let data: TushareData?
    }

    private struct TushareData: Decodable {
        let fields: [String]
        let items: [[AnyCodable]]?
    }

    /// 通用 Tushare API 调用
    private static func callAPI(
        apiName: String,
        params: [String: String],
        fields: String = ""
    ) async throws -> (fields: [String], items: [[AnyCodable]]) {
        guard let url = URL(string: apiURL) else {
            throw ServiceError.requestFailed("Invalid URL")
        }

        let body: [String: Any] = [
            "api_name": apiName,
            "token": token,
            "params": params,
            "fields": fields
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        let response = try decoder.decode(TushareResponse.self, from: data)

        guard response.code == 0 else {
            throw ServiceError.apiError(response.code, response.msg ?? "未知错误")
        }

        guard let respData = response.data, let items = respData.items, !items.isEmpty else {
            throw ServiceError.noData
        }

        return (respData.fields, items)
    }

    // MARK: - ETF 日线数据

    /// 单条 ETF 日线记录
    struct ETFDailyBar {
        let tsCode: String
        let tradeDate: String   // "YYYYMMDD"
        let open: Double
        let high: Double
        let low: Double
        let close: Double
        let vol: Double         // 成交量（手）
        let amount: Double      // 成交额（千元）
    }

    /// 获取 ETF 日线数据
    /// - Parameters:
    ///   - tsCode: Tushare 格式代码，如 "518880.SH"
    ///   - startDate: 起始日期 "YYYYMMDD"
    ///   - endDate: 结束日期 "YYYYMMDD"
    /// - Returns: 按日期升序排列的日线数组
    static func fetchETFDaily(
        tsCode: String,
        startDate: String,
        endDate: String
    ) async throws -> [ETFDailyBar] {
        let (fields, items) = try await callAPI(
            apiName: "fund_daily",
            params: [
                "ts_code": tsCode,
                "start_date": startDate,
                "end_date": endDate
            ],
            fields: "ts_code,trade_date,open,high,low,close,vol,amount"
        )

        let fieldIndex = Dictionary(uniqueKeysWithValues: fields.enumerated().map { ($1, $0) })

        let bars: [ETFDailyBar] = items.compactMap { row in
            guard
                let codeIdx = fieldIndex["ts_code"],
                let dateIdx = fieldIndex["trade_date"],
                let openIdx = fieldIndex["open"],
                let highIdx = fieldIndex["high"],
                let lowIdx = fieldIndex["low"],
                let closeIdx = fieldIndex["close"],
                let volIdx = fieldIndex["vol"],
                let amountIdx = fieldIndex["amount"]
            else { return nil }

            return ETFDailyBar(
                tsCode: row[codeIdx].stringValue ?? tsCode,
                tradeDate: row[dateIdx].stringValue ?? "",
                open: row[openIdx].doubleValue ?? 0,
                high: row[highIdx].doubleValue ?? 0,
                low: row[lowIdx].doubleValue ?? 0,
                close: row[closeIdx].doubleValue ?? 0,
                vol: row[volIdx].doubleValue ?? 0,
                amount: row[amountIdx].doubleValue ?? 0
            )
        }

        // Tushare 返回倒序，转为升序
        return bars.sorted { $0.tradeDate < $1.tradeDate }
    }

    /// 批量获取多只 ETF 的日线数据
    static func fetchMultipleETFDaily(
        tsCodes: [String],
        startDate: String,
        endDate: String
    ) async -> [String: [ETFDailyBar]] {
        var result: [String: [ETFDailyBar]] = [:]
        // 串行调用避免触发频率限制
        for code in tsCodes {
            do {
                let bars = try await fetchETFDaily(tsCode: code, startDate: startDate, endDate: endDate)
                result[code] = bars
            } catch {
                print("[TushareService] \(code) 数据获取失败: \(error.localizedDescription)")
                result[code] = []
            }
            // Tushare 限频：每分钟约 200 次，稍微间隔一下
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        return result
    }
}

// MARK: - AnyCodable（处理 Tushare 混合类型 JSON 数组）

struct AnyCodable: Decodable {
    let value: Any?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let v = try? container.decode(Double.self) {
            value = v
        } else if let v = try? container.decode(Int.self) {
            value = v
        } else if let v = try? container.decode(String.self) {
            value = v
        } else if let v = try? container.decode(Bool.self) {
            value = v
        } else {
            value = nil
        }
    }

    var stringValue: String? {
        value as? String
    }

    var doubleValue: Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    var intValue: Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        return nil
    }
}
