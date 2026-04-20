MODULE ThreadDataMod
    use ParallelConfig, only: ThreadNum
    implicit none
    
    INTEGER, PARAMETER:: t_i10 = SELECTED_REAL_KIND(6)
    INTEGER :: t_checkstat

    TYPE t_backpointer
        INTEGER :: px, pz
    END TYPE t_backpointer

    TYPE :: ThreadData
        INTEGER :: tid
        REAL(KIND=t_i10) :: pi = 3.1415926535898

        INTEGER :: nvx, nvz, nnx, nnz, fom, gdx, gdz
        INTEGER :: vnl, vnr, vnt, vnb, nrnx, nrnz, sgdl, rbint
        INTEGER :: nnxr, nnzr, asgr
        REAL(KIND=t_i10) :: gox, goz, dnx, dnz, dvx, dvz, snb, earth
        REAL(KIND=t_i10) :: goxd, gozd, dvxd, dvzd, dnxd, dnzd
        REAL(KIND=t_i10) :: drnx, drnz, gorx, gorz
        REAL(KIND=t_i10) :: dnxr, dnzr, goxr, gozr

        INTEGER, DIMENSION(:, :), ALLOCATABLE :: nsts, nstsr
        REAL(KIND=t_i10), DIMENSION(:, :), ALLOCATABLE :: velv, veln, velnb
        REAL(KIND=t_i10), DIMENSION(:, :), ALLOCATABLE :: ttn, ttnr

        INTEGER ntr
        TYPE(t_backpointer), DIMENSION(:), ALLOCATABLE :: btg

        INTEGER :: nnxb, nnzb, sgs  ! 自己添加
        REAL(KIND=t_i10) :: dnxb, dnzb, goxb, gozb ! 自己添加

    END TYPE ThreadData
CONTAINS

    subroutine init_thread_data_scalar(td)
        type(ThreadData), intent(inout) :: td
        td%nvx = 0; td%nvz = 0; td%nnx = 0; td%nnz = 0; td%fom = 0; td%gdx = 0; td%gdz = 0
        td%vnl = 0; td%vnr = 0; td%vnt = 0; td%vnb = 0; td%nrnx = 0; td%nrnz = 0; td%sgdl = 0; td%rbint = 0
        td%nnxr = 0; td%nnzr = 0; td%asgr = 0
        td%gox = 0.0; td%goz = 0.0; td%dnx = 0.0; td%dnz = 0.0; td%dvx = 0.0; td%dvz = 0.0; td%snb = 0.0; td%earth = 0.0
        td%goxd = 0.0; td%gozd = 0.0; td%dvxd = 0.0; td%dvzd = 0.0; td%dnxd = 0.0; td%dnzd = 0.0
        td%drnx = 0.0; td%drnz = 0.0; td%gorx = 0.0; td%gorz = 0.0
        td%dnxr = 0.0; td%dnzr = 0.0; td%goxr = 0.0; td%gozr = 0.0
    end subroutine init_thread_data_scalar

    subroutine init_thread_data_matrix(td, max_nnx, max_nnz)
        type(ThreadData), intent(inout) :: td
        INTEGER, intent(in) :: max_nnx, max_nnz
        INTEGER :: maxbt

        maxbt = NINT(td%snb*max_nnx*max_nnz)
        ALLOCATE (td%velv(0:td%nvz + 1, 0:td%nvx + 1), &
                  td%veln(max_nnz, max_nnx), td%velnb(max_nnz, max_nnx), &
                  td%ttn(max_nnz, max_nnx), td%ttnr(max_nnz, max_nnx), & ! allocate memory to the traveltime field array
                  td%nsts(max_nnz, max_nnx), td%nstsr(max_nnz, max_nnx), & ! Allocate memory for node status and binary trees
                  td%btg(maxbt), STAT=t_checkstat) ! Allocate memory for binary trees
        IF (t_checkstat > 0) THEN
            WRITE (6, *) 'Error with ALLOCATE: PROGRAM fmmin2d: REAL velv veln ttn ttnr nsts nstsr btg'
        END IF
        td%velv = 0.0; td%veln = 0.0; td%velnb = 0.0; td%ttn = 0.0; td%ttnr = 0.0
        td%nsts = 0; td%nstsr = 0;
        td%ntr = 0
    end subroutine init_thread_data_matrix

    subroutine free_thread_data(td)
        type(ThreadData), intent(inout) :: td
        DEALLOCATE (td%velv, &
                    td%veln, td%velnb, &
                    td%ttn, td%ttnr, & ! allocate memory to the traveltime field array
                    td%nsts, td%nstsr, & ! Allocate memory for node status and binary trees
                    td%btg, STAT=t_checkstat) ! Allocate memory for binary trees
    end subroutine free_thread_data

END MODULE ThreadDataMod

module JaggedArrayMod
    implicit none
    
    type :: JaggedArrayReal
        real, pointer :: row(:) => null()
    end type JaggedArrayReal

    type :: JaggedArrayInt
        integer, pointer :: row(:) => null()
    end type JaggedArrayInt

    interface init_jagged_array
        module procedure init_jagged_array_real
        module procedure init_jagged_array_int
    end interface
    
    interface free_jagged_array
        module procedure free_jagged_array_real
        module procedure free_jagged_array_int
    end interface

    interface jagged_array_set_value
        module procedure jagged_array_set_value_real
        module procedure jagged_array_set_value_int
    end interface

    interface scale_jagged_array
        module procedure scale_jagged_array_real
        module procedure scale_jagged_array_int
    end interface

contains
    
    subroutine init_jagged_array_real(array, row_sizes)
        type(JaggedArrayReal), allocatable, intent(out) :: array(:)
        integer, intent(in) :: row_sizes(:)
        integer :: i, n
        
        n = size(row_sizes)
        allocate(array(n))
        
        do i = 1, n
            allocate(array(i)%row(row_sizes(i)))
            array(i)%row = 0.0
        end do
    end subroutine

    subroutine init_jagged_array_int(array, row_sizes)
        type(JaggedArrayInt), allocatable, intent(out) :: array(:)
        integer, intent(in) :: row_sizes(:)
        integer :: i, n
        
        n = size(row_sizes)
        allocate(array(n))
        
        do i = 1, n
            allocate(array(i)%row(row_sizes(i)))
            array(i)%row = 0.0
        end do
    end subroutine

    subroutine free_jagged_array_real(array)
        type(JaggedArrayReal), allocatable, intent(inout) :: array(:)
        integer :: i
        
        if (allocated(array)) then
            do i = 1, size(array)
                if (associated(array(i)%row)) then
                    deallocate(array(i)%row)
                end if
            end do
            deallocate(array)
        end if
    end subroutine

    subroutine free_jagged_array_int(array)
        type(JaggedArrayInt), allocatable, intent(inout) :: array(:)
        integer :: i
        
        if (allocated(array)) then
            do i = 1, size(array)
                if (associated(array(i)%row)) then
                    deallocate(array(i)%row)
                end if
            end do
            deallocate(array)
        end if
    end subroutine

    subroutine scale_jagged_array_real(array, row_idx, scale_factor)
        type(JaggedArrayReal), allocatable, intent(inout) :: array(:)
        integer, intent(in) :: row_idx
        real, intent(in), optional :: scale_factor

        integer :: scale_size
        real :: scale_factor_default
        real, pointer  :: new_array(:)

        scale_factor_default = 1.5
        if (present(scale_factor)) then
            scale_factor_default = 1 + scale_factor
        end if
        scale_size = NINT(scale_factor_default * size(array(row_idx)%row))
        if (scale_size == size(array(row_idx)%row)) scale_size = scale_size + 1
        print * , "scale real: row = ", row_idx, "src_size = ", size(array(row_idx)%row), "scale_size = ", scale_size
        allocate(new_array(scale_size))
        new_array(1:size(array(row_idx)%row)) = array(row_idx)%row
        deallocate(array(row_idx)%row)
        array(row_idx)%row => new_array
    end subroutine

    subroutine scale_jagged_array_int(array, row_idx, scale_factor)
        type(JaggedArrayInt), allocatable, intent(inout) :: array(:)
        integer, intent(in) :: row_idx
        real, intent(in), optional :: scale_factor

        integer :: scale_size
        real :: scale_factor_default
        integer, pointer  :: new_array(:)

        scale_factor_default = 1.5
        if (present(scale_factor)) then
            scale_factor_default = 1 + scale_factor
        end if
        scale_size = NINT(scale_factor_default * size(array(row_idx)%row))
        if (scale_size == size(array(row_idx)%row)) scale_size = scale_size + 1
        print * , "scale int: row = ", row_idx, "src_size = ", size(array(row_idx)%row), "scale_size = ", scale_size
        allocate(new_array(scale_size))
        new_array(1:size(array(row_idx)%row)) = array(row_idx)%row
        deallocate(array(row_idx)%row)
        array(row_idx)%row => new_array
    end subroutine

    subroutine jagged_array_set_value_real(array, row_idx, col_idx, val)
        type(JaggedArrayReal), allocatable, intent(inout) :: array(:)
        integer, intent(in) :: row_idx, col_idx
        real, intent(in) :: val
        if (col_idx >= 1 .and. col_idx <= size(array(row_idx)%row)) then
            array(row_idx)%row(col_idx) = val
        else
            call scale_jagged_array(array, row_idx)
            array(row_idx)%row(col_idx) = val
        end if
    end subroutine

    subroutine jagged_array_set_value_int(array, row_idx, col_idx, val)
        type(JaggedArrayInt), allocatable, intent(inout) :: array(:)
        integer, intent(in) :: row_idx, col_idx
        integer, intent(in) :: val
        if (col_idx >= 1 .and. col_idx <= size(array(row_idx)%row)) then
            array(row_idx)%row(col_idx) = val
        else
            call scale_jagged_array(array, row_idx)
            array(row_idx)%row(col_idx) = val
        end if        
    end subroutine

end module JaggedArrayMod

subroutine depthkernel_disba(nx, ny, nz, vel, pvRc, sen_vsRc, sen_vpRc, sen_rhoRc, &
                       iwave, igr, kmaxRc, tRc, depz, minthk)
    use omp_lib
    use BinaryIO
    use senK_Solver
    use ParallelConfig
    implicit none

    integer nx, ny, nz
    real vel(nx, ny, nz)

    integer kmaxRc
    real*8 tRc(kmaxRc)
    real*8 pvRc(nx*ny, kmaxRc)
    real*8 sen_vpRc(ny*nx, kmaxRc, nz), sen_vsRc(ny*nx, kmaxRc, nz), sen_rhoRc(ny*nx, kmaxRc, nz)

    integer iwave, igr
    real minthk
    real depz(nz)
    
    real vpz(nz), vsz(nz), rhoz(nz)
    integer mmax, iflsph, mode, rmax
    integer ii, jj, kk, i, j, k, m, n, nn
    integer, parameter::NL = 200
    integer, parameter::NP = 80
    real*8 cg1(NP), cg2(NP), cga, cgRc(NP)
    real rdep(NL), rvp(NL), rvs(NL), rrho(NL), rthk(NL)
    real depm(NL), vpm(NL), vsm(NL), rhom(NL), thkm(NL)
    real dlnVs, dlnVp, dlnrho

    call WriteArray_binary_3D(vel, "senK/vel_senK.bin")
    call WriteArray_binary_1D(tRc, "senK/tRc.bin", kmaxRc)
    call WriteArray_binary_1D(depz, "senK/depz.bin", nz)

    mmax = nz
    iflsph = 1
    mode = 1
    dlnVs = 0.01
    dlnVp = 0.01
    dlnrho = 0.01

    !$omp parallel num_threads(ThreadNum) &
    !$omp default(private) &
    !$omp shared(depz,nx,ny,nz,minthk,kmaxRc,mmax,vel) &
    !$omp shared(tRc,pvRc,iflsph,iwave,mode,igr)
    !$omp do collapse(2)
    do jj = 1, ny
        do ii = 1, nx
            vsz(1:nz) = vel(ii, jj, 1:nz)
            vpz = 0.9409 + 2.0947*vsz - 0.8206*vsz**2 +  0.2683*vsz**3 - 0.0251*vsz**4
            rhoz = 1.6612*vpz - 0.4721*vpz**2 + 0.0671*vpz**3 - 0.0043*vpz**4 + 0.000106*vpz**5
            call refineGrid2LayerMdl_parallel(minthk, mmax, depz, vpz, vsz, rhoz, rmax, rdep, rvp, rvs, rrho, rthk)
            call surfdisp96(rthk, rvp, rvs, rrho, rmax, iflsph, iwave, mode, igr, kmaxRc, tRc, cgRc)
            pvRc((jj - 1)*nx + ii, 1:kmaxRc) = cgRc(1:kmaxRc)
        end do
    end do
    !$omp end do
    !$omp end parallel

    call run_senK(minthk, nx, ny, nz, iwave, igr)
    call ReadArray_binary_3D("senK/sen_vp_disba.bin", sen_vpRc)
    call ReadArray_binary_3D("senK/sen_vs_disba.bin", sen_vsRc)
    call ReadArray_binary_3D("senK/sen_rho_disba.bin", sen_rhoRc)
end subroutine depthkernel_disba

subroutine depthkernel_parallel(nx, ny, nz, vel, pvRc, sen_vsRc, sen_vpRc, sen_rhoRc, &
                       iwave, igr, kmaxRc, tRc, depz, minthk)
    use omp_lib
    use BinaryIO
    use ParallelConfig
    implicit none

    integer nx, ny, nz
    real vel(nx, ny, nz)

    integer kmaxRc
    real*8 tRc(kmaxRc)
    real*8 pvRc(nx*ny, kmaxRc)
    real*8 sen_vpRc(ny*nx, kmaxRc, nz), sen_vsRc(ny*nx, kmaxRc, nz), sen_rhoRc(ny*nx, kmaxRc, nz)

    integer iwave, igr
    real minthk
    real depz(nz)

    real vpz(nz), vsz(nz), rhoz(nz)
    real*8 dlncg_dlnvs(kmaxRc, nz), dlncg_dlnvp(kmaxRc, nz), dlncg_dlnrho(kmaxRc, nz)
    integer mmax, iflsph, mode, rmax
    integer ii, jj, kk, i, j, k, m, n, nn
    integer, parameter::NL = 200
    integer, parameter::NP = 80
    real*8 cg1(NP), cg2(NP), cga, cgRc(NP)
    real rdep(NL), rvp(NL), rvs(NL), rrho(NL), rthk(NL)
    real depm(NL), vpm(NL), vsm(NL), rhom(NL), thkm(NL)
    real dlnVs, dlnVp, dlnrho
    ! ------------------- My Var start -------------------
    integer:: start_date(8), end_date(8)
    character(len = 100):: func_name
    real:: loop_use_time

    real vs(nz, ny, nx), vp(nz, ny, nx), rho(nz, ny, nx)
    integer all_ii(nx * ny * nz), all_jj(nx * ny * nz), all_kk(nx * ny * nz)
    integer loop_idx, loop_total_Num

    real, dimension(:, :, :, :, :), allocatable ::  rvp_batch, rvs_batch, rrho_batch, rthk_batch
    real*8, dimension(:, :, :, :, :), allocatable ::  cgRc_batch

    allocate (rvp_batch(NL, 6, nz, ny, nx), rvs_batch(NL, 6, nz, ny, nx), rrho_batch(NL, 6, nz, ny, nx))
    allocate (cgRc_batch(NP, 6, nz, ny, nx))
 
    vs = reshape(vel, [nz, ny, nx], order = [3, 2, 1])
    vp = 0.9409 + 2.0947*vs - 0.8206*vs**2 +  0.2683*vs**3 - 0.0251*vs**4
    rho = 1.6612*vp - 0.4721*vp**2 + 0.0671*vp**3 - 0.0043*vp**4 + 0.000106*vp**5
    ! ------------------- My Var end -------------------
  
    mmax = nz
    iflsph = 1
    mode = 1 
    dlnVs = 0.01
    dlnVp = 0.01
    dlnrho = 0.01

    !$omp parallel num_threads(ThreadNum) &
    !$omp default(None) &
    !$omp shared(depz,nx,ny,nz,minthk,dlnVs,dlnVp,dlnrho,kmaxRc,mmax,vel,vp,vs,rho) &
    !$omp shared(sen_vpRc,sen_vsRc,sen_rhoRc,tRc,pvRc,iflsph,iwave,mode,igr) &
    !$omp shared(rvp_batch,rvs_batch,rrho_batch,rthk_batch,cgRc_batch) &
    !$omp private(ii, jj, kk, i, m) &
    !$omp private(vpz, vsz, rhoz, rmax, rdep, rvp, rvs, rrho, rthk, cgRc) &
    !$omp private(vpm, vsm, rhom, depm, thkm)
    
    !$omp do collapse(2)
    do ii = 1, nx
        do jj = 1, ny
            vsz(1:nz) = vs(1:nz, jj, ii)
            vpz(1:nz) = vp(1:nz, jj, ii) 
            rhoz(1:nz) = rho(1:nz, jj, ii) 

            call refineGrid2LayerMdl_parallel(minthk, mmax, depz, vpz, vsz, rhoz, rmax, rdep, rvp, rvs, rrho, rthk)
            call surfdisp96(rthk, rvp, rvs, rrho, rmax, iflsph, iwave, mode, igr, kmaxRc, tRc, cgRc)
            pvRc((jj - 1)*nx + ii, 1:kmaxRc) = cgRc(1:kmaxRc)

            do kk = 1, mmax - 1
                depm(kk) = depz(kk)
                vsm(kk) = vsz(kk)
                vpm(kk) = vpz(kk)
                thkm(kk) = depz(kk + 1) - depz(kk)
                rhom(kk) = rhoz(kk)
            end do
            ! half space
            depm(mmax) = depz(mmax)
            vsm(mmax) = vsz(mmax)
            vpm(mmax) = vpz(mmax)
            rhom(mmax) = rhoz(mmax)
            thkm(mmax) = 0.0
            ! calculate sensitivity kernel
            do i = 1, mmax
                vsm(i) = vsz(i) - 0.5*dlnVs*vsz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 1, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 1, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 1, i, jj, ii) = rrho(1:rmax)

                vsm(i) = vsz(i) + 0.5*dlnVs*vsz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 2, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 2, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 2, i, jj, ii) = rrho(1:rmax)

                vsm(i) = vsz(i)

                vpm(i) = vpz(i) - 0.5*dlnVp*vpz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 3, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 3, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 3, i, jj, ii) = rrho(1:rmax)

                vpm(i) = vpz(i) + 0.5*dlnVp*vpz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 4, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 4, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 4, i, jj, ii) = rrho(1:rmax)
    
                vpm(i) = vpz(i)

                rhom(i) = rhoz(i) - 0.5*dlnrho*rhoz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 5, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 5, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 5, i, jj, ii) = rrho(1:rmax)
    
                rhom(i) = rhoz(i) + 0.5*dlnrho*rhoz(i)
                call refineGrid2LayerMdl_parallel(minthk, mmax, depm, vpm, vsm, rhom, rmax, rdep, rvp, rvs, rrho, rthk)
                rvp_batch(1:rmax, 6, i, jj, ii) = rvp(1:rmax)
                rvs_batch(1:rmax, 6, i, jj, ii) = rvs(1:rmax)
                rrho_batch(1:rmax, 6, i, jj, ii) = rrho(1:rmax)
    
                rhom(i) = rhoz(i)
            end do
        end do
    end do
    !$omp end do

    !$omp do collapse(3)
    do ii = 1, nx
        do jj = 1, ny  
        do kk = 1, nz
        do m = 1, 6
            call surfdisp96(rthk, rvp_batch(:, m, kk, jj, ii), rvs_batch(:, m, kk, jj, ii), rrho_batch(:, m, kk, jj, ii), &
             rmax, iflsph, iwave, mode, igr, kmaxRc, tRc, cgRc_batch(:, m, kk, jj, ii))
        end do
        end do
        end do
    end do
    !$omp end do

    !$omp do collapse(3)
    do ii = 1, nx
        do jj = 1, ny
        do kk = 1, nz  
            sen_vsRc((jj - 1) * nx + ii, :, kk) = &
            (cgRc_batch(1:kmaxRc, 2, kk, jj, ii) - cgRc_batch(1:kmaxRc, 1, kk, jj, ii)) / (dlnVs * vs(kk, jj, ii))
            
            sen_vpRc((jj - 1) * nx + ii, :, kk) = &
            (cgRc_batch(1:kmaxRc, 4, kk, jj, ii) - cgRc_batch(1:kmaxRc, 3, kk, jj, ii)) / (dlnVp * vp(kk, jj, ii))
        
            sen_rhoRc((jj - 1) * nx + ii, :, kk) = &
            (cgRc_batch(1:kmaxRc, 6, kk, jj, ii) - cgRc_batch(1:kmaxRc, 5, kk, jj, ii)) / (dlnrho * rho(kk, jj, ii))
        end do 
        end do           
    end do
    !$omp end do

    !$omp end parallel
end subroutine depthkernel_parallel



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: MODULE
! CODE: FORTRAN 90
! This module contains all the subroutines used to calculate
! the first-arrival traveltime field through the grid.
! Subroutines are:
! (1) travel
! (2) fouds1
! (3) fouds2
! (4) addtree
! (5) downtree
! (6) updtree
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
MODULE traveltime_parallel
    USE Utils
    USE ThreadDataMod
    implicit none

    ! btg = backpointer to relate grid nodes to binary tree entries
    ! px = grid-point in x
    ! pz = grid-point in z
    ! ntr = number of entries in binary tree
CONTAINS

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine is passed the location of a source, and from
    ! this point the first-arrival traveltime field through the
    ! velocity grid is determined.
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE travel_parallel(scx, scz, urg, td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: isx, isz, sw, i, j, ix, iz, urg, swrg
        INTEGER :: loop_idx
        REAL(KIND=t_i10) :: scx, scz, vsrc, dsx, dsz, ds
        REAL(KIND=t_i10), DIMENSION(2, 2) :: vss
        ! isx,isz = grid cell indices (i,j,k) which contains source
        ! scx,scz = (r,x,y) location of source
        ! sw = a switch (0=off,1=on)
        ! ix,iz = j,k position of "close" point with minimum traveltime
        ! maxbt = maximum size of narrow band binary tree
        ! rd2,rd3 = substitution variables
        ! vsrc = velocity at source
        ! vss = velocity at nodes surrounding source
        ! dsx, dsz = distance from source to cell boundary in x and z
        ! ds = distance from source to nearby node
        ! urg = use refined grid (0=no,1=yes,2=previously used)
        ! swrg = switch to end refined source grid computation
        !
        ! The first step is to find out where the source resides
        ! in the grid of nodes. The cell in which it resides is
        ! identified by the "north-west" node of the cell. If the
        ! source lies on the edge or corner (a node) of the cell, then
        ! this scheme still applies.
        !
        loop_idx = 0
        isx = INT((scx - td%gox)/td%dnx) + 1
        isz = INT((scz - td%goz)/td%dnz) + 1

        sw = 0
        IF (isx .lt. 1 .or. isx .gt. td%nnx) sw = 1
        IF (isz .lt. 1 .or. isz .gt. td%nnz) sw = 1
        IF (sw .eq. 1) then
            scx = 90.0 - scx*180.0/td%pi
            scz = scz*180.0/td%pi
            WRITE (6, *) "travel_P: " // " Iteration " // ts(td%tid) // &
                        " Source lies outside bounds of model (lat, long)= ", ts(scx), ", ", ts(scz)
            WRITE (6, *) "TERMINATING PROGRAM!!!"
            STOP
        END IF
        IF (isx .eq. td%nnx) isx = isx - 1
        IF (isz .eq. td%nnz) isz = isz - 1
        !
        ! Set all values of nsts to -1 if beginning from a source
        ! point.
        !
        IF (urg .NE. 2) td%nsts = -1
        !
        ! set initial size of binary tree to zero
        !
        td%ntr = 0
        IF (urg .EQ. 2) THEN
            !
            !  In this case, source grid refinement has been applied, so
            !  the initial narrow band will come from resampling the
            !  refined grid.
            !
            DO i = 1, td%nnx
                DO j = 1, td%nnz
                    IF (td%nsts(j, i) .GT. 0) THEN
                        CALL addtree_parallel(j, i, td)
                    END IF
                END DO
            END DO
        ELSE
            !
            !  In general, the source point need not lie on a grid point.
            !  Bi-linear interpolation is used to find velocity at the
            !  source point.
            !
            td%nsts = -1
            DO i = 1, 2
                DO j = 1, 2
                    vss(i, j) = td%veln(isz - 1 + j, isx - 1 + i)
                END DO
            END DO
            dsx = (scx - td%gox) - (isx - 1)*td%dnx
            dsz = (scz - td%goz) - (isz - 1)*td%dnz
            CALL bilinear_parallel(vss, dsx, dsz, vsrc, td)
            !
            !  Now find the traveltime at the four surrounding grid points. This
            !  is calculated approximately by assuming the traveltime from the
            !  source point to each node is equal to the the distance between
            !  the two points divided by the average velocity of the points
            !
            DO i = 1, 2
                DO j = 1, 2
                    ds = SQRT((dsx - (i - 1)*td%dnx)**2 + (dsz - (j - 1)*td%dnz)**2)
                    td%ttn(isz - 1 + j, isx - 1 + i) = 2.0*ds/(vss(i, j) + vsrc)
                    CALL addtree_parallel(isz - 1 + j, isx - 1 + i, td)
                END DO
            END DO
        END IF
        !
        ! Now calculate the first-arrival traveltimes at the
        ! remaining grid points. This is done via a loop which
        ! repeats the procedure of finding the first-arrival
        ! of all "close" points, adding it to the set of "alive"
        ! points and updating the points surrounding the new "alive"
        ! point. The process ceases when the binary tree is empty,
        ! in which case all grid points are "alive".
        !
        DO WHILE (td%ntr .gt. 0)
            loop_idx = loop_idx + 1
            !
            ! First, check whether source grid refinement is
            ! being applied; if so, then there is a special
            ! exit condition.
            !
            IF (urg .EQ. 1) THEN
                ix = td%btg(1)%px
                iz = td%btg(1)%pz
                swrg = 0
                IF (ix .EQ. 1) THEN
                    IF (td%vnl .NE. 1) swrg = 1
                END IF
                IF (ix .EQ. td%nnx) THEN
                    IF (td%vnr .NE. td%nnx) swrg = 1
                END IF
                IF (iz .EQ. 1) THEN
                    IF (td%vnt .NE. 1) swrg = 1
                END IF
                IF (iz .EQ. td%nnz) THEN
                    IF (td%vnb .NE. td%nnz) swrg = 1
                END IF
                IF (swrg .EQ. 1) THEN
                    td%nsts(iz, ix) = 0
                    EXIT
                END IF
            END IF
            !
            ! Set the "close" point with minimum traveltime
            ! to "alive"
            !
            ix = td%btg(1)%px
            iz = td%btg(1)%pz
            td%nsts(iz, ix) = 0
            !
            ! Update the binary tree by removing the root and
            ! sweeping down the tree.
            !
            CALL downtree_parallel(td)
            !
            ! Now update or find values of up to four grid points
            ! that surround the new "alive" point.
            !
            ! Test points that vary in x
            !
            DO i = ix - 1, ix + 1, 2
                IF (i .ge. 1 .and. i .le. td%nnx) THEN
                    IF (td%nsts(iz, i) .eq. -1) THEN
                        !
                        ! This option occurs when a far point is added to the list
                        ! of "close" points
                        !
                        IF (td%fom .eq. 0) THEN
                            CALL fouds1_parallel(iz, i, td)
                        ELSE
                            CALL fouds2_parallel(iz, i, td)
                        END IF
                        CALL addtree_parallel(iz, i, td)
                    ELSE IF (td%nsts(iz, i) .gt. 0) THEN
                        !
                        ! This happens when a "close" point is updated
                        !
                        IF (td%fom .eq. 0) THEN
                            CALL fouds1_parallel(iz, i, td)
                        ELSE
                            CALL fouds2_parallel(iz, i, td)
                        END IF
                        CALL updtree_parallel(iz, i, td)
                    END IF
                END IF
            END DO
            !
            ! Test points that vary in z
            !
            DO i = iz - 1, iz + 1, 2
                IF (i .ge. 1 .and. i .le. td%nnz) THEN
                    IF (td%nsts(i, ix) .eq. -1) THEN
                        !
                        ! This option occurs when a far point is added to the list
                        ! of "close" points
                        !
                        IF (td%fom .eq. 0) THEN
                            CALL fouds1_parallel(i, ix, td)
                        ELSE
                            CALL fouds2_parallel(i, ix, td)
                        END IF
                        CALL addtree_parallel(i, ix, td)
                    ELSE IF (td%nsts(i, ix) .gt. 0) THEN
                        !
                        ! This happens when a "close" point is updated
                        !
                        IF (td%fom .eq. 0) THEN
                            CALL fouds1_parallel(i, ix, td)
                        ELSE
                            CALL fouds2_parallel(i, ix, td)
                        END IF
                        CALL updtree_parallel(i, ix, td)
                    END IF
                END IF
            END DO
        END DO
    END SUBROUTINE travel_parallel

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine calculates a trial first-arrival traveltime
    ! at a given node from surrounding nodes using the
    ! First-Order Upwind Difference Scheme (FOUDS) of
    ! Sethian and Popovici (1999).
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE fouds1_parallel(iz, ix, td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: j, k, ix, iz, tsw1, swsol
        REAL(KIND=t_i10) :: trav, travm, slown, tdsh, tref
        REAL(KIND=t_i10) :: a, b, c, u, v, em, ri, risti
        REAL(KIND=t_i10) :: rd1
        !
        ! ix = NS position of node coordinate for determination
        ! iz = EW vertical position of node coordinate for determination
        ! trav = traveltime calculated for trial node
        ! travm = minimum traveltime calculated for trial node
        ! slown = slowness at (iz,ix)
        ! tsw1 = traveltime switch (0=first time,1=previously)
        ! a,b,c,u,v,em = Convenience variables for solving quadratic
        ! tdsh = local traveltime from neighbouring node
        ! tref = reference traveltime at neighbouring node
        ! ri = Radial distance
        ! risti = ri*sin(theta) at point (iz,ix)
        ! rd1 = dummy variable
        ! swsol = switch for solution (0=no solution, 1=solution)
        !
        ! Inspect each of the four quadrants for the minimum time
        ! solution.
        !
        tsw1 = 0
        slown = 1.0/td%veln(iz, ix)
        ri = td%earth
        risti = ri*sin(td%gox + (ix - 1)*td%dnx)
        DO j = ix - 1, ix + 1, 2
            DO k = iz - 1, iz + 1, 2
                IF (j .GE. 1 .AND. j .LE. td%nnx) THEN
                    IF (k .GE. 1 .AND. k .LE. td%nnz) THEN
                        !
                        ! There are seven solution options in
                        ! each quadrant.
                        !
                        swsol = 0
                        IF (td%nsts(iz, j) .EQ. 0) THEN
                            swsol = 1
                            IF (td%nsts(k, ix) .EQ. 0) THEN
                                u = ri*td%dnx
                                v = risti*td%dnz
                                em = td%ttn(k, ix) - td%ttn(iz, j)
                                a = u**2 + v**2
                                b = -2.0*u**2*em
                                c = u**2*(em**2 - v**2*slown**2)
                                tref = td%ttn(iz, j)
                            ELSE
                                a = 1.0
                                b = 0.0
                                c = -slown**2*ri**2*td%dnx**2
                                tref = td%ttn(iz, j)
                            END IF
                        ELSE IF (td%nsts(k, ix) .EQ. 0) THEN
                            swsol = 1
                            a = 1.0
                            b = 0.0
                            c = -(slown*risti*td%dnz)**2
                            tref = td%ttn(k, ix)
                        END IF
                        !
                        ! Now find the solution of the quadratic equation
                        !
                        IF (swsol .EQ. 1) THEN
                            rd1 = b**2 - 4.0*a*c
                            IF (rd1 .LT. 0.0) rd1 = 0.0
                            tdsh = (-b + sqrt(rd1))/(2.0*a)
                            trav = tref + tdsh
                            IF (tsw1 .EQ. 1) THEN
                                travm = MIN(trav, travm)
                            ELSE
                                travm = trav
                                tsw1 = 1
                            END IF
                        END IF
                    END IF
                END IF
            END DO
        END DO
        td%ttn(iz, ix) = travm
    END SUBROUTINE fouds1_parallel

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine calculates a trial first-arrival traveltime
    ! at a given node from surrounding nodes using the
    ! Mixed-Order (2nd) Upwind Difference Scheme (FOUDS) of
    ! Popovici and Sethian (2002).
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE fouds2_parallel(iz, ix, td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: j, k, j2, k2, ix, iz, tsw1
        INTEGER :: swj, swk, swsol
        REAL(KIND=t_i10) :: trav, travm, slown, tdsh, tref, tdiv
        REAL(KIND=t_i10) :: a, b, c, u, v, em, ri, risti, rd1
        !
        ! ix = NS position of node coordinate for determination
        ! iz = EW vertical position of node coordinate for determination
        ! trav = traveltime calculated for trial node
        ! travm = minimum traveltime calculated for trial node
        ! slown = slowness at (iz,ix)
        ! tsw1 = traveltime switch (0=first time,1=previously)
        ! a,b,c,u,v,em = Convenience variables for solving quadratic
        ! tdsh = local traveltime from neighbouring node
        ! tref = reference traveltime at neighbouring node
        ! ri = Radial distance
        ! risti = ri*sin(theta) at point (iz,ix)
        ! swj,swk = switches for second order operators
        ! tdiv = term to divide tref by depending on operator order
        ! swsol = switch for solution (0=no solution, 1=solution)
        !
        ! Inspect each of the four quadrants for the minimum time solution.
        !
        tsw1 = 0
        slown = 1.0/td%veln(iz, ix)
        ri = td%earth
        risti = ri*sin(td%gox + (ix - 1)*td%dnx)
        DO j = ix - 1, ix + 1, 2
            IF (j .GE. 1 .AND. j .LE. td%nnx) THEN
                swj = -1
                IF (j .eq. ix - 1) THEN
                    j2 = j - 1
                    IF (j2 .GE. 1) THEN
                        IF (td%nsts(iz, j2) .EQ. 0) swj = 0
                    END IF
                ELSE
                    j2 = j + 1
                    IF (j2 .LE. td%nnx) THEN
                        IF (td%nsts(iz, j2) .EQ. 0) swj = 0
                    END IF
                END IF
                IF (td%nsts(iz, j) .EQ. 0 .AND. swj .EQ. 0) THEN
                    swj = -1
                    IF (td%ttn(iz, j) .GT. td%ttn(iz, j2)) THEN
                        swj = 0
                    END IF
                ELSE
                    swj = -1
                END IF
                DO k = iz - 1, iz + 1, 2
                    IF (k .GE. 1 .AND. k .LE. td%nnz) THEN
                        swk = -1
                        IF (k .eq. iz - 1) THEN
                            k2 = k - 1
                            IF (k2 .GE. 1) THEN
                                IF (td%nsts(k2, ix) .EQ. 0) swk = 0
                            END IF
                        ELSE
                            k2 = k + 1
                            IF (k2 .LE. td%nnz) THEN
                                IF (td%nsts(k2, ix) .EQ. 0) swk = 0
                            END IF
                        END IF
                        IF (td%nsts(k, ix) .EQ. 0 .AND. swk .EQ. 0) THEN
                            swk = -1
                            IF (td%ttn(k, ix) .GT. td%ttn(k2, ix)) THEN
                                swk = 0
                            END IF
                        ELSE
                            swk = -1
                        END IF
                        !
                        ! There are 8 solution options in each quadrant.
                        ! 
                        swsol = 0
                        IF (swj .EQ. 0) THEN
                            swsol = 1
                            IF (swk .EQ. 0) THEN
                                u = 2.0*ri*td%dnx
                                v = 2.0*risti*td%dnz
                                em = 4.0*td%ttn(iz, j) - td%ttn(iz, j2) - 4.0*td%ttn(k, ix)
                                em = em + td%ttn(k2, ix)
                                a = v**2 + u**2
                                b = 2.0*em*u**2
                                c = u**2*(em**2 - slown**2*v**2)
                                tref = 4.0*td%ttn(iz, j) - td%ttn(iz, j2)
                                tdiv = 3.0
                            ELSE IF (td%nsts(k, ix) .EQ. 0) THEN
                                u = risti*td%dnz
                                v = 2.0*ri*td%dnx
                                em = 3.0*td%ttn(k, ix) - 4.0*td%ttn(iz, j) + td%ttn(iz, j2)
                                a = v**2 + 9.0*u**2
                                b = 6.0*em*u**2
                                c = u**2*(em**2 - slown**2*v**2)
                                tref = td%ttn(k, ix)
                                tdiv = 1.0
                            ELSE
                                u = 2.0*ri*td%dnx
                                a = 1.0
                                b = 0.0
                                c = -u**2*slown**2
                                tref = 4.0*td%ttn(iz, j) - td%ttn(iz, j2)
                                tdiv = 3.0
                            END IF
                        ELSE IF (td%nsts(iz, j) .EQ. 0) THEN
                            swsol = 1
                            IF (swk .EQ. 0) THEN
                                u = ri*td%dnx
                                v = 2.0*risti*td%dnz
                                em = 3.0*td%ttn(iz, j) - 4.0*td%ttn(k, ix) + td%ttn(k2, ix)
                                a = v**2 + 9.0*u**2
                                b = 6.0*em*u**2
                                c = u**2*(em**2 - v**2*slown**2)
                                tref = td%ttn(iz, j)
                                tdiv = 1.0
                            ELSE IF (td%nsts(k, ix) .EQ. 0) THEN
                                u = ri*td%dnx
                                v = risti*td%dnz
                                em = td%ttn(k, ix) - td%ttn(iz, j)
                                a = u**2 + v**2
                                b = -2.0*u**2*em
                                c = u**2*(em**2 - v**2*slown**2)
                                tref = td%ttn(iz, j)
                                tdiv = 1.0
                            ELSE
                                a = 1.0
                                b = 0.0
                                c = -slown**2*ri**2*td%dnx**2
                                tref = td%ttn(iz, j)
                                tdiv = 1.0
                            END IF
                        ELSE
                            IF (swk .EQ. 0) THEN
                                swsol = 1
                                u = 2.0*risti*td%dnz
                                a = 1.0
                                b = 0.0
                                c = -u**2*slown**2
                                tref = 4.0*td%ttn(k, ix) - td%ttn(k2, ix)
                                tdiv = 3.0
                            ELSE IF (td%nsts(k, ix) .EQ. 0) THEN
                                swsol = 1
                                a = 1.0
                                b = 0.0
                                c = -slown**2*risti**2*td%dnz**2
                                tref = td%ttn(k, ix)
                                tdiv = 1.0
                            END IF
                        END IF
                        !
                        !           Now find the solution of the quadratic equation
                        !
                        IF (swsol .EQ. 1) THEN
                            rd1 = b**2 - 4.0*a*c
                            IF (rd1 .LT. 0.0) rd1 = 0.0
                            tdsh = (-b + sqrt(rd1))/(2.0*a)
                            trav = (tref + tdsh)/tdiv
                            IF (tsw1 .EQ. 1) THEN
                                travm = MIN(trav, travm)
                            ELSE
                                travm = trav
                                tsw1 = 1
                            END IF
                        END IF
                    END IF
                END DO
            END IF
        END DO
        td%ttn(iz, ix) = travm
    END SUBROUTINE fouds2_parallel

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine adds a value to the binary tree by
    ! placing a value at the bottom and pushing it up
    ! to its correct position.
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE addtree_parallel(iz, ix, td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: ix, iz, tpp, tpc
        TYPE(t_backpointer) :: exch
        !
        ! ix,iz = grid position of new addition to tree
        ! tpp = tree position of parent
        ! tpc = tree position of child
        ! exch = dummy to exchange btg values
        !
        ! First, increase the size of the tree by one.
        !
        td%ntr = td%ntr + 1
        !
        ! Put new value at base of tree
        !
        td%nsts(iz, ix) = td%ntr
        td%btg(td%ntr)%px = ix
        td%btg(td%ntr)%pz = iz
        !
        ! Now filter the new value up to its correct position
        !
        tpc = td%ntr
        tpp = tpc/2
        DO WHILE (tpp .gt. 0)
            IF (td%ttn(iz, ix) .lt. td%ttn(td%btg(tpp)%pz, td%btg(tpp)%px)) THEN
                td%nsts(iz, ix) = tpp
                td%nsts(td%btg(tpp)%pz, td%btg(tpp)%px) = tpc
                exch = td%btg(tpc)
                td%btg(tpc) = td%btg(tpp)
                td%btg(tpp) = exch
                tpc = tpp
                tpp = tpc/2
            ELSE
                tpp = 0
            END IF
        END DO
    END SUBROUTINE addtree_parallel

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine updates the binary tree after the root
    ! value has been used. The root is replaced by the value
    ! at the bottom of the tree, which is then filtered down
    ! to its correct position. This ensures that the tree remains
    ! balanced.
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE downtree_parallel(td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: tpp, tpc
        REAL(KIND=t_i10) :: rd1, rd2
        TYPE(t_backpointer) :: exch
        !
        ! tpp = tree position of parent
        ! tpc = tree position of child
        ! exch = dummy to exchange btg values
        ! rd1,rd2 = substitution variables
        !
        ! Replace root of tree with its last value
        !
        IF (td%ntr .EQ. 1) THEN
            td%ntr = td%ntr - 1
            RETURN
        END IF
        td%nsts(td%btg(td%ntr)%pz, td%btg(td%ntr)%px) = 1
        td%btg(1) = td%btg(td%ntr)
        !
        ! Reduce size of tree by one
        !
        td%ntr = td%ntr - 1
        !
        ! Now filter new root down to its correct position
        !
        tpp = 1
        tpc = 2*tpp
        DO WHILE (tpc .lt. td%ntr)
            !
            ! Check which of the two children is smallest - use the smallest
            !
            rd1 = td%ttn(td%btg(tpc)%pz, td%btg(tpc)%px)
            rd2 = td%ttn(td%btg(tpc + 1)%pz, td%btg(tpc + 1)%px)
            IF (rd1 .gt. rd2) THEN
                tpc = tpc + 1
            END IF
            !
            !  Check whether the child is smaller than the parent; if so, then swap,
            !  if not, then we are done
            !
            rd1 = td%ttn(td%btg(tpc)%pz, td%btg(tpc)%px)
            rd2 = td%ttn(td%btg(tpp)%pz, td%btg(tpp)%px)
            IF (rd1 .lt. rd2) THEN
                td%nsts(td%btg(tpp)%pz, td%btg(tpp)%px) = tpc
                td%nsts(td%btg(tpc)%pz, td%btg(tpc)%px) = tpp
                exch = td%btg(tpc)
                td%btg(tpc) = td%btg(tpp)
                td%btg(tpp) = exch
                tpp = tpc
                tpc = 2*tpp
            ELSE
                tpc = td%ntr + 1
            END IF
        END DO
        !
        ! If ntr is an even number, then we still have one more test to do
        !
        IF (tpc .eq. td%ntr) THEN
            rd1 = td%ttn(td%btg(tpc)%pz, td%btg(tpc)%px)
            rd2 = td%ttn(td%btg(tpp)%pz, td%btg(tpp)%px)
            IF (rd1 .lt. rd2) THEN
                td%nsts(td%btg(tpp)%pz, td%btg(tpp)%px) = tpc
                td%nsts(td%btg(tpc)%pz, td%btg(tpc)%px) = tpp
                exch = td%btg(tpc)
                td%btg(tpc) = td%btg(tpp)
                td%btg(tpp) = exch
            END IF
        END IF
    END SUBROUTINE downtree_parallel

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! TYPE: SUBROUTINE
    ! CODE: FORTRAN 90
    ! This subroutine updates a value on the binary tree. The FMM
    ! should only produce updated values that are less than their
    ! prior values.
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    SUBROUTINE updtree_parallel(iz, ix, td)
        IMPLICIT NONE
        TYPE(ThreadData) :: td
        INTEGER :: ix, iz, tpp, tpc
        TYPE(t_backpointer) :: exch
        !
        ! ix,iz = grid position of new addition to tree
        ! tpp = tree position of parent
        ! tpc = tree position of child
        ! exch = dummy to exchange btg values
        !
        ! Filter the updated value to its correct position
        !
        tpc = td%nsts(iz, ix)
        tpp = tpc/2
        DO WHILE (tpp .gt. 0)
            IF (td%ttn(iz, ix) .lt. td%ttn(td%btg(tpp)%pz, td%btg(tpp)%px)) THEN
                td%nsts(iz, ix) = tpp
                td%nsts(td%btg(tpp)%pz, td%btg(tpp)%px) = tpc
                exch = td%btg(tpc)
                td%btg(tpc) = td%btg(tpp)
                td%btg(tpp) = exch
                tpc = tpp
                tpp = tpc/2
            ELSE
                tpp = 0
            END IF
        END DO
    END SUBROUTINE updtree_parallel

END MODULE traveltime_parallel

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! MAIN PROGRAM
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: PROGRAM
! CODE: FORTRAN 90
! This program is designed to implement the Fast Marching
! Method (FMM) for calculating first-arrival traveltimes
! through a 2-D continuous velocity medium in spherical shell
! coordinates (x=theta or latitude, z=phi or longitude).
! It is written in Fortran 90, although it is probably more
! accurately  described as Fortran 77 with some of the Fortran 90
! extensions.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!PROGRAM tomo_surf


subroutine CalSurfG_parallel(nx, ny, nz, nparpi, vels, iw, rw, col, dsurf, &
                             goxdf, gozdf, dvxdf, dvzdf, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                             tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                             scxf, sczf, rcxf, rczf, nrc1, nsrcsurf1, kmax, nsrcsurf, nrcf, &
                             nar)

    use omp_lib
    use traveltime_parallel
    use ThreadDataMod
    use JaggedArrayMod
    use ParallelConfig
    use BinaryIO,only: WriteArray_binary_1D
    implicit none

    ! CHARACTER (LEN=30) ::grid,frechet
    ! CHARACTER (LEN=40) :: sources,receivers,otimes
    ! CHARACTER (LEN=30) :: travelt,rtravel,wrays,cdum
    INTEGER :: i, j, k, l, nsrc, tnr, urg
    INTEGER :: ogx, ogz, grdfx, grdfz, maxbt
    ! INTEGER :: sgs, isx, isz, sw, idm1, idm2, nnxb, nnzb
    ! REAL(KIND=t_i10) :: x, z, goxb, gozb, dnxb, dnzb
    INTEGER :: isx, isz, sw, idm1, idm2
    REAL(KIND=t_i10) :: x, z
    ! INTEGER :: sgs, nnxb, nnzb
    ! REAL(KIND=t_i10) :: goxb, gozb, dnxb, dnzb
    ! REAL(KIND=t_i10), DIMENSION (:,:), ALLOCATABLE :: scxf, sczf
    ! REAL(KIND=t_i10), DIMENSION (:,:,:), ALLOCATABLE :: rcxf, rczf
    !
    ! sources = File containing source locations
    ! receivers = File containing receiver locations
    ! grid = File containing grid of velocity vertices for
    !        resampling on a finer grid with cubic B-splines
    ! frechet = output file containing matrix of frechet derivatives
    ! travelt = File name for storage of traveltime field
    ! wttf = Write traveltimes to file? (0=no,>0=source id)
    ! fom = Use first-order(0) or mixed-order(1) scheme
    ! nsrc = number of sources
    ! scx,scz = source location in r,x,z
    ! scx,scz = source location in r,x,z
    ! x,z = temporary variables for source location
    ! fsrt = find source-receiver traveltimes? (0=no,1=yes)
    ! rtravel = output file for source-receiver traveltimes
    ! cdum = dummy character variable ! wrgf = write ray geometries to file? (<0=all,0=no,>0=source id.)
    ! wrays = file containing raypath geometries
    ! cfd = calculate Frechet derivatives? (0=no, 1=yes)
    ! tnr = total number of receivers
    ! sgs = Extent of refined source grid
    ! isx,isz = cell containing source
    ! nnxb,nnzb = Backup for nnz,nnx
    ! goxb,gozb = Backup for gox,goz
    ! dnxb,dnzb = Backup for dnx,dnz
    ! ogx,ogz = Location of refined grid origin
    ! gridfx,grdfz = Number of refined nodes per cell
    ! urg = use refined grid (0=no,1=yes,2=previously used)
    ! maxbt = maximum size of narrow band binary tree
    ! otimes = file containing source-receiver association information
    ! -----------------------------------------------------------------
    ! -------- My VARIABLE --------
    integer :: start_date(8), end_date(8)
    integer :: start_date_loop(8), end_date_loop(8)
    integer :: start_date_travel(8), end_date_travel(8)
    integer :: start_date_rpath(8), end_date_rpath(8)
    integer :: start_date_srtimes(8), end_date_srtimes(8)

    CHARACTER(LEN=100) :: func_name
    integer :: loop_idx, loop_total_Num, loop_cnt
    integer :: max_nnx, max_nnz
    integer :: G_row_nar

    real:: loop_use_time, travel_total_time, rpath_total_time, srtimes_total_time

    integer, dimension(:), allocatable:: knumi_list, srcnum_list
    integer, dimension(:), allocatable:: all_count1, all_count11, all_row_size, all_nar, all_nar1
    integer, dimension(:), allocatable:: single_G_row_size, all_G_row_count
    real, dimension(:, :, :), allocatable:: all_row
    type(JaggedArrayReal), allocatable :: all_cbst(:), all_rw(:)
    type(JaggedArrayInt), allocatable ::  all_iw(:), all_col(:)

    type(JaggedArrayInt), allocatable ::  single_G_row_count(:)

    TYPE(ThreadData) :: td
    TYPE(ThreadData) :: g_td
    ! -------- My VARIABLE --------

    !        variables defined by Hongjian Fang
    integer nx, ny, nz
    integer kmax, nsrcsurf, nrcf
    real vels(nx, ny, nz)
    real rw(*)
    integer iw(*), col(*)
    real dsurf(*)
    real goxdf, gozdf, dvxdf, dvzdf
    integer kmaxRc, kmaxRg, kmaxLc, kmaxLg
    real*8 tRc(*), tRg(*), tLc(*), tLg(*)
    integer wavetype(nsrcsurf, kmax)
    integer periods(nsrcsurf, kmax), nrc1(nsrcsurf, kmax), nsrcsurf1(kmax)
    integer igrt(nsrcsurf, kmax)
    real scxf(nsrcsurf, kmax), sczf(nsrcsurf, kmax), rcxf(nrcf, nsrcsurf, kmax), rczf(nrcf, nsrcsurf, kmax)
    integer nar
    real minthk
    integer nparpi

    real vpz(nz), vsz(nz), rhoz(nz), depz(nz)
    real(8) ,dimension(:, :, :), allocatable:: sen_vsRc, sen_vpRc, sen_rhoRc
    real(8) ,dimension(:, :, :), allocatable:: sen_vsRg, sen_vpRg, sen_rhoRg
    real(8) ,dimension(:, :, :), allocatable:: sen_vsLc, sen_vpLc, sen_rhoLc
    real(8) ,dimension(:, :, :), allocatable:: sen_vsLg, sen_vpLg, sen_rhoLg
    real(8) ,dimension(:, :, :), allocatable:: sen_vs, sen_vp, sen_rho
    real(8) ,dimension(:, :), allocatable:: pvRc, pvRg, pvLc, pvLg

    real*8 velf(ny*nx), velf0(ny*nx)
    real coe_rho(nz - 1), coe_a(nz - 1)
    integer kmax1, kmax2, kmax3, count1, count11
    integer igr
    integer iwave
    integer knumi, srcnum
    real, dimension(:, :), allocatable:: fdm
    real row(nparpi)
    real vpft(nz - 1)
    real cbst1
    integer ii, jj, kk, nn, istep
    integer level, maxlevel, maxleveld, HorizonType, VerticalType, PorS
    real:: ftol = 1e-4
    integer ig, igroup

    g_td%gdx = 8
    g_td%gdz = 8
    g_td%asgr = 1
    g_td%sgdl = 8
    g_td%sgs = 8
    g_td%earth = 6371.0
    g_td%fom = 1
    g_td%snb = 0.5
    g_td%goxd = goxdf
    g_td%gozd = gozdf
    g_td%dvxd = dvxdf
    g_td%dvzd = dvzdf
    g_td%nvx = nx - 2
    g_td%nvz = ny - 2
    !
    ! Convert from degrees to radians
    !
    g_td%dvx = g_td%dvxd*g_td%pi/180.0
    g_td%dvz = g_td%dvzd*g_td%pi/180.0
    g_td%gox = (90.0 - g_td%goxd)*g_td%pi/180.0
    g_td%goz = g_td%gozd*g_td%pi/180.0
    !
    ! Compute corresponding values for propagation grid.
    !
    g_td%nnx = (g_td%nvx - 1)*g_td%gdx + 1
    g_td%nnz = (g_td%nvz - 1)*g_td%gdz + 1
    g_td%dnx = g_td%dvx/g_td%gdx
    g_td%dnz = g_td%dvz/g_td%gdz
    g_td%dnxd = g_td%dvxd/g_td%gdx
    g_td%dnzd = g_td%dvzd/g_td%gdz

    g_td%rbint = 0

    kmax1 = kmaxRc
    kmax2 = kmaxRc + kmaxRg
    kmax3 = kmaxRc + kmaxRg + kmaxLc

    allocate(sen_vsRc(nx * ny, kmaxRc, nz), sen_vpRc(nx * ny, kmaxRc, nz), sen_rhoRc(nx * ny, kmaxRc, nz))
    allocate(sen_vsRg(nx * ny, kmaxRc, nz), sen_vpRg(nx * ny, kmaxRc, nz), sen_rhoRg(nx * ny, kmaxRc, nz))
    allocate(sen_vsLc(nx * ny, kmaxLc, nz), sen_vpLc(nx * ny, kmaxLc, nz), sen_rhoLc(nx * ny, kmaxLc, nz))
    allocate(sen_vsLg(nx * ny, kmaxLc, nz), sen_vpLg(nx * ny, kmaxLc, nz), sen_rhoLg(nx * ny, kmaxLc, nz))
    allocate(sen_vs(nx * ny, kmax, nz), sen_vp(nx * ny, kmax, nz), sen_rho(nx * ny, kmax, nz))
    allocate(pvRc(nx * ny, kmax), pvRg(nx * ny, kmax), pvLc(nx * ny, kmax), pvLg(nx * ny, kmax))
    
    call date_and_time(values=start_date)
    if (kmaxRc .gt. 0) then
        iwave = 2
        igr = 0
        write (*, "(A)") "Rayleigh wave phase velocity depth kernel"
        
        if (is_senK_disba) then 
            call depthkernel_disba(nx, ny, nz, vels, pvRc, sen_vsRc, sen_vpRc, &
                            sen_rhoRc, iwave, igr, kmaxRc, tRc, depz, minthk)
        else
            call depthkernel_parallel(nx, ny, nz, vels, pvRc, sen_vsRc, sen_vpRc, &
                             sen_rhoRc, iwave, igr, kmaxRc, tRc, depz, minthk)
        end if
    end if
    call date_and_time(values=end_date)
    func_name = "CalSurfG_parallel depthkernel"
    call cal_run_time(start_date, end_date, func_name, loop_use_time)
    call WriteRunTime("CalSurfG_parallel depthkernel", loop_use_time)

    if (kmaxRg .gt. 0) then
        iwave = 2
        igr = 0
        call caldispersion_parallel(nx, ny, nz, vels, pvRc, iwave, igr, kmaxRg, tRg, depz, minthk)
        igr = 1
        write (*, "(A)") "Rayleigh wave group velocity depth kernel"
        call depthkernel_parallel(nx, ny, nz, vels, pvRg, sen_vsRg, sen_vpRg, &
                         sen_rhoRg, iwave, igr, kmaxRg, tRg, depz, minthk)
    end if

    if (kmaxLc .gt. 0) then
        iwave = 1
        igr = 0
        call depthkernel_parallel(nx, ny, nz, vels, pvLc, sen_vsLc, sen_vpLc, &
                         sen_rhoLc, iwave, igr, kmaxLc, tLc, depz, minthk)
    end if

    if (kmaxLg .gt. 0) then
        iwave = 1
        igr = 0
        call caldispersion_parallel(nx, ny, nz, vels, pvLc, iwave, igr, kmaxLg, tLg, depz, minthk)
        igr = 1
        call depthkernel_parallel(nx, ny, nz, vels, pvLg, sen_vsLg, sen_vpLg, &
                         sen_rhoLg, iwave, igr, kmaxLg, tLg, depz, minthk)
    end if

    loop_total_Num = sum(nsrcsurf1(1:kmax))
    allocate (knumi_list(loop_total_Num), STAT=t_checkstat)
    allocate (srcnum_list(loop_total_Num), STAT=t_checkstat)
    allocate (all_count1(loop_total_Num), STAT=t_checkstat)
    allocate (all_count11(loop_total_Num), STAT=t_checkstat)
    allocate (all_row_size(loop_total_Num), STAT=t_checkstat)
    allocate (all_nar(loop_total_Num), STAT=t_checkstat)
    allocate (all_nar1(loop_total_Num), STAT=t_checkstat)
    allocate (single_G_row_size(loop_total_Num), STAT=t_checkstat)
    allocate (all_G_row_count(sum(nrc1) + nparpi), STAT=t_checkstat)

    max_nnx = MAX(g_td%nnx, (MIN(g_td%nnx - 1, 2 * g_td%sgs) * g_td%sgdl + 1))
    max_nnz = MAX(g_td%nnz, (MIN(g_td%nnz - 1, 2 * g_td%sgs) * g_td%sgdl + 1))

    loop_total_Num = 0
    do knumi = 1, kmax
        do srcnum = 1, nsrcsurf1(knumi)
            loop_total_Num = loop_total_Num + 1
            knumi_list(loop_total_Num) = knumi
            srcnum_list(loop_total_Num) = srcnum

            all_count1(loop_total_Num) = nrc1(srcnum, knumi)
            all_row_size(loop_total_Num) = NINT(nrc1(srcnum, knumi) * nparpi * 0.25)
            single_G_row_size(loop_total_Num) = nrc1(srcnum, knumi)
        end do
    end do
    call cumsum(all_count1, all_count11)

    allocate (fdm(0:g_td%nvz + 1, 0:g_td%nvx + 1))
    call init_thread_data_matrix(g_td, max_nnx, max_nnz)
    call init_jagged_array(all_cbst, all_count1)
    call init_jagged_array(all_rw, all_row_size)
    call init_jagged_array(all_iw, all_row_size)
    call init_jagged_array(all_col, all_row_size)
    call init_jagged_array(single_G_row_count, single_G_row_size)

    travel_total_time = 0.0
    srtimes_total_time = 0.0
    rpath_total_time = 0.0

    ! nar = 0
    ! count1 = 0
    call date_and_time(values=start_date)
    !$omp parallel do num_threads(ThreadNum) &
    !$omp default(None) &
    !$omp shared(loop_total_Num, g_td, ftol) &
    !$omp shared(kmax1, kmax2, kmax3, kmax, kmaxRc, kmaxRg, kmaxLc, kmaxLg) &
    !$omp shared(wavetype, igrt, periods, pvRc, pvRg, pvLc, pvLg) &
    !$omp shared(sen_vpRc, sen_vsRc, sen_rhoRc, sen_vpRg, sen_vsRg, sen_rhoRg) &
    !$omp shared(sen_vpLc, sen_vsLc, sen_rhoLc, sen_vpLg, sen_vsLg, sen_rhoLg) &
    !$omp shared(nx, ny, nz, nparpi, nsrcsurf1, nrc1, scxf, sczf, rcxf, rczf, depz, vels) &
    !$omp shared(knumi_list, srcnum_list, all_count11, all_cbst, all_rw, all_iw, all_col, all_row, all_row_size, all_nar) &
    !$omp shared(single_G_row_count) &
    !$omp private(G_row_nar) &
    !$omp private(loop_idx, knumi, srcnum, igroup, ig,x, z, urg, count1, count11, nar, cbst1) &
    !$omp private(isx, isz, sw) &
    !$omp private(idm1, idm2, ogx, ogz, grdfx, grdfz, k, l, j, jj, kk, nn) &
    !$omp private(td, velf, sen_vp, sen_vs, sen_rho) &
    !$omp private(fdm, row, coe_a, vpft, coe_rho)
    do loop_idx = 1, loop_total_Num
        td = g_td
        td%tid = loop_idx

        knumi = knumi_list(loop_idx)
        srcnum = srcnum_list(loop_idx)

        if (wavetype(srcnum, knumi) == 2 .and. igrt(srcnum, knumi) == 0) then
            velf(1:nx*ny) = pvRc(1:nx*ny, periods(srcnum, knumi))
            sen_vs(:, 1:kmax1, :) = sen_vsRc(:, 1:kmaxRc, :) !(:,nt(istep),:)
            sen_vp(:, 1:kmax1, :) = sen_vpRc(:, 1:kmaxRc, :) !(:,nt(istep),:)
            sen_rho(:, 1:kmax1, :) = sen_rhoRc(:, 1:kmaxRc, :) !(:,nt(istep),:)
        end if
        if (wavetype(srcnum, knumi) == 2 .and. igrt(srcnum, knumi) == 1) then
            velf(1:nx*ny) = pvRg(1:nx*ny, periods(srcnum, knumi))
            sen_vs(:, kmax1 + 1:kmax2, :) = sen_vsRg(:, 1:kmaxRg, :) !(:,nt,:)
            sen_vp(:, kmax1 + 1:kmax2, :) = sen_vpRg(:, 1:kmaxRg, :) !(:,nt,:)
            sen_rho(:, kmax1 + 1:kmax2, :) = sen_rhoRg(:, 1:kmaxRg, :) !(:,nt,:)
        end if
        if (wavetype(srcnum, knumi) == 1 .and. igrt(srcnum, knumi) == 0) then
            velf(1:nx*ny) = pvLc(1:nx*ny, periods(srcnum, knumi))
            sen_vs(:, kmax2 + 1:kmax3, :) = sen_vsLc(:, 1:kmaxLc, :) !(:,nt,:)
            sen_vp(:, kmax2 + 1:kmax3, :) = sen_vpLc(:, 1:kmaxLc, :) !(:,nt,:)
            sen_rho(:, kmax2 + 1:kmax3, :) = sen_rhoLc(:, 1:kmaxLc, :) !(:,nt,:)
        end if
        if (wavetype(srcnum, knumi) == 1 .and. igrt(srcnum, knumi) == 1) then
            velf(1:nx*ny) = pvLg(1:nx*ny, periods(srcnum, knumi))
            sen_vs(:, kmax3 + 1:kmax, :) = sen_vsLg(:, 1:kmaxLg, :) !(:,nt,:)
            sen_vp(:, kmax3 + 1:kmax, :) = sen_vpLg(:, 1:kmaxLg, :) !(:,nt,:)
            sen_rho(:, kmax3 + 1:kmax, :) = sen_rhoLg(:, 1:kmaxLg, :) !(:,nt,:)
        end if

        ! only for Rayleigh wave group velocity, revise this latter for Love wave group velocity
        if (igrt(srcnum, knumi) == 1) then
            igroup = 2
        else
            igroup = 1
        end if
        ! velf0 = velf
        ! count11 = count1
        count1 = 0
        count11 = all_count11(loop_idx)
        nar = 0

        do ig = 1, igroup
            if (ig == 2 .and. wavetype(srcnum, knumi) == 2) then
                velf(1:nx*ny) = pvRc(1:nx*ny, periods(srcnum, knumi))
            end if
            if (ig == 2 .and. wavetype(srcnum, knumi) == 1) then
                velf(1:nx*ny) = pvLc(1:nx*ny, periods(srcnum, knumi))
            end if
            call gridder_parallel(velf, td)
            x = scxf(srcnum, knumi)
            z = sczf(srcnum, knumi)
            !
            !  Begin by computing refined source grid if required
            !
            urg = 0          
            IF (td%asgr .EQ. 1) THEN
                !
                !     Back up coarse velocity grid to a holding matrix
                !
                ! MODIFIEDY BY HONGJIAN FANG @ USTC 2014/04/17
                td%velnb(1:td%nnz, 1:td%nnx) = td%veln(1:td%nnz, 1:td%nnx)
                td%nnxb = td%nnx
                td%nnzb = td%nnz
                td%dnxb = td%dnx
                td%dnzb = td%dnz
                td%goxb = td%gox
                td%gozb = td%goz
                !
                !     Identify nearest neighbouring node to source
                !
                isx = INT((x - td%gox)/td%dnx) + 1
                isz = INT((z - td%goz)/td%dnz) + 1
                sw = 0
                IF (isx .lt. 1 .or. isx .gt. td%nnx) sw = 1
                IF (isz .lt. 1 .or. isz .gt. td%nnz) sw = 1
                IF (sw .eq. 1) then
                    x = 90.0 - x*180.0/td%pi
                    z = z*180.0/td%pi
                    WRITE (6, *) "Iteration", td%tid, "CalSurfG_P_loop: Source lies outside bounds of model (lat, long)= ", x, z
                    WRITE (6, *) "TERMINATING PROGRAM!!!"
                    STOP
                END IF
                IF (isx .eq. td%nnx) isx = isx - 1
                IF (isz .eq. td%nnz) isz = isz - 1
                !
                !     Now find rectangular box that extends outward from the nearest source node
                !     to "sgs" nodes away.
                !
                td%vnl = isx - td%sgs
                IF (td%vnl .lt. 1) td%vnl = 1
                td%vnr = isx + td%sgs
                IF (td%vnr .gt. td%nnx) td%vnr = td%nnx
                td%vnt = isz - td%sgs
                IF (td%vnt .lt. 1) td%vnt = 1
                td%vnb = isz + td%sgs
                IF (td%vnb .gt. td%nnz) td%vnb = td%nnz
                td%nrnx = (td%vnr - td%vnl)*td%sgdl + 1
                td%nrnz = (td%vnb - td%vnt)*td%sgdl + 1
                td%drnx = td%dvx/REAL(td%gdx*td%sgdl)
                td%drnz = td%dvz/REAL(td%gdz*td%sgdl)
                td%gorx = td%gox + td%dnx*(td%vnl - 1)
                td%gorz = td%goz + td%dnz*(td%vnt - 1)
                td%nnx = td%nrnx
                td%nnz = td%nrnz
                td%dnx = td%drnx
                td%dnz = td%drnz
                td%gox = td%gorx
                td%goz = td%gorz
                !
                !     Reallocate velocity and traveltime arrays if nnx>nnxb or
                !     nnz<nnzb.
                !
                IF (td%nnx .GT. td%nnxb .OR. td%nnz .GT. td%nnzb) THEN
                    idm1 = td%nnx
                    IF (td%nnxb .GT. idm1) idm1 = td%nnxb
                    idm2 = td%nnz
                    IF (td%nnzb .GT. idm2) idm2 = td%nnzb
                    ! DEALLOCATE (veln, ttn, nsts, btg)
                    ! ALLOCATE (veln(idm2, idm1))
                    ! ALLOCATE (ttn(idm2, idm1))
                    ! ALLOCATE (nsts(idm2, idm1))
                    ! maxbt = NINT(snb*idm1*idm2)
                    ! ALLOCATE (btg(maxbt))
                END IF
                !
                !     Call a subroutine to compute values of refined velocity nodes
                !
                CALL bsplrefine_parallel(td)
                !
                !     Compute first-arrival traveltime field through refined grid.
                !
                urg = 1
                CALL travel_parallel(x, z, urg, td)
                !
                !     Now map refined grid onto coarse grid.
                !
                ! ALLOCATE (ttnr(nnzb, nnxb))
                ! ALLOCATE (nstsr(nnzb, nnxb))
                IF (td%nnx .GT. td%nnxb .OR. td%nnz .GT. td%nnzb) THEN
                    idm1 = td%nnx
                    IF (td%nnxb .GT. idm1) idm1 = td%nnxb
                    idm2 = td%nnz
                    IF (td%nnzb .GT. idm2) idm2 = td%nnzb
                    ! DEALLOCATE (ttnr, nstsr)
                    ! ALLOCATE (ttnr(idm2, idm1))
                    ! ALLOCATE (nstsr(idm2, idm1))
                END IF
                td%ttnr = td%ttn
                td%nstsr = td%nsts
                ogx = td%vnl
                ogz = td%vnt
                grdfx = td%sgdl
                grdfz = td%sgdl
                td%nsts = -1
                DO k = 1, td%nnz, grdfz
                    idm1 = ogz + (k - 1)/grdfz
                    DO l = 1, td%nnx, grdfx
                        idm2 = ogx + (l - 1)/grdfx
                        td%nsts(idm1, idm2) = td%nstsr(k, l)
                        IF (td%nsts(idm1, idm2) .GE. 0) THEN
                            td%ttn(idm1, idm2) = td%ttnr(k, l)
                        END IF
                    END DO
                END DO
                !
                !     Backup refined grid information
                !
                td%nnxr = td%nnx
                td%nnzr = td%nnz
                td%goxr = td%gox
                td%gozr = td%goz
                td%dnxr = td%dnx
                td%dnzr = td%dnz
                !
                !     Restore remaining values.
                !
                td%nnx = td%nnxb
                td%nnz = td%nnzb
                td%dnx = td%dnxb
                td%dnz = td%dnzb
                td%gox = td%goxb
                td%goz = td%gozb
                DO j = 1, td%nnx
                    DO k = 1, td%nnz
                        td%veln(k, j) = td%velnb(k, j)
                    END DO
                END DO
                !
                !     Ensure that the narrow band is complete; if
                !     not, then some alive points will need to be
                !     made close.
                !
                DO k = 1, td%nnx
                    DO l = 1, td%nnz
                        IF (td%nsts(l, k) .EQ. 0) THEN
                            IF (l - 1 .GE. 1) THEN
                                IF (td%nsts(l - 1, k) .EQ. -1) td%nsts(l, k) = 1
                            END IF
                            IF (l + 1 .LE. td%nnz) THEN
                                IF (td%nsts(l + 1, k) .EQ. -1) td%nsts(l, k) = 1
                            END IF
                            IF (k - 1 .GE. 1) THEN
                                IF (td%nsts(l, k - 1) .EQ. -1) td%nsts(l, k) = 1
                            END IF
                            IF (k + 1 .LE. td%nnx) THEN
                                IF (td%nsts(l, k + 1) .EQ. -1) td%nsts(l, k) = 1
                            END IF
                        END IF
                    END DO
                END DO
                !
                !     Finally, call routine for computing traveltimes once
                !     again.
                !
                urg = 2
                CALL travel_parallel(x, z, urg, td)
            ELSE
                !
                !     Call a subroutine that works out the first-arrival traveltime
                !     field.
                !
                CALL travel_parallel(x, z, urg, td)
            END IF
            !
            !  Find source-receiver traveltimes if required
            !
            do istep = 1, nrc1(srcnum, knumi)
                if (ig == 1) then
                    CALL srtimes_parallel(x, z, rcxf(istep, srcnum, knumi), rczf(istep, srcnum, knumi), cbst1, td)
                    count1 = count1 + 1
                    all_cbst(loop_idx)%row(count1) = cbst1
                    ! dsurf(count1) = cbst1
                end if
                ! -------------------------------------------------------------
                !   ENDIF
                !
                !  Calculate raypath geometries and write to file if required.
                !  Calculate Frechet derivatives with the same subroutine
                !  if required.
                !
                if (igrt(srcnum, knumi) == 0 .or. (ig == 2 .and. igrt(srcnum, knumi) == 1)) then
                    count11 = count11 + 1       
                    CALL rpaths_parallel(x, z, fdm, rcxf(istep, srcnum, knumi), rczf(istep, srcnum, knumi), td)
                    row(1:nparpi) = 0.0
                    ! change the Brocher relationship if depth is larger than 35 km
                    if (depz(nz - 1) < 35.0) then
                        do jj = 1, td%nvz
                        do kk = 1, td%nvx
                        if (abs(fdm(jj, kk)) .ge. ftol) then
                            coe_a = (2.0947 - 0.8206*2*vels(kk + 1, jj + 1, 1:nz - 1) + &
                                        0.2683*3*vels(kk + 1, jj + 1, 1:nz - 1)**2 - 0.0251*4*vels(kk + 1, jj + 1, 1:nz - 1)**3)
                            vpft = 0.9409 + 2.0947*vels(kk + 1, jj + 1, 1:nz - 1) - 0.8206*vels(kk + 1, jj + 1, 1:nz - 1)**2 + &
                                    0.2683*vels(kk + 1, jj + 1, 1:nz - 1)**3 - 0.0251*vels(kk + 1, jj + 1, 1:nz - 1)**4
                            coe_rho = coe_a*(1.6612 - 0.4721*2*vpft + &
                                                0.0671*3*vpft**2 - 0.0043*4*vpft**3 + &
                                                0.000106*5*vpft**4)
                            row((jj - 1)*td%nvx + kk:(nz - 2)*td%nvz*td%nvx + (jj - 1)*td%nvx + kk:td%nvx*td%nvz) = &
                                (sen_vp(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1)*coe_a + &
                                sen_rho(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1)*coe_rho + &
                                sen_vs(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1))*fdm(jj, kk)
                        end if
                        end do
                        end do
                        ! use a different formulation between Vp, Vs, and Rho, according to Luosong's
                    else
                        do jj = 1, td%nvz
                        do kk = 1, td%nvx
                        if (abs(fdm(jj, kk)) .ge. ftol) then
                            coe_a = (2.2110 - 0.8984*2*vels(kk + 1, jj + 1, 1:nz - 1) + &
                                        0.2786*3*vels(kk + 1, jj + 1, 1:nz - 1)**2 - 0.02412*4*vels(kk + 1, jj + 1, 1:nz - 1)**3)
                            vpft = 0.9098 + 2.2110*vels(kk + 1, jj + 1, 1:nz - 1) - 0.8984*vels(kk + 1, jj + 1, 1:nz - 1)**2 + &
                                    0.2786*vels(kk + 1, jj + 1, 1:nz - 1)**3 - 0.02412*vels(kk + 1, jj + 1, 1:nz - 1)**4
                            coe_rho = coe_a*(1.6612 - 0.4721*2*vpft + &
                                                0.0671*3*vpft**2 - 0.0043*4*vpft**3 + &
                                                0.000106*5*vpft**4)

                            row((jj - 1)*td%nvx + kk:(nz - 2)*td%nvz*td%nvx + (jj - 1)*td%nvx + kk:td%nvx*td%nvz) = &
                                (sen_vp(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1)*coe_a + &
                                    sen_rho(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1)*coe_rho + &
                                    sen_vs(jj*(td%nvx + 2) + kk + 1, knumi, 1:nz - 1))*fdm(jj, kk)
                        end if
                        end do
                        end do
                    end if
                    
                    G_row_nar = 0
                    do nn = 1, nparpi
                        if (abs(row(nn)) .gt. ftol) then
                            nar = nar + 1
                            G_row_nar = G_row_nar + 1
                            call jagged_array_set_value(all_rw, loop_idx, nar, real(row(nn)))
                            call jagged_array_set_value(all_iw, loop_idx, nar, count11)
                            call jagged_array_set_value(all_col, loop_idx, nar, nn)
                            ! rw(nar) = real(row(nn))
                            ! iw(nar + 1) = count11
                            ! col(nar) = nn
                        end if
                    end do
                    call jagged_array_set_value(single_G_row_count, loop_idx, istep, G_row_nar)
                end if ! 'if' before rpath
            end do
            all_nar(loop_idx) = nar
        end do ! 'do' before gridder

        IF (td%rbint .EQ. 1) THEN
            WRITE (6, *) 'Note that at least one two-point ray path'
            WRITE (6, *) 'tracked along the boundary of the model.'
            WRITE (6, *) 'This class of path is unlikely to be'
            WRITE (6, *) 'a true path, and it is STRONGLY RECOMMENDED'
            WRITE (6, *) 'that you adjust the dimensions of your grid'
            WRITE (6, *) 'to prevent this from occurring.'
        END IF

    end do
    !$omp end parallel do

    count1 = 0
    do loop_idx = 1, loop_total_Num
        srcnum = srcnum_list(loop_idx)
        knumi = knumi_list(loop_idx)
        do istep = 1, nrc1(srcnum, knumi)
            count1 = count1 + 1
            dsurf(count1) = all_cbst(loop_idx)%row(istep)

            all_G_row_count(count1) = single_G_row_count(loop_idx)%row(istep)
        end do
    end do
    if (smooth_weight >= 0.0001) then
        do k = 1, nz - 1
            do j = 1, ny - 2
            do i = 1, nx - 2
                if (i == 1 .or. i == nx - 2 .or. j == 1 .or. j == ny - 2 .or. k == 1 .or. k == nz - 1) then
                    count1 = count1 + 1
                    all_G_row_count(count1) = 1
                else
                    count1 = count1 + 1
                    all_G_row_count(count1) = 7
                end if
            end do
            end do
        end do
    end if
    call WriteArray_binary_1D(all_G_row_count, "LSMR/row_count.bin" , count1)

    call cumsum(all_nar, all_nar1)
    !$omp parallel num_threads(ThreadNum) &
    !$omp default(None) &
    !$omp shared(loop_total_Num, knumi_list, srcnum_list, all_nar, all_nar1, all_rw, all_iw, all_col, rw, iw, col) &
    !$omp private(loop_idx, i, knumi, srcnum, nar)
    !$omp do schedule(guided)
    do loop_idx = 1, loop_total_Num
        srcnum = srcnum_list(loop_idx)
        knumi = knumi_list(loop_idx)
        nar = all_nar1(loop_idx)
        do i = 1, all_nar(loop_idx)
            nar = nar + 1
            rw(nar) = all_rw(loop_idx)%row(i)
            iw(nar + 1) = all_iw(loop_idx)%row(i)
            col(nar) = all_col(loop_idx)%row(i)
        end do
    end do
    !$omp end do
    !$omp end parallel
    nar = sum(all_nar)
    call date_and_time(values=end_date)

    func_name = ""
    call cal_run_time(start_date, end_date, func_name, loop_use_time)

    write (*, '("CalSurfG_parallel travel Time:", F10.4)') loop_use_time
    call WriteRunTime("CalSurfG_parallel travel", loop_use_time)

    deallocate (sen_vsRc, sen_vpRc, sen_rhoRc, sen_vsRg, sen_vpRg, sen_rhoRg, STAT=t_checkstat)
    deallocate (sen_vsLc, sen_vpLc, sen_rhoLc, sen_vsLg, sen_vpLg, sen_rhoLg, STAT=t_checkstat)
    deallocate (sen_vs, sen_vp, sen_rho, pvRc, pvRg, pvLc, pvLg, STAT=t_checkstat)

    deallocate (knumi_list, srcnum_list, all_count1, all_count11, all_row_size, all_nar, all_nar1, STAT=t_checkstat)
    deallocate (single_G_row_size, all_G_row_count, STAT=t_checkstat)
    
    call free_thread_data(g_td)

    call free_jagged_array(all_cbst)
    call free_jagged_array(all_rw)
    call free_jagged_array(all_iw)
    call free_jagged_array(all_col)
    call free_jagged_array(all_col)
    call free_jagged_array(single_G_row_count)
    deallocate (fdm)
END subroutine

SUBROUTINE gridder_parallel(pv, td)
    ! subroutine gridder(pv)
    ! subroutine gridder()
    ! USE globalp
    USE ThreadDataMod
    IMPLICIT NONE
    TYPE(ThreadData) td
    INTEGER :: i, j, l, m, i1, j1, conx, conz, stx, stz
    REAL(KIND=t_i10) :: u, sumi, sumj
    REAL(KIND=t_i10), DIMENSION(:, :), ALLOCATABLE :: ui, vi
    !CHARACTER (LEN=30) :: grid
    !
    ! u = independent parameter for b-spline
    ! ui,vi = bspline basis functions
    ! conx,conz = variables for edge of B-spline grid
    ! stx,stz = counters for veln grid points
    ! sumi,sumj = summation variables for computing b-spline
    !
    ! ---------------------------------------------------------------
    double precision pv(*)
    ! integer count1
    ! ---------------------------------------------------------------
    ! Open the grid file and read in the velocity grid.
    !
    ! OPEN(UNIT=10,FILE=grid,STATUS='old')
    ! READ(10,*)nvx,nvz
    ! READ(10,*)goxd,gozd
    ! READ(10,*)dvxd,dvzd
    ! count1=0
    DO i = 0, td%nvz + 1
        DO j = 0, td%nvx + 1
            ! count1=count1+1
            ! READ(10,*)velv(i,j)
            ! velv(i,j)=real(pv(count1))
            td%velv(i, j) = real(pv(i*(td%nvx + 2) + j + 1))
        END DO
    END DO
    !CLOSE(10)
    !
    ! Convert from degrees to radians
    !
    !
    ! Now dice up the grid
    !
    ALLOCATE (ui(td%gdx + 1, 4), STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with ALLOCATE: Subroutine gridder: REAL ui'
    END IF
    DO i = 1, td%gdx + 1
        u = td%gdx
        u = (i - 1)/u
        ui(i, 1) = (1.0 - u)**3/6.0
        ui(i, 2) = (4.0 - 6.0*u**2 + 3.0*u**3)/6.0
        ui(i, 3) = (1.0 + 3.0*u + 3.0*u**2 - 3.0*u**3)/6.0
        ui(i, 4) = u**3/6.0
    END DO
    ALLOCATE (vi(td%gdz + 1, 4), STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with ALLOCATE: Subroutine gridder: REAL vi'
    END IF
    DO i = 1, td%gdz + 1
        u = td%gdz
        u = (i - 1)/u
        vi(i, 1) = (1.0 - u)**3/6.0
        vi(i, 2) = (4.0 - 6.0*u**2 + 3.0*u**3)/6.0
        vi(i, 3) = (1.0 + 3.0*u + 3.0*u**2 - 3.0*u**3)/6.0
        vi(i, 4) = u**3/6.0
    END DO
    DO i = 1, td%nvz - 1
        conz = td%gdz
        IF (i == td%nvz - 1) conz = td%gdz + 1
        DO j = 1, td%nvx - 1
            conx = td%gdx
            IF (j == td%nvx - 1) conx = td%gdx + 1
            DO l = 1, conz
                stz = td%gdz*(i - 1) + l
                DO m = 1, conx
                    stx = td%gdx*(j - 1) + m
                    sumi = 0.0
                    DO i1 = 1, 4
                        sumj = 0.0
                        DO j1 = 1, 4
                            sumj = sumj + ui(m, j1)*td%velv(i - 2 + i1, j - 2 + j1)
                        END DO
                        sumi = sumi + vi(l, i1)*sumj
                    END DO
                    td%veln(stz, stx) = sumi
                END DO
            END DO
        END DO
    END DO
    DEALLOCATE (ui, vi, STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with DEALLOCATE: SUBROUTINE gridder: REAL ui, vi'
    END IF
END SUBROUTINE gridder_parallel

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: SUBROUTINE
! CODE: FORTRAN 90
! This subroutine is similar to bsplreg except that it has been
! modified to deal with source grid refinement
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE bsplrefine_parallel(td)
    ! USE globalp
    USE ThreadDataMod
    IMPLICIT NONE
    TYPE(ThreadData) td
    INTEGER :: i, j, k, l, i1, j1, st1, st2, nrzr, nrxr
    INTEGER :: origx, origz, conx, conz, idm1, idm2
    REAL(KIND=t_i10) :: u, v
    REAL(KIND=t_i10), DIMENSION(4) :: sum
    REAL(KIND=t_i10), DIMENSION(td%gdx*td%sgdl + 1, td%gdz*td%sgdl + 1, 4) :: ui, vi
    !
    ! nrxr,nrzr = grid refinement level for source grid in x,z
    ! origx,origz = local origin of refined source grid
    !
    ! Begin by calculating the values of the basis functions
    !
    nrxr = td%gdx*td%sgdl
    nrzr = td%gdz*td%sgdl
    DO i = 1, nrzr + 1
        v = nrzr
        v = (i - 1)/v
        DO j = 1, nrxr + 1
            u = nrxr
            u = (j - 1)/u
            ui(j, i, 1) = (1.0 - u)**3/6.0
            ui(j, i, 2) = (4.0 - 6.0*u**2 + 3.0*u**3)/6.0
            ui(j, i, 3) = (1.0 + 3.0*u + 3.0*u**2 - 3.0*u**3)/6.0
            ui(j, i, 4) = u**3/6.0
            vi(j, i, 1) = (1.0 - v)**3/6.0
            vi(j, i, 2) = (4.0 - 6.0*v**2 + 3.0*v**3)/6.0
            vi(j, i, 3) = (1.0 + 3.0*v + 3.0*v**2 - 3.0*v**3)/6.0
            vi(j, i, 4) = v**3/6.0
        END DO
    END DO
    !
    ! Calculate the velocity values.
    !
    origx = (td%vnl - 1)*td%sgdl + 1
    origz = (td%vnt - 1)*td%sgdl + 1
    DO i = 1, td%nvz - 1
        conz = nrzr
        IF (i == td%nvz - 1) conz = nrzr + 1
        DO j = 1, td%nvx - 1
            conx = nrxr
            IF (j == td%nvx - 1) conx = nrxr + 1
            DO k = 1, conz
                st1 = td%gdz*(i - 1) + (k - 1)/td%sgdl + 1
                IF (st1 .LT. td%vnt .OR. st1 .GT. td%vnb) CYCLE
                st1 = nrzr*(i - 1) + k
                DO l = 1, conx
                    st2 = td%gdx*(j - 1) + (l - 1)/td%sgdl + 1
                    IF (st2 .LT. td%vnl .OR. st2 .GT. td%vnr) CYCLE
                    st2 = nrxr*(j - 1) + l
                    DO i1 = 1, 4
                        sum(i1) = 0.0
                        DO j1 = 1, 4
                            sum(i1) = sum(i1) + ui(l, k, j1)*td%velv(i - 2 + i1, j - 2 + j1)
                        END DO
                        sum(i1) = vi(l, k, i1)*sum(i1)
                    END DO
                    idm1 = st1 - origz + 1
                    idm2 = st2 - origx + 1
                    IF (idm1 .LT. 1 .OR. idm1 .GT. td%nnz) CYCLE
                    IF (idm2 .LT. 1 .OR. idm2 .GT. td%nnx) CYCLE
                    td%veln(idm1, idm2) = sum(1) + sum(2) + sum(3) + sum(4)
                END DO
            END DO
        END DO
    END DO
END SUBROUTINE bsplrefine_parallel


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: SUBROUTINE
! CODE: FORTRAN 90
! This subroutine calculates all receiver traveltimes for
! a given source and writes the results to file.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!SUBROUTINE srtimes(scx,scz,rcx1,rcz1,cbst1)

SUBROUTINE srtimes_parallel(scx, scz, rcx1, rcz1, cbst1, td)
    ! USE globalp
    USE ThreadDataMod
    IMPLICIT NONE
    TYPE(ThreadData):: td
    INTEGER :: i, k, l, irx, irz, sw, isx, isz, csid
    INTEGER, PARAMETER :: noray = 0, yesray = 1
    INTEGER, PARAMETER :: i5 = SELECTED_REAL_KIND(6)
    REAL(KIND=i5) :: trr
    REAL(KIND=i5), PARAMETER :: norayt = 0.0
    REAL(KIND=t_i10) :: drx, drz, produ, scx, scz
    REAL(KIND=t_i10) :: rcx1, rcz1, cbst1
    REAL(KIND=t_i10) :: sred, dpl, rd1, vels, velr
    REAL(KIND=t_i10), DIMENSION(2, 2) :: vss
    ! ------------------------------------------------------
    !        modified by Hongjian Fang @ USTC
    integer no_p, nsrc
    real dist
    ! real cbst(*) !note that the type difference(kind=i5 vs real)
    ! integer cbst_stat(*)
    ! ------------------------------------------------------
    !
    ! irx,irz = Coordinates of cell containing receiver
    ! trr = traveltime value at receiver
    ! produ = dummy multiplier
    ! drx,drz = receiver distance from (i,j,k) grid node
    ! scx,scz = source coordinates
    ! isx,isz = source cell location
    ! sred = Distance from source to receiver
    ! dpl = Minimum path length in source neighbourhood.
    ! vels,velr = velocity at source and receiver
    ! vss = velocity at four grid points about source or receiver.
    ! csid = current source ID
    ! noray = switch to indicate no ray present
    ! norayt = default value given to null ray
    ! yesray = switch to indicate that ray is present
    !
    ! Determine source-receiver traveltimes one at a time.
    !
    !0605DO i=1,nrc
    !0605   IF(srs(i,csid).EQ.0)THEN
    !0605!      WRITE(10,*)noray,norayt
    !0605      CYCLE
    !0605   ENDIF
    !
    !  The first step is to locate the receiver in the grid.
    !
    irx = INT((rcx1 - td%gox)/td%dnx) + 1
    irz = INT((rcz1 - td%goz)/td%dnz) + 1
    sw = 0
    IF (irx .lt. 1 .or. irx .gt. td%nnx) sw = 1
    IF (irz .lt. 1 .or. irz .gt. td%nnz) sw = 1
    IF (sw .eq. 1) then
        rcx1 = 90.0 - rcx1*180.0/td%pi
        rcz1 = rcz1*180.0/td%pi
        WRITE (6, *) "srtimes: Receiver lies outside model (lat, long)= ", rcx1, rcz1
        WRITE (6, *) "TERMINATING PROGRAM!!!!"
        STOP
    END IF
    IF (irx .eq. td%nnx) irx = irx - 1
    IF (irz .eq. td%nnz) irz = irz - 1
    !
    !  Location of receiver successfully found within the grid. Now approximate
    !  traveltime at receiver using bilinear interpolation from four
    !  surrounding grid points. Note that bilinear interpolation is a poor
    !  approximation when traveltime gradient varies significantly across a cell,
    !  particularly near the source. Thus, we use an improved approximation in this
    !  case. First, locate current source cell.
    !
    isx = INT((scx - td%gox)/td%dnx) + 1
    isz = INT((scz - td%goz)/td%dnz) + 1
    dpl = td%dnx*td%earth
    rd1 = td%dnz*td%earth*SIN(td%gox)
    IF (rd1 .LT. dpl) dpl = rd1
    rd1 = td%dnz*td%earth*SIN(td%gox + (td%nnx - 1)*td%dnx)
    IF (rd1 .LT. dpl) dpl = rd1
    sred = ((scx - rcx1)*td%earth)**2
    sred = sred + ((scz - rcz1)*td%earth*SIN(rcx1))**2
    sred = SQRT(sred)
    IF (sred .LT. dpl) sw = 1
    IF (isx .EQ. irx) THEN
        IF (isz .EQ. irz) sw = 1
    END IF
    IF (sw .EQ. 1) THEN
        !
        !     Compute velocity at source and receiver
        !
        DO k = 1, 2
            DO l = 1, 2
                vss(k, l) = td%veln(isz - 1 + l, isx - 1 + k)
            END DO
        END DO
        drx = (scx - td%gox) - (isx - 1)*td%dnx
        drz = (scz - td%goz) - (isz - 1)*td%dnz
        CALL bilinear_parallel(vss, drx, drz, vels, td)
        DO k = 1, 2
            DO l = 1, 2
                vss(k, l) = td%veln(irz - 1 + l, irx - 1 + k)
            END DO
        END DO
        drx = (rcx1 - td%gox) - (irx - 1)*td%dnx
        drz = (rcz1 - td%goz) - (irz - 1)*td%dnz
        CALL bilinear_parallel(vss, drx, drz, velr, td)
        trr = 2.0*sred/(vels + velr)
    ELSE
        drx = (rcx1 - td%gox) - (irx - 1)*td%dnx
        drz = (rcz1 - td%goz) - (irz - 1)*td%dnz
        trr = 0.0
        DO k = 1, 2
            DO l = 1, 2
                produ = (1.0 - ABS(((l - 1)*td%dnz - drz)/td%dnz))*(1.0 - ABS(((k - 1)*td%dnx - drx)/td%dnx))
                trr = trr + td%ttn(irz - 1 + l, irx - 1 + k)*produ
            END DO
        END DO
    END IF
    ! WRITE(10,*)yesray,trr
    ! -----------------------------------------------------------------
    ! modified by Hongjian Fang @ USTC
    ! count2=count2+1
    ! cbst((no_p-1)*nsrc*nrc+(csid-1)*nrc+i)=trr
    cbst1 = trr
    ! call delsph(scx,scz,rcx(i),rcz(i),dist)
    ! travel_path(count2)=dist
    ! cbst_stat((no_p-1)*nsrc*nrc+(csid-1)*nrc+i)=yesray
    ! 0605ENDDO
END SUBROUTINE srtimes_parallel

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: SUBROUTINE
! CODE: FORTRAN 90
! This subroutine calculates ray path geometries for each
! source-receiver combination. It will also compute
! Frechet derivatives using these ray paths if required.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!SUBROUTINE rpaths(wrgf,csid,cfd,scx,scz)
!SUBROUTINE rpaths()
SUBROUTINE rpaths_parallel(scx, scz, fdm, surfrcx, surfrcz, td)
    ! USE globalp
    USE ThreadDataMod
    IMPLICIT NONE
    TYPE(ThreadData):: td
    INTEGER, PARAMETER :: i5 = SELECTED_REAL_KIND(5, 10)
    INTEGER, PARAMETER :: nopath = 0
    INTEGER :: i, j, k, l, m, n, ipx, ipz, ipxr, ipzr, nrp, sw
    !fang!INTEGER :: wrgf,cfd,csid,ipxo,ipzo,isx,isz
    INTEGER :: ipxo, ipzo, isx, isz
    INTEGER :: ivx, ivz, ivxo, ivzo, nhp, maxrp
    INTEGER :: ivxt, ivzt, ipxt, ipzt, isum, igref
    INTEGER, DIMENSION(4) :: chp
    REAL(KIND=i5) :: rayx, rayz
    REAL(KIND=t_i10) :: dpl, rd1, rd2, xi, zi, vel, velo
    REAL(KIND=t_i10) :: v, w, rigz, rigx, dinc, scx, scz
    REAL(KIND=t_i10) :: dtx, dtz, drx, drz, produ, sred
    REAL(KIND=t_i10), DIMENSION(:), ALLOCATABLE :: rgx, rgz
    !fang!REAL(KIND=i5), DIMENSION (:,:), ALLOCATABLE :: fdm
    REAL(KIND=t_i10), DIMENSION(4) :: vrat, vi, wi, vio, wio
    !fang!------------------------------------------------

    real fdm(0:td%nvz + 1, 0:td%nvx + 1)
    REAL(KIND=t_i10) surfrcx, surfrcz
    !fang!------------------------------------------------
    !
    ! ipx,ipz = Coordinates of cell containing current point
    ! ipxr,ipzr = Same as ipx,apz except for refined grid
    ! ipxo,ipzo = Coordinates of previous point
    ! rgx,rgz = (x,z) coordinates of ray geometry
    ! ivx,ivz = Coordinates of B-spline vertex containing current point
    ! ivxo,ivzo = Coordinates of previous point
    ! maxrp = maximum number of ray points
    ! nrp = number of points to describe ray
    ! dpl = incremental path length of ray
    ! xi,zi = edge of model coordinates
    ! dtx,dtz = components of gradT
    ! wrgf = Write out raypaths? (<0=all,0=no,>0=souce id)
    ! cfd = calculate Frechet derivatives? (0=no,1=yes)
    ! csid = current source id
    ! fdm = Frechet derivative matrix
    ! nhp = Number of ray segment-B-spline cell hit points
    ! vrat = length ratio of ray sub-segment
    ! chp = pointer to incremental change in x or z cell
    ! drx,drz = distance from reference node of cell
    ! produ = variable for trilinear interpolation
    ! vel = velocity at current point
    ! velo = velocity at previous point
    ! v,w = local variables of x,z
    ! vi,wi = B-spline basis functions at current point
    ! vio,wio = vi,wi for previous point
    ! ivxt,ivzt = temporary ivr,ivx,ivz values
    ! rigx,rigz = end point of sub-segment of ray path
    ! ipxt,ipzt = temporary ipx,ipz values
    ! dinc = path length of ray sub-segment
    ! rayr,rayx,rayz = ray path coordinates in single precision
    ! isx,isz = current source cell location
    ! scx,scz = current source coordinates
    ! sred = source to ray endpoint distance
    ! igref = ray endpoint lies in refined grid? (0=no,1=yes)
    ! nopath = switch to indicate that no path is present
    !
    ! Allocate memory to arrays for storing ray path geometry
    !
    maxrp = td%nnx*td%nnz
    ALLOCATE (rgx(maxrp + 1), STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with ALLOCATE: SUBROUTINE rpaths: REAL rgx'
    END IF
    ALLOCATE (rgz(maxrp + 1), STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with ALLOCATE: SUBROUTINE rpaths: REAL rgz'
    END IF
    !
    ! Allocate memory to partial derivative array
    !
    !fang!IF(cfd.EQ.1)THEN
    !fang!   ALLOCATE(fdm(0:nvz+1,0:nvx+1), STAT=t_checkstat)
    !fang!   IF(t_checkstat > 0)THEN
    !fang!      WRITE(6,*)'Error with ALLOCATE: SUBROUTINE rpaths: REAL fdm'
    !fang!   ENDIF
    !fang!ENDIF
    !
    ! Locate current source cell
    !
    IF (td%asgr .EQ. 1) THEN
        isx = INT((scx - td%goxr)/td%dnxr) + 1
        isz = INT((scz - td%gozr)/td%dnzr) + 1
    ELSE
        isx = INT((scx - td%gox)/td%dnx) + 1
        isz = INT((scz - td%goz)/td%dnz) + 1
    END IF
    !
    ! Set ray incremental path length equal to half width
    ! of cell
    !
    dpl = td%dnx*td%earth
    rd1 = td%dnz*td%earth*SIN(td%gox)
    IF (rd1 .LT. dpl) dpl = rd1
    rd1 = td%dnz*td%earth*SIN(td%gox + (td%nnx - 1)*td%dnx)
    IF (rd1 .LT. dpl) dpl = rd1
    dpl = 0.5*dpl
    !
    ! Loop through all the receivers
    !
    !fang!DO i=1,nrc
    !
    !  If path does not exist, then cycle the loop
    !
    fdm = 0
    !fang!   IF(cfd.EQ.1)THEN
    !fang!      fdm=0.0
    !fang!   ENDIF
    !fang!   IF(srs(i,csid).EQ.0)THEN
    !fang!      IF(wrgf.EQ.csid.OR.wrgf.LT.0)THEN
    !fang!         WRITE(40)nopath
    !fang!      ENDIF
    !fang!      IF(cfd.EQ.1)THEN
    !fang!         WRITE(50)nopath
    !fang!      ENDIF
    !fang!      CYCLE
    !fang!   ENDIF
    !
    !  The first step is to locate the receiver in the grid.
    !
    ipx = INT((surfrcx - td%gox)/td%dnx) + 1
    ipz = INT((surfrcz - td%goz)/td%dnz) + 1
    sw = 0
    IF (ipx .lt. 1 .or. ipx .ge. td%nnx) sw = 1
    IF (ipz .lt. 1 .or. ipz .ge. td%nnz) sw = 1
    IF (sw .eq. 1) then
        surfrcx = 90.0 - surfrcx*180.0/td%pi
        surfrcz = surfrcz*180.0/td%pi
        WRITE (6, *) "rpath: Receiver lies outside model (lat, long)= ", surfrcx, surfrcz
        WRITE (6, *) "TERMINATING PROGRAM!!!"
        STOP
    END IF
    IF (ipx .eq. td%nnx) ipx = ipx - 1
    IF (ipz .eq. td%nnz) ipz = ipz - 1
    !
    !  First point of the ray path is the receiver
    !
    rgx(1) = surfrcx
    rgz(1) = surfrcz
    !
    !  Test to see if receiver is in source neighbourhood
    !
    sred = ((scx - rgx(1))*td%earth)**2
    sred = sred + ((scz - rgz(1))*td%earth*SIN(rgx(1)))**2
    sred = SQRT(sred)
    IF (sred .LT. 2.0*dpl) THEN
        rgx(2) = scx
        rgz(2) = scz
        nrp = 2
        sw = 1
    END IF
    !
    !  If required, see if receiver lies within refined grid
    !
    ! write(*, *) 'rpath 1'
    IF (td%asgr .EQ. 1) THEN
        ipxr = INT((surfrcx - td%goxr)/td%dnxr) + 1
        ipzr = INT((surfrcz - td%gozr)/td%dnzr) + 1
        igref = 1
        IF (ipxr .LT. 1 .OR. ipxr .GE. td%nnxr) igref = 0
        IF (ipzr .LT. 1 .OR. ipzr .GE. td%nnzr) igref = 0
        ! write(*, *) 'rpath 11'
        IF (igref .EQ. 1) THEN
            IF (td%nstsr(ipzr, ipxr) .NE. 0 .OR. td%nstsr(ipzr + 1, ipxr) .NE. 0) igref = 0
            IF (td%nstsr(ipzr, ipxr + 1) .NE. 0 .OR. td%nstsr(ipzr + 1, ipxr + 1) .NE. 0) igref = 0
        END IF
        ! write(*, *) 'rpath 22'

    ELSE
        igref = 0
    END IF
    ! write(*, *) 'rpath 2'
    !
    !  Due to the method for calculating traveltime gradient, if the
    !  the ray end point lies in the source cell, then we are also done.
    !
    IF (sw .EQ. 0) THEN
        IF (td%asgr .EQ. 1) THEN
            IF (igref .EQ. 1) THEN
                IF (ipxr .EQ. isx) THEN
                    IF (ipzr .EQ. isz) THEN
                        rgx(2) = scx
                        rgz(2) = scz
                        nrp = 2
                        sw = 1
                    END IF
                END IF
            END IF
        ELSE
            IF (ipx .EQ. isx) THEN
                IF (ipz .EQ. isz) THEN
                    rgx(2) = scx
                    rgz(2) = scz
                    nrp = 2
                    sw = 1
                END IF
            END IF
        END IF
    END IF
    !
    !  Now trace ray from receiver to "source"
    !
    DO j = 1, maxrp
        IF (sw .EQ. 1) EXIT
        !
        !     Calculate traveltime gradient vector for current cell using
        !     a first-order or second-order scheme.
        !
        IF (igref .EQ. 1) THEN
            !
            !        In this case, we are in the refined grid.
            !
            !        First order scheme applied here.
            !
            dtx = td%ttnr(ipzr, ipxr + 1) - td%ttnr(ipzr, ipxr)
            dtx = dtx + td%ttnr(ipzr + 1, ipxr + 1) - td%ttnr(ipzr + 1, ipxr)
            dtx = dtx/(2.0*td%earth*td%dnxr)
            dtz = td%ttnr(ipzr + 1, ipxr) - td%ttnr(ipzr, ipxr)
            dtz = dtz + td%ttnr(ipzr + 1, ipxr + 1) - td%ttnr(ipzr, ipxr + 1)
            dtz = dtz/(2.0*td%earth*SIN(rgx(j))*td%dnzr)
        ELSE
            !
            !        Here, we are in the coarse grid.
            !
            !        First order scheme applied here.
            !
            dtx = td%ttn(ipz, ipx + 1) - td%ttn(ipz, ipx)
            dtx = dtx + td%ttn(ipz + 1, ipx + 1) - td%ttn(ipz + 1, ipx)
            dtx = dtx/(2.0*td%earth*td%dnx)
            dtz = td%ttn(ipz + 1, ipx) - td%ttn(ipz, ipx)
            dtz = dtz + td%ttn(ipz + 1, ipx + 1) - td%ttn(ipz, ipx + 1)
            dtz = dtz/(2.0*td%earth*SIN(rgx(j))*td%dnz)
        END IF
        !
        !     Calculate the next ray path point
        !
        rd1 = SQRT(dtx**2 + dtz**2)
        rgx(j + 1) = rgx(j) - dpl*dtx/(td%earth*rd1)
        rgz(j + 1) = rgz(j) - dpl*dtz/(td%earth*SIN(rgx(j))*rd1)
        !
        !     Determine which cell the new ray endpoint
        !     lies in.
        !
        ipxo = ipx
        ipzo = ipz
        IF (td%asgr .EQ. 1) THEN
            !
            !        Here, we test to see whether the ray endpoint lies
            !        within a cell of the refined grid
            !
            ipxr = INT((rgx(j + 1) - td%goxr)/td%dnxr) + 1
            ipzr = INT((rgz(j + 1) - td%gozr)/td%dnzr) + 1
            igref = 1
            IF (ipxr .LT. 1 .OR. ipxr .GE. td%nnxr) igref = 0
            IF (ipzr .LT. 1 .OR. ipzr .GE. td%nnzr) igref = 0
            IF (igref .EQ. 1) THEN
                IF (td%nstsr(ipzr, ipxr) .NE. 0 .OR. td%nstsr(ipzr + 1, ipxr) .NE. 0) igref = 0
                IF (td%nstsr(ipzr, ipxr + 1) .NE. 0 .OR. td%nstsr(ipzr + 1, ipxr + 1) .NE. 0) igref = 0
            END IF
            ipx = INT((rgx(j + 1) - td%gox)/td%dnx) + 1
            ipz = INT((rgz(j + 1) - td%goz)/td%dnz) + 1
        ELSE
            ipx = INT((rgx(j + 1) - td%gox)/td%dnx) + 1
            ipz = INT((rgz(j + 1) - td%goz)/td%dnz) + 1
            igref = 0
        END IF
        !
        !     Test the proximity of the source to the ray end point.
        !     If it is less than dpl then we are done
        !
        sred = ((scx - rgx(j + 1))*td%earth)**2
        sred = sred + ((scz - rgz(j + 1))*td%earth*SIN(rgx(j + 1)))**2
        sred = SQRT(sred)
        sw = 0
        IF (sred .LT. 2.0*dpl) THEN
            rgx(j + 2) = scx
            rgz(j + 2) = scz
            nrp = j + 2
            sw = 1
            !fang!         IF(cfd.NE.1)EXIT
        END IF
        !
        !     Due to the method for calculating traveltime gradient, if the
        !     the ray end point lies in the source cell, then we are also done.
        !
        IF (sw .EQ. 0) THEN
            IF (td%asgr .EQ. 1) THEN
                IF (igref .EQ. 1) THEN
                    IF (ipxr .EQ. isx) THEN
                        IF (ipzr .EQ. isz) THEN
                            rgx(j + 2) = scx
                            rgz(j + 2) = scz
                            nrp = j + 2
                            sw = 1
                            !fang!                    IF(cfd.NE.1)EXIT
                        END IF
                    END IF
                END IF
            ELSE
                IF (ipx .EQ. isx) THEN
                    IF (ipz .EQ. isz) THEN
                        rgx(j + 2) = scx
                        rgz(j + 2) = scz
                        nrp = j + 2
                        sw = 1
                        !fang!                 IF(cfd.NE.1)EXIT
                    END IF
                END IF
            END IF
        END IF
        !
        !     Test whether ray path segment extends beyond
        !     box boundaries
        !
        IF (ipx .LT. 1) THEN
            rgx(j + 1) = td%gox
            ipx = 1
            td%rbint = 1
        END IF
        IF (ipx .GE. td%nnx) THEN
            rgx(j + 1) = td%gox + (td%nnx - 1)*td%dnx
            ipx = td%nnx - 1
            td%rbint = 1
        END IF
        IF (ipz .LT. 1) THEN
            rgz(j + 1) = td%goz
            ipz = 1
            td%rbint = 1
        END IF
        IF (ipz .GE. td%nnz) THEN
            rgz(j + 1) = td%goz + (td%nnz - 1)*td%dnz
            ipz = td%nnz - 1
            td%rbint = 1
        END IF
        !
        !     Calculate the Frechet derivatives if required.
        !
        !fang!     IF(cfd.EQ.1)THEN
        !
        !        First determine which B-spline cell the refined cells
        !        containing the ray path segment lies in. If they lie
        !        in more than one, then we need to divide the problem
        !        into separate parts (up to three).
        !
        ivx = INT((ipx - 1)/td%gdx) + 1
        ivz = INT((ipz - 1)/td%gdz) + 1
        ivxo = INT((ipxo - 1)/td%gdx) + 1
        ivzo = INT((ipzo - 1)/td%gdz) + 1
        !
        !        Calculate up to two hit points between straight
        !        ray segment and cell faces.
        !
        nhp = 0
        IF (ivx .NE. ivxo) THEN
            nhp = nhp + 1
            IF (ivx .GT. ivxo) THEN
                xi = td%gox + (ivx - 1)*td%dvx
            ELSE
                xi = td%gox + ivx*td%dvx
            END IF
            vrat(nhp) = (xi - rgx(j))/(rgx(j + 1) - rgx(j))
            chp(nhp) = 1
        END IF
        IF (ivz .NE. ivzo) THEN
            nhp = nhp + 1
            IF (ivz .GT. ivzo) THEN
                zi = td%goz + (ivz - 1)*td%dvz
            ELSE
                zi = td%goz + ivz*td%dvz
            END IF
            rd1 = (zi - rgz(j))/(rgz(j + 1) - rgz(j))
            IF (nhp .EQ. 1) THEN
                vrat(nhp) = rd1
                chp(nhp) = 2
            ELSE
                IF (rd1 .GE. vrat(nhp - 1)) THEN
                    vrat(nhp) = rd1
                    chp(nhp) = 2
                ELSE
                    vrat(nhp) = vrat(nhp - 1)
                    chp(nhp) = chp(nhp - 1)
                    vrat(nhp - 1) = rd1
                    chp(nhp - 1) = 2
                END IF
            END IF
        END IF
        nhp = nhp + 1
        vrat(nhp) = 1.0
        chp(nhp) = 0
        !
        !        Calculate the velocity, v and w values of the
        !        first point
        !
        drx = (rgx(j) - td%gox) - (ipxo - 1)*td%dnx
        drz = (rgz(j) - td%goz) - (ipzo - 1)*td%dnz
        vel = 0.0
        DO l = 1, 2
            DO m = 1, 2
                produ = (1.0 - ABS(((m - 1)*td%dnz - drz)/td%dnz))
                produ = produ*(1.0 - ABS(((l - 1)*td%dnx - drx)/td%dnx))
                IF (ipzo - 1 + m .LE. td%nnz .AND. ipxo - 1 + l .LE. td%nnx) THEN
                    vel = vel + td%veln(ipzo - 1 + m, ipxo - 1 + l)*produ
                END IF
            END DO
        END DO
        drx = (rgx(j) - td%gox) - (ivxo - 1)*td%dvx
        drz = (rgz(j) - td%goz) - (ivzo - 1)*td%dvz
        v = drx/td%dvx
        w = drz/td%dvz
        !
        !        Calculate the 12 basis values at the point
        !
        vi(1) = (1.0 - v)**3/6.0
        vi(2) = (4.0 - 6.0*v**2 + 3.0*v**3)/6.0
        vi(3) = (1.0 + 3.0*v + 3.0*v**2 - 3.0*v**3)/6.0
        vi(4) = v**3/6.0
        wi(1) = (1.0 - w)**3/6.0
        wi(2) = (4.0 - 6.0*w**2 + 3.0*w**3)/6.0
        wi(3) = (1.0 + 3.0*w + 3.0*w**2 - 3.0*w**3)/6.0
        wi(4) = w**3/6.0
        ivxt = ivxo
        ivzt = ivzo
        !
        !        Now loop through the one or more sub-segments of the
        !        ray path segment and calculate partial derivatives
        !
        DO k = 1, nhp
            velo = vel
            vio = vi
            wio = wi
            IF (k .GT. 1) THEN
                IF (chp(k - 1) .EQ. 1) THEN
                    ivxt = ivx
                ELSE IF (chp(k - 1) .EQ. 2) THEN
                    ivzt = ivz
                END IF
            END IF
            !
            !           Calculate the velocity, v and w values of the
            !           new point
            !
            rigz = rgz(j) + vrat(k)*(rgz(j + 1) - rgz(j))
            rigx = rgx(j) + vrat(k)*(rgx(j + 1) - rgx(j))
            ipxt = INT((rigx - td%gox)/td%dnx) + 1
            ipzt = INT((rigz - td%goz)/td%dnz) + 1
            drx = (rigx - td%gox) - (ipxt - 1)*td%dnx
            drz = (rigz - td%goz) - (ipzt - 1)*td%dnz
            vel = 0.0
            DO m = 1, 2
                DO n = 1, 2
                    produ = (1.0 - ABS(((n - 1)*td%dnz - drz)/td%dnz))
                    produ = produ*(1.0 - ABS(((m - 1)*td%dnx - drx)/td%dnx))
                    IF (ipzt - 1 + n .LE. td%nnz .AND. ipxt - 1 + m .LE. td%nnx) THEN
                        vel = vel + td%veln(ipzt - 1 + n, ipxt - 1 + m)*produ
                    END IF
                END DO
            END DO
            drx = (rigx - td%gox) - (ivxt - 1)*td%dvx
            drz = (rigz - td%goz) - (ivzt - 1)*td%dvz
            v = drx/td%dvx
            w = drz/td%dvz
            !
            !           Calculate the 8 basis values at the new point
            !
            vi(1) = (1.0 - v)**3/6.0
            vi(2) = (4.0 - 6.0*v**2 + 3.0*v**3)/6.0
            vi(3) = (1.0 + 3.0*v + 3.0*v**2 - 3.0*v**3)/6.0
            vi(4) = v**3/6.0
            wi(1) = (1.0 - w)**3/6.0
            wi(2) = (4.0 - 6.0*w**2 + 3.0*w**3)/6.0
            wi(3) = (1.0 + 3.0*w + 3.0*w**2 - 3.0*w**3)/6.0
            wi(4) = w**3/6.0
            !
            !           Calculate the incremental path length
            !
            IF (k .EQ. 1) THEN
                dinc = vrat(k)*dpl
            ELSE
                dinc = (vrat(k) - vrat(k - 1))*dpl
            END IF
            !
            !           Now compute the 16 contributions to the partial
            !           derivatives.
            !
            DO l = 1, 4
                DO m = 1, 4
                    rd1 = vi(m)*wi(l)/vel**2
                    rd2 = vio(m)*wio(l)/velo**2
                    rd1 = -(rd1 + rd2)*dinc/2.0
                    !fang!                 rd1=vi(m)*wi(l)
                    !fang!                 rd2=vio(m)*wio(l)
                    !fang!                 rd1=(rd1+rd2)*dinc/2.0
                    rd2 = fdm(ivzt - 2 + l, ivxt - 2 + m)
                    fdm(ivzt - 2 + l, ivxt - 2 + m) = rd1 + rd2
                END DO
            END DO
        END DO
        !fang!     ENDIF
        !fang!      IF(j.EQ.maxrp.AND.sw.EQ.0)THEN
        !fang!         WRITE(6,*)'Error with ray path detected!!!'
        !fang!         WRITE(6,*)'Source id: ',csid
        !fang!         WRITE(6,*)'Receiver id: ',i
        !fang!      ENDIF
    END DO
    !
    !  Write ray paths to output file
    !
    !fang!   IF(wrgf.EQ.csid.OR.wrgf.LT.0)THEN
    !if(writepath == 1) then
    !  WRITE(40,*)'#',nrp
    !  DO j=1,nrp
    !    rayx=(pi/2-rgx(j))*180.0/pi
    !    rayz=rgz(j)*180.0/pi
    !    WRITE(40,*)rayx,rayz
    !  ENDDO
    !endif
    !fang!   ENDIF
    !
    !  Write partial derivatives to output file
    !
    !fang!   IF(cfd.EQ.1)THEN
    !fang!!
    !fang!!     Determine the number of non-zero elements.
    !fang!!
    !fang!      isum=0
    !fang!      DO j=0,nvz+1
    !fang!         DO k=0,nvx+1
    !fang!            IF(ABS(fdm(j,k)).GE.ftol)isum=isum+1
    !fang!         ENDDO
    !fang!      ENDDO
    !fang!      WRITE(50)isum
    !fang!      isum=0
    !fang!      DO j=0,nvz+1
    !fang!         DO k=0,nvx+1
    !fang!            isum=isum+1
    !fang!            IF(ABS(fdm(j,k)).GE.ftol)WRITE(50)isum,fdm(j,k)
    !fang!         ENDDO
    !fang!      ENDDO
    !fang!   ENDIF
    !fang!ENDDO
    !fang!IF(cfd.EQ.1)THEN
    !fang!   DEALLOCATE(fdm, STAT=t_checkstat)
    !fang!   IF(t_checkstat > 0)THEN
    !fang!      WRITE(6,*)'Error with DEALLOCATE: SUBROUTINE rpaths: fdm'
    !fang!   ENDIF
    !fang!ENDIF
    DEALLOCATE (rgx, rgz, STAT=t_checkstat)
    IF (t_checkstat > 0) THEN
        WRITE (6, *) 'Error with DEALLOCATE: SUBROUTINE rpaths: rgx,rgz'
    END IF
END SUBROUTINE rpaths_parallel


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! TYPE: SUBROUTINE
! CODE: FORTRAN 90
! This subroutine is passed four node values which lie on
! the corners of a rectangle and the coordinates of a point
! lying within the rectangle. It calculates the value at
! the internal point by using bilinear interpolation.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE bilinear_parallel(nv, dsx, dsz, biv, td)
    ! USE globalp
    USE ThreadDataMod
    IMPLICIT NONE
    TYPE(ThreadData):: td
    INTEGER :: i, j
    REAL(KIND=t_i10) :: dsx, dsz, biv
    REAL(KIND=t_i10), DIMENSION(2, 2) :: nv
    REAL(KIND=t_i10) :: produ
    !
    ! nv = four node vertex values
    ! dsx,dsz = distance between internal point and top left node
    ! dnx,dnz = width and height of node rectangle
    ! biv = value at internal point calculated by bilinear interpolation
    ! produ = product variable
    !
    biv = 0.0
    DO i = 1, 2
        DO j = 1, 2
            produ = (1.0 - ABS(((i - 1)*td%dnx - dsx)/td%dnx))*(1.0 - ABS(((j - 1)*td%dnz - dsz)/td%dnz))
            biv = biv + nv(i, j)*produ
        END DO
    END DO
END SUBROUTINE bilinear_parallel

subroutine refineGrid2LayerMdl_parallel(minthk0, mmax, dep, vp, vs, rho, rmax, rdep, rvp, rvs, rrho, rthk)
    ! --------------------------------------------------------------------c
    ! refine grid based model to layerd based model
    ! INPUT:  minthk: is the minimum thickness of the refined layered model
    !         mmax: number of depth grid points in the model
    !         dep, vp, vs, rho: the depth-grid model parameters
    !         rmax: number of layers in the fined layered model
    !         rdep, rvp, rvs, rrho, rthk: the refined layered velocity model
    !
    implicit none
    integer NL
    parameter(NL=200)
    integer mmax, rmax
    real minthk0
    real minthk
    real dep(*), vp(*), vs(*), rho(*)
    real rdep(NL), rvp(NL), rvs(NL), rrho(NL), rthk(NL)
    integer nsublay(NL)
    real thk, newthk, initdep
    integer i, j, k, ngrid

    k = 0
    initdep = 0.0
    do i = 1, mmax - 1
        thk = dep(i + 1) - dep(i)
        minthk = thk/minthk0
        nsublay(i) = int((thk + 1.0e-4)/minthk) + 1
        ngrid = nsublay(i) + 1
        newthk = thk/nsublay(i)
        do j = 1, nsublay(i)
            k = k + 1
            rthk(k) = newthk
            rdep(k) = initdep + rthk(k)
            initdep = rdep(k)
            rvp(k) = vp(i) + (2*j - 1)*(vp(i + 1) - vp(i))/(2*nsublay(i))
            rvs(k) = vs(i) + (2*j - 1)*(vs(i + 1) - vs(i))/(2*nsublay(i))
            rrho(k) = rho(i) + (2*j - 1)*(rho(i + 1) - rho(i))/(2*nsublay(i))
        end do
    end do
    ! half space model
    k = k + 1
    rthk(k) = 0.0
    rvp(k) = vp(mmax)
    rvs(k) = vs(mmax)
    rrho(k) = rho(mmax)
    rdep(k) = dep(mmax)

    rmax = k
    return
end subroutine refineGrid2LayerMdl_parallel

subroutine synthetic_parallel(nx, ny, nz, nparpi, vels, obst, &
                              goxdf, gozdf, dvxdf, dvzdf, kmaxRc, kmaxRg, kmaxLc, kmaxLg, &
                              tRc, tRg, tLc, tLg, wavetype, igrt, periods, depz, minthk, &
                              scxf, sczf, rcxf, rczf, nrc1, nsrcsurf1, kmax, nsrcsurf, nrcf, noiselevel)

    ! use globalp
    use omp_lib
    use traveltime_parallel
    use ThreadDataMod
    use JaggedArrayMod
    use ParallelConfig
    implicit none

    ! CHARACTER (LEN=30) ::grid,frechet
    ! CHARACTER (LEN=40) :: sources,receivers,otimes
    ! CHARACTER (LEN=30) :: travelt,rtravel,wrays,cdum
    INTEGER :: i, j, k, l, nsrc, tnr, urg
    INTEGER :: ogx, ogz, grdfx, grdfz, maxbt
    ! INTEGER :: sgs, isx, isz, sw, idm1, idm2, nnxb, nnzb
    ! REAL(KIND=t_i10) :: x, z, goxb, gozb, dnxb, dnzb
    INTEGER :: isx, isz, sw, idm1, idm2
    REAL(KIND=t_i10) :: x, z

    !REAL(KIND=t_i10), DIMENSION (:,:), ALLOCATABLE :: scxf,sczf
    !REAL(KIND=t_i10), DIMENSION (:,:,:), ALLOCATABLE :: rcxf,rczf
    !
    ! sources = File containing source locations
    ! receivers = File containing receiver locations
    ! grid = File containing grid of velocity vertices for
    !        resampling on a finer grid with cubic B-splines
    ! frechet = output file containing matrix of frechet derivatives
    ! travelt = File name for storage of traveltime field
    ! wttf = Write traveltimes to file? (0=no,>0=source id)
    ! fom = Use first-order(0) or mixed-order(1) scheme
    ! nsrc = number of sources
    ! scx,scz = source location in r,x,z
    ! scx,scz = source location in r,x,z
    ! x,z = temporary variables for source location
    ! fsrt = find source-receiver traveltimes? (0=no,1=yes)
    ! rtravel = output file for source-receiver traveltimes
    ! cdum = dummy character variable ! wrgf = write ray geometries to file? (<0=all,0=no,>0=source id.)
    ! wrays = file containing raypath geometries
    ! cfd = calculate Frechet derivatives? (0=no, 1=yes)
    ! tnr = total number of receivers
    ! sgs = Extent of refined source grid
    ! isx,isz = cell containing source
    ! nnxb,nnzb = Backup for nnz,nnx
    ! goxb,gozb = Backup for gox,goz
    ! dnxb,dnzb = Backup for dnx,dnz
    ! ogx,ogz = Location of refined grid origin
    ! gridfx,grdfz = Number of refined nodes per cell
    ! urg = use refined grid (0=no,1=yes,2=previously used)
    ! maxbt = maximum size of narrow band binary tree
    ! otimes = file containing source-receiver association information
    ! -----------------------------------------------------------------
    ! -------- My VARIABLE Start --------
    integer :: start_date(8), end_date(8)
    integer :: start_date_loop(8), end_date_loop(8)
    integer :: start_date_srtimes(8), end_date_srtimes(8)
    integer :: start_date_travel(8), end_date_travel(8)

    CHARACTER(LEN=100) :: func_name
    integer :: loop_idx, loop_total_Num, loop_cnt
    integer :: max_nnx, max_nnz

    real:: loop_use_time, srtimes_total_time, travel_total_time

    integer, dimension(:), allocatable:: knumi_list, srcnum_list

    integer, dimension(:), allocatable:: all_count
    type(JaggedArrayReal), allocatable :: all_cbst(:)

    TYPE(ThreadData) :: td
    TYPE(ThreadData) :: g_td
    ! -------- My VARIABLE End --------

    !        variables defined by Hongjian Fang
    integer nx, ny, nz
    integer kmax, nsrcsurf, nrcf
    real vels(nx, ny, nz)
    real obst(*)
    real goxdf, gozdf, dvxdf, dvzdf
    integer kmaxRc, kmaxRg, kmaxLc, kmaxLg
    real*8 tRc(*), tRg(*), tLc(*), tLg(*)
    integer wavetype(nsrcsurf, kmax)
    integer periods(nsrcsurf, kmax), nrc1(nsrcsurf, kmax), nsrcsurf1(kmax)
    integer igrt(nsrcsurf, kmax)
    real scxf(nsrcsurf, kmax), sczf(nsrcsurf, kmax), rcxf(nrcf, nsrcsurf, kmax), rczf(nrcf, nsrcsurf, kmax)
    real minthk
    integer nparpi

    real vpz(nz), vsz(nz), rhoz(nz), depz(nz)
    real*8 pvRc(nx*ny, kmaxRc), pvRg(nx*ny, kmaxRg), pvLc(nx*ny, kmaxLc), pvLg(nx*ny, kmaxLg)
    real*8 velf(ny*nx)
    integer kmax1, kmax2, kmax3, count1
    integer igr
    integer iwave
    integer knumi, srcnum
    real cbst1
    real noiselevel
    real gaussian
    external gaussian
    integer ii, jj, kk, nn, istep

    g_td%gdx = 5
    g_td%gdz = 5
    g_td%asgr = 1
    g_td%sgdl = 8
    g_td%sgs = 8
    g_td%earth = 6371.0
    g_td%fom = 1
    g_td%snb = 0.5
    g_td%goxd = goxdf
    g_td%gozd = gozdf
    g_td%dvxd = dvxdf
    g_td%dvzd = dvzdf
    g_td%nvx = nx - 2
    g_td%nvz = ny - 2

    !
    ! Convert from degrees to radians
    !
    g_td%dvx = g_td%dvxd*g_td%pi/180.0
    g_td%dvz = g_td%dvzd*g_td%pi/180.0
    g_td%gox = (90.0 - g_td%goxd)*g_td%pi/180.0
    g_td%goz = g_td%gozd*g_td%pi/180.0
    !
    ! Compute corresponding values for propagation grid.
    !
    g_td%nnx = (g_td%nvx - 1)*g_td%gdx + 1
    g_td%nnz = (g_td%nvz - 1)*g_td%gdz + 1
    g_td%dnx = g_td%dvx/g_td%gdx
    g_td%dnz = g_td%dvz/g_td%gdz
    g_td%dnxd = g_td%dvxd/g_td%gdx
    g_td%dnzd = g_td%dvzd/g_td%gdz

    g_td%rbint = 0

    call date_and_time(values=start_date)
    if (kmaxRc .gt. 0) then
        iwave = 2
        igr = 0
    
        call caldispersion_parallel(nx, ny, nz, vels, pvRc, iwave, igr, kmaxRc, tRc, depz, minthk)

        open (62, file='velmap2dRc_synP.dat')
        do k = 1, kmaxRc
            do j = 1, ny - 2
            do i = 1, nx - 2
             write (62, '(5f8.4)') g_td%gozd + (j - 1)*g_td%dvzd, g_td%goxd - (i - 1)*g_td%dvxd, tRc(k), pvRc((j + 1)*nx + i + 1, k)
            end do
            end do
        end do
        close (62)
    end if
    call date_and_time(values=end_date)
    func_name = "synthetic_parallel caldispersion"
    call cal_run_time(start_date, end_date, func_name, loop_use_time)
    call WriteRunTime("synthetic_parallel caldispersion", loop_use_time)

    if (kmaxRg .gt. 0) then
        iwave = 2
        igr = 1
        call caldispersion_parallel(nx, ny, nz, vels, pvRg, iwave, igr, kmaxRg, tRg, depz, minthk)
        open (62, file='velmap2dRg_synP.dat')
        do k = 1, kmaxRg
            do j = 1, ny - 2
            do i = 1, nx - 2
            write (62, '(5f8.4)') g_td%gozd + (j - 1)*g_td%dvzd, g_td%goxd - (i - 1)*g_td%dvxd, tRg(k), pvRg((j + 1)*nx + i + 1, k)
            end do
            end do
        end do
        close (62)
    end if

    if (kmaxLc .gt. 0) then
        iwave = 1
        igr = 0
        call caldispersion_parallel(nx, ny, nz, vels, pvLc, iwave, igr, kmaxLc, tLc, depz, minthk)

        open (62, file='velmap2dLc_synP.dat')
        do k = 1, kmaxLc
            do j = 1, ny - 2
            do i = 1, nx - 2
            write (62, '(5f8.4)') g_td%gozd + (j - 1)*g_td%dvzd, g_td%goxd - (i - 1)*g_td%dvxd, tLc(k), pvLc((j + 1)*nx + i + 1, k)
            end do
            end do
        end do
        close (62)
    end if

    if (kmaxLg .gt. 0) then
        iwave = 1
        igr = 1
        call caldispersion_parallel(nx, ny, nz, vels, pvLg, iwave, igr, kmaxLg, tLg, depz, minthk)

        open (62, file='velmap2dLg_synP.dat')
        do k = 1, kmaxLg
            do j = 1, ny - 2
            do i = 1, nx - 2
            write (62, '(5f8.4)') g_td%gozd + (j - 1)*g_td%dvzd, g_td%goxd - (i - 1)*g_td%dvxd, tLg(k), pvLg((j + 1)*nx + i + 1, k)
            end do
            end do
        end do
        close (62)
    end if

    ! nar = 0
    count1 = 0

    ! sen_vs = 0
    ! sen_vp = 0
    ! sen_rho = 0
    kmax1 = kmaxRc
    kmax2 = kmaxRc + kmaxRg
    kmax3 = kmaxRc + kmaxRg + kmaxLc

    loop_total_Num = sum(nsrcsurf1(1:kmax))
    ALLOCATE (knumi_list(loop_total_Num), STAT=t_checkstat)
    ALLOCATE (srcnum_list(loop_total_Num), STAT=t_checkstat)
    ALLOCATE (all_count(loop_total_Num), STAT=t_checkstat)

    max_nnx = MAX(g_td%nnx, (MIN(g_td%nnx - 1, 2 * g_td%sgs) * g_td%sgdl + 1))
    max_nnz = MAX(g_td%nnz, (MIN(g_td%nnz - 1, 2 * g_td%sgs) * g_td%sgdl + 1))

    loop_total_Num = 0
    do knumi = 1, kmax
        do srcnum = 1, nsrcsurf1(knumi)
            loop_total_Num = loop_total_Num + 1
            knumi_list(loop_total_Num) = knumi
            srcnum_list(loop_total_Num) = srcnum

            all_count(loop_total_Num) = nrc1(srcnum, knumi)
        end do
    end do


    call init_thread_data_matrix(g_td, max_nnx, max_nnz)
    call init_jagged_array(all_cbst, all_count)

    call date_and_time(values=start_date)
    !$omp parallel do num_threads(ThreadNum) &
    !$omp default(None) &
    !$omp shared(loop_total_Num, g_td) &
    !$omp shared(wavetype, igrt, periods, pvRc, pvRg, pvLc, pvLg) &
    !$omp shared(nx, ny, nsrcsurf1, nrc1, scxf, sczf, rcxf, rczf, noiselevel) &
    !$omp shared(knumi_list, srcnum_list, all_cbst) &
    !$omp private(loop_idx, knumi, srcnum, x, z, urg, count1, cbst1) &
    !$omp private(isx, isz, sw) &
    !$omp private(idm1, idm2, ogx, ogz, grdfx, grdfz, k, l, j) &
    !$omp private(td, velf)
    do loop_idx = 1, loop_total_Num
        td = g_td
        td%tid = loop_idx

        knumi = knumi_list(loop_idx)
        srcnum = srcnum_list(loop_idx)

        if (wavetype(srcnum, knumi) == 2 .and. igrt(srcnum, knumi) == 0) then
            velf(1:nx*ny) = pvRc(1:nx*ny, periods(srcnum, knumi))
        end if
        if (wavetype(srcnum, knumi) == 2 .and. igrt(srcnum, knumi) == 1) then
            velf(1:nx*ny) = pvRg(1:nx*ny, periods(srcnum, knumi))
        end if
        if (wavetype(srcnum, knumi) == 1 .and. igrt(srcnum, knumi) == 0) then
            velf(1:nx*ny) = pvLc(1:nx*ny, periods(srcnum, knumi))
        end if
        if (wavetype(srcnum, knumi) == 1 .and. igrt(srcnum, knumi) == 1) then
            velf(1:nx*ny) = pvLg(1:nx*ny, periods(srcnum, knumi))
        end if

        call gridder_parallel(velf, td)
        x = scxf(srcnum, knumi)
        z = sczf(srcnum, knumi)
        !
        !  Begin by computing refined source grid if required
        !
        urg = 0
        IF (td%asgr .EQ. 1) THEN
            !
            !     Back up coarse velocity grid to a holding matrix
            !
            ! MODIFIEDY BY HONGJIAN FANG @ USTC 2014/04/17
            td%velnb(1:td%nnz, 1:td%nnx) = td%veln(1:td%nnz, 1:td%nnx)
            td%nnxb = td%nnx
            td%nnzb = td%nnz
            td%dnxb = td%dnx
            td%dnzb = td%dnz
            td%goxb = td%gox
            td%gozb = td%goz
            !
            !     Identify nearest neighbouring node to source
            !
            isx = INT((x - td%gox)/td%dnx) + 1
            isz = INT((z - td%goz)/td%dnz) + 1
            sw = 0
            IF (isx .lt. 1 .or. isx .gt. td%nnx) sw = 1
            IF (isz .lt. 1 .or. isz .gt. td%nnz) sw = 1
            IF (sw .eq. 1) then
                x = 90.0 - x*180.0/td%pi
                z = z*180.0/td%pi
                WRITE (6, *) "Iteration", td%tid, "synP_loop: Source lies outside bounds of model (lat, long)= ", x, z
                WRITE (6, *) "TERMINATING PROGRAM!!!"
                STOP
            END IF
            IF (isx .eq. td%nnx) isx = isx - 1
            IF (isz .eq. td%nnz) isz = isz - 1
            !
            !     Now find rectangular box that extends outward from the nearest source node
            !     to "sgs" nodes away.
            !
            td%vnl = isx - td%sgs
            IF (td%vnl .lt. 1) td%vnl = 1
            td%vnr = isx + td%sgs
            IF (td%vnr .gt. td%nnx) td%vnr = td%nnx
            td%vnt = isz - td%sgs
            IF (td%vnt .lt. 1) td%vnt = 1
            td%vnb = isz + td%sgs
            IF (td%vnb .gt. td%nnz) td%vnb = td%nnz
            td%nrnx = (td%vnr - td%vnl)*td%sgdl + 1
            td%nrnz = (td%vnb - td%vnt)*td%sgdl + 1
            td%drnx = td%dvx/REAL(td%gdx*td%sgdl)
            td%drnz = td%dvz/REAL(td%gdz*td%sgdl)
            td%gorx = td%gox + td%dnx*(td%vnl - 1)
            td%gorz = td%goz + td%dnz*(td%vnt - 1)
            td%nnx = td%nrnx
            td%nnz = td%nrnz
            td%dnx = td%drnx
            td%dnz = td%drnz
            td%gox = td%gorx
            td%goz = td%gorz
            !
            !     Reallocate velocity and traveltime arrays if nnx>nnxb or
            !     nnz<nnzb.
            !
            IF (td%nnx .GT. td%nnxb .OR. td%nnz .GT. td%nnzb) THEN
                idm1 = td%nnx
                IF (td%nnxb .GT. idm1) idm1 = td%nnxb
                idm2 = td%nnz
                IF (td%nnzb .GT. idm2) idm2 = td%nnzb
                ! DEALLOCATE (veln, ttn, nsts, btg)
                ! ALLOCATE (veln(idm2, idm1))
                ! ALLOCATE (ttn(idm2, idm1))
                ! ALLOCATE (nsts(idm2, idm1))
                ! maxbt = NINT(snb*idm1*idm2)
                ! ALLOCATE (btg(maxbt))
            END IF
            !
            !     Call a subroutine to compute values of refined velocity nodes
            !        
            CALL bsplrefine_parallel(td)
            !
            !     Compute first-arrival traveltime field through refined grid.
            !
            urg = 1
            CALL travel_parallel(x, z, urg, td)
            !
            !     Now map refined grid onto coarse grid.
            !
            ! ALLOCATE (ttnr(nnzb, nnxb))
            ! ALLOCATE (nstsr(nnzb, nnxb))
            IF (td%nnx .GT. td%nnxb .OR. td%nnz .GT. td%nnzb) THEN
                idm1 = td%nnx
                IF (td%nnxb .GT. idm1) idm1 = td%nnxb
                idm2 = td%nnz
                IF (td%nnzb .GT. idm2) idm2 = td%nnzb
                ! DEALLOCATE (ttnr, nstsr)
                ! ALLOCATE (ttnr(idm2, idm1))
                ! ALLOCATE (nstsr(idm2, idm1))
            END IF

            td%ttnr = td%ttn
            td%nstsr = td%nsts
            ogx = td%vnl
            ogz = td%vnt
            grdfx = td%sgdl
            grdfz = td%sgdl

            td%nsts = -1
            DO k = 1, td%nnz, grdfz
                idm1 = ogz + (k - 1)/grdfz
                DO l = 1, td%nnx, grdfx
                    idm2 = ogx + (l - 1)/grdfx
                    td%nsts(idm1, idm2) = td%nstsr(k, l)
                    IF (td%nsts(idm1, idm2) .GE. 0) THEN
                        td%ttn(idm1, idm2) = td%ttnr(k, l)
                    END IF
                END DO
            END DO
            !
            !     Backup refined grid information
            !
            td%nnxr = td%nnx
            td%nnzr = td%nnz
            td%goxr = td%gox
            td%gozr = td%goz
            td%dnxr = td%dnx
            td%dnzr = td%dnz
            !
            !     Restore remaining values.
            !
            td%nnx = td%nnxb
            td%nnz = td%nnzb
            td%dnx = td%dnxb
            td%dnz = td%dnzb
            td%gox = td%goxb
            td%goz = td%gozb
 
            DO j = 1, td%nnx
                DO k = 1, td%nnz
                    td%veln(k, j) = td%velnb(k, j)
                END DO
            END DO
            !
            !     Ensure that the narrow band is complete; if
            !     not, then some alive points will need to be
            !     made close.
            !
            DO k = 1, td%nnx
                DO l = 1, td%nnz
                    IF (td%nsts(l, k) .EQ. 0) THEN
                        IF (l - 1 .GE. 1) THEN
                            IF (td%nsts(l - 1, k) .EQ. -1) td%nsts(l, k) = 1
                        END IF
                        IF (l + 1 .LE. td%nnz) THEN
                            IF (td%nsts(l + 1, k) .EQ. -1) td%nsts(l, k) = 1
                        END IF
                        IF (k - 1 .GE. 1) THEN
                            IF (td%nsts(l, k - 1) .EQ. -1) td%nsts(l, k) = 1
                        END IF
                        IF (k + 1 .LE. td%nnx) THEN
                            IF (td%nsts(l, k + 1) .EQ. -1) td%nsts(l, k) = 1
                        END IF
                    END IF
                END DO
            END DO
            !
            !     Finally, call routine for computing traveltimes once
            !     again.
            !
            urg = 2
            CALL travel_parallel(x, z, urg, td)
        ELSE
            !
            !     Call a subroutine that works out the first-arrival traveltime
            !     field.
            !
            CALL travel_parallel(x, z, urg, td)
        END IF


        count1 = 0
        do istep = 1, nrc1(srcnum, knumi)
            CALL srtimes_parallel(x, z, rcxf(istep, srcnum, knumi), rczf(istep, srcnum, knumi), cbst1, td)
            count1 = count1 + 1
            all_cbst(loop_idx)%row(count1) = cbst1 + cbst1*gaussian()*noiselevel
            ! obst(count1) = cbst1 + cbst1*gaussian()*noiselevel
        end do
    end do
    !$omp end parallel do
   
    count1 = 0
    do loop_idx = 1, loop_total_Num
        srcnum = srcnum_list(loop_idx)
        knumi = knumi_list(loop_idx)
        do istep = 1, nrc1(srcnum, knumi)
            count1 = count1 + 1
            obst(count1) = all_cbst(loop_idx)%row(istep)
        end do
    end do
    call date_and_time(values=end_date)

    func_name = ""
    call cal_run_time(start_date, end_date, func_name, loop_use_time)
    
    write (*, '("synthetic_parallel travel Time:", F10.4)') loop_use_time
    call WriteRunTime("synthetic_parallel travel", loop_use_time)
    

    deallocate (knumi_list, srcnum_list, all_count, STAT=t_checkstat)
    call free_thread_data(g_td)
    call free_jagged_array(all_cbst)
END subroutine

subroutine caldispersion_parallel(nx, ny, nz, vel, pvRc, iwave, igr, kmaxRc, tRc, depz, minthk)
    use omp_lib
    use ParallelConfig, only:ThreadNum
    use BinaryIO, only: WriteArray_binary_2D, WriteArray_binary_3D
    implicit none

    integer nx, ny, nz
    real vel(nx, ny, nz)

    integer iwave, igr
    real minthk
    real depz(nz)
    integer kmaxRc
    real*8 tRc(kmaxRc)
    real*8 pvRc(nx*ny, kmaxRc)

    real vpz(nz), vsz(nz), rhoz(nz)
    integer mmax, iflsph, mode, rmax
    integer ii, jj, k, i, nn, kk
    integer, parameter::NL = 200
    integer, parameter::NP = 80
    real*8 cg1(NP), cg2(NP), cga, cgRc(NP)
    real rdep(NL), rvp(NL), rvs(NL), rrho(NL), rthk(NL)
    real depm(NL), vpm(NL), vsm(NL), rhom(NL), thkm(NL)
    real dlnVs, dlnVp, dlnrho
    integer loop_idx, loop_total_Num
    integer all_ii(nx * ny), all_jj(nx * ny)

    mmax = nz
    iflsph = 1
    mode = 1
    dlnVs = 0.01
    dlnVp = 0.01
    dlnrho = 0.01

    !$omp parallel num_threads(ThreadNum) &
    !$omp default(private) &
    !$omp shared(depz,nx,ny,nz,minthk,kmaxRc,mmax,vel) &
    !$omp shared(tRc,pvRc,iflsph,iwave,mode,igr)
    !$omp do collapse(2)
    do jj = 1, ny
        do ii = 1, nx
            vsz(1:nz) = vel(ii, jj, 1:nz)
            ! some other emperical relationship maybe better
            vpz = 0.9409 + 2.0947*vsz - 0.8206*vsz**2 + 0.2683*vsz**3 - 0.0251*vsz**4
            rhoz = 1.6612*vpz - 0.4721*vpz**2 + 0.0671*vpz**3 - 0.0043*vpz**4 + 0.000106*vpz**5
            call refineGrid2LayerMdl_parallel(minthk, mmax, depz, vpz, vsz, rhoz, rmax, rdep, rvp, rvs, rrho, rthk)
            call surfdisp96(rthk, rvp, rvs, rrho, rmax, iflsph, iwave, mode, igr, kmaxRc, tRc, cgRc)
            pvRc((jj - 1)*nx + ii, 1:kmaxRc) = cgRc(1:kmaxRc)
        end do
    end do
    !$omp end do
    !$omp end parallel
end subroutine