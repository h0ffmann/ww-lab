// kokkos/tools/fetch_analyse/main.cpp
// ww_fetch_analyse [ww3.nc] [u10]: print the fetch-growth comparison table.
//
// u10 defaults to 10 m/s and must match HOMOG_INPUT(1)%VALUE1 in ww3_shel.nml.
// Exit status: 0 printed, 1 the file could not be read, 2 bad arguments.
//
// SPDX-License-Identifier: MIT
#include <charconv>
#include <cstring>
#include <exception>
#include <iostream>
#include <string>
#include <system_error>

#include "fetch_analyse.hpp"

namespace {

const char* const kUsage =
    "usage: ww_fetch_analyse [ww3.nc] [u10]\n"
    "  ww3.nc  gridded ww3_ounf output with hs(time, y, x)   (default ww3.nc)\n"
    "  u10     wind speed in m/s, as in ww3_shel.nml          (default 10)\n";

}  // namespace

int main(int argc, char** argv) {
  std::string path = "ww3.nc";
  double u10 = 10.0;
  if (argc > 1 && (std::strcmp(argv[1], "-h") == 0 || std::strcmp(argv[1], "--help") == 0)) {
    std::cout << kUsage;
    return 0;
  }
  if (argc > 3) {
    std::cerr << kUsage;
    return 2;
  }
  if (argc > 1) path = argv[1];
  if (argc > 2) {
    const std::string s = argv[2];
    const auto r = std::from_chars(s.data(), s.data() + s.size(), u10);
    if (r.ec != std::errc{} || r.ptr != s.data() + s.size() || !(u10 > 0.0)) {
      std::cerr << "ww_fetch_analyse: u10 must be a positive number, got '" << s << "'\n" << kUsage;
      return 2;
    }
  }
  try {
    std::cout << ww::fetch::report(ww::fetch::read_profile(path), u10);
    return 0;
  } catch (const std::exception& e) {
    std::cerr << e.what() << "\n";
    return 1;
  }
}
