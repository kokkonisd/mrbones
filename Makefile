DESTDIR ?= /usr/bin

SOURCE = $(realpath .)/mrbones.sh
TARGET = mrbones


install:
	install $(SOURCE) $(DESTDIR)/$(TARGET)

uninstall:
	rm -rf $(DESTDIR)/$(TARGET)
