//
//  ListenerTests.swift
//  fut
//
//  Created by Nikolay on 1/25/17.
//  Copyright © 2017 nkim. All rights reserved.
//

import XCTest
@testable import fut


class ListenerTests: XCTestCase {

    func testWaitCancelled() {
        var result = 0
        let handler = Dispatcher<Int>(.Same) { res in
            result = res
        }
        handler.cancel()
        let executed = handler.dispatch(1)
        XCTAssertEqual(result, 0)
        XCTAssertFalse(executed)
    }

    func testWaitWeakContext() {
        var result = 0
        var context: NSObject! = NSObject()

        let handler = Dispatcher<Int>(context, target:.Same, waiter: { ctx, res in
            result = res
        })
        context = nil

        let executed = handler.dispatch(1)
        XCTAssertEqual(result, 0)
        XCTAssertFalse(executed)
    }

    func testNotifyCancelled() {
        var result = 0
        let handler = Dispatcher<Int>(.Same) {
            result = 10
        }
        handler.cancel()
        let executed = handler.dispatch(1)
        XCTAssertEqual(result, 0)
        XCTAssertFalse(executed)
    }

    func testNotifyWeakContext() {
        var result = 0
        var context: NSObject! = NSObject()

        let handler = Dispatcher<Int>(context, target:.Same, notify: { ctx in
            result = 10
        })
        context = nil

        let executed = handler.dispatch(1)
        XCTAssertEqual(result, 0)
        XCTAssertFalse(executed)
    }

    func testWaitSameTarget() {
        var result = 0
        let handler = Dispatcher<Int>(.Same) { res in
            result = res
        }
        let executed = handler.dispatch(1)
        XCTAssertTrue(result==1)
        XCTAssertTrue(executed)
    }

    func testWaitSameTargetWithContext() {
        var result = 0
        let handler = Dispatcher<Int>(self, target: .Same) { [weak self] (ctx, res) in
            if let s = self, ctx === s {
                result = res
            }
        }
        let executed = handler.dispatch(1)
        XCTAssertTrue(result==1)
        XCTAssertTrue(executed)
    }

    func testNotifySameTarget() {
        var result = 0
        let handler = Dispatcher<Int>(.Same) {
            result = 10
        }
        let executed = handler.dispatch(1)
        XCTAssertTrue(result==10)
        XCTAssertTrue(executed)
    }

    func testNotifySameTargetWithContext() {
        var result = 0
        let handler = Dispatcher<Int>(self, target: .Same, notify: { [weak self] ctx in
            if let s = self, ctx === s {
                result = 10
            }
        })
        let executed = handler.dispatch(1)
        XCTAssertTrue(result==10)
        XCTAssertTrue(executed)
    }

    func testWaitMainTarget() {
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()

        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())

        let handler = Dispatcher<Int>(target, waiter: { res in
            XCTAssertEqual(res, 1)
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testWaitMainTargetWithContext() {
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()

        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())

        let handler = Dispatcher<Int>(self, target: target, waiter: { ctx, res in
            XCTAssertEqual(res, 1)
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testNotifyMainTarget() {
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()

        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())

        let handler = Dispatcher<Int>(target, notify: {
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testNotifyMainTargetWithContext() {
        let expect = self.expectation(description: "Signal handler")
        let testQueueKey = DispatchSpecificKey<Void>()

        let target = Target.Queue(DispatchQueue.main)
        DispatchQueue.main.setSpecific(key: testQueueKey, value: ())

        let handler = Dispatcher<Int>(self, target: target, notify: { ctx in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: testQueueKey))
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testNotifyBackgroundTarget() {
        let expect = self.expectation(description: "Signal handler")

        let handler = Dispatcher<Int>(Target.Bg, notify: {
            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()) {
                XCTAssertEqual(qos, DispatchQoS.QoSClass.background)
            } else {
                XCTFail()
            }
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testNotifyBackgroundTargetWithContext() {
        let expect = self.expectation(description: "Signal handler")

        let handler = Dispatcher<Int>(self, target: Target.Bg, notify: { ctx in
            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()) {
               XCTAssertEqual(qos, DispatchQoS.QoSClass.background)
            } else {
                XCTFail()
            }
            expect.fulfill()
        })
        _ = handler.dispatch(1)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testWaitBackgroundTarget() {
        let expect = self.expectation(description: "Signal handler")

        let handler = Dispatcher<Int>(Target.Bg, waiter: { res in
            XCTAssertEqual(res, 10)

            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()) {
                XCTAssertEqual(qos, DispatchQoS.QoSClass.background)
            } else {
                XCTFail()
            }
            expect.fulfill()
        })
        _ = handler.dispatch(10)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testWaitBackgroundTargetWithContext() {
        let expect = self.expectation(description: "Signal handler")

        let handler = Dispatcher<Int>(self, target: Target.Bg, waiter: { (ctx, res) in
            XCTAssertEqual(res, 10)

            if let qos = DispatchQoS.QoSClass(rawValue: qos_class_self()) {
                XCTAssertEqual(qos, DispatchQoS.QoSClass.background)
            } else {
                XCTFail()
            }
            expect.fulfill()
        })
        _ = handler.dispatch(10)

        self.waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectations errord: \(error)")
            }
        }
    }

    func testSignalListeners() {
        var result = 0
        let signal = Signal<Int>()
        let listeners = Listeners()
        
        listeners.set(
            signal.wait(self, on: .Same) { (ctx, res) in
                result += res
            },
            signal.wait(self, on: .Same) { (ctx, res) in
                result += res
            }
        )
        
        signal.fire(1)
        XCTAssertTrue(result==2)
        
        // reset listeners container and set new signal handlers
        listeners.set(
            signal.wait(self, on: .Same) { (ctx, res) in
                result += res
            }
        )
        signal.fire(2)
        XCTAssertTrue(result==4)
        
        // register on
        listeners.append(
            signal.wait(self, on: .Same) { (ctx, res) in
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
        var listeners: Listeners! = Listeners()
        
        listeners.set(
            signal.wait(self, on: .Same) { (ctx, res) in
                result += res
            },
            signal.wait(self, on: .Same) { (ctx, res) in
                result += res
            }
        )
        listeners = nil
        
        signal.fire(1)
        XCTAssertTrue(result==0)
    }
    
}
