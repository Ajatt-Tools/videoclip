PROJECT     := videoclip
PACKAGE     := videoclip
# PREFIX is a path to the mpv config directory,
# e.g. ~/.config/mpv/ or $pkgdir/etc/mpv when using PKGBUILD.
PREFIX      ?= $(HOME)/.config/mpv
BRANCH      ?= master
VERSION     ?= $(shell git describe --tags $(BRANCH))
RELEASE_DIR := .github/RELEASE
ZIP         := $(RELEASE_DIR)/$(PROJECT)_$(VERSION).zip

EXAMPLE_CONFIG      := $(PROJECT)/config/default_config.conf
EXAMPLE_CONFIG_COPY := $(RELEASE_DIR)/$(PACKAGE).conf

.PHONY: all install uninstall clean

all: $(ZIP) $(EXAMPLE_CONFIG_COPY)

$(RELEASE_DIR):
	mkdir -p "$@"

$(ZIP): | $(RELEASE_DIR)
	git archive \
	--prefix=$(PROJECT)/ \
	--format=zip \
	--output "$@" \
	"$(BRANCH):$(PROJECT)"

$(EXAMPLE_CONFIG_COPY): $(EXAMPLE_CONFIG) | $(RELEASE_DIR)
	cp -- "$<" "$@"

install: $(EXAMPLE_CONFIG)
	@echo "Installing $(PROJECT) to $(PREFIX)/scripts/$(PROJECT)/"
	install -d "$(PREFIX)/scripts/$(PROJECT)/"
	cp -a -- "./$(PROJECT)" "$(PREFIX)/scripts/"
	if [ ! -f "$(PREFIX)/script-opts/$(PACKAGE).conf" ]; then \
		install -Dm644 "$(EXAMPLE_CONFIG)" "$(PREFIX)/script-opts/$(PACKAGE).conf"; \
	fi

uninstall:
	rm -rf -- "$(PREFIX)/scripts/$(PROJECT)"

clean:
	rm -v -- "$(ZIP)" "$(EXAMPLE_CONFIG_COPY)" || true
