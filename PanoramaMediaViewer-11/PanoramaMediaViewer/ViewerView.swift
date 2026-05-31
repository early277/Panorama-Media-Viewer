import AVFoundation
import SwiftUI

struct ViewerView: View {
    let item: MediaItem

    @Environment(\.dismiss) private var dismiss

    @State private var renderContent: RenderContent?
    @State private var errorMessage: String?
    @State private var isPlaying = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Group {
                    if let renderContent {
                        EquirectangularSceneView(content: renderContent)
                            .ignoresSafeArea()
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "読み込み失敗",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .ignoresSafeArea()
                    } else {
                        ProgressView("読み込み中")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .ignoresSafeArea()
                    }
                }

                if case .player(let player) = renderContent {
                    VideoControlsView(player: player, isPlaying: $isPlaying)
                        .padding(.horizontal, 8)
                        .padding(.bottom, bottomControlPadding(safeAreaBottom: proxy.safeAreaInsets.bottom))
                }

                ViewerBackButton {
                    dismiss()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: item.id) {
            await load()
        }
        .onDisappear {
            if case .player(let player) = renderContent {
                player.pause()
            }
        }
    }

    private func bottomControlPadding(safeAreaBottom: CGFloat) -> CGFloat {
        if safeAreaBottom > 0 {
            return safeAreaBottom + 12
        }
        return 18
    }

    private func load() async {
        do {
            renderContent = try await item.loadRenderContent()
            if case .player(let player) = renderContent {
                player.play()
                isPlaying = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ViewerBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.leading, 10)
        .accessibilityLabel("戻る")
    }
}

private struct VideoControlsView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "一時停止" : "再生")

            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        currentTime = newValue
                        seek(to: newValue, precise: false)
                    }
                ),
                in: 0...max(duration, 0.01),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if editing {
                        player.pause()
                    } else {
                        seek(to: currentTime, precise: true)
                        if isPlaying {
                            player.play()
                        }
                    }
                }
            )
            .disabled(duration <= 0)

            Text("\(formatTime(currentTime))/\(formatTime(duration))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .frame(maxWidth: .infinity)
        .onAppear {
            setupTimeObserver()
        }
        .onDisappear {
            removeTimeObserver()
        }
    }

    private func setupTimeObserver() {
        removeTimeObserver()

        updateDurationIfPossible()

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            updateDurationIfPossible()
            guard !isSeeking else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                currentTime = seconds
            }
            if player.timeControlStatus == .playing {
                isPlaying = true
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func updateDurationIfPossible() {
        guard let item = player.currentItem else { return }
        let seconds = item.duration.seconds
        if seconds.isFinite, seconds > 0 {
            duration = seconds
        }
    }

    private func seek(to seconds: Double, precise: Bool) {
        guard seconds.isFinite else { return }
        let target = CMTime(seconds: seconds, preferredTimescale: 600)

        if precise {
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            let tolerance = CMTime(seconds: 0.04, preferredTimescale: 600)
            player.seek(to: target, toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let remainingSeconds = total % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
