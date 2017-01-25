//
//  future.swift
//  fut
//
//  Created by Nikolay Kim on 1/24/17.
//  Copyright © 2017 Nikolay Kim. All rights reserved.
//
//  very simple future implementation

import Foundation


public enum FutureState<TResult> {
    case pending
    case cancelled
    case finished(TResult)
}


public func ==<T>(lhs: Future<T>, rhs: Future<T>) -> Bool {
    return lhs === lhs
}


public class Future<TResult>: Equatable, Hashable {

    private var handlers = Set<SignalDispatcher<TResult>>()
    private var notifyHandlers = Set<SignalDispatcher<FutureState<TResult>>>()

    public private(set) var state: FutureState<TResult> = .pending

    public var hashValue: Int { return ObjectIdentifier(self).hashValue }

    public func wait(_ exec:Target, f:@escaping (TResult) -> Void) -> Future<TResult>
    {
        synchronized(self) {
            switch self.state {
                case .finished(let result):
                    f(result)
                case .pending:
                    self.handlers.insert(SignalDispatcher(exec, waiter:f))
                default: ()
            }
        }
        return self
    }

    public func wait<TContext: AnyObject>(_ context:TContext, exec:Target, f:@escaping (TContext, TResult) -> Void) -> Future<TResult>
    {
        let handler = SignalDispatcher(context, exec:exec, waiter:f)

        synchronized(self) {
            switch self.state {
                case .finished(let result):
                    handler.dispatch(result)
                case .pending:
                    self.handlers.insert(handler)
                default: ()
            }
        }
        return self
    }
    
    public func notify(_ exec:Target, f:@escaping (FutureState<TResult>) -> Void) -> Future<TResult>
    {
        let handler = SignalDispatcher(exec, waiter:f)

        synchronized(self) {
            if self.isDone() {
                handler.dispatch(self.state)
            } else {
                self.notifyHandlers.insert(handler)
            }
        }
        return self
    }
    
    public func notify<TContext: AnyObject>(_ context:TContext, exec:Target, f:@escaping (TContext, FutureState<TResult>) -> Void) -> Future<TResult>
    {
        let handler = SignalDispatcher(context, exec:exec, waiter:f)

        synchronized(self) {
            if self.isDone() {
                handler.dispatch(self.state)
            } else {
                self.notifyHandlers.insert(handler)
            }
        }
        return self
    }
    
    public func set(_ result: TResult) -> Bool
    {
        if self.isDone() { return false }

        synchronized(self) {
            self.state = .finished(result)

            for handler in self.handlers {
                _ = handler.dispatch(result)
            }
            for handler in self.notifyHandlers {
                _ = handler.dispatch(self.state)
            }
            self.handlers.removeAll()
            self.notifyHandlers.removeAll()
        }
        return true
    }

    public func cancel() -> Bool
    {
        return synchronized(self) {
            switch self.state {
                case .pending:
                    self.state = .cancelled
                    for handler in self.notifyHandlers {
                        _ = handler.dispatch(.cancelled)
                    }
                    return true
                default:
                    return false
            }
        }
    }
    
    public func reset() {
        synchronized(self) {
            self.state = .pending
            self.handlers.removeAll()
            self.notifyHandlers.removeAll()
        }
    }

    public func isDone() -> Bool
    {
        return synchronized(self) {
            switch self.state {
                case .pending:
                    return false
                case .finished, .cancelled:
                    return true
            }
        }
    }

    public func copy(from: Future<TResult>)
    {
        synchronized(from) {
            synchronized(self) {
                switch self.state {
                    case .cancelled:
                        _ = from.cancel()
                    case .finished(let result):
                        _ = from.set(result)
                    case .pending:
                        for handler in from.handlers {
                            if !handler.cancelled {
                                self.handlers.insert(handler)
                            }
                        }
                        self.notifyHandlers = self.notifyHandlers.union(from.notifyHandlers)
                }
            }
            from.reset()
        }
    }

    public init() {}

    public init(result:TResult) {
        _ = self.set(result)
    }

}
