import Fluent
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    if (app.environment == .development) {
        app.logger.logLevel = .debug
    }

    let decoder = URLEncodedFormDecoder(configuration: .init(dateDecodingStrategy: .iso8601))
    ContentConfiguration.global.use(urlDecoder: decoder)

    try middlewares(app: app)

    // setup repositories:
    try setupRepositories(app: app)

    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    try databases(app)
    try redis(app: app)
    try modelMiddlewares(app)
    try jobs(app: app)

    // migrates
    try migrates(app)
    
    // register routes
    try routes(app)
    
    // lifeCycleHandlers
    try lifecycleHandlers(app: app)
}
