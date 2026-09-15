# `PATCH.md` — wiring the Kokkos DIA into WAVEWATCH III

> **Not applied in this repository.** `WW3/` here is an unmodified upstream
> checkout and stays that way; this file is the recipe for the fork branch
> (`just src-pr` / a `WW3` fork), written so that it can be applied and reviewed
> hunk by hunk. Everything below was read off the tree at
> `WW3/model/src` (WAVEWATCH III 7.14, `develop`) — the line numbers are real and
> were produced with the `grep` commands quoted next to each hunk.
>
> The Fortran shown in the hunks is a derivative of WW3's own source and carries
> WW3's licence.
>
> SPDX-License-Identifier: LGPL-3.0-or-later

The change is deliberately small and entirely opt-in. Without the `KOKKOS`
switch, nothing below is compiled; with the switch but without
`WW_KOKKOS_SNL1=1` in the environment, `KOKKOS_SNL1` is `.FALSE.` and the model
runs the Fortran `W3SNL1` exactly as before. That is what makes the port
bisectable against the model it is replacing.

---

## 1. The call site — `model/src/w3srcemd.F90`

```console
$ grep -n "CALL W3SNL1\|W3_NL1" WW3/model/src/w3srcemd.F90
578:#ifdef W3_NL1
893:#if defined(W3_NL0) || defined(W3_NL1)
1258:#ifdef W3_NL1
1260:        CALL W3SNL1 ( SPEC, CG1, WNMEAN*DEPTH, VSNL, VDNL )
```

`W3SNL1` is called from one place, `SUBROUTINE W3SRCE` (line 190), section
*2.b Nonlinear interactions*, at lines **1258–1264**:

```fortran
1255       !
1256       ! 2.b Nonlinear interactions.
1257       !
1258 #ifdef W3_NL1
1259       IF (IQTPE.GT.0) THEN
1260         CALL W3SNL1 ( SPEC, CG1, WNMEAN*DEPTH, VSNL, VDNL )
1261       ELSE
1262         CALL W3SNLGQM ( SPEC, CG1, WN1, DEPTH, VSNL, VDNL )
1263       END IF
1264 #endif
```

Three facts about this call decide the shape of the patch:

* `KDMEAN` is the **expression** `WNMEAN*DEPTH`, not a variable, and the shim
  takes it as an array of `NPTS`. The patch needs a one-element local.
* `SPEC`, `VSNL` and `VDNL` are `REAL(NSPEC)` and `CG1` is `REAL(NK)`
  (declarations at lines 684–685 and 716), contiguous and column-major — exactly
  the `NPTS = 1` case of the shim's batch layout, so they can be passed straight
  through with no copy and no reshape.
* The `IQTPE` branch must stay: `IQTPE <= 0` selects `W3SNLGQM`, a different
  routine that this port does not replace.

### Hunk 1a — the `USE` (line 578)

```diff
@@ -576,6 +576,9 @@
 #ifdef W3_NL1
     USE W3SNL1MD
     USE W3GDATMD, ONLY: IQTPE
+#ifdef W3_KOKKOS
+    USE W3KOKKOSMD, ONLY: KOKKOS_SNL1, WW_SNL1, WW_SNL1_LAST_ERROR
+    USE W3SERVMD,   ONLY: EXTCDE
+#endif
 #endif
```

`NDSE` is already in scope here (`USE W3ODATMD, ONLY: NDSE`, line 652) but
`EXTCDE` is not — `W3SRCE` imports only `STRACE`, `EXTOPN` and `EXTIOF` from
`W3SERVMD` (lines 648 and 651) — hence the second `USE`.

### Hunk 1b — a one-element `KDMEAN` (near the locals at line 712)

```diff
@@ -712,6 +712,10 @@
     REAL :: SPECINIT(NSPEC), SPEC2(NSPEC)
+#ifdef W3_KOKKOS
+    ! The shim takes KDMEAN as an array of NPTS; here NPTS is 1.
+    REAL :: KDM_K(1)
+#endif
```

### Hunk 1c — the branch (lines 1258–1264)

```diff
@@ -1256,10 +1256,23 @@
       ! 2.b Nonlinear interactions.
       !
 #ifdef W3_NL1
       IF (IQTPE.GT.0) THEN
+#ifdef W3_KOKKOS
+        IF ( KOKKOS_SNL1 ) THEN
+          KDM_K(1) = WNMEAN*DEPTH
+          CALL WW_SNL1 ( 1, SPEC, CG1, KDM_K, VSNL, VDNL )
+          IF ( WW_SNL1_LAST_ERROR() /= 0 ) THEN
+            WRITE (NDSE,'(A,I0)') '*** WAVEWATCH III ERROR IN W3SRCE : '//     &
+                 'KOKKOS W3SNL1 FAILED, CODE ', WW_SNL1_LAST_ERROR()
+            CALL EXTCDE ( 1 )
+          END IF
+        ELSE
+          CALL W3SNL1 ( SPEC, CG1, WNMEAN*DEPTH, VSNL, VDNL )
+        END IF
+#else
         CALL W3SNL1 ( SPEC, CG1, WNMEAN*DEPTH, VSNL, VDNL )
+#endif
       ELSE
         CALL W3SNLGQM ( SPEC, CG1, WN1, DEPTH, VSNL, VDNL )
       END IF
 #endif
```

The error check is not optional. `ww_snl1` is a `void` C function precisely
because a Fortran `CALL` cannot read a return value, so `WW_SNL1_LAST_ERROR()`
is the only channel a failure has; silently keeping whatever was in `VSNL`
would turn a failed launch into a plausible-looking wrong forecast.

**`NPTS = 1` is the phase-1 shape, and it is the wrong shape for a GPU.** One
sea point per launch is a kernel launch per point per timestep; the ledger in
`kokkos/PORT_STATUS.md` measures 0.75 ms for 1 000 points and 0.047 ms of that
is the kernel. Phase 2 hoists the call out of `W3SRCE` into the `JSEA` loop of
`W3WAVE` and hands the shim the whole `VA` block at once. This patch is the
correctness step, not the performance step.

---

## 2. Set-up — `model/src/w3initmd.F90`

`INSNL1` itself is called once per grid from `w3iogrmd.F90:1802`, out of
`W3IOGR('READ', ...)`, which `W3INIT` calls at line 735:

```console
$ grep -n "CALL W3IOGR" WW3/model/src/w3initmd.F90
735:    CALL W3IOGR ( 'READ', NDS(5), IMOD, FEXT )
```

That is the earliest point at which `NK`, `NTH` and `SIG` are known, so the
shim's set-up goes immediately after it, in `SUBROUTINE W3INIT` (line 163),
section *2.a Model definition* (line 733):

```diff
@@ -733,6 +733,25 @@
     ! 2.a Read model definition file
     !
     CALL W3IOGR ( 'READ', NDS(5), IMOD, FEXT )
+    !
+#ifdef W3_KOKKOS
+    ! 2.a.1 Start the Kokkos runtime and build the ported tables.
+    !
+    !       WW_KOKKOS_INIT is idempotent, so a multi-grid run may call it once
+    !       per grid. Phase 1 ignores the communicator and takes the device from
+    !       WW_KOKKOS_DEVICE_ID; pass MPI_Comm_c2f(MPI_COMM_WAVE) instead of -1
+    !       once phase 2 honours it.
+    !
+    IERR_K = WW_KOKKOS_INIT ( -1 )
+    IF ( IERR_K /= 0 ) CALL EXTCDE ( 1 )
+    CALL W3KOKKOS_SETUP
+    IF ( KOKKOS_SNL1 ) THEN
+      IERR_K = WW_SNL1_INIT ( NK, NTH, XFR, DTH, LAM, SNLC1, KDCON, KDMN,     &
+                              SNLS1, SNLS2, SNLS3, FACHFE, SIG )
+      IF ( IERR_K /= 0 ) CALL EXTCDE ( 1 )
+      WRITE (NDSO,'(A)') '  Kokkos DIA (W3SNL1) enabled.'
+    END IF
+#endif
```

with `USE W3KOKKOSMD` and `INTEGER :: IERR_K` added to the declarations of
`W3INIT`, and `SNLC1, SNLS1, SNLS2, SNLS3, KDCON, KDMN, LAM, FACHFE` added to
the existing `USE W3GDATMD, ONLY: ...` list. `WW_KOKKOS_FINALIZE` belongs at the
end of `W3WAVE`'s teardown; leaving it out leaks the device buffers until
process exit, which is untidy but not incorrect.

---

## 3. The switch — `model/src/cmake/switches.json`

`check_switches.cmake` turns each selected switch into `-DW3_<NAME>` and adds
its `build_files` to the library, so one new category is the whole build change:

```diff
@@ (append to the array in switches.json)
+  {
+    "name": "kokkos",
+    "num_switches": "upto1",
+    "description": "C++/Kokkos port of the source terms",
+    "valid-options": [
+      {
+        "name": "KOKKOS",
+        "build_files": ["w3kokkosmd.F90"],
+        "requires": ["NL1"]
+      }
+    ]
+  }
```

**`model/src/cmake/src_list.cmake` needs no change**, and the brief's
instruction to edit it is one step more than the tree actually requires:
`check_switches.cmake:78-85` collects `build_files` into `switch_files`, and
`model/src/CMakeLists.txt:19` already passes that variable to
`add_library(ww3_lib STATIC ${ftn_src} ${switch_files})`. Adding
`w3kokkosmd.F90` to `ftn_src` as well would compile it unconditionally and
break every build without the Kokkos library. Listing it once, in
`switches.json`, is both the smaller patch and the correct one.

`w3kokkosmd.F90` is copied from
`kokkos/src/fortran_iface/w3kokkosmd.F90` into `model/src/` unchanged — it has
no dependency on anything else in this lab, which is why it is built as its own
target here (`ww_kokkos_f`) rather than folded into the C++ library.

---

## 4. The link — `model/src/CMakeLists.txt`

```diff
@@ -19,6 +19,17 @@
 add_library(ww3_lib STATIC ${ftn_src} ${switch_files})
+
+# The Kokkos port. Built separately (see kokkos/README.md) and found here; the
+# switch and the library have to agree, so mismatching them is a hard error
+# rather than a link failure a thousand lines later.
+option(WW_KOKKOS "Link the C++/Kokkos port of the source terms" OFF)
+if(WW_KOKKOS)
+  if(NOT "KOKKOS" IN_LIST switches)
+    message(FATAL_ERROR "-DWW_KOKKOS=ON needs the KOKKOS switch in the switch file")
+  endif()
+  find_package(ww_kokkos REQUIRED)
+  target_link_libraries(ww3_lib PUBLIC ww_kokkos::ww_kokkos)
+endif()
```

`ww3_lib` is a Fortran target linking a C++ static library, so the link line
also needs the C++ runtime. CMake handles this by itself when the imported
target carries `IMPORTED_LINK_INTERFACE_LANGUAGES CXX`; if the Kokkos tree is
pulled in with `add_subdirectory()` instead of `find_package()`, CMake gets it
from the target's own linker language and nothing extra is needed. This is the
same mechanism that lets `kokkos/tests/fixtures/shim_driver` — a Fortran
program linking `ww_kokkos_f` — link here today.

`ww_kokkos` does **not** export a CMake package config yet; that is the one
piece of this section that is speculative, and the fork branch will either add
an `install(EXPORT)` to `kokkos/CMakeLists.txt` or use `add_subdirectory`.

---

## 5. Applying and checking it

```bash
# on the fork branch, with WW3 as a submodule or a sibling checkout
cd WW3
git switch -c feat/kokkos-snl1
#   ... apply hunks 1-4 ...
echo "... NL1 ... KOKKOS ..." > ../switch          # add KOKKOS to the switch file
cmake -B build -DWW_KOKKOS=ON -Dww_kokkos_DIR=../kokkos/build/openmp-release
cmake --build build

# bisect against the Fortran: same binary, switch flipped by the environment
WW_KOKKOS_SNL1=0 ./build/bin/ww3_shel     # Fortran W3SNL1
WW_KOKKOS_SNL1=1 ./build/bin/ww3_shel     # Kokkos DIA
# then: kokkos/tools/nccmp-tol on the two out_grd.nc
```

That last pair is the point of the whole design: one executable, one switch,
two answers that must agree to the tolerance the L1 tests already hold the
kernel to. It is the L2 row of `kokkos/PORT_STATUS.md`, and it is what this
patch is for.
