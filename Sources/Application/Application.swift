import Foundation
import Kitura
import KituraStencil
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()
    
    var rootDirectoryPath: String {
        let fileManager = FileManager()
        let currentPath = fileManager.currentDirectoryPath
        return currentPath
    }
    
    var rootDirectory: URL { URL(fileURLWithPath: rootDirectoryPath) }
    var publicDirectory: URL { rootDirectory.appendingPathComponent("public") }
    var uploadsDirectory: URL { publicDirectory.appendingPathComponent("uploads") }
    var originalsDirectory: URL { uploadsDirectory.appendingPathComponent("originals") }
    var thumbsDirectory: URL { uploadsDirectory.appendingPathComponent("thumbs") }
    
    public init() throws {
        // Configure logging
        initializeLogging()
        // Run the metrics initializer
        initializeMetrics(router: router)
    }
    
    func postInit() throws {
        // Set Stencil as template engine
        router.setDefault(templateEngine: StencilTemplateEngine())
        
        // Endpoints
        initializeHealthRoutes(app: self)
        
        print(#line, #function)
        
        router.all("/pikachu", middleware: StaticFileServer(path: "\(rootDirectoryPath)/public/Pikachu"))
        
        print(#line, #function)
        
        router.all("/originals", middleware: StaticFileServer(path: originalsDirectory.path))
        
        print(#line, #function)
        
        router.get("/public*") { request, response, next in
            defer { next() }
            
            let fileManager = FileManager()
            
            guard let files = try? fileManager.contentsOfDirectory(
                at: self.originalsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else { return }
            
            try response.render("list", context: ["files": files.map { $0.lastPathComponent }])
        }
    }
    
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: 9000 /*cloudEnv.port*/, with: router)
        Kitura.run()
    }
}
