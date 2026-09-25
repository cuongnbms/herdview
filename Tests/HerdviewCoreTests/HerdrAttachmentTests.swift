import XCTest
@testable import HerdviewCore

final class HerdrAttachmentTests: XCTestCase {
    func testBareHerdrAttachesTheDefaultSession() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys016 herdr"),
                       HerdrAttachment(tty: "ttys016", remote: nil, session: "default"))
    }

    func testSessionFlag() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys016 herdr --session remora"),
                       HerdrAttachment(tty: "ttys016", remote: nil, session: "remora"))
    }

    func testSessionAttachSubcommand() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys003 herdr session attach remora"),
                       HerdrAttachment(tty: "ttys003", remote: nil, session: "remora"))
    }

    func testRemoteWithoutSessionIsTheRemoteDefault() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys004 herdr --remote devtuf"),
                       HerdrAttachment(tty: "ttys004", remote: "devtuf", session: "default"))
    }

    func testRemoteWithSession() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys004 herdr --remote devtuf --session blue-matrix"),
                       HerdrAttachment(tty: "ttys004", remote: "devtuf", session: "blue-matrix"))
    }

    func testFlagOrderDoesNotMatter() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys004 herdr --session carex --remote devtuf"),
                       HerdrAttachment(tty: "ttys004", remote: "devtuf", session: "carex"))
    }

    func testFullExecutablePathCounts() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "ttys000 /opt/homebrew/bin/herdr --session carex"),
                       HerdrAttachment(tty: "ttys000", remote: nil, session: "carex"))
    }

    func testExtraWhitespaceBetweenFields() {
        XCTAssertEqual(HerdrAttachment.parse(psLine: "  ttys000   herdr   --session  carex  "),
                       HerdrAttachment(tty: "ttys000", remote: nil, session: "carex"))
    }

    func testHerdrHelperProcessesAreNotClients() {
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 /opt/homebrew/bin/herdr client"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "?? /opt/homebrew/bin/herdr server"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 herdr --session carex remote-client-bridge"))
    }

    func testOtherSubcommandsAreNotClients() {
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys021 herdr agent list"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys021 herdr --session carex pane current"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys021 herdr session list --json"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys021 herdr --machine tuf agent list"))
    }

    func testNoTerminalIsNotAClient() {
        XCTAssertNil(HerdrAttachment.parse(psLine: "?? herdr --session carex"))
    }

    func testOtherProgramsAreIgnored() {
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 -/bin/zsh"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 ssh -T devtuf exec /home/cuongnb/.local/bin/herdr --session carex remote-client-bridge"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 herdrx --session carex"))
    }

    func testFlagWithoutValueIsNotAClient() {
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 herdr --session"))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000 herdr --remote"))
    }

    func testEmptyLine() {
        XCTAssertNil(HerdrAttachment.parse(psLine: ""))
        XCTAssertNil(HerdrAttachment.parse(psLine: "ttys000"))
    }

    func testListCommand() {
        XCTAssertEqual(HerdrAttachment.listCommand,
                       HostCommand(executable: "/bin/ps", arguments: ["-axo", "tty=,args="]))
    }
}
