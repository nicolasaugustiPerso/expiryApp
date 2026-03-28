import Foundation

@MainActor
final class CoreDataCategoryViewModel: ObservableObject {
    @Published var categories: [CoreDataCategory] = []
    @Published var error: String?

    private let repository: CoreDataCategoryRepository

    init(repository: CoreDataCategoryRepository = CoreDataCategoryRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            categories = try repository.fetchCategories()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func categoryForKey(_ key: String) -> CoreDataCategory {
        if let match = categories.first(where: { $0.key == key }) {
            return match
        }
        if let fallback = categories.first(where: { $0.key == "other" }) {
            return fallback
        }
        return CoreDataCategory.fallbackOther()
    }
}
