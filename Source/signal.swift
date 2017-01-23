//
//  signal.swift
//  fut
//
//  Created by Nikolay Kim on 1/23/17.
//  Copyright © 2017 Nikolay Kim. All rights reserved.
//

import Foundation


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


public final class Signal<T> {

    private var listeners = Set<SignalDispatcher<T>>()

    public func notify<TContext: AnyObject>(_ context:TContext, exec:Target, f: @escaping (TContext) -> Void) -> SignalListener
    {
        let wrapper: (T) -> Bool = { [weak context] data in
            if let context = context {
                switch exec {
                    case .Same: f(context)
                    case .QoS(let qos): DispatchQueue.global(qos: qos).async { f(context) }
                    case .Queue(let queue): queue.async { f(context) }
                }
                return true
            }
            return false
        }

        return synchronized(self) {
            return self.listeners.insert(SignalDispatcher(wrapper)).memberAfterInsert
        }
    }

    public func listen<TContext: AnyObject>(_ context:TContext, exec:Target, f:@escaping (TContext, T) -> Void) -> SignalListener
    {
        let wrapper: (T) -> Bool = { [weak context] data in
            if let context = context {
                switch exec {
                    case .Same: f(context, data)
                    case .QoS(let qos): DispatchQueue.global(qos: qos).async { f(context, data) }
                    case .Queue(let queue): queue.async { f(context, data) }
                }
                return true
            }
            return false
        }
        return synchronized(self) {
            return self.listeners.insert(SignalDispatcher(wrapper)).memberAfterInsert
        }
    }

    public func fire(_ data: T)
    {
        if !self.listeners.isEmpty {
            synchronized(self) {
                var listeners = Set<SignalDispatcher<T>>()
                for listener in self.listeners {
                    if listener.dispatch(data) {
                        listeners.insert(listener)
                    }
                }
                self.listeners = listeners
            }
        }
    }

    public func reset()
    {
        synchronized(self) {
            self.listeners.removeAll()
        }
    }

    public init() {}

}


public func ==(lhs: SignalListener, rhs: SignalListener) -> Bool {
    return lhs === rhs
}

public class SignalListener: Hashable {

    private(set) var cancelled = false

    public var hashValue: Int { return ObjectIdentifier(self).hashValue }

    public func cancel()
    {
        self.cancelled = true
    }
    
    deinit {
        self.cancel()
    }

}


private class SignalDispatcher<T>: SignalListener {

    let handler: (T) -> Bool

    init(_ handler: @escaping (T) -> Bool)
    {
        self.handler = handler
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


public class SignalListeners {

    private(set) var listeners = Set<SignalListener>()

    public func set(_ listeners: SignalListener...)
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

    public func append(_ listeners: SignalListener...)
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
