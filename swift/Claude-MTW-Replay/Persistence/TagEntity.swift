import Foundation
import SwiftData

/// SwiftData entity for session tags. Composite unique key on (path, tag).
@Model
final class TagEntity {
    #Unique<TagEntity>([\.path, \.tag])

    var path: String
    var tag: String
    var createdAt: Date

    init(
        path: String,
        tag: String,
        createdAt: Date = Date()
    ) {
        self.path = path
        self.tag = tag
        self.createdAt = createdAt
    }
}
