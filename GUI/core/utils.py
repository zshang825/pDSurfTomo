import os
import sys
import posixpath
from pathlib import PurePosixPath, PurePath
import numpy as np
from collections import defaultdict

from PyQt5.QtCore import Qt
from qfluentwidgets import InfoBarIcon, InfoBar, InfoBarPosition
from .Storage import Storage


def isWin11():
    return sys.platform == 'win32' and sys.getwindowsversion().build >= 22000


def path_to_linux(path):
    return path.replace(os.sep, "/")


def posix_path_join(*args):
    return posixpath.join(*args).replace(os.sep, "/")


def os_path_join(*args):
    if Storage.is_remote:
        return str(PurePosixPath(*args))
    else:
        return str(PurePath(*args))


def info_bar(info_type = "info",
             title = "",
             content = "",
             orient = "horizontal",
             isClosable = True,
             duration = 1500,
             position = InfoBarPosition.TOP):
    info_bar_map = {
        "info": InfoBarIcon.INFORMATION,
        "warning": InfoBarIcon.WARNING,
        "error": InfoBarIcon.ERROR,
        "success": InfoBarIcon.SUCCESS,
    }

    InfoBar.new(info_bar_map.get(info_type, InfoBarIcon.INFORMATION),
                title = title,
                content = content,
                orient = Qt.Horizontal if orient.lower() == "horizontal" else Qt.Vertical,
                isClosable = isClosable,
                duration = duration,
                position = position,
                parent = Storage.MainWindow)


def parse_surf_data(filepath, is_num = False):
    src = set()
    rcv = set()
    src_to_rcv = defaultdict(set) if not is_num else None
    periods = defaultdict(set)
    current_src = None

    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line: continue

            if line[0] == "#":
                parts = line[1:].split()
                lat, lon = float(parts[0]), float(parts[1])
                period_idx = int(parts[2])
                wave_type, velocity_type = int(parts[3]), int(parts[4])
                current_src = (lat, lon)
                src.add(current_src)
                periods[f"{wave_type}_{velocity_type}"].add(period_idx)
            else:
                parts = line.split()
                lat, lon = float(parts[0]), float(parts[1])
                rcv.add((lat, lon))

                if not is_num:
                    src_to_rcv[current_src].add((lat, lon))

    n_src = len(src)
    n_rcv = len(rcv)
    n_station = len(src | rcv)
    n_periods = {key: len(val) for key, val in periods.items()}
    if is_num:
        return n_src, n_rcv, n_station, n_periods
    else:
        station = np.array(list(src | rcv))
        return station, src_to_rcv, n_periods, max(n_src, n_rcv)


def auto_get_model_parameter(station, dLat = 0.01, dLon = 0.01, pad = 0):
    Lat, Lon = station[:, 0], station[:, 1]

    lat_min, lat_max = Lat.min(), Lat.max()
    lon_min, lon_max = Lon.min(), Lon.max()

    prec_lat = len(str(dLat).split(".")[1]) if "." in str(dLat) else 0
    prec_lon = len(str(dLon).split(".")[1]) if "." in str(dLon) else 0

    ideal_top = round(np.ceil(lat_max / dLat) * dLat, prec_lat)
    ideal_bottom = round(np.floor(lat_min / dLat) * dLat, prec_lat)

    ideal_left = round(np.floor(lon_min / dLon) * dLon, prec_lon)
    ideal_right = round(np.ceil(lon_max / dLon) * dLon, prec_lon)

    nx_center = int(round((ideal_top - ideal_bottom) / dLat)) + 1
    ny_center = int(round((ideal_right - ideal_left) / dLon)) + 1

    nx = nx_center + 2 * pad + 2
    ny = ny_center + 2 * pad + 2

    originLat = round(ideal_top + pad * dLat, prec_lat)
    originLon = round(ideal_left - pad * dLon, prec_lon)

    return originLat, originLon, nx, ny


def get_src_extent(data, origin = "upper"):
    numrows, numcols = data.shape
    if origin == "upper":
        extent = (-0.5, numcols - 0.5, numrows - 0.5, -0.5)
    else:
        extent = (-0.5, numcols - 0.5, -0.5, numrows - 0.5)
    return extent


def get_image_extent(data, originLat, originLon, dLat, dLon, origin = "upper"):
    extent = get_src_extent(data, origin)
    originGrid = np.array([originLon, originLon, originLat, originLat])
    dGrid = np.array([dLon, dLon, -dLat, -dLat])
    return extent * dGrid + originGrid


def get_inv_file_dir(path_type = "local"):
    if path_type == "local":
        project_path = Storage.lastLocalProjectPath
    else:
        project_path = Storage.lastRemoteProjectPath

    inv_type = Storage.lastInvType
    inv_file_dir = os.path.join(project_path, "InvResult", inv_type)
    return inv_file_dir


def get_inv_type():
    tt = Storage.ItemWidget["travelTime"].getContent().lower()
    senK = Storage.ItemWidget["senK"].getContent().lower()
    lsmr = Storage.ItemWidget["lsmr"].getContent().lower()
    int_type = f"tt_{tt}_senK_{senK}_lsmr_{lsmr}"
    return int_type


def generate_checkerboard_mask(nx, ny, nz, grid_dx, grid_dy, grid_dz):
    z_blocks = np.zeros(nz, dtype = int)

    if isinstance(grid_dz, int):
        z_indices = np.arange(nz)
        z_blocks = z_indices // grid_dz

    elif isinstance(grid_dz, list):
        current_z = 0
        layer_idx = 0

        for height in grid_dz:
            if current_z >= nz:
                break

            end_z = min(current_z + height, nz)

            z_blocks[current_z:end_z] = layer_idx

            current_z = end_z
            layer_idx += 1

        if current_z < nz:
            z_blocks[current_z:] = layer_idx

    # X axis: (nx,) -> (nx, 1, 1)
    x_indices = np.arange(nx)
    x_blocks = (x_indices // grid_dx).reshape(-1, 1, 1)

    # Y axis: (ny,) -> (1, ny, 1)
    y_indices = np.arange(ny)
    y_blocks = (y_indices // grid_dy).reshape(1, -1, 1)

    # Z axis: (1, 1, nz)
    z_blocks = z_blocks.reshape(1, 1, -1)

    parity = (x_blocks + y_blocks + z_blocks) % 2

    # 0 -> 1, 1 -> -1
    checkerboard = np.where(parity == 0, 1, -1)

    return checkerboard
