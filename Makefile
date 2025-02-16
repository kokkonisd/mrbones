DESTDIR ?= /usr/bin

SOURCE = $(realpath .)/mrbones.sh
TARGET = mrbones
BUILD = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

install:
	install $(SOURCE) $(DESTDIR)/$(TARGET)
	sed -i -E 's/BUILD=.+/BUILD="$(BUILD)"/g' $(DESTDIR)/$(TARGET)

uninstall:
	rm $(DESTDIR)/$(TARGET)

tests:
	bash run-tests.sh


.PHONY: tests
