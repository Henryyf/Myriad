//
//  NewTripSheet.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI
import PhotosUI

struct NewTripSheet: View {

    var store: TravelStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDateEnabled: Bool = false
    @State private var endDate: Date = Date()
    @State private var selectedCountry: String? = nil
    @State private var firstMemoryText: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var heroImage: UIImage?
    
    // 可选国家列表（按字母顺序）
    private var availableCountries: [(code: String, name: String, flag: String)] {
        CountryInfoProvider.availableCountries
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题（例如 Tokyo）", text: $title)
                }
                
                Section("国家/地区") {
                    Picker("选择国家", selection: $selectedCountry) {
                        Text("未选择").tag(nil as String?)
                        ForEach(availableCountries, id: \.code) { country in
                            Text("\(country.name) \(country.flag)")
                                .tag(country.code as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedCountry != nil {
                        Text("将在地图上显示")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("选择国家后将在地图显示")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("照片（可选）") {
                    VStack(spacing: 12) {
                        if let image = heroImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: heroImage == nil ? "photo.badge.plus" : "photo")
                                    .foregroundStyle(.blue)
                                Text(heroImage == nil ? "添加照片" : "更换照片")
                                    .foregroundStyle(.blue)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        if heroImage != nil {
                            Button(role: .destructive) {
                                heroImage = nil
                                selectedPhoto = nil
                            } label: {
                                Text("移除照片")
                                    .frame(maxWidth: .infinity)
                            }
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
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        heroImage = image
                    }
                }
            }
        }
    }

    private func create() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let imageData = heroImage?.jpegData(compressionQuality: 0.8)

        store.addTrip(
            title: trimmedTitle,
            startDate: startDate,
            endDate: endDateEnabled ? endDate : nil,
            countryCode: selectedCountry,
            heroImageData: imageData,
            firstMemoryText: firstMemoryText
        )
        dismiss()
    }
}
