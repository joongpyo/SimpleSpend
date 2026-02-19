//
//  ContentView.swift
//  SimpleSpend
//
//  Created by JP on 2/18/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import Foundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)]) private var expenses: [Expense]

    @State private var isPresentingAddSheet = false
    @State private var filterText: String = ""
    @State private var didSaveToggle: Bool = false
    
    @State private var selectedMonth: Date = Date()
    @State private var selectedCategory: String? = nil

    @State private var imageStore: [PersistentIdentifier: UIImage] = [:]
    @State private var isShowingImageViewer: Bool = false

    @AppStorage("userCategories") private var categoriesJSON: String = ""
    @State private var isManagingCategories: Bool = false

    private var categories: [String] {
        get {
            if let data = categoriesJSON.data(using: .utf8),
               let arr = try? JSONDecoder().decode([String].self, from: data),
               !arr.isEmpty {
                return arr
            }
            return ["식비", "카페/간식", "교통", "쇼핑", "주거/관리", "문화/여가", "여행", "교육", "의료/건강", "기타"]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                categoriesJSON = str
            }
        }
    }
    
    private let recentMonths: [Date] = {
        var arr: [Date] = []
        let cal = Calendar.current
        let now = Date()
        for i in 0..<12 {
            if let d = cal.date(byAdding: .month, value: -i, to: now) {
                arr.append(d)
            }
        }
        return arr
    }()

    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    var filteredExpenses: [Expense] {
        var list = expenses
        // Month filter
        list = list.filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        // Category filter
        if let selectedCategory, !selectedCategory.isEmpty {
            list = list.filter { $0.category == selectedCategory }
        }
        // Text filter
        let trimmed = filterText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !trimmed.isEmpty {
            list = list.filter { exp in
                exp.title.localizedCaseInsensitiveContains(trimmed) ||
                exp.category.localizedCaseInsensitiveContains(trimmed)
            }
        }
        return list
    }

    var body: some View {
        NavigationSplitView {
            // Updated header and list view
            VStack(spacing: 0) {
                // Summary header card
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            LinearGradient(colors: [Color.cyan.opacity(0.35), Color.indigo.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .blendMode(.softLight)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.white.opacity(0.10))
                        )
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("이달 지출", systemImage: "wallet.pass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(totalAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .contentTransition(.numericText(value: totalAmount))
                                .animation(.bouncy(duration: 0.6), value: totalAmount)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.cyan.opacity(0.25), Color.indigo.opacity(0.10)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 56, height: 56)
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(22)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Compact filter bar
                HStack(spacing: 10) {
                    // Month picker (last 12 months)
                    Menu {
                        ForEach(recentMonths, id: \.self) { m in
                            Button {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { selectedMonth = m }
                            } label: {
                                HStack {
                                    Text(m, format: .dateTime.year().month(.wide))
                                    if Calendar.current.isDate(m, equalTo: selectedMonth, toGranularity: .month) { Image(systemName: "checkmark") }
                                }
                            }
                        }
                        Divider()
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { selectedMonth = Date() }
                        } label: {
                            Label("이번 달", systemImage: "sparkles")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(selectedMonth, format: .dateTime.year().month(.abbreviated))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)

                    // Category picker
                    Menu {
                        Button {
                            withAnimation(.bouncy) { selectedCategory = nil }
                        } label: {
                            HStack {
                                Text("전체")
                                if selectedCategory == nil { Image(systemName: "checkmark") }
                            }
                        }
                        Divider()
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                withAnimation(.bouncy) { selectedCategory = cat }
                            } label: {
                                HStack {
                                    Text(cat)
                                    if selectedCategory == cat { Image(systemName: "checkmark") }
                                }
                            }
                        }
                        Divider()
                        Button {
                            isManagingCategories = true
                        } label: {
                            Label("카테고리 관리…", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedCategory ?? "전체")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // List of expenses
                List {
                    ForEach(filteredExpenses) { expense in
                        let hasImage = imageStore[expense.persistentModelID] != nil
                        Button {
                            selectedExpense = expense
                        } label: {
                            ExpenseRow(expense: expense, categoryColor: colorForCategory(expense.category), hasImage: hasImage)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteExpenses)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(.bouncy(duration: 0.5, extraBounce: 0.03), value: filteredExpenses.count)
                .animation(.bouncy(duration: 0.5, extraBounce: 0.03), value: selectedMonth)
                .animation(.bouncy(duration: 0.5, extraBounce: 0.03), value: selectedCategory)
                .padding(.top, 8)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(
                                Circle()
                                    .fill(LinearGradient(colors: [Color.cyan, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 16, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresentingAddSheet)
                }
            }
            .navigationTitle("가계부")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $filterText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "제목/카테고리 검색")
            .tint(Color.indigo)
            .sensoryFeedback(.success, trigger: didSaveToggle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isManagingCategories = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("카테고리")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
        } detail: {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.green)
                            Text(expenseAmountFormatted)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                Section("정보") {
                    TextField("제목", text: Binding(get: { selectedExpense?.title ?? "" }, set: { selectedExpense?.title = $0 }))
                    TextField("카테고리", text: Binding(get: { selectedExpense?.category ?? "" }, set: { selectedExpense?.category = $0 }))
                    DatePicker("날짜", selection: Binding(get: { selectedExpense?.date ?? Date() }, set: { selectedExpense?.date = $0 }), displayedComponents: .date)
                }
                Section("첨부 이미지") {
                    if let exp = selectedExpense, let img = imageStore[exp.persistentModelID] {
                        HStack(spacing: 12) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.2)))
                                .onTapGesture { isShowingImageViewer = true }
                            Button("전체 보기") { isShowingImageViewer = true }
                            Spacer()
                        }
                    } else {
                        Text("첨부된 이미지가 없습니다")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("상세")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("작업") {
                        Button(role: .destructive) {
                            if let expense = selectedExpense {
                                deleteExpense(expense)
                            }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05),
                    Color.indigo.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $isPresentingAddSheet) {
            AddExpenseSheet(categories: categories) { title, amount, category, date, image in
                addExpense(title: title, amount: amount, category: category, date: date, image: image)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isManagingCategories) {
            ManageCategoriesSheet(initialCategories: categories) { newList in
                var trimmed = newList.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                trimmed = trimmed.filter { !$0.isEmpty }
                // de-duplicate while preserving order
                var seen = Set<String>()
                let deduped = trimmed.filter { seen.insert($0).inserted }
                if let data = try? JSONEncoder().encode(deduped),
                   let str = String(data: data, encoding: .utf8) {
                    categoriesJSON = str
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingImageViewer) {
            if let exp = selectedExpense, let img = imageStore[exp.persistentModelID] {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack {
                        Spacer()
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding()
                        Spacer()
                        Button {
                            isShowingImageViewer = false
                        } label: {
                            Label("닫기", systemImage: "xmark.circle.fill")
                                .font(.title3)
                                .padding(12)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 24)
                    }
                }
            } else {
                Color.black.ignoresSafeArea().overlay(
                    Button("닫기") { isShowingImageViewer = false }
                        .padding()
                )
            }
        }
    }

    @State private var selectedExpense: Expense?

    private var expenseAmountFormatted: String {
        guard let expense = selectedExpense else { return "" }
        return expense.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private func addExpense(title: String, amount: Double, category: String, date: Date, image: UIImage?) {
        withAnimation {
            let newExpense = Expense(title: title, amount: amount, category: category, date: date)
            modelContext.insert(newExpense)
            if let image {
                imageStore[newExpense.persistentModelID] = image
            }
            filterText = ""
            didSaveToggle.toggle()
        }
    }

    private func deleteExpenses(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(filteredExpenses[index]) }
        }
    }

    private func deleteExpense(_ expense: Expense) {
        withAnimation { modelContext.delete(expense) }
    }

    // Color helper for category pill
    private func colorForCategory(_ name: String) -> Color {
        // Map hash to a cool hue range (190°–280°) for a consistent, modern palette
        let hue = (190.0 + Double(abs(name.hashValue) % 90)) / 360.0
        return Color(hue: hue, saturation: 0.60, brightness: 0.90)
    }

    // Expense Row View
    struct ExpenseRow: View {
        let expense: Expense
        let categoryColor: Color
        let hasImage: Bool
        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(categoryColor.opacity(0.16))
                    Image(systemName: "creditcard.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(categoryColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(expense.title)
                        .font(.system(.headline, design: .rounded))
                    HStack(spacing: 8) {
                        Text(expense.category)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(categoryColor)
                        Text(expense.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if hasImage {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.system(.headline, design: .rounded))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.06))
                    )
            )
            .contentShape(Rectangle())
            .hoverEffect(.lift)
            .scaleEffect(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: UUID())
        }
    }
}

// MARK: - Add Sheet
struct AddExpenseSheet: View {
    var categories: [String]
    var onSave: (String, Double, String, Date, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var category: String = "기타"
    @State private var date: Date = Date()

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var isShowingCamera: Bool = false

    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)
                    TextField("금액", text: $amountText)
                        .keyboardType(.decimalPad)
                    Menu {
                        ForEach(categories, id: \.self) { cat in
                            Button(cat) { category = cat }
                        }
                    } label: {
                        Label("카테고리 선택", systemImage: "square.grid.2x2")
                    }
                    TextField("카테고리", text: $category)
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                }
                Section("영수증/사진") {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("사진 보관함")
                            }
                            .padding(8)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                // Data.self로 불러온 뒤 UIImage로 변환합니다.
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        await MainActor.run {
                                            pickedImage = uiImage
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            isShowingCamera = true
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                Text("카메라")
                            }
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $isShowingCamera) {
                            ImagePicker(sourceType: .camera) { image in
                                pickedImage = image
                                isShowingCamera = false
                            }
                        }
                    }

                    if let preview = pickedImage {
                        HStack(spacing: 12) {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.2)))
                            Text("선택된 이미지")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("지출 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard !title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty, amount > 0 else { return }
                        onSave(title, amount, category, date, pickedImage)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty || amount <= 0)
                }
            }
        }
    }

    struct ImagePicker: UIViewControllerRepresentable {
        enum Source { case camera, library }
        var sourceType: UIImagePickerController.SourceType = .photoLibrary
        var onPick: (UIImage?) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

        final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let onPick: (UIImage?) -> Void
            init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                let image = info[.originalImage] as? UIImage
                onPick(image)
                picker.dismiss(animated: true)
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                onPick(nil)
                picker.dismiss(animated: true)
            }
        }
    }
}

struct ManageCategoriesSheet: View {
    var initialCategories: [String]
    var onSave: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [String] = []
    @State private var newCategory: String = ""

    init(initialCategories: [String], onSave: @escaping ([String]) -> Void) {
        self.initialCategories = initialCategories
        self.onSave = onSave
        _items = State(initialValue: initialCategories)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("카테고리") {
                    ForEach(items.indices, id: \.self) { idx in
                        TextField("이름", text: Binding(
                            get: { items[idx] },
                            set: { items[idx] = $0 }
                        ))
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("새 카테고리 추가", text: $newCategory)
                        Button {
                            let trimmed = newCategory.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            items.append(trimmed)
                            newCategory = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("카테고리 관리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(items)
                        dismiss()
                    }
                }
            }
        }
    }
}

