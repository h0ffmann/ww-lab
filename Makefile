# ww3-lab -- convenience targets. Everything real lives in scripts/.

WW3    ?= $(HOME)/src/WW3
SWAN   ?= $(HOME)/src/swan
SWITCH ?= $(CURDIR)/switches/switch_lab_shrd

.PHONY: help prereqs get build regtest example01 gpu swan clean-runs

help:
	@echo "ww3-lab"
	@echo
	@echo "  make prereqs            install build dependencies (Debian/Ubuntu)"
	@echo "  make get                clone WW3 + fetch the NOAA data bundle"
	@echo "  make build              build WW3 with switches/switch_lab_shrd"
	@echo "  make build SWITCH=...   build with a different switch file"
	@echo "  make regtest            run upstream ww3_tp2.2 step by step"
	@echo "  make example01          run the fetch-limited growth case"
	@echo "  make gpu                build the GPU sandbox (needs nvfortran)"
	@echo "  make swan               clone and build SWAN (TU Delft GitLab)"
	@echo "  make clean-runs         delete run artefacts, keep configs"
	@echo
	@echo "  WW3    = $(WW3)"
	@echo "  SWAN   = $(SWAN)"
	@echo "  SWITCH = $(SWITCH)"

prereqs:
	bash scripts/00_prereqs.sh

get:
	bash scripts/01_get_ww3.sh $(WW3)

build:
	bash scripts/02_build_ww3.sh $(WW3) $(SWITCH)

regtest:
	bash scripts/03_run_regtest.sh $(WW3) ww3_tp2.2

example01:
	cd examples/01-fetch-limited-growth && WW3=$(WW3) bash run.sh

gpu:
	$(MAKE) -C gpu

swan:
	bash scripts/04_get_swan.sh $(SWAN)

clean-runs:
	rm -rf exercises/runs gpu/00_hello_acc gpu/01_dispersion gpu/02_do_concurrent gpu/03_precision
	find examples -name '*.nc' -delete
	find examples -name '*.ww3' -delete
	find examples -name '*.out' -delete
