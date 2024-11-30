import Fluent
import Vapor

func routes(_ app: Application) throws {
//    app.get { req async in
//        "It works!"
//    }
//
//    app.get("hello") { req async -> String in
//        "Hello, world!"
//    }
    try app.register(collection: TestController())
    let apiRoutes = app.grouped("api", "v1")
    try apiRoutes.register(collection: AuthController())
    try apiRoutes.register(collection: FileController())
    try apiRoutes.register(collection: AgentController())
    try apiRoutes.register(collection: DashboardController())
    try apiRoutes.register(collection: CustomerController())
    try apiRoutes.register(collection: WarehouseController())
//    try apiRoutes.register(collection: DCClientResponseController())
    try apiRoutes.register(collection: BuyerController())
    let trackableRoutes = apiRoutes.grouped(ActionLoggerMiddleware())
    try trackableRoutes.register(collection: UserController())
    try trackableRoutes.register(collection: LabelController())
    try trackableRoutes.register(collection: LabelProductController())
    try trackableRoutes.register(collection: ChainController())
    try trackableRoutes.register(collection: TrackingController())
    try trackableRoutes.register(collection: ShipmentController())
    try trackableRoutes.register(collection: DeliveryController())
    try trackableRoutes.register(collection: ProductController())
    try trackableRoutes.register(collection: LotController())
    try trackableRoutes.register(collection: ReportController())
    try trackableRoutes.register(collection: UploadPackingVideoController())
    try trackableRoutes.register(collection: CameraController())
    try trackableRoutes.register(collection: BuyerTrackedItemController())
    try trackableRoutes.register(collection: CustomerRequestController())

    if app.environment == .development {
        try app.register(collection: TestController())
    }
}
