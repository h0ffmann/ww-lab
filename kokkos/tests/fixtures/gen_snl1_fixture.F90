!> @file gen_snl1_fixture.F90
!> @brief Write the committed W3SNL1/INSNL1 parity fixture.
!>
!> Runs SNL1_REF -- the verbatim WAVEWATCH III 7.14 reference in snl1_ref.F90 --
!> on a deterministic JONSWAP x cos^2 sea state at three depths and streams the
!> inputs, the INSNL1 tables and the W3SNL1 answers to one little-endian binary
!> file. `kokkos/tests/fixtures/README.md` documents the layout byte for byte;
!> `ww::fixture::load()` reads it back.
!>
!> Nothing here is random and nothing is read from the environment: the same
!> compiler flags must reproduce the same bytes.
!>
!> Usage: gen_snl1_fixture <output-path>
!>
!> SPDX-License-Identifier: MIT
!>
PROGRAM GEN_SNL1_FIXTURE
  USE SNL1_REF
  IMPLICIT NONE
  !
  INTEGER, PARAMETER :: NK_USE   = 25
  INTEGER, PARAMETER :: NTH_USE  = 24
  INTEGER, PARAMETER :: NPTS     = 3
  INTEGER, PARAMETER :: MAGIC    = INT(z'534E4C31')   ! 'SNL1'
  REAL,    PARAMETER :: XFR_USE  = 1.1
  REAL,    PARAMETER :: FREQ1    = 0.04118
  REAL,    PARAMETER :: U10      = 10.0               ! m/s
  REAL,    PARAMETER :: FETCH    = 1.0E5              ! m
  REAL,    PARAMETER :: GAMMA_J  = 3.3
  REAL,    PARAMETER :: DEPTHS(NPTS) = (/ 1000., 50., 10. /)
  !
  CHARACTER(LEN=512)  :: PATH
  INTEGER             :: UNIT, IPT
  REAL                :: KDMEAN
  REAL, ALLOCATABLE   :: A(:), S(:), D(:), CG(:), WN(:)
  !
  IF ( COMMAND_ARGUMENT_COUNT() /= 1 ) THEN
    WRITE (*,*) 'usage: gen_snl1_fixture <output-path>'
    STOP 1
  END IF
  CALL GET_COMMAND_ARGUMENT ( 1, PATH )
  !
  ! The fixture layout is fixed-width; refuse to write it from a build whose
  ! default REAL or INTEGER is not the 32-bit one WW3 assumes.
  !
  IF ( STORAGE_SIZE(1.0) /= 32 .OR. STORAGE_SIZE(1) /= 32 ) THEN
    WRITE (*,*) 'default REAL/INTEGER are not 32-bit; refusing to write'
    STOP 2
  END IF
  !
  CALL SETUP_REF ( NK_USE, NTH_USE, XFR_USE, FREQ1 )
  CALL INSNL1_REF
  !
  ALLOCATE ( A(NSPEC), S(NSPEC), D(NSPEC), CG(NK), WN(NK) )
  !
  OPEN ( NEWUNIT=UNIT, FILE=TRIM(PATH), FORM='UNFORMATTED', &
       ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE' )
  !
  ! --- header ------------------------------------------------------------
  !
  WRITE (UNIT) MAGIC, NK, NTH, NPTS
  WRITE (UNIT) XFR, DTH, LAM, SNLC1, KDCON, KDMN, SNLS1, SNLS2, SNLS3, FACHFE
  WRITE (UNIT) SIG(1:NK)
  !
  ! --- INSNL1 tables -----------------------------------------------------
  !
  WRITE (UNIT) NFR, NFRHGH, NFRCHG, NSPECX, NSPECY
  WRITE (UNIT) DAL1, DAL2, DAL3
  WRITE (UNIT) AWG1, AWG2, AWG3, AWG4, AWG5, AWG6, AWG7, AWG8
  WRITE (UNIT) SWG1, SWG2, SWG3, SWG4, SWG5, SWG6, SWG7, SWG8
  ! 16 index tables of length NSPECX, in the order INSNL1 assigns them.
  WRITE (UNIT) IP11, IP12, IP13, IP14, IM11, IM12, IM13, IM14
  WRITE (UNIT) IP21, IP22, IP23, IP24, IM21, IM22, IM23, IM24
  ! 16 index tables of length NSPEC, in the order INSNL1 assigns them.
  WRITE (UNIT) IC11, IC21, IC31, IC41, IC51, IC61, IC71, IC81
  WRITE (UNIT) IC12, IC22, IC32, IC42, IC52, IC62, IC72, IC82
  WRITE (UNIT) AF11
  !
  ! --- one record per sea point ------------------------------------------
  !
  DO IPT=1, NPTS
    CALL DISPERSION ( DEPTHS(IPT), WN, CG )
    CALL SEA_STATE  ( DEPTHS(IPT), WN, A, KDMEAN )
    CALL W3SNL1_REF ( A, CG, KDMEAN, S, D )
    WRITE (UNIT) KDMEAN
    WRITE (UNIT) CG
    WRITE (UNIT) A
    WRITE (UNIT) S
    WRITE (UNIT) D
    WRITE (*,'(A,I2,A,F8.1,A,F9.4,A,E13.6,A,E13.6)')                  &
         ' point ', IPT, ': depth ', DEPTHS(IPT), ' m, kdmean ',      &
         KDMEAN, ', max|S| ', MAXVAL(ABS(S)), ', max|D| ', MAXVAL(ABS(D))
  END DO
  !
  CLOSE ( UNIT )
  WRITE (*,'(A,A)') ' wrote ', TRIM(PATH)
  !
  DEALLOCATE ( A, S, D, CG, WN )
  CALL FREE_REF
  !
CONTAINS
  !/ ------------------------------------------------------------------- /
  !> @brief Wavenumber and group velocity of the linear dispersion relation.
  !>
  !> Solves sigma^2 = g k tanh(k d) by 20 Newton steps from the deep-water
  !> guess, then CG = 0.5 (1 + 2kd/sinh(2kd)) sigma / k.
  !>
  SUBROUTINE DISPERSION ( DEPTH, WNO, CGO )
    IMPLICIT NONE
    REAL, INTENT(IN)  :: DEPTH
    REAL, INTENT(OUT) :: WNO(NK), CGO(NK)
    INTEGER           :: IK, IT
    REAL              :: SI, K, KD, F, FP
    DO IK=1, NK
      SI = SIG(IK)
      K  = SI*SI / GRAV
      DO IT=1, 20
        KD = MIN ( K*DEPTH, 30. )
        F  = GRAV*K*TANH(KD) - SI*SI
        FP = GRAV*TANH(KD) + GRAV*K*DEPTH/COSH(KD)**2
        K  = K - F/FP
      END DO
      KD      = MIN ( K*DEPTH, 30. )
      WNO(IK) = K
      CGO(IK) = 0.5 * ( 1. + 2.*KD/SINH(2.*KD) ) * SI / K
    END DO
  END SUBROUTINE DISPERSION
  !/ ------------------------------------------------------------------- /
  !> @brief JONSWAP x cos^2 action spectrum and its energy-weighted mean kd.
  !>
  SUBROUTINE SEA_STATE ( DEPTH, WNI, AO, KDM )
    IMPLICIT NONE
    REAL, INTENT(IN)  :: DEPTH, WNI(NK)
    REAL, INTENT(OUT) :: AO(NSPEC), KDM
    INTEGER           :: IK, ITH, ISP
    REAL              :: XT, ALPHA, FP, SP, SI, SA, R, PM, EF
    REAL              :: TH, DD, SPREAD, DSIG, EBAND, ESUM, KDSUM
    !
    XT    = GRAV * FETCH / U10**2
    ALPHA = 0.076 * XT**(-0.22)
    FP    = 3.5 * ( GRAV / U10 ) * XT**(-0.33)
    SP    = TPI * FP
    !
    ESUM  = 0.
    KDSUM = 0.
    DO IK=1, NK
      SI    = SIG(IK)
      IF ( SI <= SP ) THEN
        SA = 0.07
      ELSE
        SA = 0.09
      END IF
      R     = EXP ( -(SI-SP)**2 / (2.*(SA*SP)**2) )
      PM    = ALPHA * GRAV**2 * SI**(-5) * EXP ( -1.25 * (SP/SI)**4 )
      EF    = PM * GAMMA_J**R
      DSIG  = SI * ( XFR - 1./XFR ) * 0.5
      EBAND = 0.
      DO ITH=1, NTH
        TH = REAL(ITH-1) * DTH
        DD = TH
        DO WHILE ( DD >  PI ) ; DD = DD - TPI ; END DO
        DO WHILE ( DD < -PI ) ; DD = DD + TPI ; END DO
        IF ( ABS(DD) >= 0.5*PI ) THEN
          SPREAD = 0.
        ELSE
          SPREAD = ( 2. / PI ) * COS(DD)**2
        END IF
        ISP     = ITH + (IK-1)*NTH
        AO(ISP) = EF * SPREAD / SI
        EBAND   = EBAND + EF * SPREAD * DTH * DSIG
      END DO
      ESUM  = ESUM  + EBAND
      KDSUM = KDSUM + EBAND * WNI(IK) * DEPTH
    END DO
    !
    KDM = KDSUM / ESUM
    !
  END SUBROUTINE SEA_STATE
  !
END PROGRAM GEN_SNL1_FIXTURE
