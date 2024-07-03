//
//  PterodactylExampleUITests.swift
//  PterodactylExampleUITests
//
//  Created by Matt Stanford on 3/17/20.
//  Copyright © 2020 Matt Stanford. All rights reserved.
//

import XCTest
import PterodactylLib

class PterodactylExampleUITests: XCTestCase {

    let app = XCUIApplication()
        
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
    }

    func testUpdateUserDefaults() throws {
        let pterodactyl = Pterodactyl(targetAppBundleId: "com.mattstanford.PterodactylExample")
        let testValue = UUID()
        pterodactyl.updateDefaults([
            "Test": .string(testValue.uuidString)
        ])

        app.launch()

        waitForElementToAppear(object: app.staticTexts["Pterodactyl Example"])

        let defaultsValue = app.staticTexts["DefaultsValue"].firstMatch
        XCTAssertTrue(defaultsValue.exists)
        XCTAssertEqual(defaultsValue.label, testValue.uuidString)
    }

    func testDeleteUserDefaults() throws {
        let pterodactyl = Pterodactyl(targetAppBundleId: "com.mattstanford.PterodactylExample")
        let testValue = UUID()
        pterodactyl.updateDefaults([
            "Test": .string(testValue.uuidString)
        ])

        app.launch()

        waitForElementToAppear(object: app.staticTexts["Pterodactyl Example"])

        let defaultsValue = app.staticTexts["DefaultsValue"].firstMatch
        XCTAssertTrue(defaultsValue.exists)
        XCTAssertEqual(defaultsValue.label, testValue.uuidString)

        app.terminate()

        pterodactyl.deleteDefaults(for: ["Test"])
        app.launch()

        waitForElementToAppear(object: app.staticTexts["Pterodactyl Example"])

        XCTAssertTrue(defaultsValue.exists)
        XCTAssertEqual(defaultsValue.label, "MISSING VALUE")
    }

    func testSimulatorPush() throws {
        app.launch()

        let notificationRequest = "“PterodactylExample” Would Like to Send You Notifications"

        let pterodactyl = Pterodactyl(targetAppBundleId: "com.mattstanford.PterodactylExample")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let existsPredicate = NSPredicate { _, _ in
            springboard.staticTexts[notificationRequest].exists
        }

        let allowNotifications = XCTNSPredicateExpectation(predicate: existsPredicate, object: nil)
        let waiter = XCTWaiter()
        let wait = waiter.wait(for: [allowNotifications], timeout: 2)
        if wait != .timedOut {
            let allowButton = springboard.buttons["Allow"]
            allowButton.tap()
        }

        waitForElementToAppear(object: app.staticTexts["Pterodactyl Example"])
        
        //Tap the home button
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(1)

        //Trigger a push notification
        pterodactyl.triggerSimulatorNotification(withMessage: "here's a simple message")
        
        //Tap the notification when it appears
        let springBoardNotification = springboard.otherElements.descendants(matching: .any)["NotificationShortLookView"]
        waitForElementToAppear(object: springBoardNotification)
        springBoardNotification.tap()

        waitForElementToAppear(object: app.staticTexts["Pterodactyl Example"])
    }
    
    func waitForElementToAppear(object: Any) {
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: object, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
    }
}
