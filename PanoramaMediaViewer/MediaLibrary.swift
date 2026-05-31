import Combine
import Foundation

@MainActor
final class MediaLibrary: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var statusMessage: String = "フォルダから読み込んでください。"
    @Published var isLoading: Bool = false

    private var securityScopedFolderURL: URL?

    deinit {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
    }

    func loadFromFolder(_ folderURL: URL) {
        isLoading = true
        defer { isLoading = false }

        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil

        let didStartAccessing = folderURL.startAccessingSecurityScopedResource()
        if didStartAccessing {
            securityScopedFolderURL = folderURL
        }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            let loadedItems: [MediaItem] = urls.compactMap { url in
                guard Self.isRegularFile(url) else { return nil }
                guard let kind = Self.detectKind(from: url) else { return nil }

                let displayName = Self.removingExtension(from: url.lastPathComponent)
                return MediaItem(
                    id: url.absoluteString,
                    kind: kind,
                    displayNameWithoutExtension: displayName,
                    location: .file(url)
                )
            }
            .sorted { lhs, rhs in
                let nameComparison = lhs.displayNameWithoutExtension.localizedStandardCompare(rhs.displayNameWithoutExtension)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                let kindComparison = lhs.kind.label.localizedStandardCompare(rhs.kind.label)
                if kindComparison != .orderedSame {
                    return kindComparison == .orderedAscending
                }

                return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }

            items = loadedItems
            statusMessage = loadedItems.isEmpty ? "対応する写真・動画が見つかりませんでした。" : "\(loadedItems.count)件を読み込みました。"
        } catch {
            items = []
            statusMessage = "フォルダを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private static func detectKind(from url: URL) -> MediaKind? {
        let ext = url.pathExtension.lowercased()
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

        if imageExtensions.contains(ext) { return .photo }
        if videoExtensions.contains(ext) { return .video }
        return nil
    }

    private static func removingExtension(from filename: String) -> String {
        (filename as NSString).deletingPathExtension
    }
}
