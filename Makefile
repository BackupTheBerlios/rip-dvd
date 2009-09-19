DIRS := $(sort $(wildcard rip.*))
PATH := $(PATH):$(shell pwd)

DISTFILES := scripts/ Makefile LICENCE README mclean.c mclean
VERSION := 0.1

export PATH

all : mclean $(DIRS)

.PHONY: $(DIRS)
$(DIRS) :
	$(MAKE) -C $@

# Rely on make's builtin rules to actually do the compilation
mclean : mclean.c

dist : $(DISTFILES)
	@mkdir dvd-ripper-$(VERSION)
	@cp -Rv $(DISTFILES) dvd-ripper-$(VERSION)
	@tar -czf dvd-ripper-$(VERSION).tar.gz dvd-ripper-$(VERSION)
	@rm -Rf -- dvd-ripper-$(VERSION)
