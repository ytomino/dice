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

GARGS:=
MARGS:=-C -D $(BUILDDIR)
CARGS:=-pipe -gnatef -gnatwaI -gnatA $(addprefix -gnatec=,$(abspath $(wildcard *.adc)))
BARGS:=-x
LARGS:=
FARGS:=

ifneq ($(findstring freebsd,$(TARGET)),)
 LARGS:=$(LARGS) -lm -lgcc_eh -lpthread
endif

ifeq ($(LINK),gc)
 ifneq ($(findstring darwin,$(TARGET)),)
  LARGS:=$(LARGS) -dead_strip
  ifneq ($(WHYLIVE),)
   LARGS:=$(LARGS) -Wl,-why_live,$(WHYLIVE)
  endif
 else
  CARGS:=$(CARGS) -ffunction-sections -fdata-sections
  LARGS:=$(LARGS) -Wl,--gc-sections
 endif
else ifeq ($(LINK),lto)
 CARGS:=$(CARGS) -flto
 LARGS:=$(LARGS) -flto
endif

ifeq ($(BUILD),debug)
 CARGS:=$(CARGS) -ggdb -Og -fno-guess-branch-probability -gnata
 BARGS:=$(BARGS) -E
 LARGS:=$(LARGS) -ggdb -Og
else
 CARGS:=$(CARGS) -ggdb1 -Os -gnatB -gnatVn -gnatn2
 BARGS:=$(BARGS) -E
 LARGS:=$(LARGS) -ggdb1 -Os
 ifneq ($(findstring freebsd,$(TARGET))$(findstring linux-gnu,$(TARGET)),)
  LARGS:=$(LARGS) -Wl,--compress-debug-sections=zlib
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

ifneq ($(DRAKE_RTSDIR),)
 GARGS:=$(GARGS) --RTS=$(DRAKE_RTSDIR)
endif

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
