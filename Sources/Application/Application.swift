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
    
    func logError(
        line: Int = #line,
        function: String = #function,
        file: String = #file,
        _ message: String,
        _ error: Error
    ) {
        Log.error(
            "\(line) \(function) ERROR: \(message): \(error.localizedDescription)"
        )
    }
    
    func postInit() throws {
        // Set Stencil as template engine
        router.setDefault(templateEngine: StencilTemplateEngine())
        
        // Endpoints
        initializeHealthRoutes(app: self)
        
        router.all("/pikachu", middleware: StaticFileServer(path: "\(rootDirectoryPath)/public/Pikachu"))
        
        router.all("/originals", middleware: StaticFileServer(path: originalsDirectory.path))
        
        router.get("/public*") { request, response, next in
            
            Log.debug("\(#line) \(#function)")
        
            defer { next() }
            
            let fileManager = FileManager()
            
            guard let files = try? fileManager.contentsOfDirectory(
                at: self.originalsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else { return }
            
            try response.render("list", context: ["files": files.map { $0.lastPathComponent }])
        }
        
        router.all("/upload", middleware: BodyParser())
        router.post("/upload") { request, response, next in
            
            func createThumbnail(_ url: URL) -> Data? {
                return nil
            }
            
            defer { next() }
 
            Log.debug("\(#line) \(#function) \(request.queryParameters)")
            
            guard let values = request.body else { return }
            
            Log.debug("\(#line) \(#function)")
            
            guard case .multipart(let parts) = values else { return }
            
            let acceptableTypes = [
                "image/png",
                "image/jpeg",
                "model/vnd.pixar.usd",
                "model/usd",
            ]
            
            for part in parts {
                Log.debug("\(#line) \(#function)")
                
                guard acceptableTypes.contains(part.type) else { continue }
                
                Log.debug("\(#line) \(#function) \(part.type)")
                
                guard case .raw(let data) = part.body else { continue }
                
                let cleanedFilename = part.filename.replacingOccurrences(
                    of: " ",
                    with: "_"
                )
                
                let newURL = self.originalsDirectory.appendingPathComponent(cleanedFilename)
                
                do {
                    try data.write(to: newURL)
                    
                    let thumbsURL = self.thumbsDirectory.appendingPathComponent(cleanedFilename)
                    
                    if let image = createThumbnail(newURL) {
                        do {
                            try image.write(to: thumbsURL)
                        } catch let error {
                            self.logError("writing thumbnail file \(thumbsURL)", error)
                        }
                    }
                } catch let error {
                    self.logError("writing original file \(newURL)", error)
                }
            }
            
            try response.redirect("/public")
        }
    }
    
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: 9000 /*cloudEnv.port*/, with: router)
        Kitura.run()
    }
}
