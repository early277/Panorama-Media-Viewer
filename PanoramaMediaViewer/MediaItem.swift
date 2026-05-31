import AVFoundation
import Foundation
import UIKit

enum MediaKind: String, Codable {
    case photo
    case video

    var label: String {
        switch self {
        case .photo: return "写真"
        case .video: return "動画"
        }
    }
}

enum MediaLocation: Hashable {
    case file(URL)
}

struct MediaItem: Identifiable, Hashable {
    let id: String
    let kind: MediaKind
    let displayNameWithoutExtension: String
    let location: MediaLocation

    var displayTitle: String {
        "\(kind.label) \(displayNameWithoutExtension)"
    }
}

enum RenderContent {
    case image(UIImage)
    case player(AVPlayer)
}

enum MediaLoadError: LocalizedError {
    case imageDataUnavailable
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .imageDataUnavailable:
            return "画像データを取得できませんでした。"
        case .unsupportedFile:
            return "対応していないファイル形式です。"
        }
    }
}

extension MediaItem {
    func loadRenderContent() async throws -> RenderContent {
        switch location {
        case .file(let url):
            switch kind {
            case .photo:
                guard let image = UIImage(contentsOfFile: url.path) else {
                    throw MediaLoadError.imageDataUnavailable
                }
                return .image(image)
            case .video:
                return .player(AVPlayer(url: url))
            }
        }
    }
}
