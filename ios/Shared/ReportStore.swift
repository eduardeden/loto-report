import Foundation

enum ReportStoreError: Error {
    case invalidResponse
    case badStatusCode(Int)
}

struct ReportStore {
    private let defaults: UserDefaults
    private let bundle: Bundle
    private let cacheKey = "cached_report_json"
    private let etagKey = "cached_report_etag"

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: ReportConfig.appGroupIdentifier),
        bundle: Bundle = .main
    ) {
        self.defaults = defaults ?? .standard
        self.bundle = bundle
    }

    func loadCachedReport() -> ReportResponse? {
        if let data = defaults.data(forKey: cacheKey) {
            return try? ReportDecode.decode(data)
        }

        guard
            let url = bundle.url(forResource: "BootstrapReport", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }

        return try? ReportDecode.decode(data)
    }

    func loadCachedETag() -> String? {
        defaults.string(forKey: etagKey)
    }

    func save(reportData: Data, etag: String?) {
        defaults.set(reportData, forKey: cacheKey)
        if let etag {
            defaults.set(etag, forKey: etagKey)
        }
    }

    func fetchRemoteReport() async throws -> (report: ReportResponse?, isNotModified: Bool) {
        var request = URLRequest(url: ReportConfig.reportURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        if let etag = loadCachedETag() {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportStoreError.invalidResponse
        }

        if httpResponse.statusCode == 304 {
            return (nil, true)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReportStoreError.badStatusCode(httpResponse.statusCode)
        }

        let report = try ReportDecode.decode(data)
        save(reportData: data, etag: httpResponse.value(forHTTPHeaderField: "ETag"))
        return (report, false)
    }
}
