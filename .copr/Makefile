# COPR "make srpm" entry point. COPR runs, from the cloned repository:
#   make -f .copr/Makefile srpm outdir=<dir> spec=<spec>
# and then builds the source RPM written to <dir> for every enabled chroot.
# Locally: make -f .copr/Makefile srpm outdir=/tmp/srpm spec=packaging/rpm/omarchy/omarchy.spec
# See packaging/README.md.

spec ?= packaging/rpm/omarchy/omarchy.spec
outdir ?= $(CURDIR)/srpm

top := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

.PHONY: srpm
srpm:
	@command -v rpmbuild >/dev/null && command -v git >/dev/null || dnf -y install git rpm-build
	@# COPR clones as another user, which git refuses to read unless told the
	@# checkout is safe; -c says so for these commands only.
	@set -e; \
	git() { command git -c safe.directory='$(top)' "$$@"; }; \
	version=$$(sed -E 's/[.-]([a-z])/~\1/' '$(top)/version'); \
	commits=$$(git -C '$(top)' rev-list --count HEAD); \
	sha=$$(git -C '$(top)' rev-parse --short=10 HEAD); \
	release=0.$$commits.git$$sha; \
	name=$$(basename '$(spec)' .spec); \
	mkdir -p '$(outdir)'; \
	git -C '$(top)' archive --format=tar.gz --prefix="omarchy-$$version/" -o "$(outdir)/omarchy-$$version.tar.gz" HEAD; \
	{ printf '%%global omarchy_version %s\n%%global omarchy_release %s\n' "$$version" "$$release"; cat '$(top)/$(spec)'; } >"$(outdir)/$$name.spec"; \
	rpmbuild -bs --define "_sourcedir $(outdir)" --define "_srcrpmdir $(outdir)" "$(outdir)/$$name.spec"
