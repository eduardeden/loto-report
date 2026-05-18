import Foundation
import WidgetKit

@MainActor
final class ReportViewModel: ObservableObject {
    @Published private(set) var report: ReportResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store: ReportStore

    init(store: ReportStore = ReportStore()) {
        self.store = store
        self.report = store.loadCachedReport()
    }

    func refresh(forceWidgetReload: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let current = report
            let result = try await store.fetchRemoteReport()

            if let freshReport = result.report {
                report = freshReport
                errorMessage = nil

                if forceWidgetReload || hasMeaningfulChanges(old: current, new: freshReport) {
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.kind)
                }
            } else if report == nil {
                report = store.loadCachedReport()
            }
        } catch {
            report = report ?? store.loadCachedReport()
            errorMessage = report == nil ? "Nu am putut incarca datele momentan." : nil
        }
    }

    private func hasMeaningfulChanges(old: ReportResponse?, new: ReportResponse) -> Bool {
        guard let old else { return true }
        return old.generatedAtUtc != new.generatedAtUtc || old.eurRonRate != new.eurRonRate
    }
}
