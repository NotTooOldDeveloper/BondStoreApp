import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct DatabaseFile: FileDocument, Equatable {
    static var readableContentTypes: [UTType] = [.database]
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
