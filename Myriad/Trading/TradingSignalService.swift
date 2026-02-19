//
//  TradingSignalService.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/18/26.
//

import Foundation

/// 从 Cloudflare Worker 获取七星高照策略信号
struct TradingSignalService {

    static let defaultBaseURL = "https://seven-star-worker.henryyv0522.workers.dev"
    static let defaultAPIKey = "myriad-seven-star-2026"

    enum ServiceError: LocalizedError {
        case invalidURL
        case httpError(Int)
        case noData
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的服务器地址"
            case .httpError(let code): return "服务器错误 (\(code))"
            case .noData: return "没有获取到数据"
            case .decodingFailed(let msg): return "数据解析失败: \(msg)"
            }
        }
    }

    /// 获取最新信号
    static func fetchLatestSignal(
        baseURL: String = defaultBaseURL,
        apiKey: String = defaultAPIKey,
        totalCapital: Double? = nil
    ) async throws -> StrategySignal {
        var urlString = "\(baseURL)/signal/latest"
        if let capital = totalCapital {
            urlString += "?capital=\(Int(capital))"
        }

        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.noData
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(StrategySignal.self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error.localizedDescription)
        }
    }

    /// 获取指定日期信号
    static func fetchSignal(
        for date: String,
        baseURL: String = defaultBaseURL,
        apiKey: String = defaultAPIKey,
        totalCapital: Double? = nil
    ) async throws -> StrategySignal {
        var urlString = "\(baseURL)/signal/\(date)"
        if let capital = totalCapital {
            urlString += "?capital=\(Int(capital))"
        }

        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.noData
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(StrategySignal.self, from: data)
        } catch {
            throw ServiceError.decodingFailed(error.localizedDescription)
        }
    }

    /// 检查服务器健康状态
    static func healthCheck(baseURL: String = defaultBaseURL) async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
