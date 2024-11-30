import Foundation
import Vapor

struct UploadPackingVideoInput: Content {
    var file: File?
}

extension UploadPackingVideoInput {
    enum CodingKeys: String, CodingKey {
        case file
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.file = try container.decodeIfPresent(File.self, forKey: .file)
    }
}
