import shutil
import subprocess
import threading
import traceback
import signal

from .utils_plot import *
from .SSHClient import SSHClient, PrintLogRealTime
from .Storage import Storage

def run_inversion_remote():
    remote_python_path = Storage.ItemWidget["ssh_python_path"].getContent()
    remote_project_path = Storage.remoteProjectPath
    local_project_path = Storage.localProjectPath

    SSH = Storage.SSH

    SSH.exec_command(f"mkdir -p {remote_project_path}")

    if Storage.ItemWidget["is_synthetic"].getContent():
        inversion_file_list_all = ["MOD", "MOD.true", "surf.in", "ParallelConfig.in", "surfdata.dat", "MyRun.sh"]
    else:
        inversion_file_list_all = ["MOD", "surf.in", "ParallelConfig.in", "surfdata.dat", "MyRun.sh"]

    for filename in inversion_file_list_all:
        SSH.put(f"{local_project_path}/{filename}", f"{remote_project_path}/{filename}")

    cmd = f"{remote_python_path} -c '{SSH.get_run_template(remote_project_path)}'"
    stdin, stdout, stderr = SSH.ssh.exec_command(cmd)
    first_line = stdout.readline().strip()
    if first_line.startswith("REMOTE_PID:"):
        Storage.remote_pid = int(first_line.split(":")[1].strip())
        print(f"Remote PID: {Storage.remote_pid}")
    else:
        Storage.remote_pid = None
        # Storage.Signal.infoBarSignal.emit("warning", "Missing Remote PID", "This makes it unable to stop the remote inversion task")

    threading.Thread(target = PrintLogRealTime, args = (stderr, "stderr", Storage.Signal.stdErrSignal)).start()
    PrintLogRealTime(stdout, stdType = "stdout", logSignal = Storage.Signal.stdOutSignal, updateInvResultSignal = Storage.Signal.updateInvResultSignal)
    # PrintLogRealTime(stderr, stdType = "stderr", logSignal = Storage.Signal.stdErrSignal)

    Storage.is_running = False


def run_inversion_local():
    local_project_path = Storage.localProjectPath
    if sys.platform == "linux":
        cmd = "sh MyRun.sh"
    else:
        cmd = "MyRun.bat"

    Storage.process = subprocess.Popen(
            cmd,
            cwd = local_project_path,
            stdout = subprocess.PIPE,
            stderr = subprocess.PIPE,
            bufsize = 1,
            text = True,
            encoding = "utf-8" if sys.platform == "linux" else "gbk",
            errors = "replace",
            shell = True,
            preexec_fn = os.setsid if sys.platform == "linux" else None,

    )
    if sys.platform == "linux":
        Storage.local_pid = os.getpgid(Storage.process.pid)
        print(f"Local pid: {Storage.local_pid}")
    else:
        Storage.local_pid = Storage.process.pid
        print(f"Local pid: {Storage.local_pid}")

    threading.Thread(target = PrintLogRealTime, args = (Storage.process.stderr, "stderr", Storage.Signal.stdErrSignal)).start()
    PrintLogRealTime(Storage.process.stdout, stdType = "stdout", logSignal = Storage.Signal.stdOutSignal, updateInvResultSignal = Storage.Signal.updateInvResultSignal)
    # PrintLogRealTime(Storage.process.stderr, stdType = "stderr", logSignal = Storage.Signal.stdErrSignal)

    Storage.is_running = False


def btn_click_run():
    try:
        if Storage.is_running:
            info_bar("info", "Inversion is already Running", "")
            return
        else:
            Storage.is_running = True

        Storage.interp_model_cache.clear()
        Storage.lastLocalProjectPath = Storage.localProjectPath
        Storage.lastRemoteProjectPath = Storage.remoteProjectPath
        Storage.lastInvType = get_inv_type()
        Storage.iteration = 0

        if Storage.is_remote:
            if Storage.is_first_info_remote_inversion:
                info_bar("info",
                         "Submitting remote inversion task",
                         "This may take a moment depending on network conditions",
                         duration = -1)
                Storage.is_first_info_remote_inversion = False
            threading.Thread(target = run_inversion_remote, daemon = True).start()
        else:
            info_bar("success", "Inversion Start", "")
            threading.Thread(target = run_inversion_local, daemon = True).start()

    except Exception as e:
        traceback.print_exc()
        Storage.is_running = False
        Storage.process = None
        Storage.remote_pid = None


def stop_inversion_local():
    if Storage.process is None:
        return

    if Storage.process.poll() is not None:
        Storage.process = None
        return

    try:
        if sys.platform == "linux":
            pgid = Storage.local_pid
            os.killpg(pgid, signal.SIGTERM)
            try:
                Storage.process.wait(timeout = 1)
            except subprocess.TimeoutExpired:
                os.killpg(pgid, signal.SIGKILL)
                Storage.process.wait(timeout = 1)
        else:
            cmd = f"taskkill /F /T /PID {Storage.process.pid}"
            CREATE_NO_WINDOW = 0x08000000
            result = subprocess.run(cmd.split(), capture_output = True, creationflags = CREATE_NO_WINDOW)
            output = result.stdout.decode("gbk", errors = "ignore").strip()
            if output:
                Storage.Signal.stdOutSignal.emit("\n".join(output.split("\r\n")))
                print(output)

    except ProcessLookupError:
        pass
    except Exception as e:
        traceback.print_exc()
        Storage.Signal.stdErrSignal.emit(f"Local Inversion kill failed: \n{traceback.format_exc()}")


def stop_inversion_remote():
    try:
        if Storage.remote_pid is None:
            info_bar("error", "Invalid Remote PID", "Cannot stop the remote inversion task", isClosable = -1)
            return
        remote_python_path = Storage.ItemWidget["ssh_python_path"].getContent()
        SSH = Storage.SSH
        cmd = f"{remote_python_path} -c '{SSH.get_remote_stop_template(Storage.remote_pid)}'"
        SSH.exec_command(cmd)
    except Exception as e:
        traceback.print_exc()
        Storage.Signal.stdErrSignal.emit(f"Remote kill failed: \n{traceback.format_exc()}")


def btn_click_stop():
    if not Storage.is_running:
        info_bar("info", "Inversion is not running", "")
        return

    # info_bar("info", "Stopping Inversion...", "")
    try:
        if Storage.is_remote:
            stop_inversion_remote()
        else:
            stop_inversion_local()

        info_bar("success", "Inversion Stopped", "")

        if Storage.is_remote:
            print(f"Remote Inversion Stopped(pgid: {Storage.remote_pid})")
            Storage.Signal.stdOutSignal.emit(f"Remote Inversion Stopped(pgid: {Storage.remote_pid})")
        else:
            print(f"Inversion Stopped(pgid: {Storage.local_pid})")
            Storage.Signal.stdOutSignal.emit(f"Inversion Stopped(pgid: {Storage.local_pid})")

    except Exception as e:
        traceback.print_exc()
        info_bar("error", "Inversion Stop Failed", traceback.format_exc(), "vertical", duration = -1)
    finally:
        Storage.is_running = False


def btn_click_generate_config():
    try:
        user_setting = get_user_setting()
        project_path = user_setting["project_path"]
        generate_model_file(user_setting, project_path)
        generate_parallel_config_file(user_setting, project_path)
        generate_inversion_config_file(user_setting, project_path)
        generate_inversion_sh(project_path)
        info_bar("success", "Config File Generate Success", "")
    except Exception as e:
        traceback.print_exc()
        info_bar("error", "Config File Generate Failed", traceback.format_exc(), "vertical", duration = -1)


def btn_click_main_plot_update():
    if Storage.station is not None:
        Storage.Signal.plotMainStationSignal.emit()
    if Storage.vel_1d is not None:
        Storage.Signal.plotMainInitModelSignal.emit()


def solve_choose_init_model_file(filepath: str):
    model = load_json(filepath)
    if "depth" in model and "vel_1d" in model:
        Storage.Signal.initModelFileSelectSignal.emit(filepath)


def solve_choose_period_file(filepath: str):
    model = load_json(filepath)
    key_list = ["Rc", "Rg", "Lc", "Rg"]
    for sub_key in key_list:
        key = "p_" + sub_key
        if key in model:
            periods = " ".join([str(p) for p in model[key]])
            Storage.ItemWidget[key].setContent(periods)


def process_model_info_file(data_path: str):
    project_path = os.path.dirname(data_path)
    model_file_path = os.path.join(project_path, "model.json")
    if os.path.exists(model_file_path):
        solve_choose_init_model_file(model_file_path)
        solve_choose_period_file(model_file_path)
    else:
        Storage.depth = None
        Storage.vel_1d = None

        Storage.Signal.clearPlotMainInitModelSignal.emit()
        Storage.Signal.clearVelocityTableSignal.emit()

        key_list = ["Rc", "Rg", "Lc", "Rg"]
        for sub_key in key_list:
            Storage.ItemWidget["p_" + sub_key].setContent("")


def process_surf_data_file(filepath: str):
    station, src_to_rcv, n_periods, max_src_rcv = parse_surf_data(filepath)
    Storage.station = station
    Storage.src_to_rcv = src_to_rcv
    Storage.n_periods = n_periods
    Storage.max_src_rcv = max_src_rcv

    dLat = Storage.ItemWidget["dLat"].getContent("float")
    dLon = Storage.ItemWidget["dLon"].getContent("float")
    dLat = dLat if dLat else 0.1
    dLon = dLon if dLon else 0.1
    originLat, originLon, nx, ny = auto_get_model_parameter(Storage.station, dLat = dLat, dLon = dLon, pad = Storage.pad)
    Storage.ItemWidget["originLat"].setContent(f"{originLat}")
    Storage.ItemWidget["originLon"].setContent(f"{originLon}")
    Storage.ItemWidget["dLat"].setContent(f"{dLat}")
    Storage.ItemWidget["dLon"].setContent(f"{dLon}")
    Storage.ItemWidget["nx"].setContent(f"{nx}")
    Storage.ItemWidget["ny"].setContent(f"{ny}")

    period_key_map = {
        "2_0": "kmaxRc",
        "2_1": "kmaxRg",
        "1_0": "kmaxLc",
        "1_1": "kmaxRg",
    }
    for key, val in Storage.n_periods.items():
        Storage.ItemWidget[period_key_map[key]].setContent(f"{val}")


def btn_click_auto_setting():
    data_path = Storage.ItemWidget["data_path"].getContent()
    if os.path.exists(data_path):
        process_surf_data_file(data_path)
        process_model_info_file(data_path)
        btn_click_main_plot_update()
    else:
        info_bar("error", "SurfData File not exist", "")

        Storage.depth = None
        Storage.vel_1d = None

        Storage.station = None
        Storage.src_to_rcv = None
        Storage.n_periods = None
        Storage.max_src_rcv = None

        Storage.Signal.clearPlotMainStationSignal.emit()
        Storage.Signal.clearPlotMainInitModelSignal.emit()
        Storage.Signal.clearVelocityTableSignal.emit()
        Storage.Signal.clearPlotInterfaceSignal.emit()
        Storage.Signal.clearFileListSignal.emit()

        key_list = ["originLat", "originLon", "nx", "ny", "nz"]
        for sub_key in key_list:
            Storage.ItemWidget[sub_key].setContent("")

        key_list = ["Rc", "Rg", "Lc", "Rg"]
        for sub_key in key_list:
            Storage.ItemWidget["kmax" + sub_key].setContent("")
            Storage.ItemWidget["p_" + sub_key].setContent("")


def update_project_path_label():
    if Storage.is_remote:
        hostname = Storage.ItemWidget["ssh_ip"].getContent()
        port = Storage.ItemWidget["ssh_port"].getContent()
        Storage.ItemWidget["project_path"].label.setText(f"Project Path (<font color='red'>Remote: {Storage.remoteProjectPath}</font>)")
        Storage.ItemWidget["project_path"].label.setToolTip(f"Remote: {Storage.remoteProjectPath}")
        Storage.MainWindow.ssh_label.setText(f"  [SSH: {hostname}:{port}]")
    else:
        Storage.ItemWidget["project_path"].label.setText("Project Path")
        Storage.ItemWidget["project_path"].label.setToolTip(Storage.ItemInfo["project_path"]["Tooltip"])
        Storage.MainWindow.ssh_label.setText("")


def solve_surf_data_path_change(data_path: str):
    Storage.localProjectPath = os.path.dirname(data_path)
    Storage.ItemWidget["project_path"].setContent(Storage.localProjectPath)

    Storage.remoteProjectPath = posix_path_join(Storage.remoteRoot, os.path.basename(Storage.localProjectPath))
    update_project_path_label()


def solve_remote_root_change(remote_root: str):
    Storage.remoteRoot = remote_root
    Storage.remoteProjectPath = posix_path_join(Storage.remoteRoot, os.path.basename(Storage.localProjectPath))
    update_project_path_label()


def update_max_thread():
    if Storage.is_remote:
        cmd = "python3 -c 'import os; print(os.cpu_count())'"
        stdin, stdout, stderr = Storage.SSH.ssh.exec_command(cmd)
        Storage.max_thread = int(stdout.read().decode().strip())
    else:
        Storage.max_thread = os.cpu_count()

    threadList = [str(2 ** i) for i in range(3, 10) if 2 ** i < Storage.max_thread] + [str(Storage.max_thread)]

    Storage.ItemWidget["threadNum"].widget.clear()
    Storage.ItemWidget["threadNum"].widget.addItems(threadList)
    Storage.ItemWidget["threadNum"].widget.setCurrentText(f"{threadList[-2]}")


def btn_click_ssh_connect():
    try:
        hostname = Storage.ItemWidget["ssh_ip"].getContent()
        port = Storage.ItemWidget["ssh_port"].getContent()
        username = Storage.ItemWidget["ssh_username"].getContent()
        password = Storage.ItemWidget["ssh_password"].getContent()
        key_filename = Storage.ItemWidget["ssh_key_file_path"].getContent()
        if Storage.SSH is not None:
            Storage.SSH.close()
        if os.path.exists(key_filename):
            Storage.SSH = SSHClient(hostname, port, username, password = password, key_filename = key_filename)
        else:
            Storage.SSH = SSHClient(hostname, port, username, password = password)
        info_bar("success", "Connect to SSH", "")

        Storage.is_remote = True

        if Storage.ItemWidget["ssh_remote_root"].getContent() == "":
            stdin, stdout, stderr = Storage.SSH.ssh.exec_command("cd && pwd")
            remoteHomePath = stdout.read().decode().strip()
            Storage.ItemWidget["ssh_remote_root"].setContent(posix_path_join(remoteHomePath, "pDSurfTomo"))

        update_project_path_label()
        update_max_thread()

    except Exception as e:
        traceback.print_exc()
        info_bar("error", "Connect to SSH Failed", traceback.format_exc(), orient = "vertical")


def btn_click_ssh_disconnect():
    if Storage.SSH is None:
        return
    Storage.SSH.close()
    info_bar("success", "Disconnect from SSH", "")
    Storage.is_remote = False

    update_project_path_label()
    update_max_thread()


def update_inv_file():
    Storage.iteration += 1
    filename = f"vs_{Storage.iteration}.bin"
    local_file_dir = get_inv_file_dir("local")
    local_file_path = os.path.join(local_file_dir, filename)

    os.makedirs(local_file_dir, exist_ok = True)
    if Storage.is_remote:
        remote_file_dir = get_inv_file_dir("remote")
        remote_file_path = posix_path_join(remote_file_dir, filename)
        try:
            Storage.SSH.get(remote_file_path, local_file_path)
        except Exception:
            traceback.print_exc()
            info_bar("error", "Download Remote Inv File Failed", traceback.format_exc(), orient = "vertical", duration = -1)
            return

    shutil.copy2(local_file_path, os.path.dirname(local_file_dir))
    Storage.Signal.updateFileListSignal.emit()