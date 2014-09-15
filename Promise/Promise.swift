import Foundation
import UIKit

enum PromiseState<T> {
    case Pending
    case Fulfilled(@autoclosure () -> T)
    case Rejected(NSError)
}

private class PromiseGCD {
    class func mainQueue() -> dispatch_queue_t {
        return dispatch_get_main_queue()
    }
    class func backgroundQueue() -> dispatch_queue_t {
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND , 0)
    }
}

private func bind1<T, U>(body:(T) -> Promise<U>, value:T, fulfiller: (U)->(), rejecter: (NSError)->()) {
    let promise = body(value)
    switch promise.state {
    case .Rejected(let error):
        rejecter(error)
    case .Fulfilled(let value):
        fulfiller(value())
    case .Pending:
        promise.handlers.append{
            switch promise.state {
            case .Rejected(let error):
                rejecter(error)
            case .Fulfilled(let value):
                fulfiller(value())
            case .Pending:
                abort()
            }
        }
    }
}

private func bind2<T>(body:(NSError) -> Promise<T>, error: NSError, fulfiller: (T)->(), rejecter: (NSError)->()) {
    let promise = body(error)
    switch promise.state {
    case .Rejected(let error):
        rejecter(error)
    case .Fulfilled(let value):
        fulfiller(value())
    case .Pending:
        promise.handlers.append{
            switch promise.state {
            case .Rejected(let error):
                rejecter(error)
            case .Fulfilled(let value):
                fulfiller(value())
            case .Pending:
                abort()
            }
        }
    }
}




func dispatch_promise<T>(to queue:dispatch_queue_t = dispatch_get_global_queue(0, 0), block:(fulfiller: (T)->Void, rejecter: (NSError)->Void) -> ()) -> Promise<T> {
    return Promise<T> { (fulfiller, rejecter) in
        dispatch_async(queue) {
            block(fulfiller, rejecter)
        }
    }
}

func dispatch_main(block: ()->()) {
    dispatch_async(dispatch_get_main_queue(), block)
}


public class Promise<T> {
    var handlers:[()->()] = []
    var state:PromiseState<T> = .Pending
    
    public var rejected:Bool {
        switch state {
        case .Fulfilled, .Pending: return false
        case .Rejected: return true
        }
    }
    public var fulfilled:Bool {
        switch state {
        case .Rejected, .Pending: return false
        case .Fulfilled: return true
        }
    }
    public var pending:Bool {
        switch state {
        case .Rejected, .Fulfilled: return false
        case .Pending: return true
        }
    }
    
    public var value:T? {
        switch state {
        case .Fulfilled(let value):
            return value()
        default:
            return nil
        }
    }
    
    private func callHandlers() {
        for handler in handlers { handler() }
        handlers.removeAll(keepCapacity: false)
    }
    
    public init(_ body:(resolve:(T) -> Void, reject:(NSError) -> Void) -> Void) {
        func reject(err: NSError) {
            if pending {
                state = .Rejected(err)
                callHandlers()
            }
        }
        func resolve(obj: T) {
            if pending {
                state = .Fulfilled(obj)
                callHandlers()
            }
        }
        body(resolve, reject)
    }
    
    public class func defer() -> (promise:Promise, resolve:(T) -> Void, reject:(NSError) -> Void) {
        var f: ((T) -> Void)?
        var r: ((NSError) -> Void)?
        let p = Promise{ f = $0; r = $1 }
        return (p, f!, r!)
    }
    
    public init(value:T) {
        self.state = .Fulfilled(value)
    }
    
    public init(error:NSError) {
        self.state = .Rejected(error)
    }
    
    // MARK: Public Methods
    
    public func then<U>(body:(T) -> U) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func thenOnMain<U>(body:(T) -> U) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func then<U>(body:(T) -> Promise<U>) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func thenOnMain<U>(body:(T) -> Promise<U>) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func catch(body:(NSError) -> T) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func catchOnMain(body:(NSError) -> T) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func catch(body:(NSError) -> Void) -> Void {
        return self.catch(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func catchOnMain(body:(NSError) -> Void) -> Void {
        return self.catch(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func catch(body:(NSError) -> Promise<T>) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func catchOnMain(body:(NSError) -> Promise<T>) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func finally(body:() -> Void) -> Promise<T> {
        return self.finally(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func finallyOnMain(body:() -> Void) -> Promise<T> {
        return self.finally(onQueue: PromiseGCD.mainQueue(), body: body)
    }

    
    // MARK: Private Methods
    
    private func then<U>(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(T) -> U) -> Promise<U> {
        switch state {
        case .Rejected(let error):
            return Promise<U>(error: error)
        case .Fulfilled(let value):
            return dispatch_promise(to:q) { (resolve, reject) in
                let result = body(value())
                if let error = result as? NSError {
                    reject(error)
                } else {
                    resolve(result)
                }
            }
        case .Pending:
            return Promise<U> { (resolve, reject) in
                self.handlers.append {
                    switch self.state {
                    case .Rejected(let error):
                        reject(error)
                    case .Fulfilled(let value):
                        dispatch_async(q) {
                            let result = body(value())
                            if let error = result as? NSError {
                                reject(error)
                            } else {
                                resolve(result)
                            }
                        }
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }
    
    private func then<U>(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(T) -> Promise<U>) -> Promise<U> {
        
        switch state {
        case .Rejected(let error):
            return Promise<U>(error: error)
        case .Fulfilled(let value):
            return dispatch_promise(to:q){
                bind1(body, value(), $0, $1)
            }
        case .Pending:
            return Promise<U>{ (resolve, reject) in
                self.handlers.append{
                    switch self.state {
                    case .Pending:
                        abort()
                    case .Fulfilled(let value):
                        dispatch_async(q){
                            bind1(body, value(), resolve, reject)
                        }
                    case .Rejected(let error):
                        reject(error)
                    }
                }
            }
        }
    }
    
    private func catch(onQueue:dispatch_queue_t = dispatch_get_main_queue(), body:(NSError) -> T) -> Promise<T> {
        switch state {
        case .Fulfilled(let value):
            return Promise(value: value())
        case .Rejected(let error):
            return dispatch_promise(to:onQueue){ (resolve, reject) -> Void in
                resolve(body(error))
            }
        case .Pending:
            return Promise{ (resolve, reject) in
                self.handlers.append {
                    switch self.state {
                    case .Fulfilled(let value):
                        resolve(value())
                    case .Rejected(let error):
                        dispatch_async(onQueue){
                            resolve(body(error))
                        }
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }
    
    private func catch(onQueue:dispatch_queue_t = dispatch_get_main_queue(), body:(NSError) -> Void) -> Void {
        switch state {
        case .Rejected(let error):
            dispatch_async(onQueue, {
                body(error)
            })
        case .Fulfilled:
            let noop = 0
        case .Pending:
            self.handlers.append({
                switch self.state {
                case .Rejected(let error):
                    dispatch_async(onQueue){
                        body(error)
                    }
                case .Fulfilled:
                    let noop = 0
                case .Pending:
                    abort()
                }
            })
        }
    }
    
    private func catch(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(NSError) -> Promise<T>) -> Promise<T>
    {
        switch state {
        case .Rejected(let error):
            return dispatch_promise(to:q){
                bind2(body, error, $0, $1)
            }
        case .Fulfilled(let value):
            return Promise(value:value())
            
        case .Pending:
            return Promise{ (resolve, reject) in
                self.handlers.append{
                    switch self.state {
                    case .Pending:
                        abort()
                    case .Fulfilled(let value):
                        resolve(value())
                    case .Rejected(let error):
                        dispatch_async(q){
                            bind2(body, error, resolve, reject)
                        }
                    }
                }
            }
        }
    }
    
    private func finally(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:() -> Void) -> Promise<T> {
        return dispatch_promise(to:q) { (resolve, reject) in
            switch self.state {
            case .Fulfilled(let value):
                body()
                resolve(value())
            case .Rejected(let error):
                body()
                reject(error)
            case .Pending:
                self.handlers.append{
                    body()
                    switch self.state {
                    case .Fulfilled(let value):
                        resolve(value())
                    case .Rejected(let error):
                        reject(error)
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }
}