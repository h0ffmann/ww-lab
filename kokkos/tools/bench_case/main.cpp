// kokkos/tools/bench_case/main.cpp
// ww_bench_case: the command-line front end of the benchmark-case generator.
//
//   ww_bench_case                       # medium, ~1-2 min serial
//   ww_bench_case --size small
//   ww_bench_case --size large --hours 48
//   ww_bench_case --nx 600 --ny 400 --nth 48 -o my_case
//
// Exit status: 0 written, 1 I/O failure, 2 bad arguments.
//
// SPDX-License-Identifier: MIT
#include <exception>
#include <iostream>
#include <stdexcept>

#include "bench_case.hpp"

int main(int argc, char** argv) {
  try {
    const ww::bench::Options o = ww::bench::parse_args(argc, argv);
    if (o.help) {
      std::cout << ww::bench::usage();
      return 0;
    }
    const ww::bench::Summary s = ww::bench::write_case(o.out, o.params);
    std::cout << ww::bench::summary_text(o.out, s);
    return 0;
  } catch (const std::invalid_argument& e) {
    std::cerr << "ww_bench_case: " << e.what() << "\n\n" << ww::bench::usage();
    return 2;
  } catch (const std::exception& e) {
    std::cerr << "ww_bench_case: " << e.what() << "\n";
    return 1;
  }
}
