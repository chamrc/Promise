import Foundation

enum PromiseState<T> {
    case Pending
    case Fulfilled(@autoclosure () -> T?)
    case Rejected(NSError)
}

let promiseQueue = dispatch_queue_create("PromiseThread", DISPATCH_QUEUE_SERIAL)

private class PromiseGCD {
    class func mainQueue() -> dispatch_queue_t {
        return dispatch_get_main_queue()
    }
    class func backgroundQueue() -> dispatch_queue_t {
        return promiseQueue
    }
}

func dispatch_promise<T>(to queue:dispatch_queue_t = dispatch_get_global_queue(0, 0), block:(fulfiller: (T?)->Void, rejecter: (NSError)->Void) -> ()) -> Promise<T> {
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
    var handlers:[(queue: dispatch_queue_t, handler: () -> ())] = []
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
        case .Fulfilled(let value): return value()
        default: return nil
        }
    }
    
    private func callHandlers() {
        for callback in handlers {
            dispatch_async(callback.queue, callback.handler)
        }
        handlers.removeAll(keepCapacity: false)
    }
    
    convenience public init() {
        self.init(value: nil)
    }
    
    public init(_ body:(resolve:(T?) -> Void, reject:(NSError) -> Void) -> Void) {
        body(onResolve, onReject)
    }
    
    public class func defer() -> (promise:Promise, resolve:(T?) -> Void, reject:(NSError) -> Void) {
        var f: ((T?) -> Void)?
        var r: ((NSError) -> Void)?
        let p = Promise{ f = $0; r = $1 }
        return (p, f!, r!)
    }
    
    public init(value:T?) {
        self.state = .Fulfilled(value)
    }
    
    public init(error:NSError) {
        self.state = .Rejected(error)
    }
    
    // MARK: Public Methods
    
    public func then<U>(body:(T?) -> Void) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func thenOnMain<U>(body:(T?) -> Void) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func then<U>(body:(T?) -> U) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func thenOnMain<U>(body:(T?) -> U) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func then<U>(body:(T?) -> Promise<U>) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func thenOnMain<U>(body:(T?) -> Promise<U>) -> Promise<U> {
        return self.then(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func catch(body:(NSError) -> Void) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func catchOnMain(body:(NSError) -> Void) -> Promise<T> {
        return self.catch(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    public func finally(body:() -> Void) -> Promise<T> {
        return self.finally(onQueue: PromiseGCD.backgroundQueue(), body: body)
    }
    public func finallyOnMain(body:() -> Void) -> Promise<T> {
        return self.finally(onQueue: PromiseGCD.mainQueue(), body: body)
    }
    
    // MARK: Private (Resolve and Reject)
    
    private func onReject(err: NSError) {
        objc_sync_enter(self)
        if pending {
            state = .Rejected(err)
            callHandlers()
        }
        objc_sync_exit(self)
    }
    
    private func onResolve(obj: T?) {
        objc_sync_enter(self)
        if pending {
            state = .Fulfilled(obj)
            callHandlers()
        }
        objc_sync_exit(self)
    }
    
    // MARK: Private Methods
    
    private class func voidToNil<T>(value: T!) -> T? {
        if let val = value {
            if val is Void {
                return nil
            } else {
                return val
            }
        } else {
            return nil
        }
    }
    
    private func then<U>(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(T?) -> Void) -> Promise<U> {
        return dispatch_promise(to: q)  { (resolve, reject) in
            switch self.state {
            case .Rejected(let error):
                reject(error)
            case .Fulfilled(let value):
                let val = Promise.voidToNil(value())
                resolve(nil)
            case .Pending:
                objc_sync_enter(self)

                self.handlers.append(
                    queue: q,
                    handler: {
                        switch self.state {
                        case .Rejected(let error):
                            reject(error)
                        case .Fulfilled(let value):
                            let val = Promise.voidToNil(value())
                            resolve(nil)
                        case .Pending:
                            abort()
                        }
                    }
                )
                
                objc_sync_exit(self)
            }
        }
    }
    
    private func then<U>(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(T?) -> U) -> Promise<U> {
        return dispatch_promise(to: q)  { (resolve, reject) in
            switch self.state {
            case .Rejected(let error):
                reject(error)
            case .Fulfilled(let value):
                let val = Promise.voidToNil(value())
                let result = Promise.voidToNil(body(val))
                
                if let error = result as? NSError {
                    reject(error)
                } else {
                    resolve(result)
                }
            case .Pending:
                objc_sync_enter(self)

                self.handlers.append(
                    queue: q,
                    handler: {
                        switch self.state {
                        case .Rejected(let error):
                            reject(error)
                        case .Fulfilled(let value):
                            let val = Promise.voidToNil(value())
                            let result = Promise.voidToNil(body(val))
                            
                            if let error = result as? NSError {
                                reject(error)
                            } else {
                                resolve(result)
                            }
                        case .Pending:
                            abort()
                        }
                    }
                )
                
                objc_sync_exit(self)
            }
        }
    }
    
    private func then<U>(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(T?) -> Promise<U>) -> Promise<U> {
        return dispatch_promise(to: q)  { (resolve, reject) in
            switch self.state {
            case .Rejected(let error):
                reject(error)
            case .Fulfilled(let value):
                let val = Promise.voidToNil(value())
                let promise = body(val)
                
                switch promise.state {
                case .Rejected(let error):
                    reject(error)
                case .Fulfilled(let bodyValue):
                    let val = Promise.voidToNil(bodyValue())
                    resolve(val)
                case .Pending:
                    objc_sync_enter(promise)
                    
                    promise.handlers.append(
                        queue: q,
                        handler: {
                            switch promise.state {
                            case .Rejected(let error):
                                reject(error)
                            case .Fulfilled(let bodyValue):
                                let val = Promise.voidToNil(bodyValue())
                                resolve(val)
                            case .Pending:
                                abort()
                            }
                        }
                    )
                    
                    objc_sync_exit(promise)
                }
            case .Pending:
                objc_sync_enter(self)
                
                self.handlers.append(
                    queue: q,
                    handler: {
                        switch self.state {
                        case .Pending:
                            abort()
                        case .Rejected(let error):
                            reject(error)
                        case .Fulfilled(let value):
                            let val = Promise.voidToNil(value())
                            let promise = body(val)
                            
                            switch promise.state {
                            case .Rejected(let error):
                                reject(error)
                            case .Fulfilled(let bodyValue):
                                let val = Promise.voidToNil(bodyValue())
                                resolve(val)
                            case .Pending:
                                objc_sync_enter(promise)
                                
                                promise.handlers.append(
                                    queue: q,
                                    handler: {
                                        switch promise.state {
                                        case .Rejected(let error):
                                            reject(error)
                                        case .Fulfilled(let bodyValue):
                                            let val = Promise.voidToNil(bodyValue())
                                            resolve(val)
                                        case .Pending:
                                            abort()
                                        }
                                    }
                                )
                                
                                objc_sync_exit(promise)
                            }
                        }
                    }
                )
                
                objc_sync_exit(self)
            }
        }
    }
    
    private func catch(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:(NSError) -> Void) -> Promise<T> {
        return dispatch_promise(to: q) { (resolve, reject) -> Void in
            switch self.state {
            case .Rejected(let error):
                body(error)
                reject(error)
            case .Fulfilled(let value):
                let val = Promise.voidToNil(value())
                resolve(val)
            case .Pending:
                objc_sync_enter(self)
                
                self.handlers.append(
                    queue: q,
                    handler: {
                        switch self.state {
                        case .Rejected(let error):
                            body(error)
                            reject(error)
                        case .Fulfilled(let value):
                            let val = Promise.voidToNil(value())
                            resolve(val)
                        case .Pending:
                            abort()
                        }
                    }
                )
                
                objc_sync_exit(self)
            }
        }
    }
    
    private func finally(onQueue q:dispatch_queue_t = dispatch_get_main_queue(), body:() -> Void) -> Promise<T> {
        return dispatch_promise(to:q) { (resolve, reject) in
            body()
            switch self.state {
            case .Fulfilled(let value):
                let val = Promise.voidToNil(value())
                resolve(val)
            case .Rejected(let error):
                body()
                reject(error)
            case .Pending:
                objc_sync_enter(self)
                
                self.handlers.append(
                    queue: q,
                    handler: {
                        body()
                        switch self.state {
                        case .Fulfilled(let value):
                            let val = Promise.voidToNil(value())
                            resolve(val)
                        case .Rejected(let error):
                            reject(error)
                        case .Pending:
                            abort()
                        }
                    }
                )
                
                objc_sync_exit(self)
            }
        }
    }
}