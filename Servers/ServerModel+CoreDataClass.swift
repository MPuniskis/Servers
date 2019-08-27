import Foundation
import CoreData

@objc(ServerModel)
public final class ServerModel: NSManagedObject, Decodable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case distance
    }
    
    public convenience init(from decoder: Decoder) throws {
        
        guard
            let contextKey = CodingUserInfoKey.context,
            let modelKey = CodingUserInfoKey.model,
            let moc = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let model = decoder.userInfo[modelKey] as? String
        else {
            fatalError()
        }

        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let name = try container.decode(String.self, forKey: .name)
            let distance = try container.decode(Int64.self, forKey: .distance)
            
            guard let entity = NSEntityDescription.entity(forEntityName: model, in: moc) else {
                fatalError()
            }
            
            self.init(entity: entity, insertInto: moc)
            self.name = name
            self.distance = distance
            
        } catch {
            print(error)
            throw error
        }
    }

}
