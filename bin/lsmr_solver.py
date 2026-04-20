"""
* Author: Shaohang Zhu (USTC) : zshang@mail.ustc.edu.cn
* Date: 2026/4/20
* Description:
* Copyright (c) 2026 Shaohang Zhu.
"""

import time
import numpy as np
import argparse


def savebinfloat32(filename, obj):
    with open(filename, "wb") as f:
        np.asarray(obj, dtype = np.float32).tofile(f)


def savebinfloat64(filename, obj):
    with open(filename, "wb") as f:
        np.asarray(obj, dtype = np.float64).tofile(f)


def solve_lsmr_scipy(args, atol = 1e-6, btol = 1e-6, conlim = 100, maxiter = 400):
    m = args.m
    n = args.n
    damp = args.damp
    float_dtype = np.float32 if args.float_dtype == "float32" else np.float64
    int_dtype = np.int32 if args.int_dtype == "int32" else np.int64

    col = np.memmap(f"{args.dir}/col.bin", dtype = int_dtype, mode = "r")
    row_count = np.memmap(f"{args.dir}/row_count.bin", dtype = int_dtype, mode = "r")
    data = np.memmap(f"{args.dir}/rw.bin", dtype = np.float32, mode = "r")
    cbst = np.memmap(f"{args.dir}/cbst.bin", dtype = np.float32, mode = "r")
    if data.dtype != float_dtype:
        data = data.astype(float_dtype)
        cbst = cbst.astype(float_dtype)

    col_indices = col - 1
    row_indptr = np.cumsum(np.concatenate([np.array([0]), row_count]))

    A = csr_matrix_scipy((data, col_indices, row_indptr), shape = (m, n))
    res_scipy = lsmr_scipy(A, cbst, damp = damp, atol = atol, btol = btol, conlim = conlim, maxiter = maxiter)

    if args.float_dtype == "float64":
        savebinfloat64(args.dv_path, res_scipy[0])
    else:
        savebinfloat32(args.dv_path, res_scipy[0])


def solve_lsmr_cupy_small_GPU(args, atol = 1e-6, btol = 1e-6, conlim = 100, maxiter = 400):
    """
    CuPy-LSMR, optimized for GPUs with small VRAM capacities.

    Recommendation:
    **HIGHLY RECOMMENDED AS DEFAULT**.
    When GPU VRAM is insufficient, this approach is significantly faster than the large-VRAM version.
    When GPU VRAM is sufficient, the performance penalty is negligible compared to the large-VRAM version.
    """
    m = args.m
    n = args.n
    damp = args.damp
    float_dtype = np.float32 if args.float_dtype == "float32" else np.float64
    int_dtype = np.int32 if args.int_dtype == "int32" else np.int64

    col = np.memmap(f"{args.dir}/col.bin", dtype = int_dtype, mode = "r")
    row_count = np.memmap(f"{args.dir}/row_count.bin", dtype = int_dtype, mode = "r")
    data = np.memmap(f"{args.dir}/rw.bin", dtype = np.float32, mode = "r")
    cbst = np.memmap(f"{args.dir}/cbst.bin", dtype = np.float32, mode = "r")
    if data.dtype != float_dtype:
        data = data.astype(float_dtype)
        cbst = cbst.astype(float_dtype)

    col_indices = col - 1
    row_indptr = np.cumsum(np.concatenate([np.array([0]), row_count]))

    A = csr_matrix_scipy((data, col_indices, row_indptr), shape = (m, n))
    A_gpu = csr_matrix_cupy(A)
    cbst_gpu = cp.asarray(cbst)

    res_cupy = lsmr_cupy(A_gpu, cbst_gpu, damp = damp, atol = atol, btol = btol, conlim = conlim, maxiter = maxiter)

    if args.float_dtype == "float64":
        savebinfloat64(args.dv_path, cp.asnumpy(res_cupy[0]))
    else:
        savebinfloat32(args.dv_path, cp.asnumpy(res_cupy[0]))


def solve_lsmr_cupy_large_GPU(args, atol = 1e-6, btol = 1e-6, conlim = 100, maxiter = 400):
    """
    CuPy-LSMR, optimized for GPUs with large VRAM capacities.

    Recommendation:
    Use only if you are absolutely certain the target GPU has massive VRAM.
    When VRAM is sufficient, this function is slightly faster due to GPU-accelerated array building.
    But when VRAM is insufficient, performance degrades drastically compared to the small-VRAM version.
    """
    m = args.m
    n = args.n
    damp = args.damp
    float_dtype = np.float32 if args.float_dtype == "float32" else np.float64
    int_dtype = np.int32 if args.int_dtype == "int32" else np.int64

    col = np.memmap(f"{args.dir}/col.bin", dtype = int_dtype, mode = "r")
    row_count = np.memmap(f"{args.dir}/row_count.bin", dtype = int_dtype, mode = "r")
    data = np.memmap(f"{args.dir}/rw.bin", dtype = np.float32, mode = "r")
    cbst = np.memmap(f"{args.dir}/cbst.bin", dtype = np.float32, mode = "r")
    if data.dtype != float_dtype:
        data = data.astype(float_dtype)
        cbst = cbst.astype(float_dtype)

    col = cp.asarray(col)
    row_count = cp.asarray(row_count)
    data = cp.asarray(data)
    cbst_gpu = cp.asarray(cbst)

    col_indices = col - 1
    row_indptr = cp.cumsum(cp.concatenate([cp.array([0]), row_count]))

    A_gpu = csr_matrix_cupy((data, col_indices, row_indptr), shape = (m, n))

    res_cupy = lsmr_cupy(A_gpu, cbst_gpu, damp = damp, atol = atol, btol = btol, conlim = conlim, maxiter = maxiter)

    if args.float_dtype == "float64":
        savebinfloat64(args.dv_path, cp.asnumpy(res_cupy[0]))
    else:
        savebinfloat32(args.dv_path, cp.asnumpy(res_cupy[0]))


if __name__ == "__main__":
    time1 = time.time()

    LSMRFunctionDict = {
        "scipy": solve_lsmr_scipy,
        "cupy": solve_lsmr_cupy_small_GPU,
        # "cupy": solve_lsmr_cupy_large_GPU,
    }
    parser = argparse.ArgumentParser(description = "LSMR Solver")
    parser.add_argument("--lsmr_type", type = str, default = "scipy", choices = ["scipy", "cupy"])
    parser.add_argument("--m", type = int, required = True)
    parser.add_argument("--n", type = int, required = True)
    parser.add_argument("--damp", type = float, default = 0.0, required = True)
    parser.add_argument("--dv_path", type = str, required = True)
    parser.add_argument("--float_dtype", type = str, default = "float32", choices = ["float32", "float64"])
    parser.add_argument("--int_dtype", type = str, default = "int32", choices = ["int32", "int64"])
    parser.add_argument("--dir", type = str, default = "LSMR")

    args = parser.parse_args()

    if args.lsmr_type == "cupy":
        import cupy as cp

        cp.cuda.set_allocator(None)
        cp.cuda.set_pinned_memory_allocator(None)
        from cupyx.scipy.sparse.linalg import lsmr as lsmr_cupy
        from cupyx.scipy.sparse import csr_matrix as csr_matrix_cupy
        from scipy.sparse import csr_matrix as csr_matrix_scipy
    else:
        from scipy.sparse.linalg import lsmr as lsmr_scipy
        from scipy.sparse import csr_matrix as csr_matrix_scipy

    LSMRFunction = LSMRFunctionDict[args.lsmr_type]
    LSMRFunction(args)
    time2 = time.time()

    if args.lsmr_type == "scipy":
        print("All SciPy LSMR Time: ", time2 - time1)
    elif args.lsmr_type == "cupy":
        print("All CuPy LSMR Time: ", time2 - time1)
