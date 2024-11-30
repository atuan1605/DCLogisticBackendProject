import Foundation
import Vapor
import Fluent
import CSV
import SwiftDate

struct TrackingExportController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(ScopeCheckMiddleware(requiredScope: .usInventory)) {
            $0.get("deliCSV", use: exportDeliCSVHandler)
        }
        
        routes.group(ScopeCheckMiddleware(requiredScope: .shipmentList)) {
            $0.get("lotCSV", use: exportLotCSVHandler)
        }

        routes.group(ScopeCheckMiddleware(requiredScope: .shipmentList)) {
            $0.get("shipmentCSV", use: exportShipmentCSVHandler)
        }
    }
    
    private func exportLotCSVHandler(request: Request) async throws -> ClientResponse {
        let input = try request.query.decode(GetLotCSVExportInput.self)
        let lotIDs = input.lotIDs

        var formattingTimeZone = TimeZone.current
        if let timeZoneIdentifier = input.timeZone, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formattingTimeZone = timeZone
        }
        
        let lots = try await Lot.query(on: request.db)
            .filter(\.$id ~~ lotIDs)
            .with(\.$boxes) {
                $0.with(\.$pieces) {
                    $0.with(\.$trackingItem) {
                        $0.with(\.$customers)
                        $0.with(\.$products)
                        $0.with(\.$trackingItemReferences)
                        $0.with(\.$buyerTrackingItems)
                        $0.with(\.$warehouse)
                    }
                }
                $0.with(\.$customItems)
                $0.with(\.$shipment)
            }
            .sort(\.$createdAt, .ascending)
            .all()

        let emptyRow = ShipmentCSVExportRow(boxNumber: "", boxedAt: "", index: "", trackingNumber: "", details: "", boxWeight: "", note: "", shipmentCode: "", shipmentDate: "", customerCode: "")

        let rows: [ShipmentCSVExportRow] = lots.flatMap { lot in
            let boxes = lot.boxes.sorted(by: { lhs, rhs in
                var lhsName = lhs.name
                if let lhsIntName = Int(lhs.name), lhsIntName < 10 {
                    lhsName = "0\(lhsIntName)"
                }
                var rhsName = rhs.name
                if let rhsIntName = Int(rhs.name), rhsIntName < 10 {
                    rhsName = "0\(rhsIntName)"
                }
                return lhsName < rhsName
            })

            let boxRows: [ShipmentCSVExportRow] = boxes.enumerated().flatMap { (boxIndex, box) in
                let trackingItems = box.pieces.map {
                    $0.trackingItem
                }.sorted(by: { lhs, rhs in
                    if lhs.boxedAt == rhs.boxedAt {
                        if lhs.agentCode == rhs.agentCode {
                            return (lhs.customers.first?.customerCode ?? "") < (rhs.customers.first?.customerCode ?? "")
                        }
                        return (lhs.agentCode ?? "") < (rhs.agentCode ?? "")
                    }
                    return lhs.boxedAt ?? Date() < rhs.boxedAt ?? Date()
                })
                
                let customItems = box.customItems.sorted(by: { lhs, rhs in
                    return lhs.createdAt ?? Date() < rhs.createdAt ?? Date()
                })

                let trackingItemRows = trackingItems.enumerated().map { trackingIndex, trackingItem in
                    var trackingNumberCell = trackingItem.trackingNumber
                    if !trackingItem.trackingItemReferences.isEmpty {
                        trackingNumberCell = trackingNumberCell + "\n" + trackingItem.trackingItemReferences.map{ $0.trackingNumber }.joined(separator: "\n")
                    }
                    let customerCodes = trackingItem.$customers.value?.filter{ !$0.customerCode.isEmpty }
                    var targetCustomer: String = ""
                    if let existedCustomerCode = customerCodes, !existedCustomerCode.isEmpty {
                        targetCustomer = existedCustomerCode.map(\.customerCode).joined(separator: ", ")
                    }
                    if !trackingItem.buyerTrackingItems.isEmpty {
                        targetCustomer = targetCustomer + " YCĐB"
                    }
                    
                    var productName = trackingItem.products.description
                    if let warehouseReference = trackingItem.warehouse?.reference, !trackingItem.products.description.isEmpty {
                        productName = productName + " [\(warehouseReference)]"
                    }
                    return ShipmentCSVExportRow(
                        boxNumber: box.name,
                        boxedAt: trackingItem.boxedAt?.toISOString(formattingTimeZone) ?? "",
                        index: 0.description,
                        trackingNumber: trackingNumberCell,
                        details: productName,
                        boxWeight: box.weight?.description ?? "",
                        note: trackingItem.itemDescription ?? "",
                        lotIndex: lot.lotIndex,
                        shipmentCode: box.shipment?.shipmentCode,
                        shipmentDate: box.shipment?.commitedAt?.toISODate(formattingTimeZone) ?? "",
                        customerCode: targetCustomer
                    )
                }
                
                let customItemRows = customItems.enumerated().map { trackingIndex, customItem in
                    return ShipmentCSVExportRow(
                        boxNumber: box.name,
                        boxedAt: customItem.createdAt?.toISOString(formattingTimeZone) ?? "",
                        index: 0.description,
                        trackingNumber: customItem.reference,
                        details: customItem.details,
                        boxWeight: box.weight?.description ?? "",
                        note: "",
                        lotIndex: lot.lotIndex,
                        shipmentCode: box.shipment?.shipmentCode,
                        shipmentDate: box.shipment?.commitedAt?.toISODate(formattingTimeZone) ?? "",
                        customerCode: "")
                }
                
                let allItems: [ShipmentCSVExportRow] = [trackingItemRows, customItemRows].flatMap { $0 }.sorted { lhs, rhs in
                    return lhs.boxedAt < rhs.boxedAt
                }.enumerated().map { index, item in
                    return ShipmentCSVExportRow(
                        boxNumber: index == 0 ? item.boxNumber : "",
                        boxedAt: item.boxedAt,
                        index: (index + 1).description,
                        trackingNumber: item.trackingNumber,
                        details: item.details,
                        boxWeight: item.boxWeight,
                        note: item.note,
                        lotIndex: item.lotIndex,
                        shipmentCode: item.shipmentCode,
                        shipmentDate: item.shipmentDate,
                        customerCode: item.customerCode
                    )
                }

                return [allItems, [emptyRow, emptyRow, emptyRow]].flatMap { $0 }
            }

            return [boxRows, [emptyRow, emptyRow, emptyRow, emptyRow]].flatMap { $0 }
        }
        
        let document = try CSVEncoder().sync.encode(rows)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/csv")
        headers.add(name: .contentDisposition, value: "attachment; filename=\"shipments-\(Date().toISOString())\".csv")
        let response = ClientResponse(status: .ok,
                                      headers: headers,
                                      body: ByteBuffer(data: document))
        return response
    }
    
    struct ShipmentCSVExportRow: Content {
        var boxNumber: String
        var boxedAt: String
        var index: String
        var trackingNumber: String
        var details: String
        var boxWeight: String
        var note: String
        var lotIndex: String?
        var shipmentCode: String?
        var shipmentDate: String
        var customerCode: String
    }

    private func exportShipmentCSVHandler(request: Request) async throws -> ClientResponse {
        let input = try request.query.decode(GetShipmentCSVExportInput.self)
        let shipmentIDs = input.shipmentIDs

        var formattingTimeZone = TimeZone.current
        if let timeZoneIdentifier = input.timeZone, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formattingTimeZone = timeZone
        }
        
        let shipments = try await Shipment.query(on: request.db)
            .filter(\.$id ~~ shipmentIDs)
            .with(\.$boxes) {
                $0.with(\.$pieces) {
                    $0.with(\.$trackingItem) {
                        $0.with(\.$customers)
                        $0.with(\.$products)
                        $0.with(\.$warehouse)
                        $0.with(\.$trackingItemReferences)
                        $0.with(\.$buyerTrackingItems)
                    }
                }
                $0.with(\.$customItems)
                $0.with(\.$lot)
            }
            .sort(\.$commitedAt, .ascending)
            .all()

        let emptyRow = ShipmentCSVExportRow(boxNumber: "", boxedAt: "", index: "", trackingNumber: "", details: "", boxWeight: "", note: "", shipmentCode: "", shipmentDate: "", customerCode: "")

        let rows: [ShipmentCSVExportRow] = shipments.flatMap { shipment in
            let boxes = shipment.boxes.sorted(by: { lhs, rhs in
                var lhsName = lhs.name
                if let lhsIntName = Int(lhs.name), lhsIntName < 10 {
                    lhsName = "0\(lhsIntName)"
                }
                var rhsName = rhs.name
                if let rhsIntName = Int(rhs.name), rhsIntName < 10 {
                    rhsName = "0\(rhsIntName)"
                }
                return lhsName < rhsName
            })

            let boxRows: [ShipmentCSVExportRow] = boxes.enumerated().flatMap { (boxIndex, box) in
                let trackingItems = box.pieces.map {
                    $0.trackingItem
                }.sorted(by: { lhs, rhs in
                    if lhs.boxedAt == rhs.boxedAt {
                        if lhs.agentCode == rhs.agentCode {
                            return (lhs.customers.first?.customerCode ?? "") < (rhs.customers.first?.customerCode ?? "")
                        }
                        return (lhs.agentCode ?? "") < (rhs.agentCode ?? "")
                    }
                    return lhs.boxedAt ?? Date() < rhs.boxedAt ?? Date()
                })
                
                let customItems = box.customItems.sorted(by: { lhs, rhs in
                    return lhs.createdAt ?? Date() < rhs.createdAt ?? Date()
                })

                let trackingItemRows = trackingItems.enumerated().map { trackingIndex, trackingItem in
                    var trackingNumberCell = trackingItem.trackingNumber
                    if !trackingItem.trackingItemReferences.isEmpty {
                        trackingNumberCell = trackingNumberCell + "\n" + trackingItem.trackingItemReferences.map{ $0.trackingNumber }.joined(separator: "\n")
                    }
                    let customerCodes = trackingItem.$customers.value?.filter{ !$0.customerCode.isEmpty }
                    var targetCustomer: String = ""
                    if let existedCustomerCode = customerCodes, !existedCustomerCode.isEmpty {
                        targetCustomer = existedCustomerCode.map(\.customerCode).joined(separator: ", ")
                    }
                    if !trackingItem.buyerTrackingItems.isEmpty {
                        targetCustomer = targetCustomer + " YCĐB"
                    }
                    
                    var productName = trackingItem.products.description
                    if let warehouseReference = trackingItem.warehouse?.reference, !trackingItem.products.description.isEmpty {
                        productName = productName + " [\(warehouseReference)]"
                    }
                    return ShipmentCSVExportRow(
                        boxNumber: box.name,
                        boxedAt: trackingItem.boxedAt?.toISOString(formattingTimeZone) ?? "",
                        index: 0.description,
                        trackingNumber: trackingNumberCell,
                        details: productName,
                        boxWeight: box.weight?.description ?? "",
                        note: trackingItem.itemDescription ?? "",
                        lotIndex: box.lot?.lotIndex,
                        shipmentCode: shipment.shipmentCode,
                        shipmentDate: shipment.commitedAt?.toISODate(formattingTimeZone) ?? "",
                        customerCode: targetCustomer
                    )
                }
                
                let customItemRows = customItems.enumerated().map { trackingIndex, customItem in
                    return ShipmentCSVExportRow(
                        boxNumber: box.name,
                        boxedAt: customItem.createdAt?.toISOString(formattingTimeZone) ?? "",
                        index: 0.description,
                        trackingNumber: customItem.reference,
                        details: customItem.details,
                        boxWeight: box.weight?.description ?? "",
                        note: "",
                        lotIndex: box.lot?.lotIndex,
                        shipmentCode: shipment.shipmentCode,
                        shipmentDate: shipment.commitedAt?.toISODate(formattingTimeZone) ?? "",
                        customerCode: "")
                }
                
                let allItems: [ShipmentCSVExportRow] = [trackingItemRows, customItemRows].flatMap { $0 }.sorted { lhs, rhs in
                    return lhs.boxedAt < rhs.boxedAt
                }.enumerated().map { index, item in
                    return ShipmentCSVExportRow(
                        boxNumber: index == 0 ? item.boxNumber : "",
                        boxedAt: item.boxedAt,
                        index: (index + 1).description,
                        trackingNumber: item.trackingNumber,
                        details: item.details,
                        boxWeight: item.boxWeight,
                        note: item.note,
                        lotIndex: item.lotIndex,
                        shipmentCode: item.shipmentCode,
                        shipmentDate: item.shipmentDate,
                        customerCode: item.customerCode
                    )
                }

                return [allItems, [emptyRow, emptyRow, emptyRow]].flatMap { $0 }
            }

            return [boxRows, [emptyRow, emptyRow, emptyRow, emptyRow]].flatMap { $0 }
        }
        
        let document = try CSVEncoder().sync.encode(rows)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/csv")
        headers.add(name: .contentDisposition, value: "attachment; filename=\"shipments-\(Date().toISOString())\".csv")
        let response = ClientResponse(status: .ok,
                                      headers: headers,
                                      body: ByteBuffer(data: document))
        return response
    }

    struct DeliCSVExportRow: Content {
        var timestamp: String
        var index: String
        var trackingNumber: String
        var status: String
        var agentCode: String
        var customerCode: String
        var warehouse: String
    }

    private func exportDeliCSVHandler(request: Request) async throws -> ClientResponse {
        let input = try request.query.decode(GetDeliCSVExportInput.self)
        let query = TrackingItem.query(on: request.db)
        
        var fromDate = input.fromDate.dateAtStartOf(.day)
        var toDate = input.toDate.dateAtEndOf(.day)
        var formattingTimeZone = TimeZone.current
        if let timeZoneIdentifier = input.timeZone, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            let fromDateOffset = -timeZone.secondsFromGMT(for: fromDate)
            fromDate = fromDate.addingTimeInterval(TimeInterval(fromDateOffset))
            
            let toDateOffset = -timeZone.secondsFromGMT(for: toDate)
            toDate = toDate.addingTimeInterval(TimeInterval(toDateOffset))
            formattingTimeZone = timeZone
        }
        
        let targetKeyPath: KeyPath<TrackingItem, Date?>
        switch input.targetStatus {
        case .receivedAtUSWarehouse:
            targetKeyPath = \TrackingItem.receivedAtUSAt
            query.filter(\.$receivedAtUSAt != nil)
                .filter(\.$receivedAtUSAt >= fromDate)
                .filter(\.$receivedAtUSAt <= toDate)
		case .repacked:
			targetKeyPath = \TrackingItem.repackedAt
			query.filter(\.$repackedAt != nil)
				.filter(\.$repackedAt >= fromDate)
				.filter(\.$repackedAt <= toDate)
        case .flyingBack:
            targetKeyPath = \TrackingItem.flyingBackAt
            query.filter(\.$flyingBackAt != nil)
                .filter(\.$flyingBackAt >= fromDate)
                .filter(\.$flyingBackAt <= toDate)
        case .receivedAtVNWarehouse:
            targetKeyPath = \TrackingItem.receivedAtVNAt
            query.filter(\.$receivedAtVNAt != nil)
                .filter(\.$receivedAtVNAt >= fromDate)
                .filter(\.$receivedAtVNAt <= toDate)
        default:
            throw AppError.invalidInput
        }

        if let agentCode = input.agentCode {
            query.filter(\.$agentCode == agentCode)
        }
        if let customerID = input.customerID {
            query
                .join(children: \.$trackingItemCustomers)
                .filter(TrackingItemCustomer.self, \.$customer.$id == customerID)
        }
        if let warehouseID = input.warehouseID {
            query.filter(\.$warehouse.$id == warehouseID)
        }
        
        let trackingItems = try await query
            .with(\.$customers)
            .with(\.$trackingItemReferences)
            .with(\.$warehouse)
            .with(\.$buyerTrackingItems)
            .all()
        
        let trackingItemsByDate = try trackingItems.grouped(by: {
            guard let date = $0[keyPath: targetKeyPath] else {
                return ""
            }
            return date.toISODate(formattingTimeZone)
        })
        
        let sortedKeys = trackingItemsByDate.keys.sorted(by: <)
        let rows = sortedKeys.flatMap { date in
            let dateRow = DeliCSVExportRow(timestamp: date, index: "", trackingNumber: "", status: "", agentCode: "", customerCode: "", warehouse: "")
            let trackingsForDate = trackingItemsByDate[date] ?? []
            let sortedTrackings = trackingsForDate.sorted { lhs, rhs in
                if lhs[keyPath: targetKeyPath] == rhs[keyPath: targetKeyPath] {
                    if lhs.agentCode == rhs.agentCode {
                        return (lhs.customers.first?.customerCode ?? "") < (rhs.customers.first?.customerCode ?? "")
                    }
                    return (lhs.agentCode ?? "") < (rhs.agentCode ?? "")
                }
                return lhs[keyPath: targetKeyPath]! < rhs[keyPath: targetKeyPath]!
            }
            
            let trackingRows = sortedTrackings.enumerated().map { index, trackingItem in
                var trackingNumberCell = trackingItem.trackingNumber
                if !trackingItem.trackingItemReferences.isEmpty {
                    trackingNumberCell = trackingNumberCell + "\n" + trackingItem.trackingItemReferences.map{ $0.trackingNumber }.joined(separator: "\n")
                }
                let customerCodes = trackingItem.$customers.value?.filter{ !$0.customerCode.isEmpty }
                var targetCustomer: String = ""
                if let existedCustomerCode = customerCodes, !existedCustomerCode.isEmpty {
                    targetCustomer = existedCustomerCode.map(\.customerCode).joined(separator: ", ")
                }
                if !trackingItem.buyerTrackingItems.isEmpty {
                    targetCustomer = targetCustomer + " YCĐB"
                }
                return DeliCSVExportRow(
                    timestamp: trackingItem[keyPath: targetKeyPath]!.toISOString(formattingTimeZone),
                    index: (index + 1).description,
                    trackingNumber: trackingNumberCell,
                    status: trackingItem.status.rawValue,
                    agentCode: trackingItem.agentCode ?? "",
                    customerCode: targetCustomer,
                    warehouse: trackingItem.warehouse?.name ?? ""
                )
            }
            let emptyRow = DeliCSVExportRow(timestamp: "", index: "", trackingNumber: "", status: "", agentCode: "", customerCode: "", warehouse: "")
            return [[dateRow], trackingRows, [emptyRow]].flatMap { $0 }
        }

        let document = try CSVEncoder().sync.encode(rows)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/csv")
        headers.add(name: .contentDisposition, value: "attachment; filename=\"\(input.targetStatus.rawValue)-\(Date().toISOString())\".csv")
        let response = ClientResponse(status: .ok,
                                      headers: headers,
                                      body: ByteBuffer(data: document))
        return response
    }
}
