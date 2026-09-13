# Herdview — macOS 13+, SwiftPM
CONFIG ?= release
APP    := build/Herdview.app

.PHONY: all build app run test icon clean

all: app

build:
	swift build -c $(CONFIG)

app:
	./scripts/build-app.sh $(CONFIG)

# Redraws scripts/AppIcon.icns. Only needed when the icon itself changes; the
# committed .icns is what `app` packages. COLOR is the accent — the colour of
# the one agent that is asking — and the tile stays dark whatever it is. Hex
# without the `#`, which make would read as the start of a comment:
# `make icon COLOR=5C43DC`.
#
# Built rather than run as a script: the mark is shared with the menu bar item
# in Sources/App/HerdMark.swift, and `swift` runs only one file.
COLOR ?=
icon:
	@mkdir -p build
	swiftc -parse-as-library -O scripts/make-icon.swift Sources/App/HerdMark.swift -o build/make-icon
	./build/make-icon . $(if $(COLOR),--color $(COLOR),)

run: app
	open $(APP)

test:
	swift test

clean:
	swift package clean
	rm -rf $(APP)
