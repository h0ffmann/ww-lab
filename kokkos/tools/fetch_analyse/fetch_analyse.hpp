// kokkos/tools/fetch_analyse/fetch_analyse.hpp
// Compare WW3's fetch-limited growth against the classic empirical laws.
//
// This is the payoff of examples/01-fetch-limited-growth. WW3 integrates a
// five-dimensional PDE with a fully parameterised source-term balance; the
// empirical growth laws are curve fits to field campaigns from the 1970s-80s.
// They should agree to within tens of percent over the fetch range where the
// wind sea is still growing. Where they disagree tells you something -- usually
// about full development, or about the tuning of whichever ST package you
// compiled.
//
// The reader takes the gridded ww3_ounf output (hs(time, y, x)), the final time
// step (steady state) and the centre row (away from the edges), and the report
// prints the same table the retired analyse.py printed. No plot.
//
// SPDX-License-Identifier: MIT
#pragma once

#include <cstddef>
#include <string>
#include <vector>

namespace ww::fetch {

inline constexpr double kG = 9.806;

/// Dimensionless energy vs dimensionless fetch (Kahma & Calkoen 1992,
/// composite/stable-corrected coefficients): e_hat = g^2 E / U10^4.
double kahma_calkoen(double x_hat);

/// Hs = 4 sqrt(E), with E recovered from the dimensionless energy.
double hs_from_ehat(double e_hat, double u10);

/// Fully developed limit. Nothing should exceed this at steady state.
double pierson_moskowitz_hs(double u10);

/// The centre-row, final-time Hs profile of one ww3_ounf file.
struct Profile {
  std::string header;         ///< one-line summary of the file's dims and variables
  std::string xname;          ///< "x" (Cartesian) or "longitude" (spherical)
  std::string yname;          ///< "y" or "latitude", empty if absent
  std::vector<double> fetch;  ///< metres from the coastline at i = 1
  std::vector<double> hs;     ///< model Hs along the centre row; NaN where masked
  bool x_looks_small = false; ///< max(x) < 1e4: units may be km or degrees
};

/// Read `path`. Throws std::runtime_error with a human-readable message when the
/// file cannot be opened or has no recognisable x dimension / hs variable.
Profile read_profile(const std::string& path);

/// The report text: header, the growth-law table at `u10`, and what to look for.
std::string report(const Profile& p, double u10);

}  // namespace ww::fetch
