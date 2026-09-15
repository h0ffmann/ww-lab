// kokkos/tools/bench_case/bench_case.hpp
// Generate a WW3 benchmark case of a chosen size.
//
// Writes a complete, self-contained run directory (namelists + ASCII bathymetry
// + mask) sized so that a serial run takes long enough to measure but short
// enough to iterate on. No external data needed. The timesteps are DERIVED from
// the grid spacing via the CFL condition, so changing the size keeps the case
// physically valid instead of silently unstable -- an unstable run and a stable
// run do different amounts of work, which matters for a benchmark.
//
// This is a translation of the retired bench/make_bench_case.py. Its contract is
// byte-identical output for the same parameters (tests/L1_test_bench_case.cpp
// pins `--size small` to the Python's captured files), which is why the number
// formatting below imitates Python's float repr rather than using iostreams.
//
// SPDX-License-Identifier: MIT
#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <string_view>

namespace ww::bench {

/// Gravity and the lowest spectral frequency, as the WW3 namelist template uses them.
inline constexpr double kG = 9.806;
inline constexpr double kFreq1 = 0.04118;

/// Everything that defines one case.
struct Params {
  int nx = 0;
  int ny = 0;
  int nk = 0;
  int nth = 0;
  int hours = 0;
  double dx_m = 0.0;  ///< grid spacing in metres (both directions)
};

/// CFL-derived timesteps in seconds, rounded DOWN -- these are ceilings.
struct Timesteps {
  double dtmax = 0.0;
  double dtxy = 0.0;
  double dtkth = 0.0;
  double dtmin = 0.0;
};

/// What write_case() reports back: the case, its timesteps and the derived sizes.
struct Summary {
  Params params;
  Timesteps ts;
  long long sea_points = 0;
  long long spectral_bins = 0;
  long long state_values = 0;
  double state_mb = 0.0;
  int global_steps = 0;
};

/// Parsed command line. `help` set means: print usage() and exit 0.
struct Options {
  Params params;
  std::filesystem::path out;
  bool help = false;
};

/// The named presets: small, medium, large (at dx = 20 km). Empty for any other name.
std::optional<Params> size_preset(std::string_view name);

/// The CFL timesteps for a grid spacing in metres.
Timesteps timesteps(double dx_m);

/// Write depth.inp, mask.inp, namelists.nml, ww3_grid.nml, ww3_shel.nml, ww3_ounf.nml
/// and case.json into `out` (created if missing). Throws std::runtime_error on I/O failure.
Summary write_case(const std::filesystem::path& out, const Params& p);

/// The human-readable lines the CLI prints after writing (one trailing newline each).
std::string summary_text(const std::filesystem::path& out, const Summary& s);

/// `ww_bench_case [--size S] [--nx N] [--ny N] [--nk N] [--nth N] [--hours H] [--dx-km X] [-o DIR]`.
/// Overrides apply on top of the preset; the default output directory is case_<size>.
/// Throws std::invalid_argument with a message for anything it cannot parse.
Options parse_args(int argc, char** argv);

/// The usage text.
std::string usage();

/// Python's repr() of a double: shortest round-trip digits, always with a '.'.
/// Only the fixed-notation range is reproduced (1e-4 <= |x| < 1e16), which is
/// every value this generator prints.
std::string python_float_repr(double x);

/// Python's f"{n:,}": decimal digits grouped by three with commas.
std::string with_thousands(long long n);

}  // namespace ww::bench
