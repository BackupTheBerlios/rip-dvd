.SUFFIXES:

DIRS := $(sort $(wildcard rip.*))
PATH := $(PATH):/home/thomas/rip/

export PATH

all : $(DIRS)

.PHONY: $(DIRS)
$(DIRS) :
	$(MAKE) -C $@
