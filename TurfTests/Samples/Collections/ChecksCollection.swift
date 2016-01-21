import Foundation
import Turf

final class ChecksCollection: Collection, IndexedCollection, FTSCollection, CollectionWithRelationships {
    typealias Value = Check

    let name = "Checks"
    let schemaVersion = UInt64(1)
    let valueCacheSize: Int? = 50

    let index: SecondaryIndex<ChecksCollection, IndexedProperties>
    let indexed = IndexedProperties()

    let fts: FullTextSearch<ChecksCollection, FTSProperties>
    let textProperties = FTSProperties()

    let relationships = Relationships()

    let associatedExtensions: [Extension]

    init() {
        index = SecondaryIndex(collectionName: name, properties: indexed)
        fts = FullTextSearch(collectionName: name, properties: textProperties)
        associatedExtensions = [index]
    }

    func setUp(transaction: ReadWriteTransaction) {
        transaction.registerCollection(self)
        transaction.registerExtension(index)
    }

    func serializeValue(value: Value) -> NSData {
        //TODO
        return value.uuid.dataUsingEncoding(NSUTF8StringEncoding)!
    }

    func deserializeValue(data: NSData) -> Value? {
        if let uuid = String(data: data, encoding: NSUTF8StringEncoding) {
            return Check(uuid: uuid, name: "", isOpen: true, isCurrent: false, lineItemUuids: [])
        } else {
            return nil
        }
    }

    struct IndexedProperties: Turf.IndexedProperties {
        let isOpen = IndexedProperty<ChecksCollection, Bool>(name: "isOpen") { return $0.isOpen }
        let name = IndexedProperty<ChecksCollection, String?>(name: "name") { return $0.name }
        let isCurrent = IndexedProperty<ChecksCollection, Bool>(name: "isCurrent") { return $0.isCurrent }

        var allProperties: [CollectionProperty] {
            return [isOpen, name, isCurrent]
        }
    }

    struct FTSProperties: Turf.FTSProperties {
        let name = FTSProperty<ChecksCollection>(name: "name") { return $0.name ?? "" }

        var allProperties: [FTSProperty<ChecksCollection>] {
            return [name]
        }
    }

    struct Relationships: Turf.RelatedCollections {
        let lineItems = ToManyRelationshipProperty<ChecksCollection, LineItemsCollection>(
            name: "lineItems",
            sourceKeyFromSourceValue: { check -> String in
                return check.uuid
            }, destinationKeysFromSourceValue: { (check, lineItemsCollection) -> [String] in
                return check.lineItemUuids
            })

        var toOneRelationships: [CollectionProperty] {
            return []
        }

        var toManyRelationships: [CollectionProperty] {
            return [lineItems]
        }
    }
}