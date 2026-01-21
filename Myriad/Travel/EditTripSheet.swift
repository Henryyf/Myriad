//
//  EditTripSheet.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI
import PhotosUI

struct EditTripSheet: View {
    
    var store: TravelStore
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var startDate: Date
    @State private var endDateEnabled: Bool
    @State private var endDate: Date
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var heroImage: UIImage?
    
    init(store: TravelStore, trip: Trip) {
        self.store = store
        self.trip = trip
        
        _title = State(initialValue: trip.title)
        _startDate = State(initialValue: trip.startDate)
        _endDateEnabled = State(initialValue: trip.endDate != nil)
        _endDate = State(initialValue: trip.endDate ?? Date())
        
        if let imageData = trip.heroImageData, let image = UIImage(data: imageData) {
            _heroImage = State(initialValue: image)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题（例如 Tokyo）", text: $title)
                }
                
                Section("照片") {
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
                
                Section {
                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("编辑旅行")
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
    
    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let imageData = heroImage?.jpegData(compressionQuality: 0.8)
        
        store.updateTrip(
            tripID: trip.id,
            title: trimmedTitle,
            startDate: startDate,
            endDate: endDateEnabled ? endDate : nil,
            heroImageData: imageData
        )
        dismiss()
    }
}
