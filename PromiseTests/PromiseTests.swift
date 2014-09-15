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

            XCTAssertEqual(value, 25)
            e1.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testPromise() {
        let e1 = expectation()
        let e2 = expectation()
        
        Promise<Int> { (resolve, reject) -> Void in
            NSLog("isMainThread 3: \(NSThread.isMainThread())")

            resolve(25)
        }.then { value -> Promise<String> in
            NSLog("isMainThread 4: \(NSThread.isMainThread())")

            XCTAssertEqual(value, 25)
            e1.fulfill()
            return Promise<String>({ (resolve, reject) -> Void in
                resolve("Promise")
            })
        }.then { value -> Void in
            NSLog("isMainThread 5: \(NSThread.isMainThread())")

            XCTAssertEqual(value, "Promise")
            e2.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testCatch() {
        let e1 = expectation()
        let e2 = expectation()
        
        Promise<Int> { (resolve, reject) -> Void in
            NSLog("isMainThread 6: \(NSThread.isMainThread())")
            
            resolve(25)
        }.then { value -> Promise<String> in
            NSLog("isMainThread 7: \(NSThread.isMainThread())")
            
            XCTAssertEqual(value, 25)
            e1.fulfill()
            return Promise<String>({ (resolve, reject) -> Void in
                resolve("Promise")
            })
        }.then { value -> NSError in
            NSLog("isMainThread 8: \(NSThread.isMainThread())")
            
            return NSError(domain: "Error", code: 123, userInfo: [:])
        }.then { value -> NSError in
            NSLog("isMainThread 8: \(NSThread.isMainThread())")
            NSLog("value: \(value)")
            return NSError(domain: "Error", code: 123, userInfo: [:])
        }.catch { error -> Void in
            XCTAssertEqual(error.code, 123)
            e2.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testReturnNothing() {
        
    }
}
