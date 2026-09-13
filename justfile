# ww3-lab -- just recipes. Everything real lives in scripts/.
# Run `just` for the list. Make targets in Makefile are unchanged.

set shell := ["bash", "-euo", "pipefail", "-c"]

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
    nix develop "{{pratico}}#ww3" --command {{cmd}}

# Print exact toolchain versions (delegates to pratico's justfile).
toolchain:
    just -f {{pratico}}/justfile toolchain

# Fortran + MPI + NetCDF smoke test in the Nix sandbox (what pratico's CI runs).
smoke:
    just -f {{pratico}}/justfile smoke
