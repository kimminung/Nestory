import NestoryData
import SwiftData
import SwiftUI

@main
struct NestoryApp: App {
    /// 저장소 생성 결과. 실패해도 앱이 죽지 않고 안내 화면을 보여 준다.
    private let storage = Result { try NestoryModelContainer.make() }

    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                ContentUnavailableView(
                    "저장소를 열 수 없어요",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(error.localizedDescription)
                )
            }
        }
    }
}
