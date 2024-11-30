import Foundation
import Vapor

enum AppWithOutputError: Error {
    
    //Customer
    case customerTrackingItemsAlreadyExist(Int)
    
    //TrackingItem
    case piecesNotFound(String)
    case trackingItemsAreAlreadyBoxed([String]) // Các tracking "ABC, BCD" đã được đóng thùng, không thể thực hiện yêu cầu này
    case trackingItemsAreAlreadyRepacked([String]) // Các tracking "ABC, BCD" đã được repacking, không thể thực hiện yêu cầu này
    case trackingItemsDontHaveCustomers([String]) // Các tracking "ABC, BCD" chưa có mã khách hàng, không thể thực hiện yêu cầu này
    case trackingItemsAreBeingHold([String]) // Các tracking "ABC, BCD" đang được hold lại, không thể thực hiện yêu cầu này
    case trackingItemsAreAlReadyRequested([String]) // Các tracking "ABC, BCD" đã được yêu cầu thực hiện
}

extension AppWithOutputError: AbortError {
    enum CodingKeys: String, CodingKey, Codable {
        case customerTrackingItemsAlreadyExist
        case piecesNotFound
        case trackingItemsAreAlreadyBoxed
        case trackingItemsDontHaveCustomers
        case trackingItemsAreBeingHold
        case trackingItemsAreAlReadyRequested
    }
    
    struct Output<T>: Codable where T: Codable {
        let name: CodingKeys
        let param: T
    }
    
    var reason: String {
        switch self {
        case .customerTrackingItemsAlreadyExist(let count):
            struct Param: Codable {
                let count: Int
            }
            let output = Output(name: .customerTrackingItemsAlreadyExist, param: Param(count: count))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .piecesNotFound(let pieces):
            struct Param: Codable {
                let pieces: String
            }
            let output = Output(name: .piecesNotFound, param: Param(pieces: pieces))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .trackingItemsAreAlreadyBoxed(let trackingNumbers):
            struct Param: Codable {
                let trackingNumbers: [String]
            }
            let output = Output(name: .trackingItemsAreAlreadyBoxed, param: Param(trackingNumbers: trackingNumbers))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .trackingItemsAreAlreadyRepacked(let trackingNumbers):
            struct Param: Codable {
                let trackingNumbers: [String]
            }
            let output = Output(name: .trackingItemsAreAlreadyBoxed, param: Param(trackingNumbers: trackingNumbers))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .trackingItemsDontHaveCustomers(let trackingNumbers):
            struct Param: Codable {
                let trackingNumbers: [String]
            }
            let output = Output(name: .trackingItemsDontHaveCustomers, param: Param(trackingNumbers: trackingNumbers))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .trackingItemsAreBeingHold(let trackingNumbers):
            struct Param: Codable {
                let trackingNumbers: [String]
            }
            let output = Output(name: .trackingItemsAreBeingHold, param: Param(trackingNumbers: trackingNumbers))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        case .trackingItemsAreAlReadyRequested(let trackingNumbers):
            struct Param: Codable {
                let trackingNumbers: [String]
            }
            let output = Output(name: .trackingItemsAreAlReadyRequested, param: Param(trackingNumbers: trackingNumbers))
            let encodedData = try! JSONEncoder().encode(output)
            return String(data: encodedData,
                          encoding: .utf8) ?? ""
        }
    }
    
    var status: HTTPResponseStatus {
        switch self {
        case .customerTrackingItemsAlreadyExist(_), .piecesNotFound(_), .trackingItemsAreAlreadyBoxed(_), .trackingItemsAreAlreadyRepacked(_), .trackingItemsDontHaveCustomers(_), .trackingItemsAreBeingHold(_), .trackingItemsAreAlReadyRequested(_):
            return .badRequest
        }
    }
}
