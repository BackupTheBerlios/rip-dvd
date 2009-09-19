OBJDIR := obj
BINDIR := bin
SRCDIR := src
INCDIR := include

LDFLAGS := -lpthread
CFLAGS := -pedantic -Wall -ggdb -I$(INCDIR)

CXXFLAGS := $(CFLAGS)
CCFLAGS := $(CFLAGS) -std=c99

CX := g++ -c $(CXXFLAGS)
CC := gcc -c $(CCFLAGS)
LD := g++ $(LDFLAGS)

BINS := mkcrop mencoderwrap oggencwrap mclean
mkcropOBJS := Process mkcrop
mencoderwrapOBJS := Process mencoderwrap pretty
oggencwrapOBJS := Process oggencwrap pretty
mcleanOBJS := mclean

.PHONY: all
all : $(BINS)

.PHONY : clean
clean :
	@echo "  RMDIR      $(OBJDIR)"
	@rm -rf $(OBJDIR)
	@echo "  RMDIR      $(BINDIR)"
	@rm -rf $(BINDIR)

.PHONY : help
help :
	@echo "Binaries:"
	@echo "  $(BINS)"
	@echo
	@echo "Other targets:"
	@echo "  help - Prints this help message"
	@echo "  clean - Removes all generated files"
	@echo "  $(OBJDIR)/file.o - Build a single object"
	@echo "  info - Prints a list of variables"

.PHONY : info
info :
	@echo "CC	- '$(CC)'"
	@echo "LD	- '$(LD)'"
	@echo "CFLAGS	- '$(CFLAGS)'"
	@echo "LDFLAGS	- '$(LDFLAGS)'"

$(OBJDIR) $(BINDIR) :
	@echo "  MKDIR      $@"
	@mkdir -p $@

$(OBJDIR)/%.o : $(SRCDIR)/%.cpp | $(OBJDIR)
	@echo "  CC         $@"
	@$(CX) -MMD -MP -o $@ $<

$(OBJDIR)/%.o : $(SRCDIR)/%.c | $(OBJDIR)
	@echo "  CC         $@"
	@$(CC) -MMD -MP -o $@ $<

-include $(addprefix $(OBJDIR)/, $(addsuffix .d, $(foreach BIN, $(BINS), $($(BIN)OBJS))))

.SECONDEXPANSION :
$(BINS) : $$(addprefix $(BINDIR)/, $$@)

$(addprefix $(BINDIR)/, $(BINS)) : $$(addprefix $(OBJDIR)/, $$(addsuffix .o, $$($$(notdir $$@)OBJS))) | $(BINDIR)
	@echo "  LD         $@"
	@$(LD) $(LDFLAGS) -o $@ $(filter-out $(BINDIR), $^)
