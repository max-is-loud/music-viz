.PHONY: build test app run clean

CONFIG ?= debug
EXECUTABLE := .build/$(CONFIG)/MusicViz
APP := .build/MusicViz.app
RESOURCE_BUNDLE := .build/$(CONFIG)/MusicViz_MusicVizCore.bundle

build:
	swift build -c $(CONFIG)

test:
	swift test

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp $(EXECUTABLE) $(APP)/Contents/MacOS/MusicViz
	cp Resources/AppBundle/Info.plist $(APP)/Contents/Info.plist
	if [ -d "$(RESOURCE_BUNDLE)" ]; then cp -R "$(RESOURCE_BUNDLE)" "$(APP)/Contents/Resources/"; fi
	codesign --force --deep --sign - $(APP)
	codesign --verify --deep --strict --verbose=2 $(APP)

run: app
	open $(APP)

clean:
	rm -rf .build
