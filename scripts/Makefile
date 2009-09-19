.SUFFIXES:

DIRS := $(sort $(wildcard rip.*))
PATH := $(PATH):$(shell pwd)

export PATH

all : $(DIRS)

.PHONY: $(DIRS)
$(DIRS) :
	$(MAKE) -C $@
