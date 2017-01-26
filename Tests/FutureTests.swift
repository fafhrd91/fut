//
//  FutureTests.swift
//  fut
//
//  Created by Nikolay on 1/25/17.
//  Copyright © 2017 nkim. All rights reserved.
//

import XCTest
@testable import fut


class FutureTests: XCTestCase {

    func testCtor() {
        let fut = Future<Int>(1)

        switch fut.state {
            case .finished(let res):
                XCTAssertEqual(res, 1)
            default:
                XCTFail()
        }

        XCTAssertEqual(fut, fut)
        XCTAssertNotEqual(fut, Future<Int>(1))
        XCTAssertNotEqual(fut.hashValue, Future<Int>(1).hashValue)
    }

    func testDone() {
        let fut = Future<Int>()
        XCTAssertFalse(fut.isDone())

        _ = fut.cancel()
        XCTAssertTrue(fut.isDone())

        XCTAssertTrue(Future<Int>(1).isDone())
    }

    func testCancel() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        let cancelled = fut.cancel()
        XCTAssertTrue(cancelled)

        XCTAssertEqual(result, 0)

        fut.set(1)
        XCTAssertEqual(result, 0)

        XCTAssertFalse(fut.cancel())
    }

    func testMerge() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        _ = fut.notify(.Same) { res in
            result += 100
        }
        let fut2 = Future<Int>()
        fut2.merge(fut)
        fut2.set(1)
        fut.set(1)
        XCTAssertEqual(result, 101)
    }

    func testMergeSelfFinished() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        _ = fut.notify(.Same) { res in
            result += 100
        }
        let fut2 = Future<Int>(1)
        fut2.merge(fut)
        XCTAssertEqual(result, 101)
    }

    func testMergeSelfCancelled() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        _ = fut.notify(.Same) { res in
            result += 100
        }
        let fut2 = Future<Int>()
        _ = fut2.cancel()
        fut2.merge(fut)
        XCTAssertEqual(result, 100)
    }

    func testReset() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        _ = fut.notify(.Same) { res in
            result += 100
        }
        fut.reset()
        fut.set(1)
        XCTAssertEqual(result, 0)
    }

    func testWait() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        fut.set(1)
        XCTAssertTrue(result==1)
    }

    func testWaitFinished() {
        var result = 0
        let fut = Future<Int>()
        fut.set(1)

        // wait on finished future
        _ = fut.wait(.Same) { res in
            result += res
        }
        XCTAssertTrue(result==1)
    }

    func testWaitCancelled() {
        let fut = Future<Int>()
        let cancelled = fut.cancel()
        XCTAssertTrue(cancelled)

        var result = 0
        _ = fut.wait(.Same) { res in
            result += res
        }
        XCTAssertEqual(result, 0)
    }

    func testWaitWithContext() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.wait(self, on:.Same) { ctx, res in
            result += res
        }
        fut.set(1)
        XCTAssertTrue(result==1)
    }

    func testWaitFinishedWithContext() {
        var result = 0
        let fut = Future<Int>()
        fut.set(1)

        // wait on finished future
        _ = fut.wait(self, on:.Same) { ctx, res in
            result += res
        }
        XCTAssertTrue(result==1)
    }

    func testWaitCancelledWithContext() {
        let fut = Future<Int>()
        let cancelled = fut.cancel()
        XCTAssertTrue(cancelled)

        var result = 0
        _ = fut.wait(self, on:.Same) { ctx, res in
            result += res
        }
        XCTAssertEqual(result, 0)
    }

    func testNotify() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.notify(.Same) { res in
            switch res {
            case .finished(let val):
                result += val
            default:
                XCTFail()
            }
        }
        fut.set(1)
        XCTAssertTrue(result==1)
    }

    func testNotifyCancel() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.notify(.Same) { res in
            switch res {
            case .cancelled:
                result = 100
            default:
                XCTFail()
            }
        }
        _ = fut.cancel()
        XCTAssertTrue(result==100)
    }

    func testNotifyFinished() {
        var result = 0
        let fut = Future<Int>()
        fut.set(1)

        // wait on finished future
        _ = fut.notify(.Same) { res in
            switch res {
            case .finished(let val):
                result += val
            default:
                XCTFail()
            }
        }
        XCTAssertTrue(result==1)
    }

    func testNotifyCancelled() {
        let fut = Future<Int>()
        let cancelled = fut.cancel()
        XCTAssertTrue(cancelled)

        var result = 0
        _ = fut.notify(.Same) { res in
            switch res {
            case .cancelled:
                result = 100
            default:
                XCTFail()
            }
        }
        XCTAssertEqual(result, 100)
    }

    func testNotifyWithContext() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.notify(self, on:.Same) { ctx, res in
            switch res {
            case .finished(let val):
                result += val
            default:
                XCTFail()
            }
        }
        fut.set(1)
        XCTAssertTrue(result==1)
    }

    func testNotifyCancelWithContext() {
        let fut = Future<Int>()

        var result = 0
        _ = fut.notify(self, on:.Same) { ctx, res in
            switch res {
            case .cancelled:
                result = 100
            default:
                XCTFail()
            }
        }
        _ = fut.cancel()
        XCTAssertTrue(result==100)
    }

    func testNotifyFinishedWithContext() {
        var result = 0
        let fut = Future<Int>()
        fut.set(1)

        // wait on finished future
        _ = fut.notify(self, on:.Same) { ctx, res in
            switch res {
            case .finished(let val):
                result += val
            default:
                XCTFail()
            }
        }
        XCTAssertTrue(result==1)
    }

    func testNotifyCancelledWithContext() {
        let fut = Future<Int>()
        let cancelled = fut.cancel()
        XCTAssertTrue(cancelled)

        var result = 0
        _ = fut.notify(self, on:.Same) { ctx, res in
            switch res {
            case .cancelled:
                result = 100
            default:
                XCTFail()
            }
        }
        XCTAssertEqual(result, 100)
    }

}
