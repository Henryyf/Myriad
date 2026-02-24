//
//  TradingSettingsView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/18/26.
//

import SwiftUI

struct TradingSettingsView: View {

    @Bindable var store: TradingStore

    @State private var strategyPercent: Double = 0.8
    @State private var freePlayPercent: Double = 0.0
    @State private var cashPercent: Double = 0.2

    @State private var isTesting = false
    @State private var testResult: String?

    init(store: TradingStore) {
        self.store = store
        let config = store.portfolio.strategyConfig
        _strategyPercent = State(initialValue: config.strategyPercent)
        _freePlayPercent = State(initialValue: config.freePlayPercent)
        _cashPercent = State(initialValue: config.cashPercent)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                allocationSection
                totalCapitalSection
                dataSourceSection
                strategyInfoSection
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

            allocationBar

            sliderRow(
                title: "策略仓",
                subtitle: "跟随七星高照策略",
                value: $strategyPercent,
                color: .blue
            )

            sliderRow(
                title: "自选仓",
                subtitle: "你自己选的股票",
                value: $freePlayPercent,
                color: .purple
            )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("现金仓")
                        .font(.subheadline.bold())
                    Text("自动计算 = 100% - 策略 - 自选")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(100 - Int(round(strategyPercent * 100)) - Int(round(freePlayPercent * 100)))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.gray)
            }

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
        // 四舍五入到 5% 步长，确保总和 = 1.0
        let s = (strategyPercent * 20).rounded() / 20  // round to nearest 0.05
        let f = (freePlayPercent * 20).rounded() / 20
        let c = max(0, 1.0 - s - f)
        let config = StrategyConfig(
            strategyPercent: s,
            freePlayPercent: f,
            cashPercent: c
        )
        store.updateStrategyConfig(config)
        // 同步回 UI
        strategyPercent = s
        freePlayPercent = f
        cashPercent = c
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

    // MARK: - 数据源

    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据源", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tushare Pro")
                        .font(.subheadline.bold())
                    Text("ETF 日线数据，本地计算策略信号")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button {
                Task { await testDataSource() }
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().controlSize(.mini)
                    }
                    Text("测试数据连接")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.gray.opacity(0.2))
                .clipShape(Capsule())
            }

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("✅") ? .green : .red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func testDataSource() async {
        isTesting = true
        testResult = nil
        do {
            let bars = try await TushareService.fetchETFDaily(
                tsCode: "518880.SH",
                startDate: "20260101",
                endDate: "20261231"
            )
            testResult = "✅ 连接成功，获取到 \(bars.count) 条黄金ETF日线数据"
        } catch {
            testResult = "❌ \(error.localizedDescription)"
        }
        isTesting = false
    }

    // MARK: - 策略信息

    private var strategyInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("七星高照策略", systemImage: "star.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                infoRow("ETF 池", "\(SevenStarConfig.etfPool.count) 只")
                infoRow("持仓数量", "\(SevenStarConfig.holdingsNum) 只")
                infoRow("动量周期", "\(SevenStarConfig.lookbackDays) 天")
                infoRow("止损线", "\(Int((1 - SevenStarConfig.stopLossRatio) * 100))%")
                infoRow("RSI 周期", "\(SevenStarConfig.rsiPeriod)")
                infoRow("防御品种", SevenStarConfig.defensiveETF.name)
            }

            Divider()

            Text("ETF 池")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(SevenStarConfig.etfPool, id: \.code) { etf in
                HStack {
                    Text(etf.name)
                        .font(.caption)
                    Spacer()
                    Text(etf.code)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}
