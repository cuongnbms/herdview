import XCTest
@testable import HerdviewCore

final class TOMLSubsetTests: XCTestCase {
    func testRootKeysTablesAndArraysOfTables() throws {
        let text = """
        # comment line
        pet = "boba"   # inline comment
        count = 3
        flag = true

        [clips]
        idle = 0
        blocked = 2

        [[hosts]]
        name = "local"
        herdr_path = "/opt/homebrew/bin/herdr"

        [[hosts]]
        name = "devtuf"
        ssh = "devtuf"
        poll_seconds = 5
        """
        let doc = try TOMLSubset.parse(text)
        XCTAssertEqual(doc.root["pet"], .string("boba"))
        XCTAssertEqual(doc.root["count"], .integer(3))
        XCTAssertEqual(doc.root["flag"], .bool(true))
        XCTAssertEqual(doc.tables["clips"]?["idle"], .integer(0))
        XCTAssertEqual(doc.tables["clips"]?["blocked"], .integer(2))
        XCTAssertEqual(doc.arrays["hosts"]?.count, 2)
        XCTAssertEqual(doc.arrays["hosts"]?[0]["name"], .string("local"))
        XCTAssertEqual(doc.arrays["hosts"]?[1]["ssh"], .string("devtuf"))
        XCTAssertEqual(doc.arrays["hosts"]?[1]["poll_seconds"], .integer(5))
    }

    func testStringEscapesAndHashInsideString() throws {
        let doc = try TOMLSubset.parse(#"name = "a \"quoted\" # not a comment""#)
        XCTAssertEqual(doc.root["name"], .string(#"a "quoted" # not a comment"#))
    }

    func testBadValueThrowsWithLineNumber() {
        XCTAssertThrowsError(try TOMLSubset.parse("ok = 1\nbad = nope")) { error in
            guard case let TOMLSubsetError.syntax(line, _)? = error as? TOMLSubsetError else {
                return XCTFail("expected syntax error, got \(error)")
            }
            XCTAssertEqual(line, 2)
        }
    }

    func testMissingEqualsThrows() {
        XCTAssertThrowsError(try TOMLSubset.parse("just words"))
    }

    func testInlineStringArray() throws {
        let doc = try TOMLSubset.parse("""
        [messages]
        blocked = ["I need you!", "Your turn 👀"]   # comment
        empty = []
        one = [ "x" ]
        """)
        XCTAssertEqual(doc.tables["messages"]?["blocked"], .array([.string("I need you!"), .string("Your turn 👀")]))
        XCTAssertEqual(doc.tables["messages"]?["empty"], .array([]))
        XCTAssertEqual(doc.tables["messages"]?["one"], .array([.string("x")]))
        XCTAssertEqual(doc.tables["messages"]?["blocked"]?.stringArrayValue, ["I need you!", "Your turn 👀"])
    }

    func testArrayWithCommaInsideStringAndTrailingComma() throws {
        let doc = try TOMLSubset.parse(#"lines = ["a, b", "c",]"#)
        XCTAssertEqual(doc.root["lines"]?.stringArrayValue, ["a, b", "c"])
    }

    func testUnterminatedArrayThrows() {
        XCTAssertThrowsError(try TOMLSubset.parse(#"lines = ["a""#))
    }

    func testNestedArrayIsRejected() {
        XCTAssertThrowsError(try TOMLSubset.parse(#"lines = [["a"]]"#))
    }
}
