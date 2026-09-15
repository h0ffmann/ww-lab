// exercises/solutions/ex12_reduce.cpp
// Exercise 12 solution -- Hs at every sea point from a WW3-shaped action
// spectrum, with one Kokkos parallel_reduce per point.
//
// WW3 keeps the state as ACTION density A(theta, k) = E / sigma, in Fortran
// order (theta fastest), for NSEA points: the array is A(NTH, NK, NSEA). The
// significant wave height at one point is
//
//     Hs = 4 sqrt(m0),    m0 = sum_k sum_theta A(theta, k) * sigma_k * dtheta * dsigma_k
//
// -- the sigma_k in the sum is what turns action back into energy, and
// forgetting it is the classic mistake. The exercise is to write that as a
// team reduction: a TeamPolicy with one team per sea point, the (theta, k)
// sum done by the team with parallel_reduce over a TeamThreadRange, and the
// result written to hs(isea). That is exactly the shape a ported source term
// has (one team per point, the spectrum in scratch), which is why it is the
// exercise and not MDRangePolicy over everything at once (intro/02 does that).
//
// Self-checking: every point holds a gamma = 1 JONSWAP at its own fetch, whose
// m0 has a closed form (spectrum_fixtures.hpp), and the discrete sum must land
// within 2 % of it -- the same bound the intro programs use for the same grid.
//
// Build: see ../CMakeLists.txt (`cmake -S exercises/solutions -B exercises/solutions/build`
// inside `just ww3`), or the sheet exercises/ex12_reduce.md.
//
// SPDX-License-Identifier: MIT

#include <Kokkos_Core.hpp>

#include <cmath>
#include <cstdio>

#include "ww_kokkos/real.hpp"
#include "ww_kokkos/spectrum_fixtures.hpp"

namespace {

using DeviceSpace = Kokkos::DefaultExecutionSpace::memory_space;
using ActionView = Kokkos::View<ww::Real***, Kokkos::LayoutLeft, DeviceSpace>;  // (nth, nk, nsea)
using HsView = Kokkos::View<ww::Real*, DeviceSpace>;

constexpr int kNsea = 7;
constexpr ww::Real kU10 = static_cast<ww::Real>(10);

/// Fetch of sea point isea: 50 km, 100 km, ... so every point is a different sea.
KOKKOS_INLINE_FUNCTION ww::Real fetch_of(int isea) {
  return static_cast<ww::Real>(5.0e4) * static_cast<ww::Real>(isea + 1);
}

/// Fill A(theta, k, isea) with the gamma = 1 JONSWAP x cos^2 spectrum as ACTION.
void fill_action(const ActionView& a, const ww::SpectralGrid& g) {
  Kokkos::parallel_for(
      "ex12.fill", Kokkos::MDRangePolicy<Kokkos::Rank<3>>({0, 0, 0}, {g.nth, g.nk, kNsea}),
      KOKKOS_LAMBDA(const int ith, const int ik, const int isea) {
        const ww::Real sigma = g.sigma(ik);
        const ww::Real e = ww::jonswap(sigma, kU10, fetch_of(isea), static_cast<ww::Real>(1)) *
                           ww::cos2_spread(g.theta(ith), static_cast<ww::Real>(0));
        a(ith, ik, isea) = e / sigma;
      });
}

/// THE EXERCISE: one team per sea point, the team reduces m0, one thread writes Hs.
void hs_per_point(const ActionView& a, const ww::SpectralGrid& g, const HsView& hs) {
  using Policy = Kokkos::TeamPolicy<>;
  using Member = Policy::member_type;
  const int nspec = g.nth * g.nk;
  Kokkos::parallel_for(
      "ex12.hs", Policy(kNsea, Kokkos::AUTO), KOKKOS_LAMBDA(const Member& team) {
        const int isea = team.league_rank();
        double m0 = 0.0;  // accumulate in double: float32 state, float64 sum
        Kokkos::parallel_reduce(
            Kokkos::TeamThreadRange(team, nspec),
            [&](const int ispec, double& acc) {
              const int ith = ispec % g.nth;  // theta fastest: Fortran order
              const int ik = ispec / g.nth;
              acc += static_cast<double>(a(ith, ik, isea)) * static_cast<double>(g.sigma(ik)) *
                     static_cast<double>(g.dtheta()) * static_cast<double>(g.dsigma(ik));
            },
            m0);
        Kokkos::single(Kokkos::PerTeam(team), [&]() {
          hs(isea) = static_cast<ww::Real>(4.0 * std::sqrt(m0));
        });
      });
}

}  // namespace

int main(int argc, char* argv[]) {
  Kokkos::ScopeGuard guard(argc, argv);
  int failures = 0;
  {
    const ww::SpectralGrid g = ww::default_grid();
    ActionView a("ex12.A", g.nth, g.nk, kNsea);
    HsView hs("ex12.hs", kNsea);

    fill_action(a, g);
    hs_per_point(a, g, hs);

    auto h = Kokkos::create_mirror_view_and_copy(Kokkos::HostSpace{}, hs);
    std::printf("%6s %10s %10s %10s %8s\n", "point", "fetch[km]", "Hs kokkos", "Hs exact", "rel err");
    for (int isea = 0; isea < kNsea; ++isea) {
      const double exact =
          4.0 * std::sqrt(static_cast<double>(ww::jonswap_m0(kU10, fetch_of(isea))));
      const double got = static_cast<double>(h(isea));
      const double rel = std::fabs(got - exact) / exact;
      std::printf("%6d %10.0f %10.4f %10.4f %8.4f\n", isea,
                  static_cast<double>(fetch_of(isea)) / 1000.0, got, exact, rel);
      if (!(rel < 0.02)) ++failures;
    }
  }
  if (failures != 0) {
    std::printf("ex12_reduce: FAIL (%d of %d points outside 2 %%)\n", failures, kNsea);
    return 1;
  }
  std::printf("ex12_reduce: OK -- team-reduced Hs matches the closed-form m0 at all %d points\n",
              kNsea);
  return 0;
}
