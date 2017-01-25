//
//  Synchronized.swift
//  fut
//
//  Created by Nikolay on 1/23/17.
//  Copyright © 2017 nkim. All rights reserved.
//


public func synchronized(_ lock: AnyObject, _ f: () -> ()) {
    objc_sync_enter(lock)
    defer {
        objc_sync_exit(lock)
    }
    f()
}

public func synchronized<T>(_ lock: AnyObject, _ f: () -> T) -> T {
    objc_sync_enter(lock)
    defer {
        objc_sync_exit(lock)
    }
    return f()
}

public func synchronized(_ lock: NSLock, _ f: () -> ()) {
    lock.lock()
    defer {
        lock.unlock()
    }
    f()
}
