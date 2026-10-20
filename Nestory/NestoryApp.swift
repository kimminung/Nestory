import NestoryData
import SwiftData
import SwiftUI

@main
struct NestoryApp: App {
    /// 저장소·규칙 읽기 결과. 실패해도 앱이 죽지 않고 안내 화면을 보여 준다.
    private let storage = Result { try NestoryModelContainer.make() }
    private let catalog = Result { try RuleCatalog.load() }

    var body: some Scene {
        WindowGroup {
            switch (storage, catalog) {
            case (.success(let container), .success(let catalog)):
                RootView()
                    .modelContainer(container)
                    .environment(\.ruleCatalog, catalog)
            case (.failure(let error), _), (_, .failure(let error)):
                ContentUnavailableView(
                    "앱을 열 수 없어요",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(error.localizedDescription)
                )
            }
        }
    }
}
