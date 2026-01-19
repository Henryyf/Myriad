//
//  NewTripSheet.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI

struct NewTripSheet: View {

    var store: TravelStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDateEnabled: Bool = false
    @State private var endDate: Date = Date()
    @State private var status: TripStatus = .planned
    @State private var firstMemoryText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题（例如 Tokyo）", text: $title)
                    Picker("状态", selection: $status) {
                        ForEach(TripStatus.allCases, id: \.self) { s in
                            Text(s.title).tag(s)
                        }
                    }
                }

                Section("日期") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: [.date])

                    Toggle("设置结束日期", isOn: $endDateEnabled)

                    if endDateEnabled {
                        DatePicker("结束日期", selection: $endDate, displayedComponents: [.date])
                    }
                }

                Section("第一条记忆（可选）") {
                    TextField("写下一句话…", text: $firstMemoryText, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Button {
                        create()
                    } label: {
                        Text("创建")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("新增旅行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func create() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        store.addTrip(
            title: trimmedTitle,
            startDate: startDate,
            endDate: endDateEnabled ? endDate : nil,
            status: status,
            heroBackgroundAssetName: nil,
            firstMemoryText: firstMemoryText
        )
        dismiss()
    }
}
