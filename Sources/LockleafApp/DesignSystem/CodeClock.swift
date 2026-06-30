import Foundation
import Observation
import SwiftUI

/// One ticking clock shared by every code view, so the whole window animates in
/// lockstep and we don't spawn a timer per row (important with thousands of
/// entries). Ticks twice a second for a smooth ring without wasting cycles.
@MainActor
@Observable
final class CodeClock {
    private(set) var date = Date()
    @ObservationIgnored private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.date = Date() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
