import Vapor
import Foundation

struct GetTrackingItemPackingVideoOutput: Content {
    enum DownloadState: String, Codable {
        case extractVideo
        case extracting
        case downloadVideo
        case fail
    }
    
    var trackingID: TrackingItem.IDValue?
    var trackingNumber: String?
    var packingVideoID: String?
    var downloadState: DownloadState?
    var finishedAt: Date?
    var file: String?
    var customerCode: String?
    var queueID: VideoDownloadingJob.IDValue?
    var warehouseName: String?
}

extension TrackingItem {
    func packingVideoOutput() -> GetTrackingItemPackingVideoOutput {
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
        return .init(
            trackingID: self.id,
            trackingNumber: self.trackingNumber,
            packingVideoID: self.packingVideoFile,
            downloadState: downloadState,
            finishedAt: self.$packingVideoQueues.value?.first?.finishedAt,
            file: files.first,
            customerCode: self.$customers.value?.map(\.customerCode).joined(separator: ", "),
            queueID: self.$packingVideoQueues.value?.first?.id,
            warehouseName: self.$warehouse.value??.name
        )
    }
}

