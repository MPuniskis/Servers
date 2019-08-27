import Foundation
import CoreData

internal extension CodingUserInfoKey {
    static let context = CodingUserInfoKey(rawValue: "context")
    static let model = CodingUserInfoKey(rawValue: "model")
}

public enum ServersError: Error {
    case badResponse
    case dataError
}

public protocol ServersChangeHandler: class {
    func serversFetchCompleted()
}

public final class Servers: NSObject {
    
    public static let shared = Servers()
    
    public weak var changeHandler: ServersChangeHandler?
    
    private var bundleID: String { return "com.cookieCrust.Servers" }
    private var serverModel: String { return "ServerModel" }
    private var srversURL: String { return "http://playground.tesonet.lt/v1/servers" }
    
    private lazy var persistentContainer: NSPersistentContainer? = {
        let bundle = Bundle(identifier: bundleID)
        let modelURL = bundle?.url(forResource: serverModel, withExtension: "momd")
        guard let url = modelURL, let managedObjectModel = NSManagedObjectModel(contentsOf: url) else { return nil }
        
        let container = NSPersistentContainer(name: serverModel, managedObjectModel: managedObjectModel)
        container.loadPersistentStores { descriptor, error in
            if let error = error {
                fatalError("Failed loading persistent store with error: \(error)")
            }
        }
        return container
    }()
    
    public var servers: [ServerModel]? {
        guard let context = persistentContainer?.viewContext else { return nil }
        let request = NSFetchRequest<ServerModel>(entityName: serverModel)
        do {
            let servers = try context.fetch(request)
            return servers.isEmpty ? nil : servers
        } catch {
            return nil
        }
    }
}

public extension Servers {
    
    func fetch(with authentication: String) {
        clear()
        guard let request = request(with: authentication) else { return }
        dataTask(with: request) { error, data in
            guard error == nil, let data = data else { return }
            DispatchQueue.main.async {
                self.parse(data)
            }
        }
    }
}

extension Servers {
    
    private func request(with authentication: String) -> URLRequest? {
        guard let url = URL(string: srversURL) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 120)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authentication)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func dataTask(with request: URLRequest, completion: @escaping (_ error: Error?, _ data: Data?)->Void) {
        
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                completion(ServersError.badResponse, nil)
                return
            }
            switch response.statusCode {
            case 200...299: completion(nil, data)
            default: completion(ServersError.dataError, nil)
            }
        }
        task.resume()
    }
}

extension Servers {
    
    private func clear() {
        guard let context = persistentContainer?.viewContext else { return }
        let request = NSFetchRequest<ServerModel>(entityName: serverModel)
        do {
            let servers = try context.fetch(request)
            servers.forEach({ context.delete($0) })
            print(servers.count)
            try context.save()
        } catch {
            print(error)
            return
        }
    }
    
    private func parse(_ data: Data) {
        guard
            let contextKey = CodingUserInfoKey.context,
            let modelKey = CodingUserInfoKey.model
            else { return }
        let decoder = JSONDecoder()
        decoder.userInfo[contextKey] = self.persistentContainer?.viewContext
        decoder.userInfo[modelKey] = self.serverModel

        guard let _ = try? decoder.decode([ServerModel].self, from: data) else { return }
//        clear()
        do {
            try persistentContainer?.viewContext.save()
            changeHandler?.serversFetchCompleted()
        } catch {
            print(error)
            return
        }
    }
}
