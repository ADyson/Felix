!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! FelixSim
!
! Richard Beanland, Keith Evans and Rudolf A Roemer
!
! (C) 2013/14, all right reserved
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
!  This file is part of FelixSim.
!
!  FelixSim is free software: you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation, either version 3 of the License, or
!  (at your option) any later version.
!  
!  FelixSim is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!  
!  You should have received a copy of the GNU General Public License
!  along with FelixSim.  If not, see <http://www.gnu.org/licenses/>.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! $Id: lacbed.f90,v 1.30 2014/04/23 17:18:00 phslaz Exp $
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! $Log: lacbed.f90,v $
! Revision 1.30  2014/04/23 17:18:00  phslaz
! Improved Error checking, all subroutines now include ierr and return to main (in felixsim) or lacbed (in felixdraw) upon ierr.ne.0 and call MPI_FINALISE
!
! Revision 1.29  2014/04/14 16:51:12  phslaz
! Seemingly fixed the rhombahedral problem, turns out theres was a mistake in inpcif where the 3rd angle was being read in incorrectly, have also written a new hklmake which is more understandable and applies selection rules directly rather than mathematically
!
! Revision 1.28  2014/04/09 13:45:39  phslaz
! cleaned up the write flags also added in some of the amplitude/phase imaging
!
! Revision 1.27  2014/03/27 21:08:30  phslaz
! Read/Write after MPI run now works
!
! Revision 1.26  2014/03/27 15:57:51  phsht
! small changes to IWriteFlag handling in montage parts
!
! Revision 1.25  2014/03/27 10:13:55  phsht
! included a thickness message
!
! Revision 1.24  2014/03/27 10:08:09  phsht
! replaced "lacbed(" with "lacbed(" in all print statements
!
! Revision 1.23  2014/03/26 17:04:52  phslaz
! Bloch now creates images
!
! Revision 1.18  2014/03/25 15:45:31  phslaz
! conflict resolution
!
! Revision 1.17  2014/03/25 15:35:34  phsht
! included consistent start of each source file and GPL statements
!
! Revision 1.16  2014/03/25 15:09:17  phsht
! "DBG :" -> "DBG:"
!
! Revision 1.15  2014/03/24 12:50:31  phslaz
! fixed write flag 2 and rewrote lacbed to read file once instead of every thickness
!
! Revision 1.14  2014/03/21 15:55:36  phslaz
! New Lacbed code Working
!
! Revision 1.11  2014/03/03 18:18:07  phslaz
! Fixed some of the issues with inpcif however still not complete, mot having multiplicity in the cif file seems to be and issue
!
! Revision 1.7  2014/02/20 13:17:31  phsht
! removed WF/WI/EX/EV/etc outputs from BER-BLOCH
! combined EX+EV output into ES output and made MPI compatible
! restructured ES file
!
! Revision 1.6  2014/02/20 10:15:23  phslaz
! Working towards improved cif read in, also lacbed now creates montages
!
! Revision 1.4  2014/02/07 14:33:05  phslaz
! LACBED code now reads eigen spectra output
!
! Revision 1.2  2014/02/04 15:18:03  phsht
! redone using new lacbed.f90
!
! Revision 1.1  2014/01/31 16:53:03  phsht
! 1st version copied from lacbed.f90
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PROGRAM LACBED
 
  USE MyNumbers
  
  USE CConst; USE IConst; USE RConst
  USE IPara; USE RPara; USE SPara; USE CPara

  USE IChannels

  USE MPI
  USE MyMPI

  !--------------------------------------------------------------------
  ! local variable definitions
  !--------------------------------------------------------------------
  
  IMPLICIT NONE

  REAL(RKIND) time, norm
  COMPLEX(CKIND) sumC, sumD

  !--------------------------------------------------------------------
  ! microscopy parameter
!!$  REAL(RKIND),DIMENSION(:,:,:), ALLOCATABLE :: &
!!$       RFinalMontageImage

  !--------------------------------------------------------------------
  ! eigen problem variables
  INTEGER(IKIND) IStrongBeamIndex, IWeakBeamIndex
  INTEGER(IKIND),DIMENSION(:), ALLOCATABLE :: &
       IWeakBeamList
  REAL(RKIND),DIMENSION(:), ALLOCATABLE :: &
       RDevPara
  REAL(8), DIMENSION(:), ALLOCATABLE :: &
       RROutArray, RIOutArray
  CHARACTER*25 CThickness 
  CHARACTER*25 CThicknessLength
  CHARACTER*34 filename
  
  INTEGER(IKIND) :: IRank, &
       Iindex, Ijndex, IWriteLine,IInputBeams, &
       IAllocationChunk,InChunks,ichnk
  
  !ISeperateFolderFlag = 0

  !--------------------------------------------------------------------
  ! image related variables	

  INTEGER(IKIND) :: &
       IThicknessIndex,IThickness, IXpos, IYpos
  REAL(RKIND) Rx0,Ry0, RImageRadius,Rradius, RThickness

  INTEGER(IKIND) ILocalPixelCountMin, ILocalPixelCountMax
  REAL(RKIND) RAtomicFormFactor, RBigK,Rmemory
  COMPLEX(RKIND) CVgij
  
  INTEGER ind,jnd,hnd,knd,pnd, iAtom, currentatom,gnd
  INTEGER, DIMENSION(:), ALLOCATABLE :: &
       IWeakBeamVec

  CHARACTER*40 surname,path

!!$  INTEGER(IKIND) IErr
  INTEGER IErr
  REAL(RKIND) StartTime, CurrentTime, Duration, TotalDurationEstimate

1 FORMAT(1000f16.8)
2 FORMAT(10002f16.8)
3 FORMAT(2I7.5,1000f16.8)

  !-------------------------------------------------------------------
  ! constants
  !-------------------------------------------------------------------

  CALL Init_Numbers
  
  !-------------------------------------------------------------------
  ! set the error value to zero, will change upon error
  !-------------------------------------------------------------------

  IErr=0

  !--------------------------------------------------------------------
  ! MPI initialization
  !--------------------------------------------------------------------

  ! Initialise MPI  
  CALL MPI_Init(IErr)

  ! Get the rank of the current process
  CALL MPI_Comm_rank(MPI_COMM_WORLD,my_rank,IErr)

  ! Get the size of the current communicator
  CALL MPI_Comm_size(MPI_COMM_WORLD,p,IErr)

  !--------------------------------------------------------------------
  ! protocal feature startup
  !--------------------------------------------------------------------
  
  PRINT*,"BER-LACBED: ", RStr,DStr,AStr, ", process ", my_rank, " of ", p
  PRINT*,"--------------------------------------------------------------"

  !--------------------------------------------------------------------
  ! timing startup
  !--------------------------------------------------------------------

  CALL cpu_time(StartTime)

  !--------------------------------------------------------------------
  ! allocate memory for STATIC variables
  !--------------------------------------------------------------------

!!$  ALLOCATE( &
!!$       RXDirC(THREEDIM), RZDirC(THREEDIM), &
!!$       STAT=IErr)
!!$  IF( IErr.NE.0 ) THEN
!!$     PRINT*,"lacbed(", my_rank, ") error ", IErr, " in ALLOCATE()"
!!$     GOTO 9999
!!$  ENDIF

  !--------------------------------------------------------------------
  ! INPUT section
  !--------------------------------------------------------------------

  CALL Input( IErr )
  !PRINT*, "DBG: IErr=", IErr
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in Input()"
     GOTO 9999
  ENDIF

  CALL InpCIF(IErr)
  !PRINT*, "DBG: IErr=", IErr
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in InputScatteringFactors()"
     GOTO 9999
  ENDIF

  IF (ITotalAtoms.EQ.0) THEN
     CALL CountTotalAtoms
  END IF
     
  PRINT*,"ITotalAtoms = ",ITotalAtoms

  
  ALLOCATE( &
       RMask(2*IPixelCount,2*IPixelCount),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables RMask"
     GOTO 9999
  ENDIF
  
  CALL ImageMask (IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ImageMask"
     GOTO 9999
  END IF
  
  PRINT*,"DBG: lacbed(", my_rank, ") IPixelTotal=", IPixelTotal
  
  !--------------------------------------------------------------------
  ! allocate memory for DYNAMIC variables according to SIZE(HKL)
  !--------------------------------------------------------------------

  !Crystallography Initialisation

!!$  CALL HKLMake(IHKLMAXValue,RZDirC,2*PI/180.0D0,IErr)
!!$  IF( IErr.NE.0 ) THEN
!!$     PRINT*,"lacbed(", my_rank, ") error in HKLMake()"
!!$     GOTO 9999
!!$  ENDIF

  ALLOCATE( &
       RrVecMat(ITotalAtoms,THREEDIM), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, " in ALLOCATE()"
     GOTO 9999
  ENDIF

  !Diffraction Definitions 

!!$  ALLOCATE( &       
!!$       RXDirM(THREEDIM), RYDirM(THREEDIM), RZDirM(THREEDIM), &
!!$       RaVecM(THREEDIM), RbVecM(THREEDIM), RcVecM(THREEDIM), &
!!$       RarVecM(THREEDIM), RbrVecM(THREEDIM), RcrVecM(THREEDIM), &
!!$       RTMat(THREEDIM,THREEDIM), &
!!$       STAT=IErr)
!!$  IF( IErr.NE.0 ) THEN
!!$     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
!!$          " in ALLOCATE() of DYNAMIC variables (HKL)"
!!$     GOTO 9999
!!$  ENDIF

  !--------------------------------------------------------------------
  ! microscopy settings
  !--------------------------------------------------------------------

  CALL MicroscopySettings( IErr )
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in MicroscopySettings()"
     GOTO 9999
  ENDIF

  !--------------------------------------------------------------------
  ! crystallography initialization
  !--------------------------------------------------------------------

  CALL Crystallography( IErr )
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in Crystallography()"
     GOTO 9999
  ENDIF

  !--------------------------------------------------------------------
  ! diffraction initialization
  !--------------------------------------------------------------------

  CALL DiffractionPatternDefinitions( IErr )
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in DiffractionPatternDefinitions()"
     GOTO 9999
  ENDIF

  !--------------------------------------------------------------------
  ! This is as late as i can do all this stuff
  !--------------------------------------------------------------------

  WRITE(surname,'(A1,I1.1,A1,I1.1,A1,I1.1,A2,I4.4)') &
       "S", IScatterFactorMethodFLAG, &
       "B", ICentralBeamFLAG, &
       "M", IMaskFLAG, &
       "_P", IPixelCount
  
  PRINT*,"DBG: surname",surname

  !--------------------------------------------------------------------
  !Open Eigen Spectra File and calculate memory
  !--------------------------------------------------------------------

  WRITE(filename,'(A4,A1,A12,A4)') "F-ES","-",surname,".raw"  
  
  PRINT*,"DBG: InputEigen",filename
 
  OPEN(UNIT= IChInp, FILE= TRIM(filename),&
       STATUS= 'OLD',ERR=9999)
  
  READ(UNIT= IChInp, FMT='(7(I3.1,1X))',ADVANCE='YES') &
       IRank,Iindex, Ijndex, nReflections, IInputBeams, IWriteLine, IStrongBeamIndex
  
  REWIND(UNIT=IChInp)
  PRINT*,"DBG: nreflection", nReflections
  
  !Total Number of Elements in Eigen Spectra Array (CTEST)
  Rmemory = IPixelTotal*REAL(nReflections)*REAL(nReflections)
  PRINT*,"Size of Eigen Spectra = ",Rmemory,"Elements"
  
  !Total Bytes needed for Eigen Spectra Array (CTEST)
  Rmemory = Rmemory*16.0D0
  PRINT*,"Size of Eigen Spectra = ",Rmemory,"Bytes"
  
  !Total Gb needed for Eigen Spectra Array (CTEST
  Rmemory = Rmemory/RGigaByte
  PRINT*,"Size of Eigen Spectra = ",NINT(Rmemory),"Gb"
  
  IAllocationChunk = IPixelTotal
  DO     
     PRINT*,"Allocation Chunk = ",IAllocationChunk
     
     ALLOCATE(& 
          CEigenVectorsChunk(IAllocationChunk,nReflections,nReflections), &
          STAT=IErr)
     IF( IErr.NE.0 ) THEN
        PRINT*,"Allocation Chunk Too Large"
        IAllocationChunk = IAllocationChunk/2
        CYCLE
     ENDIF
     IAllocationChunk = IAllocationChunk/2 !Allow Memory for other Arrays
     EXIT
  END DO

  PRINT*,"Size of CEigenVectorsChunk = ",SIZE(CEigenVectorsChunk,DIM=1), &
       SIZE(CEigenVectorsChunk,DIM=2),&
       SIZE(CEigenVectorsChunk,DIM=3)


  !Determine No. of Chunks
  
  InChunks = IPixelTotal/IAllocationChunk
  InChunks = InChunks + 1 !An  extra just incase
  
  PRINT*,"No of Chunks = ",InChunks
  
  ALLOCATE(& 
       CEigenValuesChunk(IAllocationChunk,nReflections), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"ERROR IN ALLOCATE OF LACBED Input Eigen SPectra"
     GOTO 9999
  ENDIF 

  ALLOCATE(&
       ILACBEDStrongBeamList(IAllocationChunk,nReflections), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"ERROR IN ALLOCATE OF LACBED Input Eigen SPectra"
     GOTO 9999
  ENDIF
 
  ALLOCATE(& 
       InBeams(IAllocationChunk),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"ERROR IN ALLOCATE OF LACBED Input Eigen SPectra"
     GOTO 9999
  ENDIF 

  ALLOCATE(& 
       IPixelLocation(IAllocationChunk,2),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"ERROR IN ALLOCATE OF LACBED Input Eigen SPectra"
     GOTO 9999
  ENDIF
  
  !--------------------------------------------------------------------
  ! allocate memory for DYNAMIC variables according to nReflections
  !--------------------------------------------------------------------

  ! Image initialisation 
  PRINT*,"DBG: nReflections=", nReflections
  ALLOCATE( &
       Rhklpositions(nReflections,2), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables (nReflections)"
     GOTO 9999
  ENDIF
!!$  ALLOCATE( &
!!$       IImageSizeXY(2), &
!!$       STAT=IErr)
!!$  IF( IErr.NE.0 ) THEN
!!$     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
!!$          " in ALLOCATE() of DYNAMIC variables (nReflections)"
!!$     GOTO 9999
!!$  ENDIF

  IF(nReflections.LT.IReflectOut) THEN
     IReflectOut = nReflections
  END IF

  !--------------------------------------------------------------------
  ! image initialization
  !--------------------------------------------------------------------

  CALL ImageInitialization( IErr )
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error in ImageInitializtion()"
     GOTO 9999
  ENDIF
 
  IThicknessCount= (RFinalThickness- RInitialThickness)/RDeltaThickness + 1

!!$  ALLOCATE( &
!!$       RFinalMontageImage(MAXVAL(IImageSizeXY),&
!!$       MAXVAL(IImageSizeXY),IThicknessCount),&
!!$       STAT=IErr)
!!$  IF( IErr.NE.0 ) THEN
!!$     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
!!$          " in ALLOCATE() of DYNAMIC variables Montage"
!!$     GOTO 9999
!!$  ENDIF

  ALLOCATE( &
       RIndividualReflections(2*IPixelCount,&
       2*IPixelCount,IReflectOut,IThicknessCount),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Individual Images"
     GOTO 9999
  ENDIF

!!$  PRINT*,"Size of Montage = ",SIZE(RFinalMontageImage,DIM=1),&
!!$       SIZE(RFinalMontageImage,DIM=2)

  ALLOCATE( &
       CFullWaveFunctions(nReflections), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Kprime"
     GOTO 9999
  ENDIF 
  ALLOCATE( &
       RFullWaveIntensity(nReflections), & 
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Kprime"
     GOTO 9999
  ENDIF
  
  !RFinalMontageImage = ZERO

  !--------------------------------------------------------------------
  ! LACBED section
  !--------------------------------------------------------------------

  ALLOCATE( &
       RrVecMat(ITotalAtoms,THREEDIM), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, " in ALLOCATE()"
     GOTO 9999
  ENDIF

  !Diffraction Definitions 

  ALLOCATE( &
       RgVecMat(SIZE(RHKL,DIM=1),THREEDIM), &
       RgVecMatT(SIZE(RHKL,DIM=1),THREEDIM), &
       RgVecMag(SIZE(RHKL,DIM=1)), &
       RSg(SIZE(RHKL,DIM=1)), &
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables (HKL)"
     GOTO 9999
  ENDIF

  DEALLOCATE( &
       RrVecMat, Rsg, RgVecMat,RgMatMat,RgMatMag)

  
  DO ichnk=1,InChunks
     
     PRINT*,"ichnk = ",ichnk
     
     IF(IPixelCountTotal.GE.IPixelTotal) EXIT
     
     !---------------------------------------------------------------------
     !Need to read inside loop now 
     !---------------------------------------------------------------------
     
     CALL ReadEigenSystemChunk(IAllocationChunk, IErr )
     !PRINT*, "DBG: IErr=", IErr
     IF( IErr.NE.0 ) THEN
        PRINT*,"lacbed(", my_rank, ") : error in Input()"
        GOTO 9999
     ENDIF
     
     PRINT*,"Finished Reading"
          
     PRINT*,"Initial Thickness, Final Thickness, IThicknessCount = ",RInitialThickness,RFinalThickness, IThicknessCount 

     DO IThicknessIndex=1,IThicknessCount,1
        
        RThickness = RInitialThickness + (IThicknessIndex-1)*RDeltaThickness 
        IThickness = RInitialThickness + (IThicknessIndex-1)*RDeltaThickness 
        
        IF(IWriteFLAG.GE.2) THEN
           PRINT*,"lacbed(", my_rank, "): working on thickness index ", IThicknessIndex, " (", RThickness, ") of ", &
                IThicknessCount, " in total."
        ENDIF

        
        WRITE(CThickness,*) IThickness
        WRITE(CThicknessLength,*) SCAN(CThickness,'0123456789',.TRUE.)-SCAN(CThickness,'0123456789')+1
        
        WRITE(surname,"(A"//TRIM(CThicknessLength)//",A9)") &
             CThickness(SCAN(CThickness,'0123456789'):SCAN(CThickness,'0123456789',.TRUE.)), &
             "Angstroms"
              
        
        !--------------------------------------------------------------------
        ! open outfiles
        !--------------------------------------------------------------------
        
        WRITE(surname,"(A1,I1.1,A1,I1.1,A1,I1.1,A2,I4.4,A2,A"//TRIM(CThicknessLength)//")") &
             "S", IScatterFactorMethodFLAG, &
             "B", ICentralBeamFLAG, &
             "M", IMaskFLAG, &
             "_P", IPixelCount, &
             "_T", CThickness(SCAN(CThickness,'0123456789'):SCAN(CThickness,'0123456789',.TRUE.))
        
        PRINT*,"DBG LACBED surname = ",surname
        
        IF(ichnk.EQ.1) THEN
           SELECT CASE(IParallelFLAG)
           CASE(0)
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL OpenData(IChOutWF, "WF", surname, IErr)
              ENDIF
              IF( IErr.NE.0 ) THEN
                 PRINT*,"lacbed(", my_rank, ") error in OpenData()"
                 GOTO 9999
              ENDIF
           CASE DEFAULT
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL OpenData_MPI(IChOutWF_MPI, "WF", surname, IErr)
              ENDIF
              IF( IErr.NE.0 ) THEN
                 PRINT*,"lacbed(", my_rank, ") error in OpenDataMPI()"
                 GOTO 9999
              ENDIF
           END SELECT
        ELSE
           SELECT CASE(IParallelFLAG)
           CASE(0)
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL OpenDataForAppend(IChOutWF, "WF", surname, IErr)
              ENDIF
              IF( IErr.NE.0 ) THEN
                 PRINT*,"lacbed(", my_rank, ") error in OpenDataForAppend()"
                 GOTO 9999
              ENDIF
           CASE DEFAULT
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL OpenDataForAppend_MPI(IChOutWF_MPI, "WF", surname, IErr)
              ENDIF
              IF( IErr.NE.0 ) THEN
                 PRINT*,"lacbed(", my_rank, ") error in OpenDataForAppend_ MPI()"
                 GOTO 9999
              ENDIF
           END SELECT

        END IF

        
        !--------------------------------------------------------------------
        ! LACBED LOOP: solve for each (ind,jnd) pixel
        !--------------------------------------------------------------------
        
        ILocalPixelCountMin= (2*IPixelCount*(my_rank)/p)+1
        ILocalPixelCountMax= (2*IPixelCount*(my_rank+1)/p)
        
        IF(IWriteFLAG.GE.6) THEN
           PRINT*,"lacbed(", my_rank, "): starting the eigenvalue problem"
           PRINT*,"lacbed(", my_rank, "): for lines ", ILocalPixelCountMin, &
                " to ", ILocalPixelCountMax
        ENDIF
        
        IPixelComputed= 0
        DO gnd = 1,IAllocationChunk

           ind = IPixelLocation(gnd,1)
           jnd = IPixelLocation(gnd,2)
           nBeams = InBeams(gnd)
           IPixelComputed= IPixelComputed + 1
           
           !--------------------------------------------------------------------
           ! protocol progress
           !--------------------------------------------------------------------
           
           IF(IWriteFLAG.GE.3) THEN
              PRINT*,"lacbed(", my_rank, "): working on pixel (", ind, ",", jnd,") of (", &
                   2*IPixelCount, ",", 2*IPixelCount, ") in total."
           ENDIF
            
           !Eigen Problem Solving
           ALLOCATE( &
                CEigenVectors(nBeams,nBeams), &
                CEigenValues(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables Eigenproblem"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams,gnd = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           
           !Gamma Values
           ALLOCATE( &
                CGammaValues(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables GammaValues"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           
           !Calculating Wavefunctions
           ALLOCATE( &
                CInvertedEigenVectors(nBeams,nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables CInvertedEigenVectors"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                CAlphaWeightingCoefficients(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables CAlphaWeightingCoefficients"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                CEigenValueDependentTerms(nBeams,nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables CEigenValueDependentTerms"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                CWaveFunctions(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables CWaveFunctions"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                RWaveIntensity(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables RWaveIntensity"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                IStrongBeamList(nBeams), &
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables IStrongBeamList"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              
              GOTO 9999
           ENDIF
           ALLOCATE( &
                CPsi0(nBeams), & 
                STAT=IErr)
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error ", IErr, &
                   " in ALLOCATE() of DYNAMIC variables CPsi0"
              PRINT*,"Failure Occured at Thickness,Chunk,Pixel,nBeams = ",RThickness,ichnk,IPixelCountTotal,nBeams,gnd
              GOTO 9999
           ENDIF
           
           CEigenVectors = CZERO
           CEigenVectors = CEigenVectorsChunk(gnd,1:nBeams,1:nBeams)
           CEigenValues = CZERO
           CEigenValues = CEigenValuesChunk(gnd,1:nBeams)
           IStrongBeamList = ILACBEDStrongBeamList(gnd,1:nBeams)
           
           CALL CreateWaveFunctions(gnd,ichnk,rthickness,ierr)
           
           !CALL MakeMontagePixel(ind,jnd,IThicknessIndex)

           !Collection Wave Intensities from all thickness for later writing

           RIndividualReflections(ind,jnd,1:IReflectOut,IThicknessIndex) = &
                RFullWaveIntensity(1:IReflectOut)
           
           !PRINT*,"RFullWaveIntensity = ",RFullWaveIntensity
           
           !--------------------------------------------------------------------
           ! OUTPUT data for given pixel and thickness
           !--------------------------------------------------------------------
           
           IF(IWriteFLAG.GE.10) THEN
              !PRINT*,"WaveFunctions=",WaveFunctions
              PRINT*,"lacbed(", my_rank, "): WaveIntensity=",RFullWaveIntensity
           ENDIF
           
           SELECT CASE(IParallelFLAG)
           CASE(0)
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL WriteDataC(IChOutWF, ind,jnd, &
                      CFullWaveFunctions(:), nReflections, 1, IErr)
              ENDIF
              
           CASE DEFAULT
              ! wave functions
              IF(IWriteFLAG.GE.3) THEN
                 CALL WriteDataC_MPI(IChOutWF_MPI, ind,jnd, &
                      CFullWaveFunctions(:), &
                      nReflections, 1, IErr)
              ENDIF
              
           END SElECT
           IF( IErr.NE.0 ) GOTO 9999
           
           !--------------------------------------------------------------------
           ! DEALLOCATE eigen problem memory
           !--------------------------------------------------------------------
           
           DEALLOCATE(& 
                IStrongBeamList,CEigenVectors, CEigenValues, &
                CGammaValues, CInvertedEigenVectors,&
                CAlphaWeightingCoefficients, CEigenValueDependentTerms, &
                CWaveFunctions, RWaveIntensity, CPsi0,STAT=IErr)       
           IF( IErr.NE.0 ) THEN
              PRINT*,"main(", my_rank, ") error in Deallocation"
              GOTO 9999
           ENDIF
           IF(IWriteFLAG.GE.2) THEN
              CALL cpu_time(CurrentTime)
              
              Duration=(CurrentTime-StartTime)
              TotalDurationEstimate= &
                   (Duration*IPixelTotal/p)/IPixelComputed - Duration
              PRINT*,"lacbed(", my_rank, "): finished pixel (", ind, ",", jnd, &
                   ") after ", NINT(Duration), &
                   " seconds(s), total time left estimated at", &
                   NINT(TotalDurationEstimate), " second(s)"
           ENDIF
           
        END DO
        
        !--------------------------------------------------------------------
        ! close outfiles
        !--------------------------------------------------------------------
        
        SELECT CASE(IParallelFLAG)
        CASE(0)
           ! wave functions
           IF(IWriteFLAG.GE.2) THEN
              CLOSE(IChOutWF, ERR=9999)
           ENDIF
           
        CASE DEFAULT
           ! wave functions
           IF(IWriteFLAG.GE.2) THEN
              CALL MPI_FILE_CLOSE(IChOutWF_MPI, IErr)
           ENDIF
           
        END SELECT
        
     END DO
  END DO

  ALLOCATE( &
       RFinalMontageImage(MAXVAL(IImageSizeXY),&
       MAXVAL(IImageSizeXY),IThicknessCount),&
       STAT=IErr)
  IF( IErr.NE.0 ) THEN
     PRINT*,"lacbed(", my_rank, ") error ", IErr, &
          " in ALLOCATE() of DYNAMIC variables Root Reflections"
     GOTO 9999
  ENDIF

  RFinalMontageImage = ZERO
  
  IF(my_rank.EQ.0) THEN
     
     DO IThicknessIndex =1,IThicknessCount
        DO ind = 1,2*IPixelCount
           DO jnd = 1,2*IPixelCount
              
              CALL MakeMontagePixel(ind,jnd,IThicknessIndex,&
                   RFinalMontageImage,&
                   RIndividualReflections(ind,jnd,:,IThicknessIndex),IERR)
              
           END DO
        END DO
     END DO
  END IF

  IF (IImageFlag.LT.1) THEN
     DEALLOCATE(&
          RIndividualReflections,STAT=IErr)       
     IF( IErr.NE.0 ) THEN
        PRINT*,"main(", my_rank, ") error in Deallocation of RIndividualReflections"
        GOTO 9999
     ENDIF
  END IF
  
  IF(IWriteFlag.GE.10) THEN

     PRINT*,"Writing Montages"

  END IF
  
  DO knd = 1,IThicknessCount
     !--------------------------------------------------------
     ! Write Montage
     !--------------------------------------------------------
     
     RThickness = RInitialThickness + (knd-1)*RDeltaThickness 
     IThickness = RInitialThickness + (knd-1)*RDeltaThickness 
     
     PRINT*,"DBG : RThickness = ",RThickness
     
     WRITE(CThickness,*) IThickness
     WRITE(CThicknessLength,*) SCAN(CThickness,'0123456789',.TRUE.)-SCAN(CThickness,'0123456789')+1

     IF(IImageFLAG.GE.0) THEN
        
        WRITE(surname,"(A2,A"//TRIM(CThicknessLength)//")") &
             "M-", &
             CThickness(SCAN(CThickness,'0123456789'):SCAN(CThickness,'0123456789',.TRUE.))
        
        CALL OpenData(MontageOut,"WI",surname,IErr) 
        IF( IErr.NE.0 ) THEN
           PRINT*,"lacbed(", my_rank, ") error in OpenData()"
           GOTO 9999
        ENDIF
        
        PRINT*,"lacbed(", my_rank, ") working on RThickness=", RThickness
        WRITE(MontageOut,*) &
             RESHAPE(RFinalMontageImage(:,:,knd),(/MAXVAL(IImageSizeXY),MAXVAL(IImageSizeXY)/)) 
        CLOSE(MontageOut,ERR=9999)

     END IF
     
     !--------------------------------------------------------
     ! Write Reflections
     !--------------------------------------------------------
     
     IF(IImageFLAG.GE.1) THEN

        
        WRITE(path,"(A1,I1.1,A1,I1.1,A1,I1.1,A2,I4.4,A2,A"//TRIM(CThicknessLength)//")") &
             "S", IScatterFactorMethodFLAG, &
             "B", ICentralBeamFLAG, &
             "M", IMaskFLAG, &
             "_P", IPixelCount, &
             "_T", CThickness(SCAN(CThickness,'0123456789'):SCAN(CThickness,'0123456789',.TRUE.))
        
        call system('mkdir ' // path)        

        DO ind = 1,IReflectOut
           CALL OpenReflectionImage(IChOutWIImage,path, IErr,ind)
           IF( IErr.NE.0 ) THEN
              PRINT*,"Lacbed(", my_rank, ") error in OpenReflectionImage()"
              GOTO 9999
           ENDIF
           !IMAXRBuffer = (4*IPixelCount**2)*7+ADD_OUT_INFO
           !CALL WriteImageR_MPI(IChOutWI_MPI,RIndividualReflections(:,:,ind,knd),IErr)
           CALL WriteReflectionImage(IChOutWIImage,RIndividualReflections(:,:,ind,knd),IErr)   
           IF( IErr.NE.0 ) THEN
              PRINT*,"lacbed(", my_rank, ") error in WriteReflectionImage()"
              GOTO 9999
           ENDIF
           
           CLOSE(IChOutWIImage, ERR=9999)
        END DO

     END IF
  END DO

  IF(IImageFLAG.GE.1) THEN
     DEALLOCATE(&
          RIndividualReflections,STAT=IErr)       
     IF( IErr.NE.0 ) THEN
        PRINT*,"main(", my_rank, ") error in Deallocation of RIndividualReflections"
        GOTO 9999
     ENDIF
  END IF
  

  !--------------------------------------------------------------------
  ! finish off
  !--------------------------------------------------------------------
  
  CALL cpu_time(CurrentTime)
  Duration=(CurrentTime-StartTime)/3600.0D0
  
  PRINT*, "BER-BLOCH(", my_rank, ") ", RStr, ", used time=", duration, "hrs"
  
  !--------------------------------------------------------------------
  ! Shut down MPI
  !--------------------------------------------------------------------
9999 &
          CALL MPI_Finalize(IErr)
  
  STOP
  
!!$800 PRINT*,"lacbed(", my_rank, "): ERR in CLOSE()"
!!$  IErr= 1
!!$  RETURN
  
END PROGRAM LACBED
