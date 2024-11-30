import Vapor
import Foundation

struct LotListOutput: Content {
    let id: Lot.IDValue?
    let lotIndex: String
    let boxCount: Int
}

extension Lot {
    func toListOutput() -> LotListOutput {
        .init(
            id: self.id,
            lotIndex: self.lotIndex,
            boxCount: self.$boxes.value?.count ?? 0
        )
    }
}
