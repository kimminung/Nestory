import Foundation
import NestoryKit
import SwiftData

/// 체크리스트·일정 항목. 규칙에서 자동 생성되면 ruleID 를 가진다.
@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var note: String = ""
    public var due: Date?
    public var categoryRaw: String = TaskCategory.custom.rawValue
    public var doneAt: Date?
    public var ruleID: String?

    public var family: Family?

    public var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    public init(title: String = "", category: TaskCategory = .custom, due: Date? = nil) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.due = due
    }
}

/// 서류 보관함 항목. 파일 본체는 암호화해 앱 컨테이너에 두고, 여기에는 참조만 둔다.
@Model
public final class StoredDocument {
    public var id: UUID = UUID()
    public var kindRaw: String = DocumentKind.other.rawValue
    public var name: String = ""
    public var fileName: String = ""
    public var createdAt: Date = Date()

    public var family: Family?

    public var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    public init(name: String = "", kind: DocumentKind = .other) {
        self.name = name
        self.kindRaw = kind.rawValue
    }
}
