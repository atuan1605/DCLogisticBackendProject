import Vapor

func routes(_ app: Application) throws {
//        app.get { req async in
//        "It works!"
//    }
//
//    app.get("hello") { req async -> String in
//        "Hello, world!"
//    }
    let apiRoutes = app.grouped("api", "v1")
}
