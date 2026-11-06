import SwiftUI

// MARK: - Goal Prompt

/// Asked once when a labeled session starts. The goal is what every segment
/// in the session is later judged against.
struct LabelingGoalPrompt: View {
    let sessionId: String
    @ObservedObject var recorder: LabelingRecorder
    @State private var goal = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's the goal for this session?")
                    .font(TypeScale.h2)
                Text("Labeling mode is on. At the end you'll mark each minute as on goal, supporting, or off goal.")
                    .font(TypeScale.bodySm)
                    .foregroundStyle(Color.driftMuted)
            }

            TextField("e.g. Finish the Q3 report draft", text: $goal)
                .textFieldStyle(.roundedBorder)
                .font(TypeScale.bodyMd)
                .focused($fieldFocused)
                .onSubmit(save)

            HStack {
                TertiaryButton(title: "Skip for now") { recorder.skipGoal() }
                Spacer()
                PrimaryPillButton(title: "Start", icon: "target", action: save)
                    .disabled(trimmedGoal.isEmpty)
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
        .onAppear { fieldFocused = true }
    }

    private var trimmedGoal: String { goal.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmedGoal.isEmpty else { return }
        recorder.setGoal(trimmedGoal, for: sessionId)
    }
}

// MARK: - Review

/// End-of-session timeline: press 1/2/3 to label the selected minute and move
/// to the next one. Up/Down move, 0 or Delete clears a label.
struct LabelingReviewView: View {
    let sessionId: String
    @ObservedObject var recorder: LabelingRecorder
    @State private var segments: [LabelingSegment] = []
    @State private var selection = 0
    @State private var goal = ""
    @State private var savedGoal = ""
    @FocusState private var listFocused: Bool
    @FocusState private var goalFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            goalField
            timeline
            footer
        }
        .padding(Space.xl)
        .frame(width: 620, height: 560)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Label this session")
                    .font(TypeScale.h2)
                Text("1 on goal · 2 supporting · 3 off goal · ↑↓ move · 0 clear")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
            }
            Spacer()
            Text("\(labeledCount) of \(segments.count) labeled")
                .font(TypeScale.monoXs)
                .foregroundStyle(Color.driftMuted)
        }
    }

    private var goalField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.sm) {
                Image(systemName: "target").foregroundStyle(Color.sand)
                TextField("Session goal (required for export)", text: $goal)
                    .textFieldStyle(.roundedBorder)
                    .focused($goalFocused)
                    .onSubmit {
                        saveGoal()
                        listFocused = true
                    }
            }
            if goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Without a goal, this session's labels are left out of the export.", systemImage: "exclamationmark.triangle")
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.distraction)
            }
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        row(segment, isSelected: index == selection)
                            .id(segment.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selection = index
                                listFocused = true
                            }
                    }
                }
            }
            .focusable()
            .focusEffectDisabled()
            .focused($listFocused)
            .onKeyPress(keys: ["1", "2", "3", "0", .delete, .upArrow, .downArrow]) { press in
                handle(press.key)
            }
            .onChange(of: selection) { _, index in
                guard segments.indices.contains(index) else { return }
                proxy.scrollTo(segments[index].id, anchor: .center)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(Color.cream.opacity(listFocused ? 0.28 : 0.10), lineWidth: 1)
            )
        }
    }

    private func row(_ segment: LabelingSegment, isSelected: Bool) -> some View {
        HStack(spacing: Space.md) {
            Text(segment.timestamp, format: .dateTime.hour().minute())
                .font(TypeScale.monoXs)
                .foregroundStyle(Color.driftMuted)
                .frame(width: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.title.isEmpty ? segment.app : segment.title)
                    .font(TypeScale.bodySm)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text([segment.app, segment.domain].compactMap { $0 }.joined(separator: " · "))
                    .font(TypeScale.caption)
                    .foregroundStyle(Color.driftMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.md)
            labelChip(segment.label)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(isSelected ? Color.sand.opacity(0.16) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(segment.label?.displayName ?? "Unlabeled")
    }

    private func labelChip(_ label: GoalLabel?) -> some View {
        Text(label?.displayName ?? "—")
            .font(TypeScale.caption.weight(.semibold))
            .foregroundStyle(color(for: label))
            .frame(width: 84)
            .padding(.vertical, 3)
            .background(Capsule().fill(color(for: label).opacity(label == nil ? 0 : 0.14)))
    }

    private var footer: some View {
        HStack {
            if let error = recorder.lastError {
                Text(error).font(TypeScale.caption).foregroundStyle(Color.distraction).lineLimit(1)
            }
            Spacer()
            TertiaryButton(title: "Finish later") { close() }
            PrimaryPillButton(title: "Done", icon: "checkmark") { close() }
        }
    }

    // MARK: Behavior

    private var labeledCount: Int { segments.filter { $0.label != nil }.count }

    private func color(for label: GoalLabel?) -> Color {
        switch label {
        case .onGoal: return .productive
        case .supporting: return .sand
        case .offGoal: return .distraction
        case nil: return .driftMuted
        }
    }

    private func load() {
        segments = (try? recorder.store.segments(sessionId: sessionId)) ?? []
        savedGoal = ((try? recorder.store.goal(sessionId: sessionId)) ?? nil) ?? ""
        goal = savedGoal
        selection = segments.firstIndex { $0.label == nil } ?? 0
        if goal.isEmpty { goalFocused = true } else { listFocused = true }
    }

    private func saveGoal() {
        guard goal != savedGoal else { return }
        recorder.setGoal(goal, for: sessionId)
        savedGoal = goal
    }

    private func handle(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case .upArrow:
            selection = max(selection - 1, 0)
        case .downArrow:
            selection = min(selection + 1, max(segments.count - 1, 0))
        case "0", .delete:
            apply(nil, advance: false)
        default:
            guard let label = GoalLabel.allCases.first(where: { KeyEquivalent($0.shortcut) == key }) else {
                return .ignored
            }
            apply(label, advance: true)
        }
        return .handled
    }

    private func apply(_ label: GoalLabel?, advance: Bool) {
        guard segments.indices.contains(selection) else { return }
        recorder.setLabel(label, segmentId: segments[selection].id)
        segments[selection].label = label
        if advance, selection < segments.count - 1 { selection += 1 }
    }

    private func close() {
        saveGoal()
        recorder.closeReview()
    }
}

/// Identifiable wrapper so a session id can drive `.sheet(item:)`.
struct LabelingSheetID: Identifiable, Equatable {
    let id: String
}
