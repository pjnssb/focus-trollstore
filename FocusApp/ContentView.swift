import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var store: FocusStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPicker = false
    @State private var showCompletion = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AuthorizationBannerView()

                    TimerRingView(
                        progress: store.progress,
                        remaining: store.formattedRemaining,
                        isRunning: store.isRunning
                    )
                    .padding(.top, 8)

                    durationSection
                    whitelistSection
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("专注")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPicker) {
                WhitelistPickerView(selection: $store.selection)
            }
            .alert("专注完成", isPresented: $showCompletion) {
                Button("好的", role: .cancel) {
                    store.dismissCompletion()
                }
            } message: {
                Text("本次专注已完成，白名单限制已解除。")
            }
            .alert("出错了", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        store.errorMessage = nil
                    }
                }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "未知错误")
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.refreshFromScene()
                }
            }
            .onChange(of: store.completedSession?.id) { _ in
                if store.completedSession?.status == .completed {
                    showCompletion = true
                }
            }
            .onAppear {
                if store.completedSession?.status == .completed {
                    showCompletion = true
                }
            }
            .task {
                await store.requestAuthorizationIfNeeded()
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("专注时长")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach([15, 25, 45, 60, 90], id: \.self) { minutes in
                    Button {
                        store.durationMinutes = minutes
                    } label: {
                        Text("\(minutes) 分")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                store.durationMinutes == minutes
                                    ? Color.accentColor
                                    : Color(uiColor: .tertiarySystemGroupedBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(store.durationMinutes == minutes ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isRunning)
                }
            }

            HStack {
                Text("自定义")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(store.durationMinutes) },
                        set: { store.durationMinutes = Int($0) }
                    ),
                    in: 1...180,
                    step: 5
                )
                .disabled(store.isRunning)

                Text("\(store.durationMinutes) 分钟")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 76, alignment: .trailing)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var whitelistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("白名单")
                    .font(.headline)
                Spacer()
                Text("\(store.whitelistCount) 个 App")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("专注期间，只有白名单里的 App 可以打开；其他可屏蔽的 App 会被系统盾牌拦住。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("重要：请把「专注」和「TrollStore」也加入白名单，否则它们会被盾牌拦住。")
                .font(.caption)
                .foregroundStyle(Color.orange)

            if store.whitelistCount == 0 {
                Text("未选择任何 App，将屏蔽所有可屏蔽的 App。")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }

            Button {
                showPicker = true
            } label: {
                Label("选择允许的 App", systemImage: "checklist")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(store.isRunning || !store.canStart)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionButton: some View {
        Button {
            if store.isRunning {
                store.abandonSession()
            } else {
                store.startSession()
            }
        } label: {
            Text(store.isRunning ? "放弃专注" : "开始专注")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(store.isRunning ? Color.red : Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(!store.isRunning && !store.canStart)
        .opacity(!store.isRunning && !store.canStart ? 0.5 : 1)
    }
}
