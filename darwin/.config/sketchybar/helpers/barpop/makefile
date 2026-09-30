SOURCES := $(wildcard *.swift Kit/*.swift)

bin/barpop: $(SOURCES) | bin
	swiftc -O -swift-version 6 -o bin/barpop $(SOURCES)

bin:
	mkdir -p bin
