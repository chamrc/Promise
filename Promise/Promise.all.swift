//
//  Promise.all.swift
//  miusic
//
//  Created by Ranchao Zhang on 10/31/14.
//  Copyright (c) 2014 Ranchao Zhang. All rights reserved.
//

import Foundation

public func any<K>(promises: Promise<K>...) -> Promise<[PromiseResult<K>]> {
    return any(promises)
}

public func any<K>(promises: [Promise<K>]) -> Promise<[PromiseResult<K>]> {
    if promises.isEmpty {
        let results: [PromiseResult<K>] = []
        return Promise<[PromiseResult<K>]>(value: results)
    }

    let (promise, resolve, reject) = Promise<[PromiseResult<K>]>.defer()

    var results = [PromiseResult<K>](count: promises.count, repeatedValue: PromiseResult<K>())

    var x = 0
    for (index, promise) in enumerate(promises) {
        results[index] = PromiseResult<K>()

        promise.then { (value) -> Void in
            if let data = value {
                results[index].object = data
                results[index].error = nil
            }

            if ++x == promises.count {
                resolve(results)
            }
        }
        promise.catch { (error) -> Void in
            results[index].object = nil
            results[index].error = error

            if ++x == promises.count {
                for result in results {
                    if result.object != nil {
                        resolve(results)
                        return
                    }
                }

                reject(error)
            }
        }
    }

    return promise
}

public func all<K>(promises: Promise<K>...) -> Promise<[PromiseResult<K>]> {
    return all(promises)
}

public func all<K>(promises: [Promise<K>]) -> Promise<[PromiseResult<K>]> {
    if promises.isEmpty {
        let results: [PromiseResult<K>] = []
        return Promise<[PromiseResult<K>]>(value: results)
    }

    let (promise, resolve, reject) = Promise<[PromiseResult<K>]>.defer()

    var results = [PromiseResult<K>](count: promises.count, repeatedValue: PromiseResult<K>())

    var x = 0
    for (index, promise) in enumerate(promises) {
        results[index] = PromiseResult<K>()

        promise.then { (value) -> Void in
            if let data = value {
                results[index].object = data
            }

            if ++x == promises.count {
                resolve(results)
            }
        }
        promise.catch(reject)
    }

    return promise
}
