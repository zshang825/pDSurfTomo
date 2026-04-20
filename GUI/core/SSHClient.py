import threading

import paramiko
import atexit
from .Storage import Storage


def PrintLogRealTime(stdFile, stdType = "stdout", logSignal = None, updateInvResultSignal = None):
    for line in stdFile:
        process_text = " ".join(line.strip().split())
        if stdType == "stdout":
            print(process_text)
        else:
            print("\033[31m" + process_text + "\033[0m")
            # print(Fore.RED + line.strip() + Fore.RESET)

        if logSignal is not None:
            logSignal.emit(process_text + "\n")

        if updateInvResultSignal is not None:
            if "Iteration Time" in process_text:
                updateInvResultSignal.emit()


class SSHClient:

    def __init__(self, hostname, port, username, password = None, key_filename = None):
        atexit.register(self.close)

        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.key_filename = key_filename

        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh.connect(hostname, port, username, password = password, key_filename = key_filename, look_for_keys = False, allow_agent = False)
        self.fstp = self.ssh.open_sftp()

    def exec_command(self, cmd):
        stdin, stdout, stderr = self.ssh.exec_command(cmd)

        threading.Thread(target = PrintLogRealTime, args = (stderr, "stderr", Storage.Signal.stdErrSignal)).start()
        PrintLogRealTime(stdout, stdType = "stdout", logSignal = Storage.Signal.stdOutSignal)
        # PrintLogRealTime(stderr, stdType = "stderr", logSignal = Storage.Signal.stdErrSignal)

        # threading.Thread(target = PrintLogRealTime, args = (stdout, "stdout")).start()
        # threading.Thread(target = PrintLogRealTime, args = (stderr, "stderr")).start()

    def get(self, remotepath, localpath):
        self.fstp.get(remotepath, localpath)

    def put(self, localpath, remotepath):
        self.fstp.put(localpath, remotepath)

    def mkdir(self, remotepath):
        self.fstp.mkdir(remotepath)

    def close(self):
        self.ssh.close()
        self.fstp.close()

    def get_remote_stop_template(self, pgid):
        template = f"""
import os
import sys
import time
import signal

pgid = {pgid}

try:
    os.killpg(pgid, signal.SIGTERM)
except ProcessLookupError:
    sys.exit(0)

for _ in range(10):
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        sys.exit(0)
    time.sleep(0.1)

try:
    os.killpg(pgid, signal.SIGKILL)
except ProcessLookupError:
    pass
"""
        return template

    def get_run_template(self, project_path):
        template = f"""
import os
import sys
import subprocess

python_script_dir = os.path.dirname(sys.executable)
current_path = os.environ.get("PATH", "")
os.environ["PATH"] = python_script_dir + os.pathsep + current_path
cwd = "{project_path}"
cmd = "sh MyRun.sh"
process = subprocess.Popen(cmd.split(" "), cwd = cwd, preexec_fn=os.setsid)
print(f"REMOTE_PID: {{os.getpgid(process.pid)}}")
"""
        return template
