import os
import subprocess

def generate_parallel_config_file(cfg: dict, project_root = "./example"):
    os.makedirs(project_root, exist_ok = True)
    with open(os.path.join(project_root, "ParallelConfig.in"), "w") as f:
        f.write(f"tt_senK_lsmr = {cfg['tt_senK_lsmr']}\n")
        f.write(f"ThreadNum = {cfg['ThreadNum']}\n")
        f.write(f"InvResultDir = {cfg['InvResultDir']}\n")
        f.write(f"lsmr_script_path = {cfg['lsmr_script_path']}\n")
        f.write(f"senK_script_path = {cfg['senK_script_path']}")

project_root = "example"
# project_root = "example_syn"

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#                              DSurfTomo
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cmd = "../bin/DSurfTomo surf.in"
subprocess.run(cmd.split(), cwd = project_root)

os.makedirs(os.path.join(project_root, "InvResult", "DSurfTomo"), exist_ok = True)
os.system(f"mv {project_root}/surf.inMeasure* {project_root}/InvResult/DSurfTomo")

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#                             pDSurfTomo
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# cmd = "../bin/pDSurfTomo surf.in MOD MOD.true ParallelConfig.in"
cmd = "../bin/pDSurfTomo surf.in"

parallel_config = {
    "tt_senK_lsmr": "",
    "ThreadNum": os.cpu_count() // 2,
    "InvResultDir": "InvResult",
    "lsmr_script_path": os.path.join(os.getcwd(), "bin", "lsmr_solver.py"),
    "senK_script_path": os.path.join(os.getcwd(), "bin", "senK_solver.py"),
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# Native Implementation of the original DSurfTomo in pDSurfTomo
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
parallel_config["tt_senK_lsmr"] = "default, default, default"

generate_parallel_config_file(parallel_config, project_root)

subprocess.run(cmd.split(), cwd = project_root)

os.makedirs(os.path.join(project_root, "InvResult", "pDSurfTomo"), exist_ok = True)
os.system(f"mv {project_root}/surf.inMeasure* {project_root}/InvResult/pDSurfTomo")

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# Parallel Implementation of the original DSurfTomo in pDSurfTomo
# The inverted velocity model is identical to the original DSurfTomo
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
parallel_config["tt_senK_lsmr"] = "parallel, parallel, default"

generate_parallel_config_file(parallel_config, project_root)

subprocess.run(cmd.split(), cwd = project_root)

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# CPU-optimized Implementation of pDSurfTomo
# The inverted velocity model maintains a negligible discrepancy
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
parallel_config["tt_senK_lsmr"] = "parallel, disba, scipy"

generate_parallel_config_file(parallel_config, project_root)

subprocess.run(cmd.split(), cwd = project_root)

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# GPU-optimized Implementation of pDSurfTomo
# The inverted velocity model maintains a negligible discrepancy
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
parallel_config["tt_senK_lsmr"] = "parallel, disba, cupy"

generate_parallel_config_file(parallel_config, project_root)

subprocess.run(cmd.split(), cwd = project_root)