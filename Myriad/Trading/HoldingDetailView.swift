//
//  HoldingDetailView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/24/26.
//  持仓详情页
//

import SwiftUI

struct HoldingDetailView: View {

    let holding: Holding
    let classified: ClassifiedHolding?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. 持仓概览
                overviewCard

                // 2. 持仓详情
                detailCard

                // 4. 操作建议
                if let action = classified?.action, action != .match, action != .hold {
                    actionCard(action)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(holding.stockName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 持仓概览

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.stockName)
                        .font(.title2.bold())

                    if let cat = classified?.category {
                        Text(cat.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if let action = classified?.action {
                    HoldingActionTag(action: action)
                }
            }

            Divider()

            // 关键数据
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statItem(label: "持仓股数", value: "\(holding.shares)")
                statItem(label: "成本价", value: "¥\(String(format: "%.3f", holding.costPrice))")
                statItem(label: "市值", value: "¥\(formatCompact(holding.displayMarketValue))")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 持仓详情

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持仓信息")
                .font(.subheadline.bold())

            detailRow(label: "持仓股数", value: "\(holding.shares) 股")
            detailRow(label: "成本价", value: "¥\(String(format: "%.3f", holding.costPrice))")
            detailRow(label: "总成本", value: "¥\(formatCompact(holding.totalCost))")

            if let cp = holding.currentPrice {
                detailRow(label: "现价", value: "¥\(String(format: "%.3f", cp))")

                let pnl = (cp - holding.costPrice) / holding.costPrice * 100
                detailRow(label: "盈亏", value: String(format: "%+.2f%%", pnl),
                          valueColor: pnl >= 0 ? .stockUp : .stockDown)
            }

            if let mv = holding.marketValue {
                detailRow(label: "市值", value: "¥\(formatCompact(mv))")
            }

            if let cat = classified {
                if cat.strategyShares > 0 {
                    detailRow(label: "策略仓份额", value: "\(cat.strategyShares) 股")
                }
                if cat.freePlayShares > 0 {
                    detailRow(label: "自选仓份额", value: "\(cat.freePlayShares) 股")
                }
            }

            detailRow(label: "录入时间", value: holding.addedAt.formatted(date: .abbreviated, time: .omitted))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - 操作建议

    private func actionCard(_ action: HoldingAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: actionIcon(action))
                .font(.title3)
                .foregroundStyle(action.displayColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("操作建议")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(actionDescription(action))
                    .font(.subheadline.bold())
                    .foregroundStyle(action.displayColor)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(action.displayColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func actionIcon(_ action: HoldingAction) -> String {
        switch action {
        case .buy: return "arrow.up.circle.fill"
        case .sell: return "arrow.down.circle.fill"
        case .add: return "plus.circle.fill"
        case .reduce: return "minus.circle.fill"
        case .adjust: return "arrow.triangle.2.circlepath"
        default: return "checkmark.circle"
        }
    }

    private func actionDescription(_ action: HoldingAction) -> String {
        switch action {
        case .buy: return "建议买入"
        case .sell: return "建议卖出"
        case .add: return "建议加仓"
        case .reduce: return "建议减仓"
        case .adjust: return "建议调仓"
        default: return "继续持有"
        }
    }

    // MARK: - Helpers

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "%.2f万", value / 10_000)
        }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}
