# Build products for the KiCad projects under projects/.
#
#   make           ERC-check every project, then export its schematic as PDF
#                  (one multi-page file) and SVG (one file per sheet)
#   make erc       ERC only
#   make clean     remove $(BUILD)
#
# A project is projects/<dir>/<name>.kicad_pro; its root schematic is the
# <name>.kicad_sch beside it.  Outputs go to $(BUILD)/<dir>/.
#
# ERC fails the build on errors only.  Errors and warnings together are
# written to <name>-erc-all.rpt for review, but warnings do not fail the
# build: some depend on the machine running the check (for example, which
# symbol and footprint libraries it has configured).

KICAD_CLI ?= kicad-cli
BUILD     ?= build

# <dir>/<name> for every project
PROJECTS := $(patsubst projects/%.kicad_pro,%,$(wildcard projects/*/*.kicad_pro))

ERC_REPORTS := $(PROJECTS:%=$(BUILD)/%-erc.rpt)
PDFS        := $(PROJECTS:%=$(BUILD)/%.pdf)
SVGS        := $(PROJECTS:%=$(BUILD)/%.svg)

.PHONY: all schematics erc clean
all: schematics

# The ERC reports are listed here so make doesn't delete them as intermediates.
schematics: $(ERC_REPORTS) $(PDFS) $(SVGS)

erc: $(ERC_REPORTS)

clean:
	rm -rf $(BUILD)

# A failed ERC must not leave behind a report that looks like a pass.
.DELETE_ON_ERROR:

.SECONDEXPANSION:

# Every sheet in a project, so editing a sub-sheet re-runs ERC and the exports.
project_sheets = $(shell find projects/$(dir $(1)) -name '*.kicad_sch')

# <name>-erc.rpt exists only if ERC found no errors; the exports depend on it.
$(BUILD)/%-erc.rpt: projects/%.kicad_pro $$(call project_sheets,$$*)
	@mkdir -p $(@D)
	$(KICAD_CLI) sch erc --severity-error --severity-warning \
		-o $(@:-erc.rpt=-erc-all.rpt) projects/$*.kicad_sch
	$(KICAD_CLI) sch erc --severity-error --exit-code-violations \
		-o $@ projects/$*.kicad_sch || { [ -f $@ ] && cat $@; exit 1; }

$(BUILD)/%.pdf: $(BUILD)/%-erc.rpt
	$(KICAD_CLI) sch export pdf -o $@ projects/$*.kicad_sch

# Writes one SVG per sheet into the same directory; the root sheet's is $@.
$(BUILD)/%.svg: $(BUILD)/%-erc.rpt
	$(KICAD_CLI) sch export svg -o $(@D) projects/$*.kicad_sch
