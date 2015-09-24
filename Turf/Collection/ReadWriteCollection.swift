public final class ReadWriteCollection<TCollection: Collection>: ReadCollection<TCollection>, WritableCollection {
    // MARK: Internal properties

    /// Reference to read-write transaction from which this collection operates on
    internal unowned let readWriteTransaction: ReadWriteTransaction

    // MARK: Private properties

    /// Work around to stop swift segfaulting when calling self.collection.serializeValue(...)
    private let serializeValue: (Value) -> NSData

    // MARK: Object lifecycle

    /**
     - parameter collection: Collection this read-write view wraps
     - parameter transaction: Read-write transaction the read-write view operates on
    */
    internal init(collection: TCollection, transaction: ReadWriteTransaction) {
        self.readWriteTransaction = transaction
        //TODO Remove this local property when calling this directly stops segfaulting swiftc
        self.serializeValue = collection.serializeValue
        super.init(collection: collection, transaction: transaction)
    }

    // MARK: Public methods

    /**
     Set a value in the collection with `key`
     - parameter value: Value
     - parameter key: Primary key for `value`
     */
    public func setValue(value: Value, forKey key: String) {
        commonSetValue(value, forKey: key)
    }

    /**
     Remove values with the given primary keys
     - parameter keys: Primary keys of the values to remove
     */
    public func removeValuesWithKeys(keys: [String]) {
        commonRemoveValuesWithKeys(keys)
    }

    /**
     Remove all values in the collection
     */
    public func removeAllValues() {
        commonRemoveAllValues()
    }

    // MARK: Private methods

    private func commonSetValue(value: Value, forKey key: String) -> SQLiteRowChangeType {
        let _ = serializeValue(value)
        let rowChange: SQLiteRowChangeType = .Insert(rowId: 0)
        switch rowChange {
        case .Insert(_): localStorage.changeSet.recordValueInsertedWithKey(key)
        case .Update(_): localStorage.changeSet.recordValueUpdatedWithKey(key)
        }
        localStorage.valueCache[key] = value
        localStorage.cacheUpdates.recordValue(value, upsertedWithKey: key)

        readWriteTransaction.connection.recordModifiedCollection(collection)

        return rowChange
    }

    private func commonRemoveValuesWithKeys(keys: [String]) {
        for key in keys {
            localStorage.valueCache.removeValueForKey(key)
            localStorage.changeSet.recordValueRemovedWithKey(key)
            localStorage.cacheUpdates.recordValueRemovedWithKey(key)
        }
        readWriteTransaction.connection.recordModifiedCollection(collection)
    }

    private func commonRemoveAllValues() {
        localStorage.valueCache.removeAllValues()
        localStorage.changeSet.recordAllValuesRemoved()
        localStorage.cacheUpdates.recordAllValuesRemoved()
        readWriteTransaction.connection.recordModifiedCollection(collection)
    }
}

public extension ReadWriteCollection where TCollection: ExtendedCollection {
    /**
     Set a value in the collection with `key`
     - note: Executes any associated extensions
     - parameter value: Value
     - parameter key: Primary key for `value`
     */
    public func setValue(value: Value, forKey key: String) {
        let rowChange: SQLiteRowChangeType = commonSetValue(value, forKey: key)
        
        let connection = readWriteTransaction.connection
        switch rowChange {
        case .Insert(let rowId):
            for ext in collection.associatedExtensions {
                let extConnection = connection.connectionForExtension(ext)
                let extTransaction = extConnection.writeTransaction(readWriteTransaction)

                extTransaction.handleValueInsertion(value, forKey: key, rowId: rowId, inCollection: collection)
            }

        case .Update(let rowId):
            for ext in collection.associatedExtensions {
                let extConnection = connection.connectionForExtension(ext)
                //TODO Investigate the potential of caching extension write transactions on the connection
                let extTransaction = extConnection.writeTransaction(readWriteTransaction)

                extTransaction.handleValueUpdate(value, forKey: key, rowId: rowId, inCollection: collection)
            }
        }
    }

    /**
     Remove values with the given primary keys
     - note: Executes any associated extensions
     - parameter keys: Primary keys of the values to remove
     */
    public func removeValuesWithKeys(keys: [String]) {
        commonRemoveValuesWithKeys(keys)

        let connection = readWriteTransaction.connection
        for ext in collection.associatedExtensions {
            let extConnection = connection.connectionForExtension(ext)
            let extTransaction = extConnection.writeTransaction(readWriteTransaction)

            extTransaction.handleRemovalOfRowsWithKeys(keys, inCollection: collection)
        }
    }

    /**
     Remove all values in the collection
     - note: Executes any associated extensions
     */
    public func removeAllValues() {
        commonRemoveAllValues()

        let connection = readWriteTransaction.connection
        for ext in collection.associatedExtensions {
            let extConnection = connection.connectionForExtension(ext)
            let extTransaction = extConnection.writeTransaction(readWriteTransaction)

            extTransaction.handleRemovalOfAllRowsInCollection(collection)
        }
    }
}
