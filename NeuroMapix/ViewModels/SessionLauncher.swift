import Foundation
import Combine

/// Owns the presentation of a live session so any tab can start one.
@MainActor
final class SessionLauncher: ObservableObject {
    @Published var config: SessionConfig?
    @Published var isPresented = false
    @Published var token = 0

    func start(_ config: SessionConfig) {
        self.config = config
        token += 1
        isPresented = true
    }

    func replay() { token += 1 }

    func close() { isPresented = false }
}
