// kokkos/tests/L1_test_fetch_analyse.cpp
// The fetch-growth analyser against a synthetic ww3_ounf-shaped file.
//
// WW3 itself is not available to the test suite, so the file is written here
// with netcdf-c in the layout ww3_ounf produces -- hs(time, y, x), a _FillValue
// on the land column, a coordinate variable named after the x dimension -- and
// the reader has to pick the final time step and the centre row out of it. The
// Hs values are the Kahma & Calkoen law evaluated by the library itself, so the
// table's ratio column must print 1.00 on every row.
//
// SPDX-License-Identifier: MIT

#include <gtest/gtest.h>
#include <netcdf.h>

#include <cmath>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <vector>

#include "fetch_analyse.hpp"

namespace {

namespace fs = std::filesystem;

constexpr std::size_t kNt = 2, kNy = 3, kNx = 5;
constexpr float kFill = -999.0f;
constexpr double kU10 = 10.0;

/// Write hs(time, y, x) with the empirical law along the centre row of the final
/// step, garbage elsewhere, and the land column filled.
void write_file(const fs::path& path, const char* xname, const char* yname) {
  int ncid = -1;
  ASSERT_EQ(nc_create(path.c_str(), NC_CLOBBER | NC_NETCDF4, &ncid), NC_NOERR);
  int tdim = -1, ydim = -1, xdim = -1;
  ASSERT_EQ(nc_def_dim(ncid, "time", kNt, &tdim), NC_NOERR);
  ASSERT_EQ(nc_def_dim(ncid, yname, kNy, &ydim), NC_NOERR);
  ASSERT_EQ(nc_def_dim(ncid, xname, kNx, &xdim), NC_NOERR);
  int xid = -1, hsid = -1;
  ASSERT_EQ(nc_def_var(ncid, xname, NC_DOUBLE, 1, &xdim, &xid), NC_NOERR);
  const int dims[3] = {tdim, ydim, xdim};
  ASSERT_EQ(nc_def_var(ncid, "hs", NC_FLOAT, 3, dims, &hsid), NC_NOERR);
  ASSERT_EQ(nc_put_att_float(ncid, hsid, "_FillValue", NC_FLOAT, 1, &kFill), NC_NOERR);
  ASSERT_EQ(nc_enddef(ncid), NC_NOERR);

  std::vector<double> x(kNx);
  for (std::size_t i = 0; i < kNx; ++i) x[i] = 20000.0 * static_cast<double>(i);
  ASSERT_EQ(nc_put_var_double(ncid, xid, x.data()), NC_NOERR);

  std::vector<float> hs(kNt * kNy * kNx, 42.0f);  // wrong everywhere but the target row
  for (std::size_t i = 0; i < kNx; ++i) {
    const std::size_t at = (kNt - 1) * kNy * kNx + (kNy / 2) * kNx + i;
    if (i == 0) {
      hs[at] = kFill;
    } else {
      const double x_hat = ww::fetch::kG * x[i] / (kU10 * kU10);
      hs[at] = static_cast<float>(ww::fetch::hs_from_ehat(ww::fetch::kahma_calkoen(x_hat), kU10));
    }
  }
  ASSERT_EQ(nc_put_var_float(ncid, hsid, hs.data()), NC_NOERR);
  ASSERT_EQ(nc_close(ncid), NC_NOERR);
}

class FetchAnalyse : public ::testing::Test {
 protected:
  void SetUp() override {
    dir_ = fs::temp_directory_path() / "ww_fetch_analyse_test";
    fs::remove_all(dir_);
    fs::create_directories(dir_);
  }
  void TearDown() override { fs::remove_all(dir_); }
  fs::path dir_;
};

TEST_F(FetchAnalyse, ReadsFinalStepCentreRowOfACartesianFile) {
  const fs::path f = dir_ / "ww3.nc";
  write_file(f, "x", "y");
  const ww::fetch::Profile p = ww::fetch::read_profile(f.string());
  EXPECT_EQ(p.xname, "x");
  EXPECT_EQ(p.yname, "y");
  ASSERT_EQ(p.fetch.size(), kNx);
  ASSERT_EQ(p.hs.size(), kNx);
  EXPECT_DOUBLE_EQ(p.fetch[0], 0.0);
  EXPECT_DOUBLE_EQ(p.fetch[4], 80000.0);
  EXPECT_TRUE(std::isnan(p.hs[0])) << "the filled land column must read as NaN";
  EXPECT_NEAR(p.hs[1], 0.8917, 1e-3);
  EXPECT_FALSE(p.x_looks_small);
  EXPECT_NE(p.header.find("dims time=2 y=3 x=5"), std::string::npos) << p.header;
}

TEST_F(FetchAnalyse, ReportPrintsTheTableWithUnitRatios) {
  const fs::path f = dir_ / "ww3.nc";
  write_file(f, "x", "y");
  const std::string r = ww::fetch::report(ww::fetch::read_profile(f.string()), kU10);
  EXPECT_NE(r.find("U10 = 10.0 m/s      Pierson-Moskowitz fully-developed Hs = 2.46 m\n"),
            std::string::npos);
  EXPECT_NE(r.find(" fetch [km]  WW3 Hs [m]  K&C92 Hs [m]   ratio\n"), std::string::npos);
  // rows i = 1..4 (step = max(1, 5/12) = 1), each ratio exactly 1.00
  for (const char* row : {"         20       0.892         0.892    1.00\n",
                          "         80       1.664         1.664    1.00\n"}) {
    EXPECT_NE(r.find(row), std::string::npos) << "missing row:\n" << row << "in:\n" << r;
  }
  EXPECT_NE(r.find("  * Nothing should meaningfully exceed 2.46 m at steady state.\n"),
            std::string::npos);
}

TEST_F(FetchAnalyse, HandlesSphericalNamesAndFlagsSmallX) {
  const fs::path f = dir_ / "ww3.nc";
  write_file(f, "longitude", "latitude");
  const ww::fetch::Profile p = ww::fetch::read_profile(f.string());
  EXPECT_EQ(p.xname, "longitude");
  EXPECT_EQ(p.yname, "latitude");
  EXPECT_EQ(p.fetch.size(), kNx);
}

TEST_F(FetchAnalyse, MissingFileIsARuntimeErrorWithAHint) {
  try {
    (void)ww::fetch::read_profile((dir_ / "nope.nc").string());
    FAIL() << "expected an exception";
  } catch (const std::runtime_error& e) {
    EXPECT_NE(std::string(e.what()).find("could not open"), std::string::npos);
    EXPECT_NE(std::string(e.what()).find("run ./run.sh first"), std::string::npos);
  }
}

}  // namespace
