//
//  ScanImportSheet.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import SwiftUI
import PhotosUI

struct ScanImportSheet: View {

    @Bindable var store: TradingStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrResults: [OCRHoldingResult] = []
    @State private var ocrSummary: OCRPortfolioSummary?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var hasScanned = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 图片选择区
                    imagePickerSection

                    // 处理中
                    if isProcessing {
                        ProgressView("正在识别...")
                            .padding()
                    }

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }

                    // OCR 结果预览
                    if hasScanned {
                        resultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("扫描导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { confirmImport() }
                        .bold()
                        .disabled(ocrResults.isEmpty)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }
        }
    }

    // MARK: - 图片选择

    private var imagePickerSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("重新选择")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("选择东方财富持仓截图")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("从相册中选取")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }

    // MARK: - 识别结果

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 汇总信息
            if let summary = ocrSummary {
                summaryPreview(summary)
            }

            // 持仓列表
            if ocrResults.isEmpty {
                Text("未识别到持仓信息，请确认截图为东方财富持仓页面")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("识别到 \(ocrResults.count) 只持仓")
                    .font(.headline)

                ForEach(ocrResults) { result in
                    ocrResultRow(result)
                }
            }
        }
    }

    private func summaryPreview(_ summary: OCRPortfolioSummary) -> some View {
        VStack(spacing: 8) {
            HStack {
                if let assets = summary.totalAssets {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总资产").font(.caption).foregroundStyle(.secondary)
                        Text(formatNumber(assets)).font(.headline.monospacedDigit())
                    }
                }
                Spacer()
                if let cash = summary.cashBalance {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("可用").font(.caption).foregroundStyle(.secondary)
                        Text(formatNumber(cash)).font(.headline.monospacedDigit())
                    }
                }
            }
            if let pl = summary.totalProfitLoss {
                HStack {
                    Text("持仓盈亏").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(formatNumber(pl))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(pl >= 0 ? .red : .green)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ocrResultRow(_ result: OCRHoldingResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.stockName)
                    .font(.headline)
                Text("\(result.shares) 股")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("成本 \(String(format: "%.3f", result.costPrice))")
                    .font(.subheadline.monospacedDigit())
                if let price = result.currentPrice {
                    Text("现价 \(String(format: "%.3f", price))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // 置信度指示
            Circle()
                .fill(result.confidence > 0.8 ? Color.green : (result.confidence > 0.5 ? Color.orange : Color.red))
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Actions

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法加载图片"
                return
            }

            selectedImage = image
            errorMessage = nil

            // 自动开始 OCR
            await runOCR(on: image)
        } catch {
            errorMessage = "加载图片失败: \(error.localizedDescription)"
        }
    }

    private func runOCR(on image: UIImage) async {
        isProcessing = true
        hasScanned = false
        errorMessage = nil

        do {
            let (holdings, summary) = try await OCRService.recognizeHoldings(from: image)
            ocrResults = holdings
            ocrSummary = summary
            hasScanned = true
        } catch {
            errorMessage = "识别失败: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    private func confirmImport() {
        guard !ocrResults.isEmpty else { return }
        store.importFromOCR(results: ocrResults, summary: ocrSummary ?? OCRPortfolioSummary())
        dismiss()
    }

    private func formatNumber(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}
