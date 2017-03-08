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
      $(SRCDIR)/undead/doformat.d \
      $(SRCDIR)/undead/internal/file.d \
      $(SRCDIR)/undead/cstream.d \
      $(SRCDIR)/undead/socketstream.d \
      $(SRCDIR)/undead/stream.d


BIN=$(BINDIR)/soulcurses

all: soulcurses

soulcurses: $(BIN)

$(BIN): $(FILES)
	@mkdir -p $(OBJDIR)
	@mkdir -p $(BINDIR)
ifeq ($(DC), gdc)
		$(DC) $(FILES) -I$(SRCDIR) -lreadline -o$(BIN)
else
		$(DC) $(FILES) -I$(SRCDIR) -L-lreadline -od$(OBJDIR) -of$(BIN) -gc
endif

install: $(SOULCURSES)
	install -D --strip $(BIN) $(PREFIX)/$(BIN)

clean:
	-rm -rf $(OBJDIR)
	-rm -rf $(BINDIR)
