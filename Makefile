DIRS := $(sort $(wildcard rip.*))
PATH := $(PATH):$(shell pwd)

DISTFILES := scripts/ Makefile LICENCE README mclean.c mclean
PROJECT := rip-dvd
VERSION := 0.2

export PATH

all : mclean $(DIRS)

.PHONY: $(DIRS)
$(DIRS) :
	@$(MAKE) -C '$@'

# Rely on make's builtin rules to actually do the compilation
mclean : mclean.c

dist : $(DISTFILES)
	@mkdir $(PROJECT)-$(VERSION)
	@cp -Rv $(DISTFILES) $(PROJECT)-$(VERSION)
	@tar -czf $(PROJECT)-$(VERSION).tar.gz $(PROJECT)-$(VERSION)
	@rm -Rf -- $(PROJECT)-$(VERSION)
