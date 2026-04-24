import Foundation
import Combine

@Observable
final class ReplayViewModel {
    var turns: [Turn] = []
    var currentTurnIndex: Int = 0
    var revealedBlockCount: Int = 0
    var isPlaying = false
    var speed: Double = 1.0
    var showThinking = true
    var showToolCalls = true
    var bookmarks: [Bookmark] = []
    var isLoading = false
    var errorMessage: String?

    private var playbackTask: Task<Void, Never>?

    static let speedSteps: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 20]

    var currentTurn: Turn? {
        guard currentTurnIndex > 0, currentTurnIndex <= turns.count else { return nil }
        return turns[currentTurnIndex - 1]
    }

    var progress: Double {
        guard !turns.isEmpty else { return 0 }
        return Double(currentTurnIndex) / Double(turns.count)
    }

    func loadSession(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let text = try String(contentsOf: path, encoding: .utf8)
            turns = TranscriptParser.parseTranscriptFromText(text)
            currentTurnIndex = 0
            revealedBlockCount = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        playbackTask?.cancel()
        isPlaying = true
        playbackTask = Task { @MainActor in
            while isPlaying && currentTurnIndex < turns.count {
                if currentTurnIndex == 0 { currentTurnIndex = 1; revealedBlockCount = 0 }
                let turn = turns[currentTurnIndex - 1]
                while revealedBlockCount < turn.blocks.count && isPlaying {
                    revealedBlockCount += 1
                    let delay = adaptiveDelay(for: turn, blockIndex: revealedBlockCount - 1)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                if isPlaying && currentTurnIndex < turns.count {
                    currentTurnIndex += 1
                    revealedBlockCount = 0
                    try? await Task.sleep(nanoseconds: UInt64(0.5 / speed * 1_000_000_000))
                }
            }
            isPlaying = false
        }
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
    }

    func stepForward() {
        pause()
        if currentTurnIndex == 0 { currentTurnIndex = 1; revealedBlockCount = 0; return }
        let turn = turns[currentTurnIndex - 1]
        if revealedBlockCount < turn.blocks.count {
            revealedBlockCount += 1
        } else if currentTurnIndex < turns.count {
            currentTurnIndex += 1
            revealedBlockCount = 0
        }
    }

    func stepBack() {
        pause()
        if revealedBlockCount > 0 { revealedBlockCount -= 1; return }
        if currentTurnIndex > 1 {
            currentTurnIndex -= 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        } else { currentTurnIndex = 0 }
    }

    func nextTurn() {
        pause()
        if currentTurnIndex < turns.count {
            currentTurnIndex += 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        }
    }

    func prevTurn() {
        pause()
        if currentTurnIndex > 1 {
            currentTurnIndex -= 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        } else { currentTurnIndex = 0; revealedBlockCount = 0 }
    }

    func seekToTurn(_ index: Int) {
        pause()
        currentTurnIndex = max(0, min(index, turns.count))
        if currentTurnIndex > 0 { revealedBlockCount = turns[currentTurnIndex - 1].blocks.count }
    }

    private func adaptiveDelay(for turn: Turn, blockIndex: Int) -> Double {
        let block = turn.blocks[blockIndex]
        let charCount: Double
        if block.kind == .toolUse, let tc = block.toolCall {
            // For tool calls, use result length if available, else serialized input length
            if let result = tc.result {
                charCount = Double(result.count)
            } else {
                let inputDesc = tc.input.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
                charCount = Double(inputDesc.count)
            }
        } else {
            charCount = Double(block.text.count)
        }
        let baseDelay = min(max(charCount * 0.03, 0.6), 10.0)
        return baseDelay / speed
    }

}
