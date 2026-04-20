//
//  CategoryManagementView.swift
//  FitNotes iOS
//
//  Category management (product_roadmap.md 1.20).
//  View, add, edit, reorder, and delete categories.
//  Built-in categories (8 defaults) cannot be deleted.
//

import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @Environment(\.modelContext) private var context

    @State private var showAddCategory = false
    @State private var editingCategory: WorkoutCategory?

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    HStack {
                        Circle()
                            .fill(category.color)
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Text("\(category.exercises.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if category.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onMove { source, destination in
                var sorted = categories.sorted { $0.sortOrder < $1.sortOrder }
                sorted.move(fromOffsets: source, toOffset: destination)
                for (index, cat) in sorted.enumerated() {
                    cat.sortOrder = index
                }
                try? context.save()
            }
            .onDelete { offsets in
                for index in offsets {
                    let cat = categories[index]
                    guard !cat.isBuiltIn else { continue }
                    context.delete(cat)
                }
                try? context.save()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryEditSheet(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditSheet(category: category)
        }
    }
}

// MARK: - Category Edit Sheet

struct CategoryEditSheet: View {
    var category: WorkoutCategory?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColor = Color.blue

    private var isNew: Bool { category == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                }

                Section("Color") {
                    ColorPicker("Category Color", selection: $selectedColor)
                }

                if let category, !category.isBuiltIn {
                    Section {
                        Button(role: .destructive) {
                            context.delete(category)
                            try? context.save()
                            dismiss()
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                        }
                    } footer: {
                        Text("Deleting a category will remove the category assignment from all its exercises. The exercises themselves will not be deleted.")
                    }
                }
            }
            .navigationTitle(isNew ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    selectedColor = category.color
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Convert Color to ARGB Int32 (approximate)
        let argb = colorToARGB(selectedColor)

        if let category {
            category.name = trimmed
            category.colourARGB = argb
        } else {
            let maxSort = (try? context.fetch(FetchDescriptor<WorkoutCategory>()))?.map(\.sortOrder).max() ?? -1
            let newCat = WorkoutCategory(
                name: trimmed,
                colourARGB: argb,
                sortOrder: maxSort + 1,
                isBuiltIn: false
            )
            context.insert(newCat)
        }
        try? context.save()
    }

    private func colorToARGB(_ color: Color) -> Int32 {
        let resolved = color.resolve(in: EnvironmentValues())
        let a = UInt32(resolved.opacity * 255) & 0xFF
        let r = UInt32(resolved.red * 255) & 0xFF
        let g = UInt32(resolved.green * 255) & 0xFF
        let b = UInt32(resolved.blue * 255) & 0xFF
        let unsigned = (a << 24) | (r << 16) | (g << 8) | b
        return Int32(bitPattern: unsigned)
    }
}
