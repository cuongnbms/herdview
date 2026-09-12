# HerdPet — macOS 13+, SwiftPM
CONFIG ?= release
APP    := build/HerdPet.app

.PHONY: all build app run test icon clean

all: app

build:
	swift build -c $(CONFIG)

app:
	./scripts/build-app.sh $(CONFIG)

# Redraws scripts/AppIcon.icns. Only needed when the icon itself changes; the
# committed .icns is what `app` packages. Hex without the `#`, which make would
# read as the start of a comment: `make icon COLOR=5C43DC`.
COLOR ?=
icon:
	swift scripts/make-icon.swift . $(if $(COLOR),--color $(COLOR),)

run: app
	open $(APP)

test:
	swift test

clean:
	swift package clean
	rm -rf $(APP)
