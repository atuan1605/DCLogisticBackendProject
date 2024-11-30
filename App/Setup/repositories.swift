import Foundation
import Vapor
import JWT

public func setupRepositories(app: Application) throws {
    app.jwt.signers.use(.hs256(key: "atuan1605"))
    app.fileStorages.use { req in
        return AzureStorageRepository(request: req)
    }

    app.azureStorageName = Environment.process.AZURE_STORAGE_NAME
    app.azureStorageKey = Environment.process.AZURE_STORAGE_ACCESS_KEY
    
    try app.loadGoogleConfig()
    app.google.use { req in
        return DefaultGoogleCloudRepository(
            config: app.googleCloudConfig!,
            client: req.client
        )
    }
    app.dcClient.use { req in
        return DefaultDCClientRepository(
            baseURL: Environment.process.DCClient_BASE_URL ?? "",
            client: req.client)
    }
    app.emails.use { req in
        return SendGridEmailRepository(
            appFrontendURL: req.application.appFrontendURL ?? "",
            queue: req.queue,
            db: req.db,
            eventLoop: req.eventLoop
        )
    }
    
    app.trackingItems.use { req in
        return DatabaseTrackingItemRespository(db: req.db, request: req)
    }
    
    app.buyerTrackingItemLinkViews.use { request in
        return DatabaseBuyerTrackingItemLinkViewRepository(db: request.db)
    }
    
    app.buyerTrackingItems.use { request in
        return DatabaseBuyerTrackingItemRepository(db: request.db, request: request)
    }
    
    app.appFrontendURL = Environment.process.FRONTEND_URL
    
    app.googleCloudSpreadSheet = "1EodDepVHd6C_Dhxu61z79GTXZnLkn1JkiHibGKPlSDo"
	app.isLoggingToGoogleSheetEnabled = Environment.process.IS_LOGGING_TO_GOOGLE_SHEET_ENABLED == "True" ? true : false
    if (Environment.process.SENDGRID_API_KEY != nil) {
        app.sendgrid.initialize()
    }
}
