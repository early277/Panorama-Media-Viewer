import SwiftUI

struct ContentView: View {
    @StateObject private var library = MediaLibrary()
    @State private var showsFolderPicker = false
    @State private var selectedItem: MediaItem?

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 6, alignment: .leading)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                header

                if library.items.isEmpty {
                    emptyState
                } else {
                    mediaGrid
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .navigationTitle("360メディア")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedItem) { item in
                ViewerView(item: item)
            }
            .sheet(isPresented: $showsFolderPicker) {
                FolderPicker { url in
                    showsFolderPicker = false
                    library.loadFromFolder(url)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Button {
                showsFolderPicker = true
            } label: {
                Text("フォルダを選択")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(library.isLoading)

            Text(library.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "未読込",
            systemImage: "folder",
            description: Text("360度写真・360度動画を保存したフォルダを選択してください。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediaGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(library.items) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        Text(item.displayTitle)
                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .padding(.horizontal, 8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(item.displayTitle)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    ContentView()
}
