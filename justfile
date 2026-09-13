# ww3-lab -- just recipes. Everything real lives in scripts/.
# Run `just` for the list. Make targets in Makefile are unchanged.

set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

setup_script     := "scripts/ww-lab-tool-setup.sh"
submodule_path   := "nix-config"

default:
    @just --list --unsorted

# Shorthand: `just up` == `just submodule-update`.
alias up := submodule-update
alias st := submodule-status

# Materialise nix-config (sparse: only labs/pratico). Safe after a fresh clone.
submodule-init:
    bash {{setup_script}} .

# Move the nix-config pin to the latest origin/<branch> and stage it.
submodule-update branch="main":
    bash {{setup_script}} . --bump --branch {{branch}}

# Same as submodule-update, but also commit .gitmodules + the new pin.
submodule-commit branch="main":
    bash {{setup_script}} . --bump --branch {{branch}} --commit

# Show the pinned commit vs. the branch tip.
submodule-status:
    @git submodule status -- {{submodule_path}}
    @git -C {{submodule_path}} fetch --quiet --depth 1 origin "$(git config -f .gitmodules submodule.{{submodule_path}}.branch)"
    @echo "tip: $(git -C {{submodule_path}} rev-parse --short FETCH_HEAD)  pinned: $(git -C {{submodule_path}} rev-parse --short HEAD)"
    @echo "checked out: $(git -C {{submodule_path}} sparse-checkout list | tr '\n' ' ')"

# ---------------------------------------------------------------------
# WW3 toolchain from nix-config/labs/pratico (gfortran, OpenMPI, NetCDF, ...).
# ---------------------------------------------------------------------

pratico := "./" + submodule_path + "/labs/pratico"

# Enter the toolchain-only shell (`nix develop .#ww3` in pratico).
ww3:
    nix develop "{{pratico}}#ww3"

# Run one command inside the toolchain shell, e.g. `just ww3-run gfortran --version`.
ww3-run *cmd:
    nix develop "{{pratico}}#ww3" --command "$@"

# Print exact toolchain versions (delegates to pratico's justfile).
toolchain:
    just -f {{pratico}}/justfile toolchain

# Fortran + MPI + NetCDF smoke test in the Nix sandbox (what pratico's CI runs).
smoke:
    just -f {{pratico}}/justfile smoke

# ---------------------------------------------------------------------
# WW3 source as a submodule (./WW3) from the fork h0ffmann/WW3, tracking
# NOAA-EMC/WW3 develop as remote "upstream". scripts/ww3-submodule.sh.
# ---------------------------------------------------------------------

src_script := "scripts/ww3-submodule.sh"

# Add the WW3 fork as ./WW3, or initialise it after a fresh clone.
src-init:
    bash {{src_script}} .

# Move the WW3 pin to the fork's latest <branch> and stage it.
src-up branch="develop":
    bash {{src_script}} . --bump --branch {{branch}}

# Fast-forward the fork from upstream, push it, and bump the pin (the usual refresh).
src-sync branch="develop":
    bash {{src_script}} . --sync --push --bump --branch {{branch}}

# Pin ./WW3 to an unmerged upstream pull request, e.g. `just src-pr 1234`.
src-pr n:
    bash {{src_script}} . --pr {{n}}

# Pinned commit vs. fork and upstream tips.
src-st:
    @git submodule status -- WW3
    @git -C WW3 fetch --quiet origin develop && git -C WW3 fetch --quiet upstream develop
    @echo "pinned: $(git -C WW3 rev-parse --short HEAD)  fork/develop: $(git -C WW3 rev-parse --short origin/develop)  upstream/develop: $(git -C WW3 rev-parse --short upstream/develop)"
    @echo "fork is $(git -C WW3 rev-list --count origin/develop..upstream/develop) commits behind upstream"

# ---------------------------------------------------------------------
# Build and regtest WW3 inside the Nix toolchain. <ww3> is the source
# tree: $WW3, else ~/src/WW3 (the upstream NOAA-EMC clone from `just get`,
# not the fork). Pass `WW3` to use the fork submodule:  just rt ww3_tp1.1 PR3_UQ WW3
# ---------------------------------------------------------------------

ww3_src := env_var_or_default("WW3", env_var("HOME") + "/src/WW3")

# Clone upstream NOAA-EMC/WW3 develop into <ww3>. No FTP bundle unless WW3_DATA=1.
get ww3=ww3_src:
    WW3_DATA="${WW3_DATA:-0}" bash scripts/01_get_ww3.sh "{{ww3}}"

# Full rebuild of <ww3> with <switch> (a path, or a name resolved in <ww3>/model/bin).
build switch="switches/switch_lab_shrd" ww3=ww3_src:
    nix develop "{{pratico}}#ww3" --command bash scripts/02_build_ww3.sh "{{ww3}}" "{{switch}}"

# Run one upstream regtest step by step (grid, strt, shel, ounf, ounp) in <ww3>/regtests/<test>/work_lab.
regtest test="ww3_tp1.1" ww3=ww3_src:
    nix develop "{{pratico}}#ww3" --command bash scripts/03_run_regtest.sh "{{ww3}}" "{{test}}"

# The simple regtest: build with the test's own switch_<sw>, then run it.
rt test="ww3_tp1.1" sw="PR3_UQ" ww3=ww3_src: (build (ww3 + "/regtests/" + test + "/input/switch_" + sw) ww3) (regtest test ww3)
