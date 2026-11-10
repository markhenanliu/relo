import SwiftUI

@main
struct ReloApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView(model: .preview)
        }
    }
}
