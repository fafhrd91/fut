//
//  Future.swift
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

    private var handlers = Set<Dispatcher<TResult>>()
    private var notifyHandlers = Set<Dispatcher<FutureState<TResult>>>()

    public private(set) var state: FutureState<TResult> = .pending

    public var hashValue: Int { return ObjectIdentifier(self).hashValue }

    public func wait(_ on:Target, f:@escaping (TResult) -> Void) -> Listener
    {
        let handler = Dispatcher(on, waiter:f)

        switch self.state {
            case .finished(let result):
                _ = handler.dispatch(result)
            case .pending:
                synchronized(self) {
                    _ = self.handlers.insert(handler)
                }
            default: ()
        }
        return handler
    }

    public func wait<TContext: AnyObject>(_ context:TContext, on:Target, f:@escaping (TContext, TResult) -> Void) -> Listener
    {
        let handler = Dispatcher(context, target:on, waiter:f)

        switch self.state {
            case .finished(let result):
                _ = handler.dispatch(result)
            case .pending:
                synchronized(self) {
                    _ = self.handlers.insert(handler)
                }
            default: ()
        }
        return handler
    }

    public func notify(_ on:Target, f:@escaping (FutureState<TResult>) -> Void) -> Listener
    {
        let handler = Dispatcher(on, waiter:f)

        if self.isDone() {
            _ = handler.dispatch(self.state)
        } else {
            synchronized(self) {
                _ = self.notifyHandlers.insert(handler)
            }
        }
        return handler
    }
    
    public func notify<TContext: AnyObject>(_ context:TContext, on:Target, f:@escaping (TContext, FutureState<TResult>) -> Void) -> Listener
    {
        let handler = Dispatcher(context, target:on, waiter:f)

        if self.isDone() {
            _ = handler.dispatch(self.state)
        } else {
            synchronized(self) {
                _ = self.notifyHandlers.insert(handler)
            }
        }
        return handler
    }
    
    public func set(_ result: TResult) -> Bool
    {
        return synchronized(self) {
            switch self.state {
                case .pending:
                    self.state = .finished(result)

                    for handler in self.handlers {
                        _ = handler.dispatch(result)
                    }
                    for handler in self.notifyHandlers {
                        _ = handler.dispatch(self.state)
                    }

                    self.handlers.removeAll()
                    self.notifyHandlers.removeAll()
            
                    return true
                default:
                    return false
            }
        }
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
