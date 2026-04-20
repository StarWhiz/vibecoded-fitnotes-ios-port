//
//  ContentView.swift
//  FitNotes iOS
//
//  Root TabView navigation. Four tabs: Home (workout), Calendar, Body Tracker, Settings.
//  The rest timer banner overlays across all tabs when active.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(RestTimerStore.self) private var timerStore
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @State private var selectedTab: Tab = .home

    enum Tab: String {
        case home, calendar, bodyTracker, settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tag(Tab.home)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }

                NavigationStack {
                    CalendarView()
                }
                .tag(Tab.calendar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

                NavigationStack {
                    BodyTrackerView()
                }
                .tag(Tab.bodyTracker)
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }

                NavigationStack {
                    SettingsView()
                }
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }

            // Floating rest timer banner visible across all tabs
            if timerStore.state.isActive {
                RestTimerBannerView()
                    .padding(.bottom, 50) // above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: timerStore.state.isActive)
        .preferredColorScheme(colorScheme)
        .onChange(of: workoutStore.isWorkoutActive) { _, isActive in
            UIApplication.shared.isIdleTimerDisabled = isActive
        }
        .task {
            try? workoutStore.load(for: workoutStore.date, context: context)
        }
    }

    private var colorScheme: ColorScheme? {
        switch settingsStore.appThemeID {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
