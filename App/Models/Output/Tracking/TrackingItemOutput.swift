import Vapor
import Foundation

struct TrackingItemOutput: Content {
    let id: TrackingItem.IDValue?
    let trackingNumber: String
    let customerCode: String?
    let agentCode: String?
    let receivedAtUSAt: Date?
    let repackingAt: Date?
    let repackedAt: Date?
    let boxedAt: Date?
    let flyingBackAt: Date?
    let receivedAtVNAt: Date?
    let packedAtVnAt: Date?
    let packboxComitedAt: Date?
    let status: TrackingItem.Status?
    var files: [String]?
    let itemDescription: String?
    var products: [ProductOutput]?
    let chain: String?
    let updatedAt: Date?
    let boxName: String?
    let shipmentCode: String?
    let lots: String?
    let brokenProduct: BrokenProduct?
    let chainedTrackingItems: [TrackingItemOutput]?
    let productDescription: String?
    let warehouse: WarehouseOutput?
    let isWalmartTracking: Bool?
    let alternativeRef: String?
    let returnRequestAt: Date?
    let registeredAt: Date?
    let pieces: [GetTrackingItemPieceOutput]?
    let piecesCount: Int?
    let customers: [CustomerOutput]?
    let trackingItemReferences: String?
    let cameraDetail: TrackingCameraDetailOutput?
    let isDeleted: Bool?
    let holdState: TrackingItem.HoldState?
    let buyerTrackingItems: [BuyerTrackingItemOutput]?
    let allAccessCheckTrackingWithImages: Bool?
    
    internal init(id: TrackingItem.IDValue? = nil, trackingNumber: String, customerCode: String? = nil, agentCode: String? = nil, receivedAtUSAt: Date? = nil,repackingAt: Date? = nil, repackedAt: Date? = nil, boxedAt: Date? = nil, flyingBackAt: Date? = nil, receivedAtVNAt: Date? = nil, packedAtVnAt: Date? = nil, packboxComitedAt: Date? = nil, status: TrackingItem.Status? = nil, files: [String]? = nil, itemDescription: String? = nil, products: [ProductOutput]? = nil, chain: String? = nil, updatedAt: Date? = nil, boxName: String? = nil, shipmentCode: String? = nil, lots: String? = nil, brokenProduct: BrokenProduct? = nil, chainedTrackingItems: [TrackingItemOutput]? = nil, productDescription: String? = nil, warehouse: WarehouseOutput? = nil, isWalmartTracking: Bool? = nil, alternativeRef: String? = nil, returnRequestAt: Date? = nil, registeredAt: Date? = nil, pieces: [GetTrackingItemPieceOutput]? = nil, piecesCount: Int? = nil, customers: [CustomerOutput]? = nil, trackingItemReferences: String? = nil, cameraDetail: TrackingCameraDetailOutput? = nil, isDeleted: Bool? = nil, holdState: TrackingItem.HoldState? = nil, buyerTrackingItems: [BuyerTrackingItemOutput]? = nil, allAccessCheckTrackingWithImages: Bool? = nil) {
        self.id = id
        self.trackingNumber = trackingNumber
        self.customerCode = customerCode
        self.agentCode = agentCode
        self.receivedAtUSAt = receivedAtUSAt
        self.repackingAt = repackingAt
        self.repackedAt = repackedAt
        self.boxedAt = boxedAt
        self.flyingBackAt = flyingBackAt
        self.receivedAtVNAt = receivedAtVNAt
        self.packedAtVnAt = packedAtVnAt
        self.packboxComitedAt = packboxComitedAt
        self.status = status
        self.files = files
        self.itemDescription = itemDescription
        self.products = products
        self.chain = chain
        self.updatedAt = updatedAt
        self.boxName = boxName
        self.shipmentCode = shipmentCode
        self.lots = lots
        self.brokenProduct = brokenProduct
        self.chainedTrackingItems = chainedTrackingItems
        self.productDescription = productDescription
        self.warehouse = warehouse
        self.isWalmartTracking = isWalmartTracking
        self.alternativeRef = alternativeRef
        self.returnRequestAt = returnRequestAt
        self.registeredAt = registeredAt
        self.pieces = pieces
        self.piecesCount = piecesCount
        self.customers = customers
        self.trackingItemReferences = trackingItemReferences
        self.cameraDetail = cameraDetail
        self.isDeleted = isDeleted
        self.holdState = holdState
        self.buyerTrackingItems = buyerTrackingItems
        self.allAccessCheckTrackingWithImages = allAccessCheckTrackingWithImages
    }
}

extension TrackingItem {
    func output() -> TrackingItemOutput {
        var files = self.files
        if files.isEmpty, let product = self.$products.value?.first {
            files = product.images
        }
        let customers = self.$customers.value?.map { $0.output() }
        let lotIndex = self.$pieces.value?.compactMap {
            $0.$box.wrappedValue?.$lot.value??.lotIndex
        }
        let trackingNumberReferences = self.$trackingItemReferences.value?.compactMap({ item in
            item.trackingNumber
        })
        let trackingNumbers = trackingNumberReferences?.joined(separator: ", ")
        let cameraDetail = self.requireCameraDetail()?.output()
        let now = Date()
        var isDeleted : Bool = false
        if let deletedAt = self.deletedAt {
            isDeleted = deletedAt < now
        }
        let customerCode = self.$customers.value?.filter{ !$0.customerCode.isEmpty }
        var targetCustomer: String? = nil
        if let customerCode = customerCode, !customerCode.isEmpty {
            targetCustomer = customerCode.map(\.customerCode).joined(separator: ", ")
        }
        let buyerTrackingItems = self.$buyerTrackingItems.value?.compactMap { $0.output() }
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            customerCode: targetCustomer,
            agentCode: self.agentCode,
            receivedAtUSAt: self.receivedAtUSAt,
            repackingAt: self.repackingAt,
            repackedAt: self.repackedAt,
            boxedAt: self.boxedAt,
            flyingBackAt: self.flyingBackAt,
            receivedAtVNAt: self.receivedAtVNAt,
            packedAtVnAt: self.packedAtVNAt,
            packboxComitedAt: self.packBoxCommitedAt,
            status: self.status,
            files: files,
            itemDescription: self.itemDescription,
            products: self.$products.value?.map {
                $0.toOutput()
            },
            chain: self.chain,
            updatedAt: self.updatedAt,
            boxName: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.name }.uniqued().joined(separator: ", "),
            shipmentCode: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.$shipment.value??.shipmentCode }.uniqued().joined(separator: ", "),
            lots: lotIndex?.uniqued().joined(separator: ", "),
            brokenProduct: self.brokenProduct,
            chainedTrackingItems: nil,
            productDescription: self.$products.value?.description,
            warehouse: self.$warehouse.value??.output(),
            isWalmartTracking: self.$isWalmartTracking.value,
            alternativeRef: self.alternativeRef,
            returnRequestAt: self.returnRequestAt,
            registeredAt: self.registeredAt,
            pieces: self.$pieces.value?.map {
                $0.output(trackingNumber: self.trackingNumber)
            },
            piecesCount: self.$pieces.value?.filter { $0.$box.id == nil }.count,
            customers: customers,
            trackingItemReferences: trackingNumbers,
            cameraDetail: cameraDetail,
            isDeleted: isDeleted,
            holdState: self.holdState,
            buyerTrackingItems: buyerTrackingItems,
            allAccessCheckTrackingWithImages: self.allAccessCheckTrackingWithImages
        )
    }
    
    func outputWithChainItems(_ chainItems: [TrackingItemOutput]) -> TrackingItemOutput {
        var files = self.files
        if files.isEmpty, let product = self.$products.value?.first {
            files = product.images
        }
        let customers = self.$customers.value?.map { $0.output() }
        let lotIndex = self.$pieces.value?.compactMap {
            $0.$box.wrappedValue?.$lot.value??.lotIndex
        }
        let trackingNumberReferences = self.$trackingItemReferences.value?.compactMap({ item in
            item.trackingNumber
        })
        let trackingNumbers = trackingNumberReferences?.joined(separator: ", ")
        
        var cameraDetail: TrackingCameraDetailOutput? = nil
        cameraDetail = chainItems.compactMap { $0.cameraDetail }.sorted {
            $0.recordFinishAt ?? .distantPast > $1.recordFinishAt ?? .distantPast
        }.first
        if cameraDetail == nil {
            cameraDetail = self.requireCameraDetail()?.output()
        }
        let now = Date()
        var isDeleted : Bool = false
        if let deletedAt = self.deletedAt {
            isDeleted = deletedAt < now
        }
        let customerCode = self.$customers.value?.filter{ !$0.customerCode.isEmpty }
        var targetCustomer: String? = nil
        if let customerCode = customerCode, !customerCode.isEmpty {
            targetCustomer = customerCode.map(\.customerCode).joined(separator: ", ")
        }
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            customerCode: targetCustomer,
            agentCode: self.agentCode,
            receivedAtUSAt: self.receivedAtUSAt,
            repackingAt: self.repackingAt,
            repackedAt: self.repackedAt,
            boxedAt: self.boxedAt,
            flyingBackAt: self.flyingBackAt,
            receivedAtVNAt: self.receivedAtVNAt,
            packedAtVnAt: self.packedAtVNAt,
            packboxComitedAt: self.packBoxCommitedAt,
            status: self.status,
            files: files,
            itemDescription: self.itemDescription,
            products: self.$products.value?.map {
                $0.toOutput()
            },
            chain: self.chain,
            updatedAt: self.updatedAt,
            boxName: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.name }.uniqued().joined(separator: ", "),
            shipmentCode: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.$shipment.value??.shipmentCode }.uniqued().joined(separator: ", "),
            lots: lotIndex?.uniqued().joined(separator: ", "),
            brokenProduct: self.brokenProduct,
            chainedTrackingItems: chainItems,
            productDescription: self.$products.value?.description,
            warehouse: self.$warehouse.value??.output(),
            isWalmartTracking: self.$isWalmartTracking.value,
            alternativeRef: self.alternativeRef,
            returnRequestAt: self.returnRequestAt,
            registeredAt: self.registeredAt,
            pieces: self.$pieces.value?.map {
                $0.output(trackingNumber: self.trackingNumber)
            },
            piecesCount: self.$pieces.value?.filter { $0.$box.id == nil }.count,
            customers: customers,
            trackingItemReferences: trackingNumbers,
            cameraDetail: cameraDetail,
            isDeleted: isDeleted,
            allAccessCheckTrackingWithImages: self.allAccessCheckTrackingWithImages
        )
    }
    
    func outputByChain() -> TrackingItemOutput {
        var files = self.files
        if files.isEmpty, let product = self.$products.value?.first {
            files = product.images
        }
        let customers = self.$customers.value?.map { $0.output() }
        return .init(id: self.id, trackingNumber: self.trackingNumber, agentCode: self.agentCode,  files: files, chain: self.chain, brokenProduct: self.brokenProduct, productDescription: self.$products.value?.description, customers: customers, allAccessCheckTrackingWithImages: self.allAccessCheckTrackingWithImages)
    }
}
