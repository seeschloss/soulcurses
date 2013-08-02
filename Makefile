DC?=dmd

BINDIR=bin
SRCDIR=src
OBJDIR=obj
DOCDIR=doc

PREFIX?=/usr

FILES=$(SRCDIR)/soulcurses.d \
      $(SRCDIR)/messages.d \
      $(SRCDIR)/message_codes.d \
      $(SRCDIR)/defines.d \
      $(SRCDIR)/system.d

BIN=$(BINDIR)/soulcurses

all: soulcurses

soulcurses: $(BIN)

$(BIN): $(FILES)
	@mkdir -p $(OBJDIR)
	@mkdir -p $(BINDIR)
ifeq ($(DC), gdc)
		$(DC) $(FILES) -I$(SRCDIR) -o$(BIN)
else
		$(DC) $(FILES) -I$(SRCDIR) -od$(OBJDIR) -of$(BIN) -gc
endif

install: $(SOULCURSES)
	install -D --strip $(BIN) $(PREFIX)/$(BIN)

clean:
	-rm -rf $(OBJDIR)
	-rm -rf $(BINDIR)
