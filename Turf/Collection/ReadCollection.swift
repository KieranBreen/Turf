public class ReadCollection<TCollection: Collection>: ReadableCollection {
    /// Collection row type
    public typealias Value = TCollection.Value

    // MARK: Public properties

    /// Collection name
    var name: String { return collection.name }

    /// Collection schema version - This must be incremented when the serialization structure changes
    var schemaVersion: UInt { return collection.schemaVersion }

    // MARK: Internal properties

    /// Reference to user defined collection
    internal unowned let collection: TCollection

    /// Reference to read transaction from which this collection reads on
    internal unowned let readTransaction: ReadTransaction

    /// Internal attributes required for functionality
    internal let localStorage: CollectionLocalStorage<Value>

    // MARK: Object lifecycle

    /**
     - parameter collection: Collection this read-only view wraps
     - parameter transaction: Read transaction the read-only view reads on
     */
    internal init(collection: TCollection, transaction: ReadTransaction) {
        self.collection = collection
        self.readTransaction = transaction
        self.localStorage = readTransaction.connection.localStorageForCollection(collection)
    }

    // MARK: Public methods

    /**
     - returns: Number of keys in the collection
    */
    public var numberOfKeys: UInt {
        return 0
    }

    /**
     - returns: Primary keys in collection
     */
    public var allKeys: [String] {
        return []
    }

    /**
     Lazyily iterates over all values in the collection
     - warning: A ValueSequence is not a `struct` as it requires a `deinit` hook for safety
     - returns: All values in the collection
     */
    public var allValues: ValuesSequence<Value> {
        var stmt: COpaquePointer = nil
        sqlite3_prepare_v2(readTransaction.connection.sqlite.db, "SELECT data FROM table",  -1, &stmt, nil)
        return ValuesSequence(stmt: stmt, valueDataColumnIndex: 1, deserializer: collection.deserializeValue)
    }

    /**
     Fetch the latest value from the database.
     - note: This can either hit the value cache or hit the database and deserialize the data blob.
     - parameter key: Primary key
     - returns: Value for primary key if it exists
     */
    public func valueForKey(key: String) -> Value? {
        if let cachedValue = localStorage.valueCache[key] {
            return cachedValue
        }

        return nil
    }

    /**
     Registers a change set observer that will persist beyond the current transaction
     - parameter observer: Handler for change set that will be called post-transaction each time this collection changes
     - returns: A token that is used to unregister this change set observer
     */
    public func registerPermamentChangeSetObserver(observer: (ChangeSet<String> -> Void)) -> String {
        let token = NSUUID().UUIDString

        return token
    }

    /**
     Unregister a previously registered change set observer
     - parameter token: A token returned from `registerPermamentChangeSetObserver(_)`
     - seeAlso: `registerPermamentChangeSetObserver(_)`
     */
    public func unregisterPermamentChangeSetObserver(token: String) {
//        collectionObservers[collection.name]?[token] = nil
    }

}