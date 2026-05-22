//
//  AdvanceLifeState.swift
//  Notchmeister
//
//  Advance Life integration — reads state written by the desktop-companion
//  to ~/Library/Application Support/advance-life/notch-state.json
//

import Foundation
import AppKit

// MARK: - Data model

struct ALTimerSnapshot: Codable {
    enum State: String, Codable { case idle, running, paused, completed }
    var state: State
    var label: String
    var totalMs: Double
    var elapsedMs: Double
    var remainingMs: Double
    var progress: Double   // 0…1
}

struct ALNotchState: Codable {
    var mode: String          // "deep_work" | "meeting" | "workout" | "commute" | "wind_down" | "free_time" | "morning"
    var confidence: Double    // 0…1
    var paused: Bool
    var taskTitle: String?
    var taskProject: String?
    var showTask: Bool
    var timer: ALTimerSnapshot?
    var updatedAt: Double     // unix ms — used to detect stale state
}

// MARK: - Mode helpers

enum ALMode: String {
    case deepWork   = "deep_work"
    case meeting    = "meeting"
    case workout    = "workout"
    case commute    = "commute"
    case windDown   = "wind_down"
    case freeTime   = "free_time"
    case morning    = "morning"

    var color: NSColor {
        switch self {
        case .deepWork:  return NSColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1) // #3b82f6
        case .meeting:   return NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1) // #f59e0b
        case .workout:   return NSColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1) // #ef4444
        case .commute:   return NSColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1) // #8b5cf6
        case .windDown:  return NSColor(red: 0.976, green: 0.592, blue: 0.090, alpha: 1) // #f97316
        case .freeTime:  return NSColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1) // #22c55e
        case .morning:   return NSColor(red: 0.918, green: 0.702, blue: 0.031, alpha: 1) // #eab308
        }
    }

    var label: String {
        switch self {
        case .deepWork:  return "Deep Work"
        case .meeting:   return "Meeting"
        case .workout:   return "Workout"
        case .commute:   return "Commute"
        case .windDown:  return "Wind Down"
        case .freeTime:  return "Free Time"
        case .morning:   return "Morning"
        }
    }

    init(rawString: String) {
        self = ALMode(rawValue: rawString) ?? .freeTime
    }
}

// MARK: - State file watcher

/// Polls ~/Library/Application Support/advance-life/notch-state.json every second.
/// Calls the callback on the main queue whenever the state changes.
class AdvanceLifeStateWatcher {

    static let shared = AdvanceLifeStateWatcher()

    private(set) var current: ALNotchState? = nil
    private var timer: Timer?
    private var lastUpdatedAt: Double = 0
    private var callbacks: [(ALNotchState?) -> Void] = []

    private static var stateFileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("advance-life/notch-state.json")
    }()

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll() // immediate first read
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func onChange(_ callback: @escaping (ALNotchState?) -> Void) {
        callbacks.append(callback)
    }

    private func poll() {
        let url = Self.stateFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(ALNotchState.self, from: data)
        else {
            // File gone or unreadable — clear state
            if current != nil {
                current = nil
                notify()
            }
            return
        }

        // Only notify if something actually changed
        guard state.updatedAt != lastUpdatedAt else { return }
        lastUpdatedAt = state.updatedAt
        current = state
        notify()
    }

    private func notify() {
        let snapshot = current
        DispatchQueue.main.async { [weak self] in
            self?.callbacks.forEach { $0(snapshot) }
        }
    }
}
