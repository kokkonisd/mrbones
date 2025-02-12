DESTDIR ?= /usr/bin

SOURCE = $(realpath .)/mrbones.sh
TARGET = mrbones


install:
	install $(SOURCE) $(DESTDIR)/$(TARGET)

uninstall:
	rm $(DESTDIR)/$(TARGET)

test:
	bash run-tests.sh
