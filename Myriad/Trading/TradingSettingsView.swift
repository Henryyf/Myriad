//
//  TradingSettingsView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/18/26.
//

import SwiftUI

struct TradingSettingsView: View {

    var store: TradingStore

    @State private var strategyPercent: Double = 0.8
    @State private var freePlayPercent: Double = 0.0
    @State private var cashPercent: Double = 0.2

    @State private var workerURL: String = ""
    @State private var apiKey: String = ""

    @State private var isCheckingHealth = false
    @State private var healthStatus: Bool?

    init(store: TradingStore) {
        self.store = store
        let config = store.portfolio.strategyConfig
        _strategyPercent = State(initialValue: config.strategyPercent)
        _freePlayPercent = State(initialValue: config.freePlayPercent)
        _cashPercent = State(initialValue: config.cashPercent)
        _workerURL = State(initialValue: UserDefaults.standard.string(forKey: "trading_worker_url") ?? TradingSignalService.defaultBaseURL)
        _apiKey = State(initialValue: UserDefaults.standard.string(forKey: "trading_api_key") ?? TradingSignalService.defaultAPIKey)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                allocationSection
                totalCapitalSection
                serverSection
            }
            .padding()
        }
        .navigationTitle("策略设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 仓位分配

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("仓位分配", systemImage: "chart.pie.fill")
                .font(.headline)

            // 可视化饼图条
            allocationBar

            // 策略仓滑块
            sliderRow(
                title: "📊 策略仓",
                subtitle: "跟随七星高照策略",
                value: $strategyPercent,
                color: .blue
            )

            // 自选仓滑块
            sliderRow(
                title: "🎮 自选仓",
                subtitle: "你自己选的股票",
                value: $freePlayPercent,
                color: .purple
            )

            // 现金仓（自动计算）
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("💵 现金仓")
                        .font(.subheadline.bold())
                    Text("自动计算 = 100% - 策略 - 自选")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(cashPercent * 100))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.gray)
            }

            // 警告提示
            if strategyPercent < StrategyConfig.minStrategyPercent {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("建议策略仓不低于 50%，让纪律帮你赚钱")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                saveAllocation()
            } label: {
                Text("保存分配")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var allocationBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                if strategyPercent > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * strategyPercent)
                }
                if freePlayPercent > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * freePlayPercent)
                }
                if cashPercent > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: geo.size.width * cashPercent)
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sliderRow(title: String, subtitle: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            Slider(value: value, in: 0...1, step: 0.05) { _ in
                balanceSliders(changed: title)
            }
            .tint(color)
        }
    }

    /// 滑块联动：调一个，现金自动调整；如果超出则截断
    private func balanceSliders(changed: String) {
        let total = strategyPercent + freePlayPercent
        if total > 1.0 {
            if changed.contains("策略") {
                freePlayPercent = max(0, 1.0 - strategyPercent)
            } else {
                strategyPercent = max(0, 1.0 - freePlayPercent)
            }
        }
        cashPercent = max(0, 1.0 - strategyPercent - freePlayPercent)
    }

    private func saveAllocation() {
        let config = StrategyConfig(
            strategyPercent: strategyPercent,
            freePlayPercent: freePlayPercent,
            cashPercent: cashPercent
        )
        store.updateStrategyConfig(config)
    }

    // MARK: - 总资金设置

    private var totalCapitalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("资金设置", systemImage: "yensign.circle.fill")
                .font(.headline)

            HStack {
                Text("总资产")
                    .font(.subheadline)
                Spacer()
                Text("¥\(formatNumber(store.portfolio.totalCapital))")
                    .font(.headline.monospacedDigit())
            }

            Text("总资产通过 OCR 扫描自动更新，也可在持仓页手动调整")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 服务器配置

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("信号服务器", systemImage: "server.rack")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Worker URL")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("https://...", text: $workerURL)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                SecureField("API Key", text: $apiKey)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button {
                    saveServerConfig()
                } label: {
                    Text("保存")
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button {
                    Task { await checkHealth() }
                } label: {
                    HStack(spacing: 4) {
                        if isCheckingHealth {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text("测试连接")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.gray.opacity(0.2))
                    .clipShape(Capsule())
                }

                if let status = healthStatus {
                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(status ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func saveServerConfig() {
        UserDefaults.standard.set(workerURL, forKey: "trading_worker_url")
        UserDefaults.standard.set(apiKey, forKey: "trading_api_key")
    }

    private func checkHealth() async {
        isCheckingHealth = true
        healthStatus = nil
        healthStatus = await TradingSignalService.healthCheck(baseURL: workerURL)
        isCheckingHealth = false
    }

    private func formatNumber(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}
