//import Foundation
//import Vapor
//import Fluent
//import CodableCSV
//
//struct TrackingCSVImporter: RouteCollection {
//    
//    struct CSVFlyingBackRecord {
//        let flyingBackAt: Date?
//        let trackingNumber: String?
//        let productName: String?
//        let productQuantity: Int?
//        let weight: Float?
//        let shipmentCode: String?
//        let box: String?
//        
//        init(dateFormatter: DateFormatter, res: [String]) {
//            self.box = res.first
//            self.flyingBackAt = res.get(at: 1)?.date(using: dateFormatter)
//            self.trackingNumber = res.get(at: 3)
//            self.productName = res.get(at: 4)
//            self.productQuantity = 1
//            self.weight = Float(res.get(at: 5) ?? "0.0")
//            self.shipmentCode = res.get(at: 9)
//        }
//    }
//    
//    func boot(routes: RoutesBuilder) throws {
//        let grouped = routes.grouped("importData")
//        grouped.on(.POST, "flyingBackTrackingItems", ":agentID", body: .collect(maxSize: "80mb"), use: importFlyingBackTrackingItems)
//    }
//    
//    private func importFlyingBackTrackingItems(request: Request) async throws -> Int {
//        guard
//            let buffer = request.body.data,
//            let agentID = request.parameters.get("agentID", as: String.self),
//            !agentID.isEmpty
//        else {
//            throw AppError.invalidInput
//        }
//        let data = Data(buffer: buffer)
//        let reader = try CSVReader(input: data) {
//            $0.headerStrategy = .none
//            $0.presample = false
//            $0.escapingStrategy = .doubleQuote
//            $0.delimiters.row = "\r\n"
//        }
//        let dateFormatter = DateFormatter()
//        dateFormatter.timeZone = TimeZone(identifier: "UTC")
//        
//        //Lấy ra dữ liệu trong file CSV
//        var records: [CSVFlyingBackRecord] = []
//        var count = 0
//        var currentBoxInShipment: [String: String] = [:]
//        while var row = try reader.readRow() {
//            count += 1
//            if count <= -1 {
//                continue
//            }
//            else {
//                if let shipmentCode = row.get(at: 9), var trackingNumber = row.get(at: 3), !trackingNumber.isEmpty, trackingNumber.isValidTrackingNumber() {
//                    if trackingNumber.contains("...") {
//                        trackingNumber = trackingNumber.components(separatedBy: "...")[1]
//                        print("invalid input", trackingNumber)
//                    }
//                    if let safeBox = row.first, Int(safeBox) != nil {
//                        row[0] = safeBox
//                        currentBoxInShipment[shipmentCode] = safeBox
//                    }
//                    else {
//                        if let box = currentBoxInShipment[shipmentCode] {
//                            row[0] = box
//                        }
//                    }
//                    let item = CSVFlyingBackRecord(dateFormatter: dateFormatter, res: row)
//                    records.append(item)
//                }
//                else {
//                    continue
//                }
//            }
//        }
//        
//        //Import dữ liệu vào database
//        let items = records
//        
//        let trackingItems = try await request.db.transaction { db -> [TrackingItem] in
//            let allTrackingNumbers = items.compactMap { $0.trackingNumber }
//            let trackingNumbers = allTrackingNumbers.removingDuplicates()
//            
//            guard trackingNumbers.count > 0 else {
//                return []
//            }
//
//            let shipmentCodes = items.compactMap { $0.shipmentCode }.removingDuplicates()
//            let shipments: [Shipment] = shipmentCodes.compactMap { shipmentCode in
//                let filterItem = items.filter { $0.shipmentCode == shipmentCode && $0.flyingBackAt != nil }.sorted(by: { $0.flyingBackAt!.compare($1.flyingBackAt!) == .orderedDescending }).first
//                let shipment = Shipment(shipmentCode: shipmentCode, commitedAt: filterItem?.flyingBackAt)
//                return shipment
//            }
//            try await shipments.create(on: db)
//            try shipments.forEach { shipment in
//                try request.appendAction(.createShipment(shipmentID: shipment.requireID()))
//            }
//            
//            let boxes: [Box] = try shipments.map { shipment in
//                let shipmentID = try shipment.requireID()
//                let shipmentRecords: [CSVFlyingBackRecord] = items.filter { $0.shipmentCode == shipment.shipmentCode }
//                let boxes = shipmentRecords.compactMap { $0.box }.removingDuplicates()
//                return boxes.map { box in
//                    let boxRecord = shipmentRecords.filter { $0.box == box && $0.weight != 0.0 }.first
//                    let weight = boxRecord?.weight
//                    return Box(name: box, weight: Double(weight ?? 0.0), agentCodes: [agentID], shipmentID: shipmentID)
//                }
//            }.flatMap { $0 }
//            try await boxes.create(on: db)
//            try boxes.forEach({ box in
//                try request.appendAction(.createBox(boxID: box.requireID()))
//            })
//            
//            let trackingItems: [TrackingItem] = try items.map { item in
//                let shipment = shipments.filter { $0.shipmentCode == item.shipmentCode }.first
//                let currentBox = boxes.filter { box in
//                    return box.name == item.box && box.$shipment.id == shipment?.id
//                }.first
//                let boxId = try currentBox?.requireID()
//                let trackingItem = TrackingItem(trackingNumber: item.trackingNumber ?? "", agentCode: agentID, receivedAtUSAt: item.flyingBackAt, repackingAt: item.flyingBackAt, repackedAt: item.flyingBackAt, boxedAt: item.boxedAt, lottedAt: item.lottedAt, flyingBackAt: item.flyingBackAt, importedAt: Date(), chain: UUID().uuidString)
//                trackingItem.$box.id = boxId
//                return trackingItem
//            }
//            
//            let countExistingTrackingItem = try await TrackingItem.query(on: db)
//                .filter(trackingNumbers: trackingNumbers)
//                .count()
//            
//            if countExistingTrackingItem > 0 {
//                throw AppError.trackingNumbersAlreadyOnSystem
//            }
//            
//            try await trackingItems.create(on: db)
//            try trackingItems.forEach { trackingItem in
//                try request.appendAction(.createTrackingItem(trackingItemId: trackingItem.requireID()))
//            }
//            
//            let products: [Product?] = try items.map { item in
//                if let trackingItem = trackingItems.filter({ $0.trackingNumber == item.trackingNumber }).first {
//                    let trackingId = try trackingItem.requireID()
//                    return Product(trackingItemID: trackingId, images: [], index: 0, description: item.productName ?? "", quantity: item.productQuantity ?? 0)
//                }
//                return nil
//            }
//            try await products.compactMap { $0 }.create(on: db)
//            
//            try trackingItems.forEach { trackingItem in
//                let allProductIDs = products.filter { $0?.$trackingItem.id == trackingItem.id }.compactMap { $0 }.compactMap { $0.id }
//                try request.appendAction(.assignProducts(trackingItemID: trackingItem.requireID(), productIDs: allProductIDs))
//            }
//            
//            return trackingItems
//        }
//
//        return trackingItems.count
//    }
//}
