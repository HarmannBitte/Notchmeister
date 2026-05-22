//
//  AdvanceLifeEffect.swift
//  Notchmeister
//
//  A NotchEffect that renders Advance Life context directly in the macOS notch:
//
//  ┌──────────────────────────────────────────────────────────────┐
//  │  [●] [▓▓▓░░] Deep Work: Fix auth bug          2:47 [▓▓▓░░░] │
//  └──────────────────────────────────────────────────────────────┘
//
//  Layout (left → right, all inside the notch bounds):
//    • Mode dot  — 10 pt circle, mode color, pulses when active
//    • Confidence bar — 30 × 3 pt, filled to confidence %
//    • Task label — truncated text, strikethrough when paused
//    • PAUSED badge — shown when paused
//    • Timer label + progress bar — shown when timer is active
//

import AppKit
import QuartzCore

class AdvanceLifeEffect: NotchEffect {

    // MARK: - Layers

    /// Pill-shaped container that sits inside the notch
    private let containerLayer = CALayer()

    /// Mode indicator dot
    private let dotLayer = CALayer()

    /// Confidence bar track + fill
    private let confTrackLayer = CALayer()
    private let confFillLayer = CALayer()

    /// Task / status text
    private let taskTextLayer = CATextLayer()

    /// "PAUSED" badge
    private let pausedLayer = CATextLayer()

    /// Timer label (e.g. "Pomodoro: 2:47")
    private let timerTextLayer = CATextLayer()

    /// Timer progress track + fill
    private let timerTrackLayer = CALayer()
    private let timerFillLayer = CALayer()

    // MARK: - Layout constants

    private let dotSize: CGFloat = 10
    private let confWidth: CGFloat = 30
    private let confHeight: CGFloat = 3
    private let timerBarWidth: CGFloat = 40
    private let timerBarHeight: CGFloat = 4
    private let hPad: CGFloat = 12
    private let gap: CGFloat = 8
    private let containerHeight: CGFloat = 28
    private let fontSize: CGFloat = 11

    // MARK: - State

    private var currentState: ALNotchState? = nil
    private var pulseTimer: Timer? = nil

    // MARK: - Init

    required init(with parentLayer: CALayer, in parentView: NSView, of parentWindow: NSWindow) {
        super.init(with: parentLayer, in: parentView, of: parentWindow)
        buildLayers()
        AdvanceLifeStateWatcher.shared.onChange { [weak self] state in
            self?.apply(state)
        }
        AdvanceLifeStateWatcher.shared.start()
        apply(AdvanceLifeStateWatcher.shared.current)
    }

    // MARK: - Layer construction

    private func buildLayers() {
        guard let parentLayer = parentLayer else { return }

        let notchBounds = parentLayer.bounds
        let scale = parentLayer.contentsScale

        // ── Container ──────────────────────────────────────────────────────
        containerLayer.cornerRadius = containerHeight / 2
        containerLayer.backgroundColor = NSColor(white: 0.06, alpha: 0.88).cgColor
        containerLayer.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        containerLayer.borderWidth = 0.5
        containerLayer.masksToBounds = true
        containerLayer.contentsScale = scale
        // Position will be set in layoutContainer()
        parentLayer.addSublayer(containerLayer)

        // ── Mode dot ───────────────────────────────────────────────────────
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotLayer.contentsScale = scale
        containerLayer.addSublayer(dotLayer)

        // ── Confidence bar ─────────────────────────────────────────────────
        confTrackLayer.cornerRadius = confHeight / 2
        confTrackLayer.backgroundColor = NSColor(white: 1, alpha: 0.15).cgColor
        confTrackLayer.bounds = CGRect(x: 0, y: 0, width: confWidth, height: confHeight)
        confTrackLayer.contentsScale = scale
        containerLayer.addSublayer(confTrackLayer)

        confFillLayer.cornerRadius = confHeight / 2
        confFillLayer.bounds = CGRect(x: 0, y: 0, width: confWidth, height: confHeight)
        confFillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        confFillLayer.contentsScale = scale
        confTrackLayer.addSublayer(confFillLayer)

        // ── Task text ──────────────────────────────────────────────────────
        taskTextLayer.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        taskTextLayer.fontSize = fontSize
        taskTextLayer.foregroundColor = NSColor(white: 0.9, alpha: 1).cgColor
        taskTextLayer.contentsScale = scale
        taskTextLayer.truncationMode = .end
        taskTextLayer.alignmentMode = .left
        taskTextLayer.bounds = CGRect(x: 0, y: 0, width: 160, height: fontSize + 4)
        containerLayer.addSublayer(taskTextLayer)

        // ── Paused badge ───────────────────────────────────────────────────
        pausedLayer.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        pausedLayer.fontSize = 9
        pausedLayer.foregroundColor = NSColor(red: 0.988, green: 0.647, blue: 0.647, alpha: 1).cgColor
        pausedLayer.backgroundColor = NSColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 0.25).cgColor
        pausedLayer.cornerRadius = 4
        pausedLayer.string = "PAUSED"
        pausedLayer.contentsScale = scale
        pausedLayer.alignmentMode = .center
        pausedLayer.bounds = CGRect(x: 0, y: 0, width: 44, height: 14)
        pausedLayer.isHidden = true
        containerLayer.addSublayer(pausedLayer)

        // ── Timer bar ──────────────────────────────────────────────────────
        timerTrackLayer.cornerRadius = timerBarHeight / 2
        timerTrackLayer.backgroundColor = NSColor(white: 1, alpha: 0.15).cgColor
        timerTrackLayer.bounds = CGRect(x: 0, y: 0, width: timerBarWidth, height: timerBarHeight)
        timerTrackLayer.contentsScale = scale
        timerTrackLayer.isHidden = true
        containerLayer.addSublayer(timerTrackLayer)

        timerFillLayer.cornerRadius = timerBarHeight / 2
        timerFillLayer.bounds = CGRect(x: 0, y: 0, width: timerBarWidth, height: timerBarHeight)
        timerFillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        timerFillLayer.backgroundColor = NSColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1).cgColor
        timerFillLayer.contentsScale = scale
        timerTrackLayer.addSublayer(timerFillLayer)

        timerTextLayer.font = NSFont.monospacedDigitSystemFont(ofSize: fontSize - 1, weight: .semibold)
        timerTextLayer.fontSize = fontSize - 1
        timerTextLayer.foregroundColor = NSColor(white: 0.6, alpha: 1).cgColor
        timerTextLayer.contentsScale = scale
        timerTextLayer.alignmentMode = .left
        timerTextLayer.bounds = CGRect(x: 0, y: 0, width: 80, height: fontSize + 2)
        timerTextLayer.isHidden = true
        containerLayer.addSublayer(timerTextLayer)

        layoutContainer(for: notchBounds)
    }

    /// Positions the container pill centered under the notch
    private func layoutContainer(for notchBounds: CGRect) {
        let timerVisible = !(timerTrackLayer.isHidden)
        let containerWidth = computeContainerWidth(timerVisible: timerVisible)

        containerLayer.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        // Anchor at top-center of notch, offset down by 6 pt so it sits just below
        containerLayer.position = CGPoint(x: notchBounds.midX, y: notchBounds.maxY + containerHeight / 2 + 6)

        layoutSubviews(containerWidth: containerWidth)
    }

    private func computeContainerWidth(timerVisible: Bool) -> CGFloat {
        var w = hPad + dotSize + gap + confWidth + gap + 160 + gap
        if !(pausedLayer.isHidden) { w += 44 + gap }
        if timerVisible { w += timerBarWidth + gap + 80 + gap }
        w += hPad
        return w
    }

    private func layoutSubviews(containerWidth: CGFloat) {
        let midY = containerHeight / 2

        var x = hPad

        // Dot
        dotLayer.position = CGPoint(x: x + dotSize / 2, y: midY)
        x += dotSize + gap

        // Confidence bar
        confTrackLayer.position = CGPoint(x: x + confWidth / 2, y: midY)
        x += confWidth + gap

        // Task text
        let taskH = fontSize + 4
        taskTextLayer.position = CGPoint(x: x, y: midY - taskH / 2)
        taskTextLayer.anchorPoint = CGPoint(x: 0, y: 0)
        x += 160 + gap

        // Paused badge
        if !pausedLayer.isHidden {
            pausedLayer.position = CGPoint(x: x + 22, y: midY)
            x += 44 + gap
        }

        // Timer
        if !timerTrackLayer.isHidden {
            timerTrackLayer.position = CGPoint(x: x + timerBarWidth / 2, y: midY)
            x += timerBarWidth + gap
            timerTextLayer.position = CGPoint(x: x, y: midY - (fontSize - 1 + 2) / 2)
            timerTextLayer.anchorPoint = CGPoint(x: 0, y: 0)
        }
    }

    // MARK: - State application

    private func apply(_ state: ALNotchState?) {
        guard let parentLayer = parentLayer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.35)

        if let state = state {
            let mode = ALMode(rawString: state.mode)
            let modeColor = mode.color

            // Dot
            dotLayer.backgroundColor = modeColor.withAlphaComponent(state.paused ? 0.35 : 1.0).cgColor

            // Confidence fill
            let confPct = max(0, min(1, state.confidence))
            confFillLayer.backgroundColor = modeColor.cgColor
            CATransaction.withActionsDisabled {
                confFillLayer.bounds = CGRect(x: 0, y: 0,
                                              width: confWidth * confPct,
                                              height: confHeight)
            }

            // Task text
            let taskStr: String
            if state.showTask, let title = state.taskTitle {
                let prefix = state.taskProject.map { "\($0): " } ?? ""
                taskStr = prefix + title
            } else if !state.showTask {
                taskStr = "Focus mode"
            } else {
                taskStr = "No active task"
            }

            if state.paused {
                // Strikethrough via attributed string
                let attrs: [NSAttributedString.Key: Any] = [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor(white: 0.9, alpha: 0.4),
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .medium)
                ]
                taskTextLayer.string = NSAttributedString(string: taskStr, attributes: attrs)
            } else {
                taskTextLayer.foregroundColor = NSColor(white: 0.9, alpha: 0.9).cgColor
                taskTextLayer.string = taskStr
            }

            // Paused badge
            pausedLayer.isHidden = !state.paused

            // Timer
            if let timer = state.timer, timer.state != .idle {
                timerTrackLayer.isHidden = false
                timerTextLayer.isHidden = false

                let pct = max(0, min(1, timer.progress))
                CATransaction.withActionsDisabled {
                    timerFillLayer.bounds = CGRect(x: 0, y: 0,
                                                   width: timerBarWidth * pct,
                                                   height: timerBarHeight)
                }

                switch timer.state {
                case .running:
                    timerFillLayer.backgroundColor = NSColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1).cgColor
                case .paused:
                    timerFillLayer.backgroundColor = NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1).cgColor
                case .completed:
                    timerFillLayer.backgroundColor = NSColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1).cgColor
                default:
                    break
                }

                timerTextLayer.string = "\(timer.label): \(formatMs(timer.remainingMs))"
            } else {
                timerTrackLayer.isHidden = true
                timerTextLayer.isHidden = true
            }

            containerLayer.isHidden = false
            startPulse(color: modeColor, paused: state.paused)

        } else {
            // No state file — hide the container
            containerLayer.isHidden = true
            stopPulse()
        }

        CATransaction.commit()

        // Re-layout after visibility changes
        layoutContainer(for: parentLayer.bounds)
    }

    // MARK: - Pulse animation

    private func startPulse(color: NSColor, paused: Bool) {
        stopPulse()
        guard !paused else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.4
        pulse.duration = 1.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(pulse, forKey: "pulse")
    }

    private func stopPulse() {
        dotLayer.removeAnimation(forKey: "pulse")
    }

    // MARK: - Helpers

    private func formatMs(_ ms: Double) -> String {
        let totalSec = Int(ceil(max(0, ms) / 1000))
        let min = totalSec / 60
        let sec = totalSec % 60
        return String(format: "%d:%02d", min, sec)
    }

    // MARK: - NotchEffect lifecycle

    override func start() {
        containerLayer.isHidden = false
        apply(AdvanceLifeStateWatcher.shared.current)
    }

    override func end() {
        stopPulse()
        containerLayer.isHidden = true
    }
}
