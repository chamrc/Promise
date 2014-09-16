# Promise


## Sample Usage

### Simple Example
```
let promise = Promise<Int> { (resolve, reject) -> Void in
    // Will run in Main Thread
    resolve(25)
}.then { value -> Void in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = 25
}
```

### Short hand
```
let promise = Promise<Int>()
.then { value -> Void in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = nil
}
```

### Return an object
```
let promise = Promise<Int> { (resolve, reject) -> Void in
    // Will run in Main Thread
    resolve(25)
}.then { value -> Promise<String> in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = 25
    return "Promise"
}.thenOnMain { value -> Void in
    // Will run in main thread
    // value = "Promise"
}.then { value -> Void in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = nil
}
```

### Return an instance of NSError
```
let promise = Promise<Int> { (resolve, reject) -> Void in
    // Will run in Main Thread
    resolve(25)
}.then { value -> Promise<String> in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = 25
    let error = NSError(...) // 
    return error
}.catch { error -> Void in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
}
```

### Return another promise in `then`
```
let promise = Promise<Int> { (resolve, reject) -> Void in
    // Will run in Main Thread
    resolve(25)
}.then { value -> Promise<String> in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = 25
    return Promise<String>({ (resolve, reject) -> Void in
        resolve("Promise")
    })
}.thenOnMain { value -> Void in
    // Will run in main thread
    // value = "Promise"
}
```

### Defer object
```
let promise = Promise<Int> { (resolve, reject) -> Void in
    // Will run in Main Thread
    resolve(25)
}.then { value -> Promise<String> in
    // Will run in `dispatch_queue_t` with priority `DISPATCH_QUEUE_PRIORITY_BACKGROUND`
    // value = 25
    let (promise, resolve, reject) = Promise<String>.defer()
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
        resolve("Hello")
    })
    return promise
}.thenOnMain { value -> Void in
    // Will run in main thread
    // value = "Hello"
}
```
