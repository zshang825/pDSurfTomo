import json

from .utils import *


def loadbinfloat32(filename, is_as_float64 = False):
    with open(filename, "rb") as f:
        obj = np.fromfile(f, dtype = np.float32)

    if is_as_float64:
        return np.array(obj).astype(np.float64)
    else:
        return np.array(obj)


def loadbinfloat64(filename):
    with open(filename, "rb") as f:
        obj = np.fromfile(f, dtype = np.float64)
    return np.array(obj)


def load_json(filepath):
    with open(filepath) as f:
        return json.load(f)


def save_json(filepath, data):
    with open(filepath, "w") as f:
        json.dump(data, f, indent = 4)


def read_surf_model(filepath, nx, ny, nz, is_true_model = False):
    model = np.zeros((nx, ny, nz))
    depth = None
    with open(filepath, "r") as f:
        if not is_true_model:
            depth = np.array(f.readline().strip().split(), dtype = np.float64)
        for k in range(nz):
            for j in range(ny):
                model[:, j, k] = np.array(f.readline().strip().split())
    return model, depth


def write_surf_model(filepath, model, depth = None, is_true_model = False):
    if not is_true_model:
        if depth is None:
            print("depth cannot be None for Init Model, File Write Failed")
            return

    nx, ny, nz = model.shape
    with open(os.path.join(filepath), "w") as f:
        if not is_true_model:
            for k in range(nz):
                f.write(f"{depth[k]:<8.2f}")
            f.write("\n")
        for k in range(nz):
            for j in range(ny):
                for i in range(nx):
                    f.write(f"{model[i, j, k]:<8.4f}")
                f.write("\n")


def get_user_setting():
    user_setting = {}
    for key, widget in Storage.ItemWidget.items():
        user_setting[key] = widget.getContent()
    return user_setting


def save_user_setting():
    user_setting = get_user_setting()
    filter_user_setting = {key: val for key, val in user_setting.items() if isinstance(val, bool) or val.strip()}
    save_json("UserLastSetting.json", filter_user_setting)


def generate_model_file(cfg: dict, project_root = "./example"):
    nx, ny, nz = int(cfg["nx"]), int(cfg["ny"]), int(cfg["nz"])
    depth, vel_1d = Storage.depth, Storage.vel_1d
    vs_init = np.tile(vel_1d, (nx, ny, 1))
    write_surf_model(os.path.join(project_root, "MOD"), vs_init, depth, is_true_model = False)

    inv_result_dir = os.path.join(Storage.localProjectPath, "InvResult")
    os.makedirs(inv_result_dir, exist_ok = True)
    np.save(os.path.join(inv_result_dir, "vs_init.npy"), vs_init)

    if Storage.ItemWidget["is_synthetic"].getContent():
        grid_dx, grid_dy = int(cfg["grid_dx"]), int(cfg["grid_dy"])
        vel_perturbation = float(cfg["perturbation"])

        try:
            grid_dz = int(cfg["grid_dz"])
        except Exception as e:
            grid_dz = [int(dz) for dz in cfg["grid_dz"].split(" ")]

        checkerboard_mask = generate_checkerboard_mask(nx, ny, nz, grid_dx, grid_dy, grid_dz)
        vs_true = (vel_perturbation * checkerboard_mask + 1) * vs_init
        write_surf_model(os.path.join(project_root, "MOD.true"), vs_true, depth, is_true_model = True)
        np.save(os.path.join(inv_result_dir, "vs_true.npy"), vs_true)
        np.save(os.path.join(inv_result_dir, "vs_mask.npy"), checkerboard_mask)

def generate_inversion_sh(project_root = "./example"):
    if Storage.is_remote:
        exe_program_path = os.path.join(Storage.remoteRoot, "bin", "pDSurfTomo")
        exe_program_path = path_to_linux(exe_program_path)
        script_name = "MyRun.sh"
    else:
        if sys.platform == "linux":
            exe_program_path = os.path.join(Storage.localRoot, "bin", "pDSurfTomo")
            script_name = "MyRun.sh"
        else:
            exe_program_path = os.path.join(Storage.localRoot, "bin", "pDSurfTomo.exe")
            script_name = "MyRun.bat"

    with open(os.path.join(project_root, script_name), "w") as f:
        f.write(f"{exe_program_path} surf.in MOD MOD.true ParallelConfig.in")


def generate_parallel_config_file(cfg: dict, project_root = "./project"):
    os.makedirs(project_root, exist_ok = True)

    if Storage.is_remote:
        lsmr_script_path = posix_path_join(Storage.remoteRoot, "bin", "lsmr_solver.py")
        senK_script_path = posix_path_join(Storage.remoteRoot, "bin", "senK_solver.py")
    else:
        lsmr_script_path = os.path.join(Storage.localRoot, "bin", "lsmr_solver.py")
        senK_script_path = os.path.join(Storage.localRoot, "bin", "senK_solver.py")

    tt_senK_lsmr = [cfg["travelTime"].lower(), cfg["senK"].lower(), cfg["lsmr"].lower()]
    threadNum = cfg["threadNum"]
    InvResultDir = "InvResult"

    with open(os.path.join(project_root, "ParallelConfig.in"), "w") as f:
        f.write(f"tt_senK_lsmr = {', '.join(tt_senK_lsmr)}\n")
        f.write(f"ThreadNum = {threadNum}\n")
        f.write(f"InvResultDir = {InvResultDir}\n")
        f.write(f"lsmr_script_path = {lsmr_script_path}\n")
        f.write(f"senK_script_path = {senK_script_path}\n")


def generate_inversion_config_file(cfg: dict, project_root = "./project"):
    os.makedirs(project_root, exist_ok = True)
    cfg['max_src_rcv'] = Storage.max_src_rcv

    lines = [
        {
            "data": f"{os.path.basename(cfg['data_path'])}",
            "comment": "c: data file"
        },
        {
            "data": f"{cfg['nx']} {cfg['ny']} {cfg['nz']}",
            "comment": "c: nx ny nz (grid number in lat lon and depth direction)"
        },
        {
            "data": f"{cfg['originLat']} {cfg['originLon']}",
            "comment": "c: goxd gozd (upper left point [lat, lon])"
        },
        {
            "data": f"{cfg['dLat']} {cfg['dLon']}",
            "comment": "c: dvxd dvzd (grid interval in lat and lon direction)"
        },
        {
            "data": f"{cfg['max_src_rcv']}",
            "comment": "c: max(sources, receivers)"
        },
        {
            "data": f"{cfg['weight']} {cfg['damp']}",
            "comment": "c: weight damp"
        },
        {
            "data": f"{cfg['subLayer']}",
            "comment": "c: sablayers (for computing depth kernel, 2~5)"
        },
        {
            "data": f"{cfg['min_vel']} {cfg['max_vel']}",
            "comment": "c: minimum velocity, maximum velocity (a priori information)"
        },
        {
            "data": f"{cfg['iteration']}",
            "comment": "c: maximum iteration"
        },
        {
            "data": f"{cfg['sparsity']}",
            "comment": "c: sparsity fraction "
        },
        {
            "data": f"{cfg['kmaxRc'] if cfg['kmaxRc'] else 0}",
            "comment": "c: kmaxRc (followed by periods)"
        },
        {
            "data": cfg['p_Rc'].strip(),
            "comment": ""
        },
        {
            "data": f"{cfg['kmaxRg'] if cfg['kmaxRg'] else 0}",
            "comment": "c: kmaxRg"
        },
        {
            "data": cfg['p_Rg'].strip(),
            "comment": ""
        },
        {
            "data": f"{cfg['kmaxLc'] if cfg['kmaxLc'] else 0}",
            "comment": "c: kmaxLc"
        },
        {
            "data": cfg['p_Lc'].strip(),
            "comment": ""
        },
        {
            "data": f"{cfg['kmaxLg'] if cfg['kmaxLg'] else 0}",
            "comment": "c: kmaxLg"
        },
        {
            "data": cfg['p_Lg'].strip(),
            "comment": ""
        },
        {
            "data": f"{int(cfg['is_synthetic'])}",
            "comment": "c: synthetic flag(0:real data, 1:synthetic)"
        },
        {
            "data": f"{cfg['noiseLevel']}",
            "comment": "c: noiselevel"
        },
        {
            "data": f"{cfg['threshold']}",
            "comment": "c: threshold"
        },
    ]

    with open(os.path.join(project_root, "surf.in"), "w") as f:
        f.write("cccc" * 15 + "\n")
        f.write("c INPUT PARAMETERS" + "\n")
        f.write("cccc" * 15 + "\n")
        for item in lines:
            data_part = item["data"]
            comment_part = item["comment"]
            if len(data_part.strip()) == 0:
                continue
            line = f"{data_part.strip():30}{comment_part}\n"
            f.write(line)
