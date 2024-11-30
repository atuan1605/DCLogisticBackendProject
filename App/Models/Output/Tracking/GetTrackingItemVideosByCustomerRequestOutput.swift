import Vapor
import Foundation

struct GetTrackingItemVideosByCustomerRequestOutput: Content {
    var trackingID: TrackingItem.IDValue?
    var trackingNumber: String?
    var packingVideoID: String?
    var downloadState: GetTrackingItemPackingVideoOutput.DownloadState?
    var finishedAt: Date?
    var files: [String]?
    var description: String?
    var flagAt: Date?
    var feedback: TrackingItem.CustomerFeedback?
    let receivedAtUSAt: Date?
    let boxedAt: Date?
    let flyingBackAt: Date?
    let receivedAtVNAt: Date?
    let customerNote: String?
    let packingRequestNote: String?
    let customerEmail: [String]?
}

extension TrackingItem {
    func outputPackingVideoByCustomerRequest() -> GetTrackingItemVideosByCustomerRequestOutput {
        var files = self.files
        if files.isEmpty, let product = self.$products.value?.first {
            files = product.images
        }
        var downloadState: GetTrackingItemPackingVideoOutput.DownloadState = .extractVideo
        if let queue = self.$packingVideoQueues.value?.first {
            if queue.finishedAt == nil {
                downloadState = .extracting
            } else {
                if self.packingVideoFile != nil {
                    downloadState = .downloadVideo
                } else {
                    downloadState = .fail
                }
            }
        }
        return .init (
            trackingID: self.id,
            trackingNumber: self.trackingNumber,
            packingVideoID: self.packingVideoFile,
            downloadState: downloadState,
            finishedAt: self.$packingVideoQueues.value?.first?.finishedAt,
            files: files,
            description: self.brokenProduct.description,
            flagAt: self.brokenProduct.flagAt,
            feedback: self.brokenProduct.customerFeedback,
            receivedAtUSAt: self.receivedAtUSAt,
            boxedAt: self.boxedAt,
            flyingBackAt: self.flyingBackAt,
            receivedAtVNAt: self.receivedAtVNAt,
            customerNote: self.$buyerTrackingItems.value?.first?.customerNote,
            packingRequestNote: self.$buyerTrackingItems.value?.first?.packingRequestNote,
            customerEmail: self.$customers.value?.map{ $0.email ?? "" }
        )
    }
}
