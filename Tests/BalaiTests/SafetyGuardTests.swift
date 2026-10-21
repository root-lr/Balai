import XCTest
@testable import Balai

final class SafetyGuardTests: XCTestCase {
    private let home = Paths.home

    private func isAllowed(_ url: URL) -> Bool {
        SafetyGuard.verdict(for: url) == .allowed
    }

    func testProtectedFoldersAreDenied() {
        XCTAssertFalse(isAllowed(home))
        XCTAssertFalse(isAllowed(Paths.library))
        XCTAssertFalse(isAllowed(Paths.lib("Caches")))
        XCTAssertFalse(isAllowed(Paths.lib("Application Support")))
        XCTAssertFalse(isAllowed(Paths.inHome("Documents")))
        XCTAssertFalse(isAllowed(Paths.inHome("Desktop")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/Applications")))
    }

    func testSensitiveAreasAreDenied() {
        XCTAssertFalse(isAllowed(Paths.lib("Keychains", "login.keychain-db")))
        XCTAssertFalse(isAllowed(Paths.lib("Mobile Documents", "com~apple~CloudDocs", "file.txt")))
        XCTAssertFalse(isAllowed(Paths.lib("Mail", "V10")))
    }

    func testCredentialsAndPersonalDataAreDenied() {
        XCTAssertFalse(isAllowed(Paths.inHome(".ssh", "id_ed25519")))
        XCTAssertFalse(isAllowed(Paths.inHome(".gnupg")))
        XCTAssertFalse(isAllowed(Paths.lib("Accounts", "Accounts4.sqlite")))
        XCTAssertFalse(isAllowed(Paths.lib("Application Support", "AddressBook")))
        XCTAssertFalse(isAllowed(Paths.lib("Safari", "History.db")))
    }

    /// Les volumes macOS ignorent la casse : changer de casse ne doit pas contourner la protection.
    func testCaseVariantsAreDenied() {
        XCTAssertFalse(isAllowed(Paths.inHome("library", "keychains", "login.keychain-db")))
        XCTAssertFalse(isAllowed(Paths.inHome("LIBRARY")))
        XCTAssertFalse(isAllowed(Paths.inHome(".SSH", "id_rsa")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/APPLICATIONS/readme.txt")))
    }

    func testSystemPathsAreDenied() {
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/System/Library")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/usr/local/bin/tool")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/Library/Caches/foo")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/etc/hosts")))
    }

    func testPathTraversalIsDenied() {
        let sneaky = Paths.lib("Caches", "foo", "..", "..")
        XCTAssertFalse(isAllowed(sneaky))
        let outside = Paths.lib("Caches", "..", "..", "..", "..", "etc")
        XCTAssertFalse(isAllowed(outside))
    }

    func testContentOfUserFoldersIsAllowed() {
        XCTAssertTrue(isAllowed(Paths.lib("Caches", "com.example.app")))
        XCTAssertTrue(isAllowed(Paths.lib("Logs", "DiagnosticReports")))
        XCTAssertTrue(isAllowed(Paths.inHome("Downloads", "installer.dmg")))
    }

    func testApplicationsRules() {
        XCTAssertTrue(isAllowed(URL(fileURLWithPath: "/Applications/SomeThirdParty.app")))
        XCTAssertTrue(isAllowed(URL(fileURLWithPath: "/Applications/Vendor/Tool.app")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/Applications/readme.txt")))
        XCTAssertFalse(isAllowed(URL(fileURLWithPath: "/Applications/A/B/Deep.app")))
    }
}

final class LeftoverMatcherTests: XCTestCase {
    private let bid = "com.example.Editor"
    private let appName = "Editor"

    private func match(_ file: String, _ rule: LeftoverRule, bundleID: String? = nil) -> Bool {
        LeftoverMatcher.matches(file, rule: rule, bundleID: bundleID ?? bid, appName: appName)
    }

    func testExactName() {
        XCTAssertTrue(match("com.example.Editor", .exactName))
        XCTAssertTrue(match("editor", .exactName))
        XCTAssertFalse(match("Editor Pro", .exactName))
    }

    func testBundlePrefix() {
        XCTAssertTrue(match("com.example.Editor.helper", .bundlePrefix))
        XCTAssertFalse(match("com.example.EditorPro", .bundlePrefix))
        XCTAssertFalse(match("com.example.Other", .bundlePrefix))
    }

    func testShortBundleIDDoesNotMatchWholeVendor() {
        XCTAssertFalse(match("com.vendor.other", .bundlePrefix, bundleID: "com.vendor"))
        XCTAssertTrue(match("com.vendor", .bundlePrefix, bundleID: "com.vendor"))
    }

    func testPlist() {
        XCTAssertTrue(match("com.example.Editor.plist", .plist))
        XCTAssertTrue(match("com.example.Editor.1A2B3C.plist", .plist))
        XCTAssertFalse(match("com.example.EditorPro.plist", .plist))
    }

    func testGroupContainer() {
        XCTAssertTrue(match("ABCDE12345.com.example.Editor", .groupSuffix))
        XCTAssertFalse(match("ABCDE12345.com.example.Office", .groupSuffix))
    }

    /// Sans nom d'app, seules les correspondances sur l'identifiant restent : c'est ce qui décide
    /// si un fichier résiduel est pré-coché.
    func testNameOnlyMatchIsNotABundleMatch() {
        XCTAssertTrue(match("Editor", .exactName))
        XCTAssertFalse(LeftoverMatcher.matches("Editor", rule: .exactName, bundleID: bid, appName: ""))
        XCTAssertTrue(LeftoverMatcher.matches("com.example.Editor", rule: .exactName, bundleID: bid, appName: ""))
    }

    func testSavedStateAndCookies() {
        XCTAssertTrue(match("com.example.Editor.savedState", .savedState))
        XCTAssertTrue(match("com.example.Editor.binarycookies", .cookies))
    }
}
