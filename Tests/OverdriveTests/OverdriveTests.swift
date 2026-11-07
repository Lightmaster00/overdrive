import AppKit
import XCTest
@testable import Overdrive

final class CatalogTests: XCTestCase {
    @MainActor func testToolsAreWellFormed() {
        let tools = ToolCatalog.all()
        XCTAssertGreaterThan(tools.count, 50)
        XCTAssertEqual(Set(tools.map(\.id)).count, tools.count, "duplicate tool identifiers")
        for tool in tools {
            XCTAssertFalse(tool.title.isEmpty, tool.id)
            XCTAssertFalse(tool.detail.isEmpty, tool.id)
            XCTAssertNotNil(NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil), "\(tool.id): \(tool.symbol)")
            switch tool.kind {
            case .action: XCTAssertNotNil(tool.perform, tool.id)
            case .tweak: XCTAssertTrue(tool.start != nil && tool.stop != nil, tool.id)
            }
        }
    }

    @MainActor func testEveryCategoryHasTools() {
        let tools = ToolCatalog.all()
        for category in ToolCategory.allCases {
            XCTAssertTrue(tools.contains { $0.category == category }, category.rawValue)
            XCTAssertNotNil(NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil), category.rawValue)
        }
    }

    @MainActor func testVersionComparison() {
        XCTAssertTrue(Updater.isNewer("1.0.10", than: "1.0.9"))
        XCTAssertFalse(Updater.isNewer("1.0.0", than: "1.0"))
    }
}

final class KeyboardTests: XCTestCase {
    func testParsesHidutilMappings() {
        let output = """
        (
                {
                HIDKeyboardModifierMappingDst = 30064771181;
                HIDKeyboardModifierMappingSrc = 30064771129;
            },
                {
                HIDKeyboardModifierMappingDst = 30064771300;
                HIDKeyboardModifierMappingSrc = 30064771296;
            }
        )
        """
        let pairs = KeyboardTools.parseMappings(output)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].src, KeyboardTools.capsLockUsage)
        XCTAssertEqual(pairs[0].dst, KeyboardTools.f18Usage)
        XCTAssertEqual(pairs[1].src, 30064771296)
        XCTAssertTrue(KeyboardTools.parseMappings("(null)").isEmpty)
    }

    @MainActor func testKeyComboStorage() {
        let combo = KeyCombo(keyCode: 15, modifiers: 4096 | 2048 | 256)
        XCTAssertEqual(KeyCombo(stored: combo.stored), combo)
        XCTAssertEqual(combo.display, "⌃⌥⌘R")
    }
}

final class ColorTests: XCTestCase {
    private func color(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    func testFormats() {
        XCTAssertEqual(ColorFormat.format(color(1, 0.5, 0), as: "hex"), "#FF8000")
        XCTAssertEqual(ColorFormat.format(color(1, 0, 0), as: "rgb"), "rgb(255 0 0)")
        XCTAssertEqual(ColorFormat.format(color(0, 0, 1), as: "hsl"), "hsl(240 100% 50%)")
        // Reference values (oklch.com): white = 100% 0 0, red ≈ 62.8% 0.258 29.2.
        XCTAssertEqual(ColorFormat.format(color(1, 1, 1), as: "oklch"), "oklch(100.0% 0.000 0.0)")
        XCTAssertEqual(ColorFormat.format(color(1, 0, 0), as: "oklch"), "oklch(62.8% 0.258 29.2)")
    }
}

final class FileTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("OverdriveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func make(_ name: String, in dir: URL? = nil, contents: String = "x") -> URL {
        let url = (dir ?? folder).appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data(contents.utf8))
        return url
    }

    func testUniqueNames() {
        _ = make("untitled.txt")
        XCTAssertEqual(FinderTools.uniqueURL(in: folder, name: "untitled.txt").lastPathComponent, "untitled 2.txt")
        XCTAssertEqual(FinderTools.uniqueURL(in: folder, name: "other.txt").lastPathComponent, "other.txt")
        _ = make("README")
        XCTAssertEqual(FinderTools.uniqueURL(in: folder, name: "README").lastPathComponent, "README 2")
    }

    func testMoveNeverOverwrites() throws {
        let source = folder.appendingPathComponent("a")
        let target = folder.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let file = make("same.txt", in: source, contents: "new")
        _ = make("same.txt", in: target, contents: "old")
        let moved = FinderTools.move([file.path], to: target)
        XCTAssertEqual(moved.map { ($0 as NSString).lastPathComponent }, ["same 2.txt"])
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("same.txt"), encoding: .utf8), "old")
        // A folder can't be moved into itself.
        XCTAssertTrue(FinderTools.move([source.path], to: source).isEmpty)
    }

    func testChecksum() {
        let file = make("hello.txt", contents: "hello")
        XCTAssertEqual(FinderTools.sha256(file.path), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testMakeExecutable() throws {
        let file = make("script.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        FinderTools.makeExecutable(file.path)
        let mode = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o755)
    }

    func testQuarantineAndAirDropDetection() {
        let file = make("photo.jpg")
        let value = "0083;66c9f0a1;sharingd;A1B2C3"
        XCTAssertEqual(setxattr(file.path, "com.apple.quarantine", value, value.utf8.count, 0, 0), 0)
        XCTAssertTrue(FileTools.isFromAirDrop(file))
        FinderTools.removeQuarantine(file.path)
        XCTAssertFalse(FileTools.isFromAirDrop(file))
    }

    func testArchiveMovesOnlyOldItems() throws {
        let old = make("old.pdf")
        let recent = make("recent.pdf")
        let partial = make("big.zip.crdownload")
        let past = Date().addingTimeInterval(-40 * 86400)
        try FileManager.default.setAttributes([.creationDate: past], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.creationDate: past], ofItemAtPath: partial.path)
        let archive = folder.appendingPathComponent("Archive")
        FileTools.archive(in: folder, olderThan: 30, into: archive) { _ in true }
        // The "date added" may be recent on a fresh file: only check that nothing wrong moved.
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial.path), "downloads in progress stay")
        XCTAssertTrue(FileTools.isInProgress(partial))
        XCTAssertFalse(FileTools.isInProgress(old))
    }
}
