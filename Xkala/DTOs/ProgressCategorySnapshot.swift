import Foundation

struct ProgressCategoryBucket: Identifiable, Equatable {
    let id: String
    let chronologicalIndex: Int
    let axisLabel: String
    let completedCount: Int
}

struct ProgressCategoryOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    /// Diminutivo para picker compacto (nombre completo en accesibilidad).
    let shortLabel: String
}

struct ProgressCategorySeries: Identifiable, Equatable {
    let id: String
    let displayName: String
    let buckets: [ProgressCategoryBucket]
    let totalInRange: Int
}

struct ProgressByCategorySnapshot: Equatable {
    let range: StatsRange
    let series: [ProgressCategorySeries]

    var hasAnyData: Bool {
        series.contains { $0.totalInRange > 0 }
    }
}
