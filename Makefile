# HerdPet — macOS 13+, SwiftPM
CONFIG ?= release
APP    := build/HerdPet.app

.PHONY: all build app run test clean

all: app

build:
	swift build -c $(CONFIG)

app:
	./scripts/build-app.sh $(CONFIG)

run: app
	open $(APP)

test:
	swift test

clean:
	swift package clean
	rm -rf $(APP)
