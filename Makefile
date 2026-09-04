.PHONY: build run test check icon
SIGNING_IDENTITY ?= Apple Development

icon:
	sh Scripts/build-icon.sh

build:
	swift build -c release
	mkdir -p dist/SchnapShot.app/Contents/MacOS dist/SchnapShot.app/Contents/Resources
	cp .build/release/SchnapShot dist/SchnapShot.app/Contents/MacOS/SchnapShot.next
	mv -f dist/SchnapShot.app/Contents/MacOS/SchnapShot.next dist/SchnapShot.app/Contents/MacOS/SchnapShot
	cp Resources/Info.plist dist/SchnapShot.app/Contents/Info.plist
	cp Resources/AppIcon.icns dist/SchnapShot.app/Contents/Resources/AppIcon.icns
	codesign --force --sign "$(SIGNING_IDENTITY)" --identifier com.anson.SchnapShot dist/SchnapShot.app

run: build
	open dist/SchnapShot.app

test:
	swift test

check: test build
	plutil -lint dist/SchnapShot.app/Contents/Info.plist
	codesign --verify --deep --strict dist/SchnapShot.app
	test -s dist/SchnapShot.app/Contents/Resources/AppIcon.icns
