#$(call bb-install, \
#    1 target, \               # name (lowercase)
#    2 variable, \             # name (uppercase)
#    3 gfortran, \             # signifies a GCC ABI (e.g. libgfortran version) dependency
#    4 cxx11)                  # signifies a cxx11 ABI dependency

# Auto-detect triplet once, create different versions that we use as defaults below for each BB install target
BB_TRIPLET_LIBGFORTRAN_CXXABI := $(shell $(call invoke_python,$(JULIAHOME)/contrib/normalize_triplet.py) $(or $(XC_HOST),$(XC_HOST),$(BUILD_MACHINE)) "$(shell $(FC) --version | head -1)" "$(or $(shell echo '\#include <string>' | $(CXX) $(CXXFLAGS) -x c++ -dM -E - | grep _GLIBCXX_USE_CXX11_ABI | awk '{ print $$3 }' ),1)")
BB_TRIPLET_LIBGFORTRAN := $(subst $(SPACE),-,$(filter-out cxx%,$(subst -,$(SPACE),$(BB_TRIPLET_LIBGFORTRAN_CXXABI))))
BB_TRIPLET_CXXABI := $(subst $(SPACE),-,$(filter-out libgfortran%,$(subst -,$(SPACE),$(BB_TRIPLET_LIBGFORTRAN_CXXABI))))
BB_TRIPLET := $(subst $(SPACE),-,$(filter-out cxx%,$(filter-out libgfortran%,$(subst -,$(SPACE),$(BB_TRIPLET_LIBGFORTRAN_CXXABI)))))

define bb-install
TRIPLET_VAR := BB_TRIPLET
ifeq ($(3),true)
TRIPLET_VAR := $$(TRIPLET_VAR)_LIBGFORTRAN
endif
ifeq ($(4),true)
TRIPLET_VAR := $$(TRIPLET_VAR)_CXXABI
endif

# Look for JLL version within Project.toml in stdlib/
$(2)_STDLIB_PATH := $(JULIAHOME)/stdlib/$$($(2)_JLL_NAME)_jll

# If the file doesn't exist (e.g. we're downloading a JLL release for something
# that we don't actually ship) silently continue despite the Project.toml file missing.
$(2)_JLL_VER ?= $$(shell [ -f $$($(2)_STDLIB_PATH)/Project.toml ] && grep "^version" $$($(2)_STDLIB_PATH)/Project.toml | sed -E 's/version\s*=\s*"?([^"]+)"?/\1/')

$(2)_BB_TRIPLET := $$($$(TRIPLET_VAR))
$(2)_JLL_VER_NOPLUS := $$(firstword $$(subst +,$(SPACE),$$($(2)_JLL_VER)))
$(2)_JLL_BASENAME := $$($(2)_JLL_NAME).v$$($(2)_JLL_VER).$$($(2)_BB_TRIPLET).tar.gz

# Allow things to override which JLL we pull from, e.g. libLLVM_jll vs. libLLVM_assert_jll
$(2)_JLL_DOWNLOAD_NAME ?= $$($(2)_JLL_NAME)
$(2)_BB_URL := https://github.com/JuliaBinaryWrappers/$$($(2)_JLL_NAME)_jll.jl/releases/download/$$($(2)_JLL_NAME)-v$$($(2)_JLL_VER)/$$($(2)_JLL_NAME).v$$($(2)_JLL_VER_NOPLUS).$$($(2)_BB_TRIPLET).tar.gz

$$(SRCCACHE)/$$($(2)_JLL_BASENAME): | $$(SRCCACHE)
	$$(JLDOWNLOAD) $$@ $$($(2)_BB_URL)

stage-$(strip $1): $$(SRCCACHE)/$$($(2)_JLL_BASENAME)
install-$(strip $1): $$(build_prefix)/manifest/$(strip $1)

reinstall-$(strip $1):
	+$$(MAKE) uninstall-$(strip $1)
	+$$(MAKE) stage-$(strip $1)
	+$$(MAKE) install-$(strip $1)

UNINSTALL_$(strip $1) := $$($(2)_JLL_BASENAME:.tar.gz=) bb-uninstaller

$$(build_prefix)/manifest/$(strip $1): $$(SRCCACHE)/$$($(2)_JLL_BASENAME) | $(build_prefix)/manifest
	-+[ ! -e $$@ ] || $$(MAKE) uninstall-$(strip $1)
	$$(JLCHECKSUM) $$<
	mkdir -p $$(build_prefix)
	$(UNTAR) $$< -C $$(build_prefix)
	echo '$$(UNINSTALL_$(strip $1))' > $$@

clean-bb-download-$(1):
	rm -f $$(SRCCACHE)/$$($(2)_JLL_BASENAME)

clean-$(1):
distclean-$(1): clean-bb-download-$(1)
get-$(1): $$(SRCCACHE)/$$($(2)_JLL_BASENAME)
extract-$(1):
configure-$(1):
compile-$(1): get-$(1)
fastcheck-$(1):
check-$(1):

.PHONY: clean-bb-$(1)

endef

define bb-uninstaller
uninstall-$(strip $1):
	-cd $$(build_prefix) && rm -fdv -- $$$$($$(TAR) -tzf $$(SRCCACHE)/$2.tar.gz --exclude './$$$$')
	-rm $$(build_prefix)/manifest/$(strip $1)
endef
