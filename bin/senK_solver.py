"""
* Author: Shaohang Zhu (USTC) : zshang@mail.ustc.edu.cn
* Date: 2026/4/20
* Description:
* Copyright (c) 2026 Shaohang Zhu.
"""

import os
import time
import argparse
import numpy as np


def savebinfloat64(filename, array, order = "C"):
    with open(filename, "wb") as f:
        f.write(array.astype(np.float64).tobytes(order = order))


def savebinfloat32(filename, array, order = "C"):
    with open(filename, "wb") as f:
        f.write(array.astype(np.float32).tobytes(order = order))


def loadbinfloat64(filename):
    with open(filename, "rb") as f:
        obj = np.fromfile(f, dtype = np.float64)
    return np.array(obj)


def loadbinfloat32(filename, is_as_float64 = False):
    with open(filename, "rb") as f:
        obj = np.fromfile(f, dtype = np.float32)

    if is_as_float64:
        return np.array(obj).astype(np.float64)
    else:
        return np.array(obj)


def refine_grid2_layer_mdl_batch(minthk0, dep, vp, vs, rho, NL = 200):
    batch_size, mmax = vp.shape
    rdep = np.zeros(NL, dtype = np.float64)
    rthk = np.zeros(NL, dtype = np.float64)
    rvp = np.zeros([batch_size, NL], dtype = np.float64)
    rvs = np.zeros([batch_size, NL], dtype = np.float64)
    rrho = np.zeros([batch_size, NL], dtype = np.float64)

    nsublay = np.empty(mmax, dtype = np.int32)
    k = 0
    initdep = 0.0

    for i in range(mmax - 1):
        thk = dep[i + 1] - dep[i]
        minthk = thk / minthk0
        nsublay[i] = int((thk + 1.0e-4) / minthk) + 1
        newthk = thk / nsublay[i]

        for j in range(1, nsublay[i] + 1):
            k += 1

            rthk[k - 1] = newthk
            rdep[k - 1] = initdep + rthk[k - 1]
            initdep = rdep[k - 1]

            # Linear interpolation within the sublayer
            rvp[:, k - 1] = vp[:, i] + (2 * j - 1) * (vp[:, i + 1] - vp[:, i]) / (2 * nsublay[i])
            rvs[:, k - 1] = vs[:, i] + (2 * j - 1) * (vs[:, i + 1] - vs[:, i]) / (2 * nsublay[i])
            rrho[:, k - 1] = rho[:, i] + (2 * j - 1) * (rho[:, i + 1] - rho[:, i]) / (2 * nsublay[i])

    # Half space model (last layer)
    k += 1

    rthk[k - 1] = 0.0
    rdep[k - 1] = dep[mmax - 1]
    rvp[:, k - 1] = vp[:, mmax - 1]
    rvs[:, k - 1] = vs[:, mmax - 1]
    rrho[:, k - 1] = rho[:, mmax - 1]

    rmax = k
    rthk = rthk[None, :].repeat(batch_size, axis = 0)

    return rmax, rdep[:rmax], rvp[:, :rmax], rvs[:, :rmax], rrho[:, :rmax], rthk[:, :rmax]


def solve_senK_disba(args):
    minthk = args.minthk
    nx, ny, nz = args.nx, args.ny, args.nz

    vs = loadbinfloat32(f"{args.dir}/vel_senK.bin", is_as_float64 = True).reshape((nx, ny, nz), order = "F")
    depz = loadbinfloat32(f"{args.dir}/depz.bin", is_as_float64 = True)
    tRc = loadbinfloat64(f"{args.dir}/tRc.bin")
    kmaxRc = len(tRc)

    # vp = 0.9409 + 2.0947 * vs - 0.8206 * vs ** 2 + 0.2683 * vs ** 3 - 0.0251 * vs ** 4
    # rho = 1.6612 * vp - 0.4721 * vp ** 2 + 0.0671 * vp ** 3 - 0.0043 * vp ** 4 + 0.000106 * vp ** 5

    vp = 0.9409 + vs * (2.0947 + vs * (-0.8206 + vs * (0.2683 - 0.0251 * vs)))
    rho = vp * (1.6612 + vp * (-0.4721 + vp * (0.0671 + vp * (-0.0043 + 0.000106 * vp))))

    vp_batch = np.tile(vp[..., None, None, :], (1, 1, nz, 6, 1))
    vs_batch = np.tile(vs[..., None, None, :], (1, 1, nz, 6, 1))
    rho_batch = np.tile(rho[..., None, None, :], (1, 1, nz, 6, 1))

    dlnVs = 0.01
    dlnVp = 0.01
    dlnrho = 0.01

    for k in range(nz):
        vs_batch[:, :, k, 0, k] *= (1 - 0.5 * dlnVs)
        vs_batch[:, :, k, 1, k] *= (1 + 0.5 * dlnVs)
        vp_batch[:, :, k, 2, k] *= (1 - 0.5 * dlnVp)
        vp_batch[:, :, k, 3, k] *= (1 + 0.5 * dlnVp)
        rho_batch[:, :, k, 4, k] *= (1 - 0.5 * dlnrho)
        rho_batch[:, :, k, 5, k] *= (1 + 0.5 * dlnrho)

    depm = depz
    vpm_batch = vp_batch.reshape(-1, nz)
    vsm_batch = vs_batch.reshape(-1, nz)
    rhom_batch = rho_batch.reshape(-1, nz)
    tRc_batch = np.repeat(tRc[None, :], vpm_batch.shape[0], axis = 0)

    rmax_batch, rdep_batch, rvp_batch, rvs_batch, rrho_batch, rthk_batch = refine_grid2_layer_mdl_batch(minthk, depm, vpm_batch, vsm_batch, rhom_batch)
    time1 = time.time()
    cg_batch_flat = surf96_batch(tRc_batch, rthk_batch, rvp_batch, rvs_batch, rrho_batch,
                                 iflsph = 1, mode = 0,
                                 itype = args.itype, ifunc = args.ifunc,
                                 dc = 0.005, dt = 0.005)
    time2 = time.time()
    print("Disba Dispersion Time: ", time2 - time1)
    cg_batch = cg_batch_flat.reshape(nx, ny, nz, 6, kmaxRc)

    sen_vs_batch = (cg_batch[..., 1, :] - cg_batch[..., 0, :]) / (dlnVs * vs[..., None])
    sen_vp_batch = (cg_batch[..., 3, :] - cg_batch[..., 2, :]) / (dlnVp * vp[..., None])
    sen_rho_batch = (cg_batch[..., 5, :] - cg_batch[..., 4, :]) / (dlnrho * rho[..., None])

    # sen_vp_batch: [nx, ny, nz, kmaxRc] -> [nx, ny, kmaxRc, nz]
    sen_vp_batch = sen_vp_batch.swapaxes(-1, -2).reshape(ny * nx, kmaxRc, nz, order = "F")
    sen_vs_batch = sen_vs_batch.swapaxes(-1, -2).reshape(ny * nx, kmaxRc, nz, order = "F")
    sen_rho_batch = sen_rho_batch.swapaxes(-1, -2).reshape(ny * nx, kmaxRc, nz, order = "F")
    savebinfloat64(f"{args.dir}/sen_vp_disba.bin", sen_vp_batch, order = "F")
    savebinfloat64(f"{args.dir}/sen_vs_disba.bin", sen_vs_batch, order = "F")
    savebinfloat64(f"{args.dir}/sen_rho_disba.bin", sen_rho_batch, order = "F")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description = "SenK Solver")
    parser.add_argument("--minthk", type = float, default = 3)
    parser.add_argument("--nx", type = int, required = True)
    parser.add_argument("--ny", type = int, required = True)
    parser.add_argument("--nz", type = int, required = True)
    parser.add_argument("--ifunc", type = int, default = 2)
    parser.add_argument("--itype", type = int, default = 0)
    parser.add_argument("--dir", type = str, default = "senK")
    parser.add_argument("--ThreadNum", type = int, default = os.cpu_count() // 2)

    args = parser.parse_args()

    import numba

    numba.set_num_threads(args.ThreadNum)
    from surf96_disba import surf96_batch

    time1 = time.time()
    solve_senK_disba(args)
    time2 = time.time()
    print("Disba All Time: ", time2 - time1)
