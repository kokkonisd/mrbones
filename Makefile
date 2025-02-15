DESTDIR ?= /usr/bin

SOURCE = $(realpath .)/mrbones.sh
TARGET = mrbones


install:
	install $(SOURCE) $(DESTDIR)/$(TARGET)

uninstall:
	rm $(DESTDIR)/$(TARGET)

tests:
	bash run-tests.sh


.PHONY: tests
