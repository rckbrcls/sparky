//
//  FocusTabView.swift
//  sparky
//
//  Focus tab: one persistent canvas for setup and active sessions.
//

import SwiftUI

struct FocusTabView: View {
    @ObservedObject var environment: AppEnvironment
    @ObservedObject private var timer: FocusTimer
    @ObservedObject private var focusSettings: FocusSettings

    @State private var quickRecipe: FocusRecipe
    @State private var hasLocalQuickOverrides = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _timer = ObservedObject(wrappedValue: environment.focusTimer)
        _focusSettings = ObservedObject(wrappedValue: environment.focusSettings)
        _quickRecipe = State(
            initialValue: FocusRecipe.from(settings: environment.focusSettings)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                FocusCanvasView(
                    timer: timer,
                    selectedWorkMinutes: quickWorkDurationBinding,
                    onStartQuick: {
                        environment.startQuickFocus(recipe: quickRecipe)
                    },
                    onEnd: {
                        timer.endSession()
                    }
                )

                if !timer.isSessionActive {
                    FocusConfigurationMenu(
                        recipe: $quickRecipe,
                        onChange: {
                            hasLocalQuickOverrides = true
                        }
                    )
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
            }
            .tabBarSpacer()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                syncQuickRecipeWithDefaultsIfNeeded()
            }
            .onChange(of: defaultRecipe) { _, newValue in
                guard !timer.isSessionActive, !hasLocalQuickOverrides else { return }
                quickRecipe = newValue
            }
            .onChange(of: timer.isSessionActive) { _, active in
                if !active {
                    resetQuickRecipeToDefaults()
                }
            }
        }
    }

    // MARK: - Quick Focus recipe

    private var defaultRecipe: FocusRecipe {
        FocusRecipe.from(settings: focusSettings)
    }

    private var quickWorkDurationBinding: Binding<Int> {
        Binding(
            get: { quickRecipe.workDurationMinutes },
            set: { minutes in
                quickRecipe = FocusRecipe(
                    workDurationMinutes: clampWork(minutes),
                    shortBreakDurationMinutes: quickRecipe.shortBreakDurationMinutes,
                    longBreakDurationMinutes: quickRecipe.longBreakDurationMinutes,
                    pomodorosUntilLongBreak: quickRecipe.pomodorosUntilLongBreak,
                    autoContinue: quickRecipe.autoContinue
                )
                hasLocalQuickOverrides = true
            }
        )
    }

    private func syncQuickRecipeWithDefaultsIfNeeded() {
        guard !timer.isSessionActive, !hasLocalQuickOverrides else { return }
        quickRecipe = defaultRecipe
    }

    private func resetQuickRecipeToDefaults() {
        quickRecipe = defaultRecipe
        hasLocalQuickOverrides = false
    }

    private func clampWork(_ value: Int) -> Int {
        min(
            FocusRecipe.workRange.upperBound,
            max(FocusRecipe.workRange.lowerBound, value)
        )
    }
}
