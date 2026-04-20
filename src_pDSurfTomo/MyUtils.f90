module Utils
    implicit none
    interface ts
        module procedure:: int_to_str
        module procedure:: real4_to_str
        module procedure:: real8_to_str
    end interface ts

contains

    subroutine cal_run_time(start_date, end_date, func_name, elapsed_sec)
        integer, intent(in) :: start_date(8), end_date(8)
        real:: start_sec, end_sec, elapsed_sec
        CHARACTER(LEN=100) :: func_name

        start_sec = start_date(5)*3600 + start_date(6)*60 + start_date(7) + start_date(8)/1000.
        end_sec = end_date(5)*3600 + end_date(6)*60 + end_date(7) + end_date(8)/1000.

        elapsed_sec = end_sec - start_sec
        if (elapsed_sec < 0) then
            elapsed_sec = elapsed_sec + 24*3600
        end if

        if (len_trim(func_name) > 0) then
            write (*, '(A, " Time:", F10.4)') trim(adjustl(func_name)), elapsed_sec
        end if
    end subroutine cal_run_time

    function int_to_str(i) result(str)
        integer, intent(in) :: i
        character(len=:), allocatable :: str
        character(len=32) :: tmp
        write (tmp, '(I0)') i
        str = trim(adjustl(tmp))
    end function int_to_str

    function real4_to_str(x) result(str)
        real, intent(in) :: x
        character(len=:), allocatable :: str
        character(len=32) :: tmp
        write (tmp, '(f20.6)') x
        str = trim(adjustl(tmp))
    end function real4_to_str

    function real8_to_str(x) result(str)
        real(8), intent(in) :: x
        character(len=:), allocatable :: str
        character(len=32) :: tmp
        write (tmp, '(f20.6)') x
        str = trim(adjustl(tmp))
    end function real8_to_str

    subroutine cumsum(arr, res_arr)
        implicit none
        integer, intent(in) :: arr(:)
        integer, intent(out) :: res_arr(:)
        integer :: nn
        do nn = 1, size(arr)
            if (nn == 1) then
                res_arr(nn) = 0
            else
                res_arr(nn) = res_arr(nn - 1) + arr(nn - 1)
            end if
        end do
    end subroutine cumsum
end module Utils

module ParallelConfig
    use Utils
    implicit none
    character(len=:), allocatable :: parallel_config_file
    integer :: ThreadNum = 64

    integer :: Iteration = 1
    integer :: log_unit
    real:: smooth_weight = 0.0

    character(len=10) :: lsmr_float_dtype = "float32"
    ! character(len=10) :: lsmr_float_dtype = "float64"

    character(len=100) :: dir = "InvResult"

    character(len=20) :: tt_type = "default"
    ! character(len=20) :: tt_type = "parallel"

    character(len=20) :: senK_type = "default"
    ! character(len=20) :: senK_type = "parallel"
    ! character(len=20) :: senK_type = "disba"

    character(len=20) :: lsmr_type = "default"
    ! character(len=20) :: lsmr_type = "scipy"
    ! character(len=20) :: lsmr_type = "cupy"

    logical :: is_tt_parallel, is_senK_disba, is_lsmr_py

    character(len=:), allocatable :: lsmr_script_path, senK_script_path
contains

   subroutine mkdir_py(path)
        implicit none
        character(len=*), intent(in) :: path
        character(len=:), allocatable :: cmd
        cmd = 'python -c "import os; os.makedirs(''' // trim(path)  // ''', exist_ok=True)"'
        call system(trim(cmd))
    end subroutine mkdir_py

    subroutine cp_py(src, dst)
        implicit none
        character(len=*), intent(in) :: src, dst
        character(len=:), allocatable :: cmd
        cmd = 'python -c "import shutil; shutil.copy2(''' // trim(src) // ''', ''' // trim(dst) // ''')"'
        call system(trim(cmd))
    end subroutine cp_py

    subroutine parse_ParallelConfig()
        logical :: file_exists
        character(len=1024) :: line, key, val
        integer :: stat, unit, sep_pos, io_err

        inquire (file=parallel_config_file, exist=file_exists)
        if (.not. file_exists) then
            print *, "Config File: ", trim(parallel_config_file), " not exist, Stop"
            stop
        else
            print *, "Read Config File: ", trim(parallel_config_file)
        end if

        open (newunit=unit, file=parallel_config_file, status='old', iostat=stat)
        do
            read (unit, '(A)', iostat=stat) line
            if (stat /= 0) exit

            line = adjustl(line)
            if (len_trim(line) == 0) cycle
            if (line(1:1) == ";") cycle

            sep_pos = index(line, "=")
            if (sep_pos == 0) cycle

            key = trim(adjustl(line(1:sep_pos - 1)))
            val = trim(adjustl(line(sep_pos + 1:)))

            select case (trim(key))
            case ("tt_senK_lsmr")
                tt_type = trim(val)
                read (val, *, iostat=io_err) tt_type, senK_type, lsmr_type
                is_tt_parallel = (tt_type == "parallel")
                is_senK_disba = (senK_type == "disba")
                is_lsmr_py = (lsmr_type == "scipy" .or. lsmr_type == "cupy")

            case ("lsmr_float_dtype")
                lsmr_float_dtype = trim(val)

            case ("InvResultDir")
                dir = trim(val)

            case ("senK_script_path")
                senK_script_path = trim(val)

            case ("lsmr_script_path")
                lsmr_script_path = trim(val)

            case ("ThreadNum")
                read (val, *) ThreadNum

            end select
        end do
        close (unit)

        print *, "Paralle Config:"
        print *, "ThreadNum = ", ts(ThreadNum)
        print *, "tt_type = ", trim(tt_type)
        print *, "senK_type = ", trim(senK_type)
        print *, "lsmr_type = ", trim(lsmr_type)
        ! print *, "senK_script_path = ", trim(senK_script_path)
        ! print *, "lsmr_script_path = ", trim(lsmr_script_path)
        ! print *, "lsmr_float_dtype = ", trim(lsmr_float_dtype)
        ! print *, "InvResultDir = ", trim(dir)
        ! print *, "is_model_from_bin = ", is_model_from_bin
        print *, ""
    end subroutine parse_ParallelConfig

    subroutine init_ParallelConfig()
        implicit none

        call parse_ParallelConfig()

        if (.not. is_tt_parallel) then
            is_senK_disba = .false.
            is_lsmr_py = .false.
        end if

        if (is_senK_disba) then
            senK_type = "disba"
        else
            if (is_tt_parallel) then
                senK_type = "parallel"
            else
                senK_type = "default"
            end if
        end if

        if (.not. is_lsmr_py) then
            lsmr_type = "default"
        end if

        call mkdir_py("senK")
        call mkdir_py("LSMR")
        call mkdir_py(get_path("dir"))
        open (newunit=log_unit, file=get_path("log"), status="replace")
    end subroutine init_ParallelConfig

    subroutine print_ParallelConfig()
        print *, "Iteration = ", ts(Iteration)
        print *, "ThreadNum = ", ts(ThreadNum)
        print *, "is_tt_parallel = ", is_tt_parallel
        print *, "is_senK_disba = ", is_senK_disba
        print *, "is_lsmr_py = ", is_lsmr_py
        print *, "tt_type = ", tt_type
        print *, "senK_type = ", senK_type
        print *, "lsmr_type = ", lsmr_type
        print *, "senK_script_path = ", senK_script_path
        print *, "lsmr_script_path = ", lsmr_script_path
        print *, "lsmr_float_dtype = ", lsmr_float_dtype
        print *, "dir = ", get_path("dir")
        print *, "vs_file = ", get_path("vs")
        print *, "dv_file = ", get_path("dv")
        print *, "log_file = ", get_path("log")
        print *, "log_file_unit = ", log_unit
    end subroutine print_ParallelConfig

    subroutine WriteRunTime(func_name, use_time)
        character(len=*), intent(in) :: func_name
        real(4), intent(in) :: use_time
        write (log_unit, '(A, " Time:", F10.4)') trim(adjustl(func_name)), use_time
    end subroutine WriteRunTime

    subroutine test_ParallelConfig()
        implicit none
        call init_ParallelConfig()
        call print_ParallelConfig()
        close (log_unit)
    end subroutine test_ParallelConfig

    ! function get_inv_folder_name() result(folder_name)
    !     character(len=:), allocatable :: folder_name
    !     folder_name = "tt_" // trim(tt_type) // "_senK_" // trim(senK_type) // "_lsmr_" // trim(lsmr_type) // &
    !     "_td_" // ts(ThreadNum)
    ! end function get_inv_folder_name

    function get_inv_folder_name() result(folder_name)
        character(len=:), allocatable :: folder_name
        folder_name = "tt_" // trim(tt_type) // "_senK_" // trim(senK_type) // "_lsmr_" // trim(lsmr_type)
    end function get_inv_folder_name

    function get_path(path_type) result(filename)
        character(len=*), intent(in) :: path_type
        character(len=:), allocatable :: tmp, filename
 
        if (trim(path_type) == "dir") then
            tmp = trim(dir) // "/" // get_inv_folder_name() 
        
        else if (trim(path_type) == "vs") then
            tmp = trim(dir) // "/" // get_inv_folder_name() // "/" //"vs_" // ts(Iteration) // ".bin"
        
        else if (trim(path_type) == "dv") then
            tmp = trim(dir) // "/" // get_inv_folder_name() // "/" //"dv_" // ts(Iteration) // ".bin"
        
        else if (trim(path_type) == "log") then
            tmp = trim(dir) // "/" // get_inv_folder_name() // "/" // "run_time.log"
        end if

        filename = trim(adjustl(tmp))
    end function get_path

end module ParallelConfig

module LSMR_Solver
    implicit none

contains
    subroutine run_lsmr(m, n, damp)
        use ParallelConfig, only: get_path, lsmr_float_dtype, lsmr_type, lsmr_script_path
        use Utils, only: ts
        implicit none
        integer, intent(in) :: m, n
        real, intent(in) :: damp
        character(len=:), allocatable :: command, int_dtype
        integer :: status
        if (kind(status) == 4) then
            int_dtype = "int32"
        else
            int_dtype = "int64"
        end if

        command = "python " // trim(lsmr_script_path) // " --lsmr_type " // trim(lsmr_type) // &
                  " --m " // ts(m) // " --n " // ts(n) // " --damp "// ts(damp) //  &
                  " --dv_path " // get_path("dv") // &
                  " --float_dtype " // trim(lsmr_float_dtype) // " --int_dtype " // trim(int_dtype)
        write (*, '("CMD: ", A)') trim(command)
        call SYSTEM(command, status)

        ! if (status /= 0) then
        !     print *, 'Python script Run Error! Exit.'
        !     stop
        ! end if
    end subroutine run_lsmr

    subroutine ReadLSMR_res(filename, dv, vector_size)
        use ParallelConfig, only: lsmr_float_dtype
        implicit none
        character(len=*), intent(in) :: filename
        integer, intent(in) :: vector_size
        real(4), intent(out) :: dv(:)
        real(8) :: vector(vector_size)
        integer :: unit, ierr
        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        if (trim(lsmr_float_dtype) == "float64") then
            read (unit, iostat=ierr) vector(1:vector_size)
            dv = real(vector, 4)
        else if (trim(lsmr_float_dtype) == "float32") then
            read (unit, iostat=ierr) dv(1:vector_size)
        end if
        close (unit)
    end subroutine ReadLSMR_res

end module LSMR_Solver

module senK_Solver
    implicit none

contains
    subroutine run_senK(minthk, nx, ny, nz, ifunc, itype)
        use ParallelConfig, only: senK_script_path, ThreadNum
        use Utils, only: ts
        implicit none
        integer, intent(in)  :: nx, ny, nz, ifunc, itype
        real, intent(in) :: minthk
        character(len=:), allocatable :: command
        integer:: status
        command = "python " // trim(senK_script_path) // " --minthk " // ts(minthk) // &
                  " --nx " // ts(nx) // " --ny " // ts(ny) // " --nz "// ts(nz) // &
                  " --ifunc " // ts(ifunc) // " --itype " // ts(itype) // " --ThreadNum " // ts(ThreadNum)
        write (*, '("CMD: ", A)') trim(command)
        call SYSTEM(command, status)

        ! if (status /= 0) then
        !     print *, 'Python script Run Error! Exit.'
        !     stop
        ! end if
    end subroutine run_senK

end module senK_Solver

module BinaryIO
    implicit none

    interface ReadArray_binary_1D
        module procedure read_int_binary_1D
        module procedure read_real4_binary_1D
        module procedure read_real8_binary_1D
    end interface ReadArray_binary_1D

    interface ReadArray_binary_2D
        module procedure read_int_binary_2D
        module procedure read_real4_binary_2D
        module procedure read_real8_binary_2D
    end interface ReadArray_binary_2D

    interface ReadArray_binary_3D
        module procedure read_int_binary_3D
        module procedure read_real4_binary_3D
        module procedure read_real8_binary_3D
    end interface ReadArray_binary_3D

    interface WriteArray_binary_1D
        module procedure write_int_binary_1D
        module procedure write_real4_binary_1D
        module procedure write_real8_binary_1D
    end interface WriteArray_binary_1D

    interface WriteArray_binary_2D
        module procedure write_int_binary_2D
        module procedure write_real4_binary_2D
        module procedure write_real8_binary_2D
    end interface WriteArray_binary_2D

    interface WriteArray_binary_3D
        module procedure write_int_binary_3D
        module procedure write_real4_binary_3D
        module procedure write_real8_binary_3D
    end interface WriteArray_binary_3D

    interface show_bit
        module procedure show_bit_int
        module procedure show_bit_real4
        module procedure show_bit_real8
    end interface show_bit
contains

    subroutine read_int_binary_1D(filename, vector, vector_size)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: vector(:)
        integer, intent(in) :: vector_size
        integer :: unit, ierr

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit, iostat=ierr) vector(1:vector_size)
        close (unit)
    end subroutine read_int_binary_1D

    subroutine read_real4_binary_1D(filename, vector, vector_size)
        character(len=*), intent(in) :: filename
        real(4), intent(out) :: vector(:)
        integer, intent(in) :: vector_size
        integer :: unit, ierr

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit, iostat=ierr) vector(1:vector_size)
        close (unit)
    end subroutine read_real4_binary_1D

    subroutine read_real8_binary_1D(filename, vector, vector_size)
        character(len=*), intent(in) :: filename
        real(8), intent(out) :: vector(:)
        integer, intent(in) :: vector_size
        integer :: unit, ierr

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit, iostat=ierr) vector(1:vector_size)
        close (unit)
    end subroutine read_real8_binary_1D

    subroutine write_int_binary_1D(vector, filename, vector_size)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: vector_size
        integer, intent(in) :: vector(:)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) vector(1:vector_size)
        close (unit)
    end subroutine write_int_binary_1D

    subroutine write_real4_binary_1D(vector, filename, vector_size)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: vector_size
        real(4), intent(in) :: vector(:)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) vector(1:vector_size)
        close (unit)
    end subroutine write_real4_binary_1D

    subroutine write_real8_binary_1D(vector, filename, vector_size)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: vector_size
        real(8), intent(in) :: vector(:)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) vector(1:vector_size)
        close (unit)
    end subroutine write_real8_binary_1D

    subroutine read_int_binary_2D(filename, array)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_int_binary_2D

    subroutine read_real4_binary_2D(filename, array)
        character(len=*), intent(in) :: filename
        real(4), intent(out) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_real4_binary_2D

    subroutine read_real8_binary_2D(filename, array)
        character(len=*), intent(in) :: filename
        real(8), intent(out) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_real8_binary_2D

    subroutine write_int_binary_2D(array, filename)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_int_binary_2D

    subroutine write_real4_binary_2D(array, filename)
        character(len=*), intent(in) :: filename
        real(4), intent(in) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_real4_binary_2D

    subroutine write_real8_binary_2D(array, filename)
        character(len=*), intent(in) :: filename
        real(8), intent(in) :: array(:, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_real8_binary_2D

    subroutine read_int_binary_3D(filename, array)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_int_binary_3D

    subroutine read_real4_binary_3D(filename, array)
        character(len=*), intent(in) :: filename
        real(4), intent(out) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_real4_binary_3D

    subroutine read_real8_binary_3D(filename, array)
        character(len=*), intent(in) :: filename
        real(8), intent(out) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='old', action='read')
        read (unit) array
        close (unit)
    end subroutine read_real8_binary_3D

    subroutine write_int_binary_3D(array, filename)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_int_binary_3D

    subroutine write_real4_binary_3D(array, filename)
        character(len=*), intent(in) :: filename
        real(4), intent(in) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_real4_binary_3D

    subroutine write_real8_binary_3D(array, filename)
        character(len=*), intent(in) :: filename
        real(8), intent(in) :: array(:, :, :)
        integer :: unit

        open (newunit=unit, file=filename, form='unformatted', access='stream', status='replace')
        write (unit) array
        close (unit)
    end subroutine write_real8_binary_3D

    subroutine show_bit_int(x)
        integer(4), intent(in) :: x
        print '(A, B32.32)', 'Binary: ', x
    end subroutine

    subroutine show_bit_real4(x)
        real(4), intent(in) :: x
        integer(4) :: int_val

        int_val = transfer(x, 1_4)
        print '(A, B32.32)', 'Binary: ', int_val
    end subroutine

    subroutine show_bit_real8(x)
        real(8), intent(in) :: x
        integer(8) :: int_val

        int_val = transfer(x, 1_8)
        print '(A, B64.64)', 'Binary: ', int_val
    end subroutine

    subroutine test()
        implicit none

        real(4), allocatable :: vec_r4_write(:), vec_r4_read(:)
        real(8), allocatable :: vec_r8_write(:), vec_r8_read(:)
        integer :: i, n
        character(len=20) :: filename_r4, filename_r8

        n = 5
        filename_r4 = 'test_real4.bin'
        filename_r8 = 'test_real8.bin'

        allocate (vec_r4_write(n), vec_r4_read(n))
        allocate (vec_r8_write(n), vec_r8_read(n))

        do i = 1, n
            vec_r4_write(i) = real(i)*1.1_4
            vec_r8_write(i) = real(i)*2.2_8
        end do

        print *, "Write Data real(4):", vec_r4_write
        call WriteArray_binary_1D(vec_r4_write, filename_r4, n)
        call ReadArray_binary_1D(filename_r4, vec_r4_read, n)

        print *, "Write Data real(8):", vec_r8_write
        call WriteArray_binary_1D(vec_r8_write, filename_r8, n)
        call ReadArray_binary_1D(filename_r8, vec_r8_read, n)

        print *, 'Real(4) bin comparison:'
        do i = 1, n
            call show_bit(vec_r4_write(i))
            call show_bit(vec_r4_read(i))
        end do

        print *, 'Real(8) bin comparison:'
        do i = 1, n
            call show_bit(vec_r8_write(i))
            call show_bit(vec_r8_read(i))
        end do

        deallocate (vec_r4_write, vec_r4_read, vec_r8_write, vec_r8_read)

    end subroutine test

    subroutine check_bin_file_equal(f1, f2)
        character(len=*), intent(in) :: f1, f2
        integer(kind=1), allocatable :: d1(:), d2(:)
        integer :: s1, s2, u1, u2
        logical :: file_equal

        inquire (file=f1, size=s1)
        inquire (file=f2, size=s2)

        if (s1 /= s2) then
            file_equal = .false.
            return
        end if

        allocate (d1(s1), d2(s2))
        open (newunit=u1, file=f1, form='unformatted', access='stream', action='read')
        open (newunit=u2, file=f2, form='unformatted', access='stream', action='read')
        read (u1) d1
        read (u2) d2
        close (u1)
        close (u2)

        file_equal = all(d1 == d2)
        print *, file_equal

        deallocate (d1, d2)
    end subroutine check_bin_file_equal
end module BinaryIO