//
//  Listener.swift
//  fut
//
//  Created by Nikolay on 1/25/17.
//  Copyright © 2017 nkim. All rights reserved.
//


public enum Target {
    /// Execute signal handler on the same queue as source of signal
    case Same
    /// Execute signal handler on global queue with specific QoSClass class
    case QoS(DispatchQoS.QoSClass)
    /// Execute signal handler on user defined queue
    case Queue(DispatchQueue)

    /// Execute signal handler on queue with background priority
    static let Bg = Target.QoS(.background)
    /// Execute signal handler on main thread
    static let Main = Target.Queue(DispatchQueue.main)
}


public func ==(lhs: Listener, rhs: Listener) -> Bool {
    return lhs === rhs
}

public class Listener: Hashable {

    public let target: Target
    public private(set) var cancelled = false

    public var hashValue: Int { return ObjectIdentifier(self).hashValue }

    public func cancel()
    {
        self.cancelled = true
    }

    public init(_ target: Target) {
        self.target = target
    }

    deinit {
        self.cancel()
    }

}


internal class Dispatcher<T>: Listener {

    var handler: (T) -> Bool

    init(_ target:Target, notify:@escaping () -> Void)
    {
        let handler: (T) -> Bool = { data in
            switch target {
            case .Same: notify()
            case .QoS(let qos): DispatchQueue.global(qos: qos).async { notify() }
            case .Queue(let queue): queue.async { notify() }
            }
            return true
        }

        self.handler = handler

        super.init(target)
    }

    init(_ target:Target, waiter:@escaping (T) -> Void)
    {
        let handler: (T) -> Bool = { data in
            switch target {
                case .Same: waiter(data)
                case .QoS(let qos): DispatchQueue.global(qos: qos).async { waiter(data) }
                case .Queue(let queue): queue.async { waiter(data) }
            }
            return true
        }

        self.handler = handler

        super.init(target)
    }

    init<TContext: AnyObject>(_ context:TContext, target:Target, notify:@escaping (TContext) -> Void)
    {
        let handler: (T) -> Bool = { [weak context] data in
            if let context = context {
                switch target {
                    case .Same: notify(context)
                    case .QoS(let qos): DispatchQueue.global(qos: qos).async { notify(context) }
                    case .Queue(let queue): queue.async { notify(context) }
                }
                return true
            }
            return false
        }

        self.handler = handler

        super.init(target)
    }

    init<TContext: AnyObject>(_ context:TContext, target:Target, waiter:@escaping (TContext, T) -> Void)
    {
        let handler: (T) -> Bool = { [weak context] data in
            if let context = context {
                switch target {
                    case .Same: waiter(context, data)
                    case .QoS(let qos): DispatchQueue.global(qos: qos).async { waiter(context, data) }
                    case .Queue(let queue): queue.async { waiter(context, data) }
                }
                return true
            }
            return false
        }

        self.handler = handler

        super.init(target)
    }

    func dispatch(_ data: T) -> Bool
    {
        if !self.cancelled {
            if !self.handler(data) {
                return false
            }
        }
        return !self.cancelled
    }

}


public class Listeners {

    private(set) var listeners = Set<Listener>()

    public func set(_ listeners: Listener...)
    {
        synchronized(self) {
            // reset
            for listener in self.listeners {
                listener.cancel()
            }
            // register
            self.listeners = Set(listeners)
        }
    }

    public func append(_ listeners: Listener...)
    {
        synchronized(self) {
            self.listeners = self.listeners.union(listeners)
        }
    }

    public func reset()
    {
        synchronized(self) {
            for listener in self.listeners {
                listener.cancel()
            }
            self.listeners = Set()
        }
    }

    public init() {}

    deinit {
        for listener in self.listeners {
            listener.cancel()
        }
    }

}
