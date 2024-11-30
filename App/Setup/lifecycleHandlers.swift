
import Foundation
import Vapor

public func lifecycleHandlers(app: Application) throws {
    app.lifecycle.use(MasterSellerRegistration())
}
