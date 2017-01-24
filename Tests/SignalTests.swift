//
//  SignalTests.swift
//  fut
//
//  Created by Nikolay on 1/23/17.
//  Copyright © 2017 nkim. All rights reserved.
//

import XCTest
@testable import fut


class SignalTests: XCTestCase {

    func testSameTarget() {
        var result = 0
        let signal = Signal<Int>()

        _ = signal.wait(self, exec: .Same) { (ctx, res) in
            if ctx === self {
                result = res
            }
        }
        signal.fire(1)
        XCTAssertTrue(result==1)
    }

    func testConcurrentNotify() {
        var result = 0
        let signal = Signal<Int>()
        let group = DispatchGroup()
        let group2 = DispatchGroup()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        queue.suspend()

        for _ in 0..<100 {
            group.enter()
            group2.enter()
            queue.async {
                _ = signal.notify(self, exec: .Queue(queue)) { ctx in
                    result += 1
                    group2.leave()
                }
                group.leave()
            }
        }
        queue.resume()

        if group.wait(timeout: .now() + .seconds(1)) == .timedOut {
            XCTFail("can not complete signal registrations within 1 second")
        }
    
        signal.fire(1)
        if group2.wait(timeout: .now() + .seconds(1)) == .timedOut {
            XCTFail("can not complete signal handling within 1 second")
        }
        XCTAssertTrue(result==100)
    }

    func testConcurrentWait() {
        var result = 0
        let signal = Signal<Int>()
        let group = DispatchGroup()
        let group2 = DispatchGroup()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        queue.suspend()
        
        for _ in 0..<100 {
            group.enter()
            group2.enter()
            queue.async {
                _ = signal.wait(self, exec: .Queue(queue)) { ctx, res in
                    result += res
                    group2.leave()
                }
                group.leave()
            }
        }
        queue.resume()
        
        if group.wait(timeout: .now() + .seconds(1)) == .timedOut {
            XCTFail("can not complete signal registrations within 1 second")
        }
        
        signal.fire(2)
        if group2.wait(timeout: .now() + .seconds(1)) == .timedOut {
            XCTFail("can not complete signal handling within 1 second")
        }
        XCTAssertTrue(result==200)
    }

    func testMainTarget() {
        let signal = Signal<Int>()
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()

        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())

        _ = signal.notify(self, exec: target) { ctx in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        }
        signal.fire(1)
        
        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testWaitMainTarget() {
        let signal = Signal<Int>()
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()
        
        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())
        
        _ = signal.wait(self, exec: target) { ctx, res in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        }
        signal.fire(1)
        
        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }
    
    func testBackgroundTarget() {
        let signal = Signal<Int>()
        let expect = self.expectation(description: "Signal handler")

        _ = signal.notify(self, exec: Target.Bg) { ctx in
            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()),
                   qos == DispatchQoS.QoSClass.background {
                expect.fulfill()
            }
        }
        signal.fire(1)
        
        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testWaitBackgroundTarget() {
        let signal = Signal<Int>()
        let expect = self.expectation(description: "Signal handler")

        _ = signal.wait(self, exec: Target.Bg) { ctx, res in
            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()),
                qos == DispatchQoS.QoSClass.background {
                expect.fulfill()
            }
        }
        signal.fire(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }
    
    func testNotifySameTarget() {
        var result = 0
        let signal = Signal<Int>()
        
        _ = signal.notify(self, exec: .Same) { ctx in
            if ctx === self {
                result = 10
            }
        }
        signal.fire(1)
        XCTAssertTrue(result==10)
    }

    func testCancelledListener() {
        var result = 0
        let signal = Signal<Int>()

        let listener = signal.wait(self, exec: .Same) { (ctx, res) in
            result = res
        }
        listener.cancel()
        signal.fire(1)
        XCTAssertTrue(result==0)
    }

    func testResetSignal() {
        var result = 0
        let signal = Signal<Int>()
        
        _ = signal.wait(self, exec: .Same) { (ctx, res) in
            result = res
        }
        signal.reset()
        signal.fire(1)
        XCTAssertTrue(result==0)
    }

    func testWeakNotifyContext() {
        var result = 0
        let signal = Signal<Int>()
        var context: NSObject! = NSObject()
        
        _ = signal.notify(context, exec: .Same) { ctx in
            result = 1
        }
        context = nil
        
        signal.fire(1)
        XCTAssertTrue(result==0)
    }
    
    func testWeakWaitContext() {
        var result = 0
        let signal = Signal<Int>()
        var context: NSObject! = NSObject()

        _ = signal.wait(context, exec: .Same) { (ctx, res) in
            result = res
        }
        context = nil

        signal.fire(1)
        XCTAssertTrue(result==0)
    }

    func testSignalListeners() {
        var result = 0
        let signal = Signal<Int>()
        let listeners = SignalListeners()
        
        listeners.set(
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            },
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            }
        )
            
        signal.fire(1)
        XCTAssertTrue(result==2)
        
        // reset listeners container and set new signal handlers
        listeners.set(
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            }
        )
        signal.fire(2)
        XCTAssertTrue(result==4)

        // register on
        listeners.append(
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            }
        )
        signal.fire(2)
        XCTAssertTrue(result==8)

        // reset listeners container
        listeners.reset()
        signal.fire(3)
        XCTAssertTrue(result==8)
    }

    func testSignalListenersDeinit() {
        var result = 0
        let signal = Signal<Int>()
        var listeners: SignalListeners! = SignalListeners()
        
        listeners.set(
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            },
            signal.wait(self, exec: .Same) { (ctx, res) in
                result += res
            }
        )
        listeners = nil

        signal.fire(1)
        XCTAssertTrue(result==0)
    }

}
