//
//  Signal.swift
//  fut
//
//  Created by Nikolay Kim on 1/23/17.
//  Copyright © 2017 Nikolay Kim. All rights reserved.
//


public final class Signal<T> {

    private var listeners = Set<Dispatcher<T>>()

    public func wait(_ on:Target, f:@escaping (T) -> Void) -> Listener
    {
        return synchronized(self) {
            return self.listeners.insert(Dispatcher(on, waiter:f)).memberAfterInsert
        }
    }

    public func wait<TContext: AnyObject>(_ context:TContext, on:Target, f:@escaping (TContext, T) -> Void) -> Listener
    {
        return synchronized(self) {
            return self.listeners.insert(Dispatcher(context, target:on, waiter:f)).memberAfterInsert
        }
    }

    public func notify(_ on:Target, f:@escaping () -> Void) -> Listener
    {
        return synchronized(self) {
            return self.listeners.insert(Dispatcher(on, notify:f)).memberAfterInsert
        }
    }

    public func notify<TContext: AnyObject>(_ context:TContext, on:Target, f: @escaping (TContext) -> Void) -> Listener
    {
        return synchronized(self) {
            return self.listeners.insert(Dispatcher(context, target:on, notify:f)).memberAfterInsert
        }
    }

    public func fire(_ data: T)
    {
        if !self.listeners.isEmpty {
            synchronized(self) {
                var listeners = Set<Dispatcher<T>>()
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
