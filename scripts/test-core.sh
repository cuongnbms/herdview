#!/bin/bash
# Runs XCTest files against Sources/HerdviewCore without XCTest.
#
# This Mac has the Command Line Tools only, whose SDK ships no XCTest, so
# `swift test` cannot build. The test files stay real XCTest files; this
# compiles them with a small shim of the assertions they use.
#
# Usage: scripts/test-core.sh Tests/HerdviewCoreTests/FooTests.swift [...]
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
cat > "$work/shim.swift" <<'SHIM'
import Foundation
class XCTestCase { required init() {}; func setUp() {}; func tearDown() {} }
var failures: [String] = []
func XCTFail(_ m: String = "", file: StaticString = #file, line: UInt = #line) { failures.append("\(file):\(line) \(m)") }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { let x = try a(), y = try b(); if x != y { XCTFail("\(x) != \(y) \(m)", file: file, line: line) } } catch { XCTFail("threw \(error)", file: file, line: line) } }
func XCTAssertNil<T>(_ a: @autoclosure () throws -> T?, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { if let x = try a() { XCTFail("not nil: \(x) \(m)", file: file, line: line) } } catch { XCTFail("threw \(error)", file: file, line: line) } }
func XCTAssertNotNil<T>(_ a: @autoclosure () throws -> T?, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { if try a() == nil { XCTFail("nil \(m)", file: file, line: line) } } catch { XCTFail("threw \(error)", file: file, line: line) } }
func XCTAssertTrue(_ a: @autoclosure () throws -> Bool, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { if !(try a()) { XCTFail("false \(m)", file: file, line: line) } } catch { XCTFail("threw \(error)", file: file, line: line) } }
func XCTAssertFalse(_ a: @autoclosure () throws -> Bool, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { if try a() { XCTFail("true \(m)", file: file, line: line) } } catch { XCTFail("threw \(error)", file: file, line: line) } }
func XCTAssertThrowsError<T>(_ a: @autoclosure () throws -> T, _ m: String = "", file: StaticString = #file, line: UInt = #line) {
    do { _ = try a(); XCTFail("did not throw \(m)", file: file, line: line) } catch {} }
struct XCTUnwrapError: Error {}
func XCTUnwrap<T>(_ a: @autoclosure () throws -> T?, file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let x = try a() else { XCTFail("unwrap nil", file: file, line: line); throw XCTUnwrapError() }; return x }
SHIM
main="$work/main.swift"
echo "import Foundation" > "$main"
: > "$work/names"
i=0
for f in "$@"; do
  i=$((i+1))
  sed -e 's/^import XCTest$/import Foundation/' -e 's/^@testable import HerdviewCore$//' "$f" > "$work/case$i.swift"
  cls=$(grep -o 'class [A-Za-z0-9_]*: XCTestCase' "$f" | head -1 | awk '{print $2}' | tr -d ':')
  grep -o 'func test[A-Za-z0-9_]*()\( throws\)\?' "$f" | while read -r _ sig rest; do
    name=${sig%()}
    if [ "$rest" = "throws" ]; then
      call="do { try s.$name() } catch { failures.append(\"$cls.$name threw \\(error)\") }"
    else
      call="s.$name()"
    fi
    echo "do { let s = $cls(); s.setUp(); $call; s.tearDown() }" >> "$main"
    echo "$cls.$name" >> "$work/names"
  done
done
cat >> "$main" <<'MAIN'
for f in failures { print("FAIL: \(f)") }
print(failures.isEmpty ? "ALL PASSED" : "\(failures.count) FAILURE(S)")
exit(failures.isEmpty ? 0 : 1)
MAIN
echo "$(wc -l < "$work/names" | tr -d ' ') tests"
swiftc -o "$work/tests" "$work"/shim.swift "$work"/case*.swift "$main" "$repo"/Sources/HerdviewCore/*.swift
"$work/tests"
