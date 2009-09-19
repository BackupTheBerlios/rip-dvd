DIRS := $(sort $(wildcard rip.*))
PATH := $(PATH):$(shell pwd)

export PATH

all : mclean $(DIRS)

.PHONY: $(DIRS)
$(DIRS) :
	$(MAKE) -C $@

# Rely on make's builtin rules to actually do the compilation
mclean : mclean.c
