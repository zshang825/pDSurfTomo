import os
import filecmp

import numpy as np


def compare_txt_file(file1, file2):
    data1 = np.loadtxt(file1)
    data2 = np.loadtxt(file2)
    return np.array_equal(data1, data2)


def compare_binary_file(file1, file2):
    return filecmp.cmp(file1, file2, shallow = False)


project_root = "example"
# project_root = "example_syn"
epoch = 10

print(f"Project Root: {project_root}")
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# file1: the origin DSurfTomo
# file2: Native Implementation of the original DSurfTomo in pDSurfTomo
# result: The inverted velocity model is numerically identical
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
print("""
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
file1: the origin DSurfTomo
file2: Native Implementation of the original DSurfTomo in pDSurfTomo
result: The inverted velocity model is numerically identical
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
""".strip("\n"))
result_dir_DSurtTomo = os.path.join(project_root, "InvResult", "DSurfTomo")
result_dir_pDSurtTomo = os.path.join(project_root, "InvResult", "pDSurfTomo")

for i in range(epoch):
    file1 = f"{result_dir_DSurtTomo}/surf.inMeasure.dat.iter{i + 1:03d}"
    file2 = f"{result_dir_pDSurtTomo}/surf.inMeasure.dat.iter{i + 1:03d}"
    cmp_res = compare_txt_file(file1, file2)
    print(f"surf.inMeasure.dat.iter{i + 1:03d}: {cmp_res}")

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# file1: Native Implementation of the original DSurfTomo in pDSurfTomo
# file2: Parallel Implementation of the original DSurfTomo in pDSurfTomo
# result: The inverted velocity model is numerically identical
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
print("""
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
file1: Native Implementation of the original DSurfTomo in pDSurfTomo
file2: Parallel Implementation of the original DSurfTomo in pDSurfTomo
result: The inverted velocity model is numerically identical
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
""".rstrip("\n"))
result_dir_pDSurtTomo1 = os.path.join(project_root, "InvResult", "tt_default_senK_default_lsmr_default")
result_dir_pDSurtTomo2 = os.path.join(project_root, "InvResult", "tt_parallel_senK_parallel_lsmr_default")

for i in range(epoch):
    file1 = f"{result_dir_pDSurtTomo1}/vs_{i + 1}.bin"
    file2 = f"{result_dir_pDSurtTomo2}/vs_{i + 1}.bin"
    cmp_res = compare_binary_file(file1, file2)
    print(f"vs_{i + 1}.bin: {cmp_res}")

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# file1: Native Implementation of the original DSurfTomo in pDSurfTomo
# file2: CPU-optimized Implementation of pDSurfTomo
# result: The inverted velocity model maintains a negligible discrepancy
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
print("""
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
file1: Native Implementation of the original DSurfTomo in pDSurfTomo
file2: CPU-optimized Implementation of pDSurfTomo
result: The inverted velocity model maintains a negligible discrepancy
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
""".rstrip("\n"))
result_dir_pDSurtTomo1 = os.path.join(project_root, "InvResult", "tt_default_senK_default_lsmr_default")
result_dir_pDSurtTomo2 = os.path.join(project_root, "InvResult", "tt_parallel_senK_disba_lsmr_scipy")

for i in range(epoch):
    file1 = f"{result_dir_pDSurtTomo1}/vs_{i + 1}.bin"
    file2 = f"{result_dir_pDSurtTomo2}/vs_{i + 1}.bin"
    data1 = np.fromfile(file1, dtype = np.float32)
    data2 = np.fromfile(file2, dtype = np.float32)
    print(f"vs_{i + 1}.bin Max Difference: {np.abs(data1 - data2).max():.4e}")

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# file1: Native Implementation of the original DSurfTomo in pDSurfTomo
# file2: GPU-optimized Implementation of pDSurfTomo
# result: The inverted velocity model maintains a negligible discrepancy
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
print("""
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
file1: Native Implementation of the original DSurfTomo in pDSurfTomo
file2: GPU-optimized Implementation of pDSurfTomo
result: The inverted velocity model maintains a negligible discrepancy
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
""".rstrip("\n"))
result_dir_pDSurtTomo1 = os.path.join(project_root, "InvResult", "tt_default_senK_default_lsmr_default")
result_dir_pDSurtTomo2 = os.path.join(project_root, "InvResult", "tt_parallel_senK_disba_lsmr_cupy")

for i in range(epoch):
    file1 = f"{result_dir_pDSurtTomo1}/vs_{i + 1}.bin"
    file2 = f"{result_dir_pDSurtTomo2}/vs_{i + 1}.bin"
    data1 = np.fromfile(file1, dtype = np.float32)
    data2 = np.fromfile(file2, dtype = np.float32)
    print(f"vs_{i + 1}.bin Max Difference: {np.abs(data1 - data2).max():.4e}")
