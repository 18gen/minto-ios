import SwiftUI
import SwiftData
import UIKit

struct NotepadBottomBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    @Binding var currentPage: NotePage

    @State private var coordinator = iOSRecordingCoordinator.shared
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    @State private var askText = ""
    @State private var askAnswer = ""
    @State private var askError: String?
    @State private var isAsking = false
    @State private var showAskSheet = false

    @FocusState private var askFocused: Bool

    private let claudeService = ClaudeService.shared

    private var receipts: [Receipt] {
        [
            .init(title: "Write follow up email", prompt: "Write a follow up email based on these notes.", style: .blue),
            .init(title: "List my todos", prompt: "List all action items and todos.", style: .green),
            .init(title: "Make notes longer", prompt: "Rewrite notes to be more detailed and structured.", style: .cyan),
        ]
    }

    var body: some View {
        VStack(spacing: 10) {
            if let error = coordinator.recordingError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            VStack(spacing: 10) {
                if askFocused {
                    receiptsRow
                        .transition(
                            .asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .push(from: .top).combined(with: .opacity)
                            )
                        )
                }

                HStack(spacing: 10) {
                    AskBar(
                        text: $askText,
                        isAsking: $isAsking,
                        focus: $askFocused,
                        placeholder: "Ask anything",
                        onSend: { Task { await askQuestion() } }
                    )

                    if !askFocused {
                        recordingCapsule
                    }
                }
            }
            .glassSurface(cornerRadius: AppTheme.barCorner, padding: 12)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.barCorner, style: .continuous)
                    .strokeBorder(
                        askFocused ? AppTheme.primary : Color.clear,
                        lineWidth: askFocused ? 1.5 : 0
                    )
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocused)
        }
        .sheet(isPresented: $showAskSheet) {
            askSheetContent
        }
    }

    // MARK: - Receipts Row

    private var receiptsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(receipts.prefix(3)) { r in
                    ReceiptPill(receipt: r) {
                        applyReceipt(r)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        }
    }

    private func applyReceipt(_ r: Receipt) {
        askText = r.prompt
        askFocused = true
    }

    // MARK: - Left Recording Capsule

    private var recordingCapsule: some View {
        HStack(spacing: 10) {

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentPage = currentPage == .notes ? .transcript : .notes
                }
            } label: {
                Image(systemName: currentPage == .notes ? "chevron.right" : "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }

            Button {
                haptic.impactOccurred()
                Task {
                    if coordinator.isRecording {
                        await coordinator.stopRecording()
                    } else {
                        await coordinator.startRecording(meeting: meeting, modelContext: modelContext)
                    }
                }
            } label: {
                Text(coordinator.isRecording ? "Pause" : "Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(coordinator.isRecording ? AppTheme.primary : AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1).blendMode(.overlay))
    }

    // MARK: - Ask Sheet

    private var askSheetContent: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                if isAsking {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let askError {
                    Text(askError).foregroundStyle(.red).font(.caption)
                } else {
                    ScrollView {
                        Text(askAnswer)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationTitle("Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showAskSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Action

    private func askQuestion() async {
        let q = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isAsking = true
        askError = nil
        showAskSheet = true

        do {
            askAnswer = try await claudeService.askQuestion(
                question: q,
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript
            )
        } catch {
            askError = error.localizedDescription
        }

        isAsking = false
    }
}
