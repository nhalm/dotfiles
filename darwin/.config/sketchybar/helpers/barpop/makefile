SOURCES := $(wildcard *.swift Kit/*.swift)
APP := bin/barpop.app/Contents

# A bundle, so macOS asks for Calendar, Bluetooth and Location in barpop's
# own name. bin/barpop is the same binary for the show/hide commands.
bin/barpop: $(APP)/MacOS/barpop
	ln -sf barpop.app/Contents/MacOS/barpop bin/barpop

$(APP)/MacOS/barpop: $(SOURCES) Info.plist
	mkdir -p $(APP)/MacOS
	cp Info.plist $(APP)/Info.plist
	swiftc -O -swift-version 6 -o $@ $(SOURCES)
	codesign --force --sign - --identifier local.dotfiles.barpop bin/barpop.app
