! ======================================================================
! CODE FOR SURFACE WAVE TOMOGRAPHY USING DISPERSION MEASUREMENTS
! 
! PROJECT:
!       pDSurfTomo (A High-Performance Parallel Computing Package for Direct Surface Wave Tomography)
!
! ORIGINAL AUTHOR:
!       HONGJIAN FANG. fanghj@mail.ustc.edu.cn
!
! MODIFIED BY:
!       SHAOHANG ZHU. zshang@mail.ustc.edu.cn
!
! LICENSE:
!       Original DSurfTomo code is under the MIT License.
!       Derivative modifications for pDSurfTomo are under the GNU GPL v3.
!       Copyright (c) 2017 Hongjian Fang
!       Copyright (c) 2026 Shaohang Zhu
!
! REFERENCES:
!       Fang, H., Yao, H., Zhang, H., Huang, Y. C., & van der Hilst, R. D.
!       (2015). Direct inversion of surface wave dispersion for
!       three-dimensional shallow crustal structure based on ray tracing:
!       methodology and application. Geophysical Journal International.
!
!       Zhu, S., Li, J., Chen, G., Fang, H., & Yao, H. (2026). 
!       pDSurfTomo: A High-Performance Parallel Computing Package for 
!       Direct Surface Wave Tomography. arXiv preprint arXiv:2604.11920.
!
! HISTORY:
!       2015/01/31  START TO REORGANIZE THE MESSY CODE (Hongjian Fang)
!       2026/04/20  PARALLEL OPTIMIZATION (Shaohang Zhu)
! ======================================================================

program SurfTomo
    use lsmrModule, only: lsmr
    use lsmrblasInterface, only: dnrm2
    use omp_lib
    use BinaryIO
    use ParallelConfig
    use LSMR_Solver
    implicit none

    ! ---------------------- My VARIABLE start ----------------------
    integer :: start_date(8), end_date(8)
    integer :: start_date_sub(8), end_date_sub(8)
    integer :: start_date_iter(8), end_date_iter(8)
    real :: loop_use_time
    character(len=100) :: func_name

    character InitModelFile*200
    character TrueModelFile*200
    ! ---------------------- My VARIABLE end ----------------------

    ! VARIABLE DEFINE
    character inputfile*200
    character logfile*200
    character outmodel*200
    character outsyn*200
    logical ex
    character dummy*40
    character datafile*200

    integer nx, ny, nz
    real goxd, gozd
    real dvxd, dvzd
    integer nsrc, nrc
    real weight, weight0
    real damp
    real minthk
    integer kmax, kmaxRc, kmaxRg, kmaxLc, kmaxLg
    real*8, dimension(:), allocatable:: tRc, tRg, tLc, tLg
    real, dimension(:), allocatable:: depz
    integer itn
    integer nout
    integer localSize
    real mean, std_devs, balances, balanceb
    integer msurf
    real, dimension(:), allocatable:: obst, dsyn, cbst, wt, dtres, dist, datweight
    real, dimension(:), allocatable:: pvall, depRp, pvRp
    real sta1_lat, sta1_lon, sta2_lat, sta2_lon
    real dist1
    integer dall
    integer istep
    real, parameter :: pi = 3.1415926535898
    integer checkstat
    integer ii, jj, kk
    real, dimension(:, :), allocatable :: scxf, sczf
    real, dimension(:, :, :), allocatable :: rcxf, rczf
    integer, dimension(:, :), allocatable::wavetype, igrt, nrc1
    integer, dimension(:), allocatable::nsrc1
    integer, dimension(:, :), allocatable::periods
    real, dimension(:), allocatable::rw
    integer, dimension(:), allocatable::iw, col, nrow
    real, dimension(:), allocatable::dv, norm, dvsub, dvstd, dvall
    ! real,dimension(:),allocatable::dvall
    real, dimension(:, :, :), allocatable::vsf
    real, dimension(:, :, :), allocatable::vsftrue
    character strf
    integer veltp, wavetp
    real velvalue
    integer knum, knumo, err
    integer istep1, istep2
    integer period
    integer knumi, srcnum, count1
    integer HorizonType, VerticalType
    character line*200
    integer iter, maxiter
    integer maxnar
    real acond
    real anorm
    real arnorm
    real rnorm
    real xnorm
    character str1
    real atol, btol
    real conlim
    integer istop
    integer itnlim
    integer lenrw, leniw
    integer nar, nar_tmp, nars
    integer count3, nvz, nvx
    integer m, maxvp, n
    integer i, j, k
    real Minvel, MaxVel
    real spfra
    real noiselevel
    integer ifsyn
    real averdws
    real maxnorm
    real threshold0, q25, q75

    ! OPEN FILES FIRST TO OUTPUT THE PROCESS
    nout = 36
    if (nout > 0) open(unit=nout, file='lsmr.txt', action='write')

    ! OUTPUT PROGRAM INFOMATION
    write (*, *)
    write (*, "(A)") '                   pDSurfTomo (modified from DSurfTomo)'
    write (*, "(A)") 'For bug report for DSurfTomo, PLEASE contact Hongjian Fang (fanghj1990@gmail.com)'
    write (*, "(A)") 'For bug report for pDSurfTomo, PLEASE contact Shaohang Zhu (zshang@mail.ustc.edu.cn)'
    write (*, *)

    ! READ INPUT FILE
    if (iargc() < 1) then
        write (*, "(A)") 'input file [pDSurfTomo.in(default)]:'
        read (*, "(A)") inputfile
        if (len_trim(inputfile) <= 1) then
            inputfile = 'pDSurfTomo.in'
        else
            inputfile = inputfile(1:len_trim(inputfile))
        end if
    else
        call getarg(1, inputfile)
    end if

    InitModelFile = "MOD"
    TrueModelFile = "MOD.true"
    parallel_config_file = "ParallelConfig.in"
    if (iargc() >= 2) then
        call getarg(2, InitModelFile)
    end if
    if (iargc() >= 3) then
        call getarg(3, TrueModelFile)
    end if
    if (iargc() >= 4) then
        call getarg(4, parallel_config_file)
    end if

    call init_ParallelConfig()

    inquire (file=inputfile, exist=ex)
    if (.not. ex) stop 'unable to open the inputfile'

    open (10, file=inputfile, status='old')
    read (10, '(a30)') dummy
    read (10, '(a30)') dummy
    read (10, '(a30)') dummy
    read (10, *) datafile
    read (10, *) nx, ny, nz
    read (10, *) goxd, gozd
    read (10, *) dvxd, dvzd
    read (10, *) nsrc
    ! read (10, *) weight0, damp
    read (10, *) smooth_weight, damp
    read (10, *) minthk
    read (10, *) Minvel, Maxvel
    read (10, *) maxiter
    read (10, *) spfra
    read (10, *) kmaxRc
    write (*, "(A)") 'model origin: latitude, longitue'
    write (*, '(2f10.5)') goxd, gozd
    write (*, "(A)") 'grid spacing: latitude, longitue'
    write (*, '(2f10.5)') dvxd, dvzd
    write (*, "(A)") 'model dimension: nx, ny, nz'
    write (*, '(3i5)') nx, ny, nz
    write (logfile, '(a,a)') trim(inputfile), '.log'
    open (66, file=logfile)
    write (66, *)
    write (66, "(A)") '                       p D S U R F T O M O'
    write (66, "(A)") 'PLEASE contact Shaohang Zhu (zshang@mail.ustc.edu.cn) if you find any bug'
    write (66, *)
    write (66, "(A)") 'model origin: latitude, longitue'
    write (66, '(2f10.5)') goxd, gozd
    write (66, "(A)") 'grid spacing: latitude, longitue'
    write (66, '(2f10.5)') dvxd, dvzd
    write (66, "(A)") 'model dimension: nx, ny, nz'
    write (66, '(3i5)') nx, ny, nz
    if (kmaxRc .gt. 0) then
        allocate (tRc(kmaxRc), stat=checkstat)
        if (checkstat > 0) stop 'error allocating RP'
        read (10, *) (tRc(i), i=1, kmaxRc)
        write (*, "(A)") 'Rayleigh wave phase velocity used, periods:(s)'
        write (*, '(50f7.2)') (tRc(i), i=1, kmaxRc)
        write (66, "(A)") 'Rayleigh wave phase velocity used, periods:(s)'
        write (66, '(50f7.2)') (tRc(i), i=1, kmaxRc)
    end if
    read (10, *) kmaxRg
    if (kmaxRg .gt. 0) then
        allocate (tRg(kmaxRg), stat=checkstat)
        if (checkstat > 0) stop 'error allocating RP'
        read (10, *) (tRg(i), i=1, kmaxRg)
        write (*, "(A)") 'Rayleigh wave group velocity used, periods:(s)'
        write (*, '(50f7.2)') (tRg(i), i=1, kmaxRg)
        write (66, "(A)") 'Rayleigh wave group velocity used, periods:(s)'
        write (66, '(50f7.2)') (tRg(i), i=1, kmaxRg)
    end if
    read (10, *) kmaxLc
    if (kmaxLc .gt. 0) then
        allocate (tLc(kmaxLc), stat=checkstat)
        if (checkstat > 0) stop 'error allocating RP'
        read (10, *) (tLc(i), i=1, kmaxLc)
        write (*, "(A)") 'Love wave phase velocity used, periods:(s)'
        write (*, '(50f7.2)') (tLc(i), i=1, kmaxLc)
        write (66, "(A)") 'Love wave phase velocity used, periods:(s)'
        write (66, '(50f7.2)') (tLc(i), i=1, kmaxLc)
    end if
    read (10, *) kmaxLg
    if (kmaxLg .gt. 0) then
        allocate (tLg(kmaxLg), stat=checkstat)
        if (checkstat > 0) stop 'error allocating RP'
        read (10, *) (tLg(i), i=1, kmaxLg)
        write (*, "(A)") 'Love wave group velocity used, periods:(s)'
        write (*, '(50f7.2)') (tLg(i), i=1, kmaxLg)
        write (66, "(A)") 'Love wave group velocity used, periods:(s)'
        write (66, '(50f7.2)') (tLg(i), i=1, kmaxLg)
    end if
    read (10, *) ifsyn
    read (10, *) noiselevel
    read (10, *) threshold0

    close (10)
    nrc = nsrc
    kmax = kmaxRc + kmaxRg + kmaxLc + kmaxLg

    ! READ MEASUREMENTS
    open (unit=87, file=datafile, status='old')
    allocate (scxf(nsrc, kmax), sczf(nsrc, kmax), &
              rcxf(nrc, nsrc, kmax), rczf(nrc, nsrc, kmax), stat=checkstat)
    if (checkstat > 0) then
        write (6, *) 'error with allocate'
    end if
    allocate (periods(nsrc, kmax), wavetype(nsrc, kmax), &
              nrc1(nsrc, kmax), nsrc1(kmax), &
              igrt(nsrc, kmax), stat=checkstat)
    if (checkstat > 0) then
        write (6, *) 'error with allocate'
    end if
    allocate (obst(nrc*nsrc*kmax), dist(nrc*nsrc*kmax), stat=checkstat)
    allocate (pvall(nrc*nsrc*kmax), depRp(nrc*nsrc*kmax), pvRp(nrc*nsrc*kmax), stat=checkstat)
    IF (checkstat > 0) THEN
        write (6, *) 'error with allocate'
    END IF
    istep = 0
    istep2 = 0
    dall = 0
    knumo = 12345
    knum = 0
    istep1 = 0
    do
        read (87, '(a)', iostat=err) line
        if (err .eq. 0) then
            if (line(1:1) .eq. '#') then
                read (line, *) str1, sta1_lat, sta1_lon, period, wavetp, veltp
                if (wavetp .eq. 2 .and. veltp .eq. 0) knum = period
                if (wavetp .eq. 2 .and. veltp .eq. 1) knum = kmaxRc + period
                if (wavetp .eq. 1 .and. veltp .eq. 0) knum = kmaxRg + kmaxRc + period
                if (wavetp .eq. 1 .and. veltp .eq. 1) knum = kmaxLc + kmaxRg + kmaxRc + period
                if (knum .ne. knumo) then
                    istep = 0
                    istep2 = istep2 + 1
                end if
                istep = istep + 1
                istep1 = 0
                sta1_lat = (90.0 - sta1_lat)*pi/180.0
                sta1_lon = sta1_lon*pi/180.0
                scxf(istep, knum) = sta1_lat
                sczf(istep, knum) = sta1_lon
                periods(istep, knum) = period
                wavetype(istep, knum) = wavetp
                igrt(istep, knum) = veltp
                nsrc1(knum) = istep
                knumo = knum
            else
                read (line, *) sta2_lat, sta2_lon, velvalue
                istep1 = istep1 + 1
                dall = dall + 1
                sta2_lat = (90.0 - sta2_lat)*pi/180.0
                sta2_lon = sta2_lon*pi/180.0
                rcxf(istep1, istep, knum) = sta2_lat
                rczf(istep1, istep, knum) = sta2_lon
                call delsph(sta1_lat, sta1_lon, sta2_lat, sta2_lon, dist1)
                dist(dall) = dist1
                obst(dall) = dist1/velvalue
                pvall(dall) = velvalue
                nrc1(istep, knum) = istep1
            end if
        else
            exit
        end if
    end do
    close (87)
    allocate (depz(nz), stat=checkstat)
    maxnar = spfra*dall*nx*ny*nz  ! sparsity fraction
    if (maxnar < 0) write(*, *) 'number overflow, decrease your sparsefrac'
    maxvp = (nx - 2)*(ny - 2)*(nz - 1)
    allocate (dv(maxvp), dvsub(maxvp), dvstd(maxvp), dvall(maxvp), stat=checkstat)
    ! allocate(dvall(maxvp*nrealizations), stats=checkstat)
    allocate (norm(maxvp), stat=checkstat)
    allocate (vsf(nx, ny, nz), stat=checkstat)
    allocate (vsftrue(nx, ny, nz), stat=checkstat)

    allocate (rw(maxnar), stat=checkstat)
    if (checkstat > 0) then
        write (6, *) 'error with allocate: real rw'
    end if
    allocate (iw(2*maxnar + 1), stat=checkstat)
    if (checkstat > 0) then
        write (6, *) 'error with allocate: integer iw'
    end if
    allocate (col(maxnar), nrow(dall), stat=checkstat)
    if (checkstat > 0) then
        write (6, *) 'error with allocate: integer col'
    end if
    allocate (cbst(dall + maxvp), dsyn(dall), datweight(dall), wt(dall + maxvp), dtres(dall + maxvp), stat=checkstat)

    ! MEASUREMENTS STATISTICS AND READ INITIAL MODEL
    write (*, '(A, I0)') 'Number of all measurements: ', dall
    write (66, '(A, I0)') 'Number of all measurements: ', dall

    ! open (10, file='MOD', status='old')
    open (10, file=InitModelFile, status='old')
    read (10, *) (depz(i), i=1, nz)
    do k = 1, nz
        do j = 1, ny
            read (10, *) (vsf(i, j, k), i=1, nx)
        end do
    end do
    close (10)
    write (*, "(A)") 'grid points in depth direction:(km)'
    write (*, '(50f7.2)') depz
 
    ! CHECKERBOARD TEST
    if (ifsyn == 1) then
        write (*, "(A)") 'Synthetic Test Begin'
        vsftrue = vsf

        ! open (11, file='MOD.true', status='old')
        open (11, file=TrueModelFile, status='old')
        do k = 1, nz
            do j = 1, ny
                read (11, *) (vsftrue(i, j, k), i=1, nx)
            end do
        end do
        close (11)

        call date_and_time(values=start_date)
        if (is_tt_parallel) then
            call synthetic_parallel(nx, ny, nz, maxvp, vsftrue, obst, &
                                    goxd, gozd, dvxd, dvzd, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                                    tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                                    scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, &
                                    nsrc, nrc, noiselevel)
            func_name = "main synthetic_parallel"
        else
            call synthetic(nx, ny, nz, maxvp, vsftrue, obst, &
                           goxd, gozd, dvxd, dvzd, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                           tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                           scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, &
                           nsrc, nrc, noiselevel)
            func_name = "main synthetic"
        end if
        call date_and_time(values=end_date)
        call cal_run_time(start_date, end_date, func_name, loop_use_time)
        call WriteRunTime(func_name, loop_use_time)
    end if

    ! ITERATE UNTILL CONVERGE
    do iter = 1, maxiter
        call date_and_time(values=start_date_iter)
        write (*, "(A, I0, A)") "= = = = = = = = = = ", iter, "th iteration start = = = = = = = = = ="
        write (66, "(A, I0, A)") "= = = = = = = = = = ", iter, "th iteration start = = = = = = = = = ="
        
        Iteration = iter
        write(log_unit, '("Iteration ", I0)') iter

        iw = 0
        rw = 0.0
        col = 0

        ! COMPUTE SENSITIVITY MATRIX
        write (*, "(A)") 'computing sensitivity matrix...'
        call date_and_time(values=start_date)
        if (is_tt_parallel) then
            call CalSurfG_parallel(nx, ny, nz, maxvp, vsf, iw, rw, col, dsyn, &
                                   goxd, gozd, dvxd, dvzd, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                                   tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                                   scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, &
                                   nsrc, nrc, nar)
            func_name = "main CalSurfG_parallel"
        else
            call CalSurfG(nx, ny, nz, maxvp, vsf, iw, rw, col, dsyn, &
                          goxd, gozd, dvxd, dvzd, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                          tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                          scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, &
                          nsrc, nrc, nar)
            func_name = "main CalSurfG"
        end if
        call date_and_time(values=end_date)
        call cal_run_time(start_date, end_date, func_name, loop_use_time)
        call WriteRunTime(func_name, loop_use_time)

        do i = 1, dall
            cbst(i) = obst(i) - dsyn(i)
        end do

        call getpercentile(dall, cbst, q25, q75)
        datweight = 1.0
        do i = 1, dall
        if (cbst(i) < q25*threshold0 .or. cbst(i) > q75*threshold0) then
            datweight(i) = 0.0
            cbst(i) = 0
        end if
        end do
        ! do i = 1,dall
        ! datweight(i) = 0.01+1.0/(1+0.05*exp(cbst(i)**2*threshold0))
        ! cbst(i) = cbst(i)*datweight(i)
        ! enddo

        do i = 1, nar
            rw(i) = rw(i)*datweight(iw(1 + i))
        end do

        norm = 0
        do i = 1, nar
            norm(col(i)) = norm(col(i)) + abs(rw(i))
        end do
        averdws = 0
        maxnorm = 0
        do i = 1, maxvp
            averdws = averdws + norm(i)
            if (norm(i) > maxnorm) maxnorm = norm(i)
        end do
        averdws = averdws/maxvp
        write (66, "(A, 2F13.5)") 'Maximum and Average DWS values:', maxnorm, averdws

        ! WRITE OUT RESIDUAL FOR THE FIRST AND LAST ITERATION
        if (iter .eq. 1) then
            open (88, file='residualFirst.dat')
            do i = 1, dall
                write (88, *) dist(i), dsyn(i), obst(i), &
                    dsyn(i)*datweight(i), obst(i)*datweight(i), datweight(i)
            end do
            close (88)
        end if
        if (iter .eq. maxiter) then
            open (88, file='residualLast.dat')
            do i = 1, dall
                write (88, *) dist(i), dsyn(i), obst(i), &
                    dsyn(i)*datweight(i), obst(i)*datweight(i), datweight(i)
            end do
            close (88)
        end if

        ! weight = weight0
        weight = smooth_weight
        nar_tmp = nar
        nars = 0

        count3 = 0
        ! write (*, '(a, f7.4)') 'Smoothing Weight:', weight
        write (66, '(a, f7.4)') 'Smoothing Weight:', weight
        ! Perform smoothing only when smooth is greater than 0.0001; otherwise, treat it as 0.
        if (weight >= 0.0001) then
            nvz = ny - 2
            nvx = nx - 2
            do k = 1, nz - 1
                do j = 1, nvz
                do i = 1, nvx
                    if (i == 1 .or. i == nvx .or. j == 1 .or. j == nvz .or. k == 1 .or. k == nz - 1) then
                        count3 = count3 + 1
                        col(nar + 1) = (k - 1)*nvz*nvx + (j - 1)*nvx + i
                        rw(nar + 1) = 2.0*weight
                        iw(1 + nar + 1) = dall + count3
                        cbst(dall + count3) = 0
                        nar = nar + 1
                    else
                        if (is_lsmr_py) then 
                            count3 = count3 + 1

                            rw(nar + 1) = -1.0*weight
                            iw(1 + nar + 1) = dall + count3
                            col(nar + 1) = (k - 2)*nvz*nvx + (j - 1)*nvx + i ! 6

                            rw(nar + 2) = -1.0*weight
                            iw(1 + nar + 2) = dall + count3
                            col(nar + 2) = (k - 1)*nvz*nvx + (j - 2)*nvx + i  ! 4

                            rw(nar + 3) = -1.0*weight
                            iw(1 + nar + 3) = dall + count3
                            col(nar + 3) = (k - 1)*nvz*nvx + (j - 1)*nvx + i - 1  ! 2

                            rw(nar + 4) = 6.0*weight
                            iw(1 + nar + 4) = dall + count3
                            col(nar + 4) = (k - 1)*nvz*nvx + (j - 1)*nvx + i  ! 1

                            rw(nar + 5) = -1.0*weight
                            iw(1 + nar + 5) = dall + count3
                            col(nar + 5) = (k - 1)*nvz*nvx + (j - 1)*nvx + i + 1  ! 3

                            rw(nar + 6) = -1.0*weight
                            iw(1 + nar + 6) = dall + count3
                            col(nar + 6) = (k - 1)*nvz*nvx + j*nvx + i  ! 5

                            rw(nar + 7) = -1.0*weight
                            iw(1 + nar + 7) = dall + count3
                            col(nar + 7) = k*nvz*nvx + (j - 1)*nvx + i  ! 7

                            cbst(dall + count3) = 0
                            nar = nar + 7
                        else
                            count3 = count3 + 1

                            rw(nar + 1) = 6.0*weight
                            iw(1 + nar + 1) = dall + count3
                            col(nar + 1) = (k - 1)*nvz*nvx + (j - 1)*nvx + i  ! 1
                            
                            rw(nar + 2) = -1.0*weight
                            iw(1 + nar + 2) = dall + count3
                            col(nar + 2) = (k - 1)*nvz*nvx + (j - 1)*nvx + i - 1  ! 2
                            
                            rw(nar + 3) = -1.0*weight
                            iw(1 + nar + 3) = dall + count3
                            col(nar + 3) = (k - 1)*nvz*nvx + (j - 1)*nvx + i + 1  ! 3
                            
                            rw(nar + 4) = -1.0*weight
                            iw(1 + nar + 4) = dall + count3
                            col(nar + 4) = (k - 1)*nvz*nvx + (j - 2)*nvx + i  ! 4
                            
                            rw(nar + 5) = -1.0*weight
                            iw(1 + nar + 5) = dall + count3
                            col(nar + 5) = (k - 1)*nvz*nvx + j*nvx + i  ! 5
                            
                            rw(nar + 6) = -1.0*weight
                            iw(1 + nar + 6) = dall + count3
                            col(nar + 6) = (k - 2)*nvz*nvx + (j - 1)*nvx + i  ! 6
                            
                            rw(nar + 7) = -1.0*weight
                            iw(1 + nar + 7) = dall + count3
                            col(nar + 7) = k*nvz*nvx + (j - 1)*nvx + i  ! 7
                            
                            cbst(dall + count3) = 0
                            nar = nar + 7
                        end if
                    end if
                end do
                end do
            end do
        end if

        m = dall + count3
        n = maxvp

        iw(1) = nar
        do i = 1, nar
            iw(1 + nar + i) = col(i)
        end do
        if (nar > maxnar) stop 'increase sparsity fraction(spfra)'

        ! CALLING IRLS TO SOLVE THE PROBLEM
        leniw = 2*nar + 1
        lenrw = nar
        dv = 0
        atol = 1e-6
        btol = 1e-6
        ! atol = 1e-3/((dvxd+dvzd)*111.19/2.0*0.1) !1e-2
        ! btol = 1e-3/(dvxd*nx*111.19/3.0)!1e-3
        conlim = 100
        itnlim = 400
        istop = 0
        anorm = 0.0
        acond = 0.0
        arnorm = 0.0
        xnorm = 0.0
        localSize = 10

        if (is_lsmr_py) then 
            call date_and_time(values=start_date)

            call date_and_time(values=start_date_sub)
            call WriteArray_binary_1D(col, "LSMR/col.bin" , nar)
            call WriteArray_binary_1D(rw, "LSMR/rw.bin" , lenrw)
            call WriteArray_binary_1D(cbst, "LSMR/cbst.bin" , m)
            call date_and_time(values=end_date_sub)
            func_name = "main LSMR Save"
            call cal_run_time(start_date_sub, end_date_sub, func_name, loop_use_time)
            
            call date_and_time(values=start_date_sub)
            call run_lsmr(m, n, damp)
            call ReadLSMR_res(get_path("dv"), dv, maxvp)
            call date_and_time(values=end_date_sub)
            func_name = "main LSMR Solve"
            call cal_run_time(start_date_sub, end_date_sub, func_name, loop_use_time)

            call date_and_time(values=end_date)
            func_name = "main LSMR All"
            call cal_run_time(start_date, end_date, func_name, loop_use_time)
            call WriteRunTime(func_name, loop_use_time)
        else
            call date_and_time(values=start_date)

            call LSMR(m, n, leniw, lenrw, iw, rw, cbst, damp, &
                    atol, btol, conlim, itnlim, localSize, nout, &
                    dv, istop, itn, anorm, acond, rnorm, arnorm, xnorm)
            call WriteArray_binary_1D(dv, get_path("dv"), maxvp)

            call date_and_time(values=end_date)
            func_name = "main LSMR All"
            call cal_run_time(start_date, end_date, func_name, loop_use_time)
            call WriteRunTime(func_name, loop_use_time)
        end if

        mean = sum(cbst(1:dall))/dall
        std_devs = sqrt(sum(cbst(1:dall)**2)/dall - mean**2)

        ! write(*, '(a,f7.3)')'weight is: ', weight
        write (*, '(a,f8.1,a,f8.2,a,f8.3)') 'mean, std_devs and rms of residual after weighting: ', &
            mean*1000, 'ms ', 1000*std_devs, 'ms ', dnrm2(dall, cbst, 1)/sqrt(real(dall))

        !do i =1,dall
        !cbst(i)=cbst(i)/datweight(i)
        !enddo

        !mean = sum(cbst(1:dall))/dall
        !std_devs = sqrt(sum(cbst(1:dall)**2)/dall - mean**2)
        !write(*,'(a,f8.1,a,f8.2,a,f8.3)')' residual before weighting: ',mean*1000,'ms ',1000*std_devs,'ms ',&
        !        dnrm2(dall,cbst,1)/sqrt(real(dall))

        
        ! write(66, '(a,f7.3)')'weight is: ', weight
        write (66, '(a,f8.1,a,f8.2,a,f8.3)') 'mean,std_devs and rms of residual: ', &
            mean*1000, 'ms ', 1000*std_devs, 'ms ', dnrm2(dall, cbst, 1)/sqrt(real(dall))

        write (*, '(a,2f10.4)') 'min and max velocity variation ', minval(dv), maxval(dv)
        write (66, '(a,2f10.4)') 'min and max velocity variation ', minval(dv), maxval(dv)

        do k = 1, nz - 1
            do j = 1, ny - 2
            do i = 1, nx - 2
                if (dv((k - 1)*(nx - 2)*(ny - 2) + (j - 1)*(nx - 2) + i) .ge. 0.500) then
                    dv((k - 1)*(nx - 2)*(ny - 2) + (j - 1)*(nx - 2) + i) = 0.500
                end if
                if (dv((k - 1)*(nx - 2)*(ny - 2) + (j - 1)*(nx - 2) + i) .le. -0.500) then
                    dv((k - 1)*(nx - 2)*(ny - 2) + (j - 1)*(nx - 2) + i) = -0.500
                end if
                vsf(i + 1, j + 1, k) = vsf(i + 1, j + 1, k) + dv((k - 1)*(nx - 2)*(ny - 2) + (j - 1)*(nx - 2) + i)
                if (vsf(i + 1, j + 1, k) .lt. Minvel) vsf(i + 1, j + 1, k) = Minvel
                if (vsf(i + 1, j + 1, k) .gt. Maxvel) vsf(i + 1, j + 1, k) = Maxvel
            end do
            end do
        end do

        write (outmodel, '(a,a,i3.3)') trim(inputfile), 'Measure.dat.iter', iter
        open (64, file=outmodel)
        do k = 1, nz - 1
            do j = 1, ny - 2
            do i = 1, nx - 2
                write (64, '(5f10.5)') gozd + (j - 1)*dvzd, goxd - (i - 1)*dvxd, depz(k), vsf(i + 1, j + 1, k)
            end do
            end do
        end do
        close (64)

        call date_and_time(values=end_date_iter)
        func_name = "Iteration"
        call cal_run_time(start_date_iter, end_date_iter, func_name, loop_use_time)
        call WriteRunTime(func_name, loop_use_time)
        call WriteArray_binary_3D(vsf, get_path("vs"))

    end do !end iteration

    ! OUTPUT THE VELOCITY MODEL
    write (*, *)
    write (*, "(A)") 'Program finishes successfully'
    write (66, "(A)") 'Program finishes successfully'

    if (ifsyn == 1) then
        open (65, file='Vs_model.real')
        write (outsyn, '(a,a)') trim(inputfile), 'Syn.dat'
        open (63, file=outsyn)
        do k = 1, nz - 1
            do j = 1, ny - 2
            do i = 1, nx - 2
                write (65, '(5f10.5)') gozd + (j - 1)*dvzd, goxd - (i - 1)*dvxd, depz(k), vsftrue(i + 1, j + 1, k)
                write (63, '(5f10.5)') gozd + (j - 1)*dvzd, goxd - (i - 1)*dvxd, depz(k), vsf(i + 1, j + 1, k)
            end do
            end do
        end do
        close (65)
        close (63)
        write (*, "(A)") 'Output True velocity model to Vs_model.real'
        write (*, "(A, A)") 'Output inverted shear velocity model to ', outsyn
        write (66, "(A)") 'Output True velocity model to Vs_model.real'
        write (66, "(A, A)") 'Output inverted shear velocity model to ', outsyn
    else
        write (outmodel, '(a, a)') trim(inputfile), 'Measure.dat'
        open (64, file=outmodel)
        do k = 1, nz - 1
            do j = 1, ny - 2
            do i = 1, nx - 2
                write (64, '(5f10.5)') gozd + (j - 1)*dvzd, goxd - (i - 1)*dvxd, depz(k), vsf(i + 1, j + 1, k)
            end do
            end do
        end do
        close (64)
        write (*, "(A, A)") 'Output inverted shear velocity model to ', outmodel
        write (66, "(A, A)") 'Output inverted shear velocity model to ', outmodel

    end if
    ! close(40)
    if (nout > 0) close(nout) ! close lsmr.txt
    close (66) ! close surf_tomo.log
    close (log_unit) ! close run_time.log

    deallocate (obst)
    deallocate (dsyn)
    deallocate (dist)
    deallocate (depz)
    deallocate (scxf, sczf)
    deallocate (rcxf, rczf)
    deallocate (wavetype, igrt, nrc1)
    deallocate (nsrc1, periods)
    deallocate (rw)
    deallocate (iw, col, nrow)
    deallocate (cbst, wt, dtres, datweight)
    deallocate (dv, dvsub, dvstd, dvall)
    deallocate (norm)
    deallocate (vsf)
    deallocate (vsftrue)
    if (kmaxRc .gt. 0) then
        deallocate (tRc)
    end if
    if (kmaxRg .gt. 0) then
        deallocate (tRg)
    end if
    if (kmaxLc .gt. 0) then
        deallocate (tLc)
    end if
    if (kmaxLg .gt. 0) then
        deallocate (tLg)
    end if

end program

