/**
 
 * Lab 2
 * Dave Norvall and Jim Mittler
 * 10 October 2025
 
 Classic  Concentration Flip Game with Emojis
 
 _Italic text_
 __Bold text__
 ~~Strikethrough text~~

 */

import XCTest

final class lab2UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
