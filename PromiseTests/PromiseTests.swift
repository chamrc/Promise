//
//  PromiseTests.swift
//  PromiseTests
//
//  Created by Ranchao Zhang on 9/15/14.
//  Copyright (c) 2014 Ranchao Zhang. All rights reserved.
//

import UIKit
import XCTest

extension XCTestCase {
    func expectation() -> XCTestExpectation {
        return expectationWithDescription("")
    }
}

class PromiseTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSimplePromise() {
        let e1 = expectation()
        
        Promise<Int> { (resolve, reject) -> Void in
            resolve(25)
            NSLog("isMainThread 1: \(NSThread.isMainThread())")
        }.then { value -> Void in
            NSLog("isMainThread 2: \(NSThread.isMainThread())")

            XCTAssertEqual(value!, 25)
            e1.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testPromise() {
        let e1 = expectation()
        let e2 = expectation()
        
        Promise<Int> { (resolve, reject) -> Void in
            NSLog("isMainThread 3: \(NSThread.isMainThread())")

            resolve(25)
        }.then { value -> Promise<String> in
            NSLog("isMainThread 4: \(NSThread.isMainThread())")

            XCTAssertEqual(value!, 25)
            e1.fulfill()
            return Promise<String>({ (resolve, reject) -> Void in
                resolve("Promise")
            })
        }.then { value -> Void in
            NSLog("isMainThread 5: \(NSThread.isMainThread())")

            XCTAssertEqual(value!, "Promise")
            e2.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testCatch() {
        let e1 = expectation()
        let e2 = expectation()
        
        Promise<Int> { (resolve, reject) -> Void in
            NSLog("isMainThread 6: \(NSThread.isMainThread())")
            
            resolve(25)
        }.then { value -> Promise<String> in
            NSLog("isMainThread 7: \(NSThread.isMainThread())")
            
            XCTAssertEqual(value!, 25)
            e1.fulfill()
            return Promise<String>({ (resolve, reject) -> Void in
                resolve("Promise")
            })
        }.then { value -> NSError in
            NSLog("isMainThread 8: \(NSThread.isMainThread())")
            
            return NSError(domain: "Error", code: 123, userInfo: [:])
        }.then { value -> NSError in
            NSLog("isMainThread 9: \(NSThread.isMainThread())")
            NSLog("value: \(value)")
            return NSError(domain: "Error", code: 123, userInfo: [:])
        }.catch { error -> Void in
            XCTAssertEqual(error.code, 123)
            e2.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testReturnNothing() {
        let e1 = expectation()
        let e2 = expectation()
        let e3 = expectation()
        
        let promise = Promise<Int> { (resolve, reject) -> Void in
            NSLog("isMainThread 10: \(NSThread.isMainThread())")
            
            resolve(25)
        }.then { value -> Promise<String> in
            NSLog("isMainThread 11: \(NSThread.isMainThread())")
            
            XCTAssertEqual(value!, 25)
            e1.fulfill()
            return Promise<String>({ (resolve, reject) -> Void in
                resolve("Promise")
            })
        }.then { (value) -> Void in
            NSLog("isMainThread 12: \(NSThread.isMainThread())")
            XCTAssertEqual(value!, "Promise")
            e2.fulfill()
            
        }.thenOnMain { (value) -> Void in
            NSLog("isMainThread 13: \(NSThread.isMainThread())")
            
            NSLog("Value 13: \(value)")
            
            if value == nil {
                e3.fulfill()
            }
            
        }.catch { error -> Void in
            
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testEmptyInit() {
        let e1 = expectation()
        let e2 = expectation()
        let e3 = expectation()
        
        Promise<Int>()
        .then { (value) -> Int in
            if value == nil {
                e1.fulfill()
            }
            return 24
        }
        .then { (value) -> String in
            XCTAssertEqual(value!, 24)
            e2.fulfill()
            return "Hello"
        }
        .thenOnMain { (value) -> Void in
            XCTAssertEqual(value!, "Hello")
            e3.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testDefer() {
        let e1 = expectation()
        let e2 = expectation()
        let e3 = expectation()
        
        Promise<Int>()
        .then { (value) -> Int in
            NSLog("value 1: \(value)")
            
            if value == nil {
                e1.fulfill()
            }
            return 24
        }
        .then { (value) -> Promise<String> in
            NSLog("value 2: \(value)")
            XCTAssertEqual(value!, 24)
            e2.fulfill()
            
            let (promise, resolve, reject) = Promise<String>.defer()
            
            resolve("Hello")
            
            return promise
        }
        .thenOnMain { (value) -> Void in
            NSLog("value 3: \(value)")

            XCTAssertEqual(value!, "Hello")
            e3.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testAll() {
        let e1 = expectation()
        let e2 = expectation()
        
        let testData = [24, 16, 7, 2]
        
        let p1 = Promise<Int>().then { (value) -> Int in
            return testData[0]
        }
        
        let p2 = Promise<Int>().then { (value) -> Int in
            return testData[1]
        }
        
        let p3 = Promise<Int>().then { (value) -> Int in
            return testData[2]
        }
        
        let p4 = Promise<Int>().then { (value) -> Int in
            return testData[3]
        }
        
        Promise<Int>.all(p1, p2, p3, p4).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    println("RESULT \(i): \(result)")
                    XCTAssertEqual(result.object!, testData[i])
                }
                
                e1.fulfill()
            }
        }
        
        Promise<Int>.all([p1, p2, p3, p4]).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    println("RESULT \(i): \(result)")
                    XCTAssertEqual(result.object!, testData[i])
                }
                
                e2.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testAllError() {
        let e1 = expectation()
        let e2 = expectation()
        
        let testData = [24, 16, 7, 2]
        
        let p1 = Promise<Int>().then { (value) -> Int in
            return testData[0]
        }
        
        let p2 = Promise<Int>().then { (value) -> Int in
            return testData[1]
        }
        
        let p3 = Promise<Int>().then { (value) -> Int in
            return testData[2]
        }

        let (p4, resolve, reject) = Promise<Int>.defer()
        reject(NSError(domain: "Error", code: 123, userInfo: [:]))
        
        Promise<Int>.all(p1, p2, p3, p4).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    println("RESULT \(i): \(result)")
                    XCTAssertEqual(result.object!, testData[i])
                }
            }
        }.catch { (error) -> Void in
            e1.fulfill()
        }
        
        Promise<Int>.all([p1, p2, p3, p4]).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    println("RESULT \(i): \(result)")
                    XCTAssertEqual(result.object!, testData[i])
                }
            }
        }.catch { (error) -> Void in
            e2.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testAny() {
        let e1 = expectation()
        let e2 = expectation()
        
        let testData = [24, 16, 7, 2]
        
        let p1 = Promise<Int>().then { (value) -> Int in
            return testData[0]
        }
        
        let p2 = Promise<Int>().then { (value) -> Int in
            return testData[1]
        }
        
        let p3 = Promise<Int>().then { (value) -> Int in
            return testData[2]
        }
        
        let p4 = Promise<Int>().then { (value) -> Int in
            return testData[3]
        }
        
        Promise<Int>.any(p1, p2, p3, p4).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    XCTAssertEqual(result.object!, testData[i])
                }
                
                e1.fulfill()
            }
        }
        
        Promise<Int>.any([p1, p2, p3, p4]).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    let result = results[i]
                    XCTAssertEqual(result.object!, testData[i])
                }
                
                e2.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testAnyError() {
        let e1 = expectation()
        let e2 = expectation()
        
        let testError = NSError(domain: "Error", code: 123, userInfo: [:])
        let testData = [24, 16, 7, 2]
        
        let p1 = Promise<Int>().then { (value) -> Int in
            return testData[0]
        }
        
        let p2 = Promise<Int>().then { (value) -> Int in
            return testData[1]
        }
        
        let p3 = Promise<Int>().then { (value) -> Int in
            return testData[2]
        }
        
        let (p4, resolve, reject) = Promise<Int>.defer()
        reject(testError)
        
        Promise<Int>.any(p1, p2, p3, p4).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    if let obj = results[i].object {
                        XCTAssertEqual(obj, testData[i])
                    } else if let err = results[i].error {
                        XCTAssertEqual(err, testError)
                    }
                }
                e1.fulfill()
            }
        }.catch { (error) -> Void in
        }
        
        Promise<Int>.any(p1, p2, p3, p4).then { (value) -> Void in
            if let results = value {
                for i in 0..<results.count {
                    if let obj = results[i].object {
                        XCTAssertEqual(obj, testData[i])
                    } else if let err = results[i].error {
                        XCTAssertEqual(err, testError)
                    }
                }
                e2.fulfill()
            }
        }.catch { (error) -> Void in
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
}
