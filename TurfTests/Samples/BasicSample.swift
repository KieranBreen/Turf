import XCTest
import Turf

class BasicSample: XCTestCase {
    var collections: Collections!
    var db: Database!
    override func setUp() {
        super.setUp()

        collections = Collections()
        db = try! Database(path: "/Users/jordanhamill/basic2.sqlite", collections: collections)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        let expectation = expectationWithDescription("just waiting to test stuff")

        let connection = try! db.newConnection()
        let connection2 = try! db.newConnection()

        NSNotificationCenter.defaultCenter().addObserverForName(Database.CollectionChangedNotification, object: collections.Checks, queue: nil) { notification in
            let changeSet = notification.userInfo?[Database.CollectionChangedNotificationChangeSetKey] as? ChangeSet<String>
            print(changeSet?.changes)
        }

        let openChecksCountQuery =
            try!connection.prepareQueryFor(collections.Checks,
                                           countWhere: collections.Checks.indexed.isOpen.equals(true))
        
        try! connection.readWriteTransaction { transaction in
            print("connection 1 write 1")
            let checksCollection = transaction.readWrite(self.collections.Checks)
            checksCollection.removeAllValues()

            let check = Check(uuid: "A", name: "A", isOpen: true, isCurrent: false, lineItemUuids: [])
            checksCollection.setValue(check, forKey: "1234")

            let check2 = Check(uuid: "AV", name: "AV", isOpen: true, isCurrent: false, lineItemUuids: [])

            checksCollection.setValue(check2, forKey: "1235")
            print(checksCollection.valueForKey("1234")?.uuid)

        }

        try! connection.readWriteTransaction { transaction in
            print("connection 1 write 2")
            let checksCollection = transaction.readWrite(self.collections.Checks)

            print("all: \(checksCollection.findValuesWhere(checksCollection.indexed.isOpen.equals(true)))")
            print("first: \(checksCollection.findFirstValueWhere(checksCollection.indexed.isOpen.equals(true)))")

            print(checksCollection.valueForKey("1234")?.uuid)

            var check = Check(uuid: "AB", name: "AB", isOpen: true, isCurrent: false, lineItemUuids: [])
            checksCollection.setValue(check, forKey: "1234")

            check = Check(uuid: "ABC", name: "ABC", isOpen: true, isCurrent: false, lineItemUuids: [])
            checksCollection.setValue(check, forKey: "1234")

            checksCollection.countValuesWhere(openChecksCountQuery)
            print("all: \(checksCollection.findValuesWhere(checksCollection.indexed.isOpen.equals(true)))")

            print(checksCollection.valueForKey("1234")?.uuid)
        }

        try! connection2.readWriteTransaction { transaction in
            print("connection 2 write 1")

            let checksCollection = transaction.readWrite(self.collections.Checks)
            print(checksCollection.valueForKey("1234"))

            let check = Check(uuid: "ZEG", name: "AB", isOpen: true, isCurrent: false, lineItemUuids: [])
            checksCollection.setValue(check, forKey: "1234")
            print(checksCollection.valueForKey("1234"))
        }

        try! connection.readWriteTransaction { transaction in
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(5, handler: nil)
    }
}
