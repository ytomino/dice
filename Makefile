HOST:=$(shell gcc -dumpmachine)
TARGET=$(HOST)

ifneq (,$(findstring mingw,$(TARGET)))
 EXESUFFIX=.exe
else
 EXESUFFIX=
endif

ifneq ($(TARGET),$(HOST))
 GNATPREFIX=$(TARGET)-
 BINLN=
else
 GNATPREFIX=
 BINLN=bin
endif

BUILD=release

ifeq ($(BUILD),debug)
 BUILDDIR=$(TARGET).noindex/debug
 LINK=
else
 BUILDDIR=$(TARGET).noindex
 LINK=gc
endif

CFLAGS=-pipe
CFLAGS_ADA=-gnatef -gnatwaI
LDFLAGS=

ifneq ($(findstring freebsd,$(TARGET)),)
 LDFLAGS+=-lm -lgcc_eh -lpthread
endif

ifeq ($(LINK),gc)
 ifneq ($(findstring darwin,$(TARGET)),)
  LDFLAGS+=-dead_strip
  ifneq ($(WHYLIVE),)
   LDFLAGS+=-Wl,-why_live,$(WHYLIVE)
  endif
 else
  CFLAGS+=-ffunction-sections -fdata-sections
  LDFLAGS+=-Wl,--gc-sections
 endif
else ifeq ($(LINK),lto)
 CFLAGS+=-flto
 LDFLAGS+=-flto
endif

ifeq ($(BUILD),debug)
 CFLAGS+=-ggdb -Og -fno-guess-branch-probability
 CFLAGS_ADA+=-gnata
 LDFLAGS+=-ggdb -Og
else
 CFLAGS+=-ggdb1 -Os
 CFLAGS_ADA+=-gnatB -gnatn2 -gnatVn
 LDFLAGS+=-ggdb1 -Os
 ifneq ($(findstring freebsd,$(TARGET))$(findstring linux-gnu,$(TARGET)),)
  LDFLAGS+=-Wl,--compress-debug-sections=zlib
 endif
endif

ifneq ($(DRAKE_RTSROOT),)
 VERSION:=$(shell gcc -dumpversion)
 ifneq ($(and $(filter debug,$(BUILD)),$(wildcard $(DRAKE_RTSROOT)/$(TARGET)/$(VERSION)/debug)),)
  DRAKE_RTSDIR=$(DRAKE_RTSROOT)/$(TARGET)/$(VERSION)/debug
 else
  DRAKE_RTSDIR=$(DRAKE_RTSROOT)/$(TARGET)/$(VERSION)
 endif
endif

GARGS=$(addprefix --RTS=,$(DRAKE_RTSDIR))
MARGS=-C -D $(BUILDDIR) -gnatA $(addprefix -gnatec=,$(wildcard *.adc))
CARGS=$(CFLAGS) $(CFLAGS_ADA)
BARGS=-E -x
LARGS=$(LDFLAGS)
FARGS=

DESTDIR=
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin

.PHONY: all clean install install-bin xfind xfindall

all: $(BUILDDIR)/dice$(EXESUFFIX) $(BINLN)

$(BUILDDIR)/dice$(EXESUFFIX): source/dice.adb | $(BUILDDIR)
	$(GNATPREFIX)gnatmake -c $< $(MARGS) $(GARGS) -cargs $(CARGS)
	cd $(BUILDDIR) && $(GNATPREFIX)gnatbind $(basename $(notdir $<)).ali $(GARGS) $(BARGS)
	cd $(BUILDDIR) && $(GNATPREFIX)gnatlink -o $(notdir $@) $(basename $(notdir $<)).ali $(GARGS) $(LARGS)

$(BINLN): | $(BUILDDIR)
	ln -s $(BUILDDIR) $@

$(BUILDDIR):
	mkdir -p $@

clean:
	-rm -r $(BUILDDIR)

install: install-bin

install-bin: $(BUILDDIR)/dice$(EXESUFFIX) | $(DESTDIR)$(BINDIR)
	install -s $< $(DESTDIR)$(BINDIR)

$(DESTDIR)$(BINDIR):
	mkdir -p $@

xfind:
	gnatfind -f -aIsource -aO$(BUILDDIR) $(X) $(GARGS) $(FARGS) | sed 's|^$(PWD)/||'

xfindall: FARGS+=-r
xfindall: xfind
