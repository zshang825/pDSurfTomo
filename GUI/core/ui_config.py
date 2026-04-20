import os


def get_default_ssh_key():
    ssh_dir = os.path.join(os.path.expanduser("~"), ".ssh")

    default_keys = ["id_ed25519", "id_rsa", "id_ecdsa", "id_dsa"]

    for key_name in default_keys:
        full_path = os.path.join(ssh_dir, key_name)
        if os.path.exists(full_path):
            return full_path
    return ""

ItemDefaultValue = {
    # ParallelItemInfo
    "threadNum": f"{os.cpu_count() // 2}",
    "senK": "Disba",
    "travelTime": "Parallel",
    "lsmr": "SciPy",

    # ModelItemInfo
    "nx": "",
    "ny": "",
    "nz": "",
    "originLat": "",
    "originLon": "",
    "dLat": "",
    "dLon": "",

    # InversionItemInfo
    "project_path": "",
    "data_path": "",
    "is_synthetic": False,
    "grid_dx": "2",
    "grid_dy": "2",
    "grid_dz": "3 6 9",
    "perturbation": "0.05",
    "iteration": "10",
    "weight": "5.0",
    "damp": "1.0",
    "min_vel": "0.5",
    "max_vel": "4.5",
    "sparsity": "0.2",
    "subLayer": "3",
    "noiseLevel": "0.02",
    "threshold": "3.5",
    "kmaxRc": "",
    "p_Rc": "",
    "kmaxRg": "",
    "p_Rg": "",
    "kmaxLc": "",
    "p_Lc": "",
    "kmaxLg": "",
    "p_Lg": "",

    # plotStationItemInfo
    "plot_nx": "",
    "plot_ny": "",
    "plot_nz": "",
    "plot_station_image_export_type": "PNG",
    "plot_originLat": "",
    "plot_originLon": "",
    "plot_dLat": "",
    "plot_dLon": "",

    # plotMultiSliceItemInfo
    "plot_row": "2",
    "plot_col": "3",
    "plot_layer": "0 2 4 6 8 10",
    "plot_multi_slice_image_export_type": "PNG",
    "plot_multi_cmap": "BlueDarkRed18",
    "plot_multi_vmin": "None",
    "plot_multi_vmax": "None",
    "plot_multi_colorbar_direction": "horizontal",

    # plotOrthoSliceItemInfo
    "plot_ortho_slice_image_export_type": "PNG",
    "plot_ortho_cmap": "BlueDarkRed18",
    "plot_ortho_vmin": "None",
    "plot_ortho_vmax": "None",
    "plot_ortho_colorbar_direction": "horizontal",

    # SSHItemInfo
    "ssh_ip": "",
    "ssh_port": "22",

    "ssh_username": "",
    "ssh_password": "",
    "ssh_key_file_path": get_default_ssh_key(),
    "ssh_remote_root": "",
    "ssh_python_path": "",
}

ParallelItemInfo = {
    "threadNum": {
        "LabelText": "ThreadNum",
        "Tooltip": "ThreadNum",
        "WidgetType": "MyEditableComboBox",
        "WidgetLayout": "V"
    },
    "travelTime": {
        "LabelText": "TravelTime Module",
        "Tooltip": "TravelTime Module Type",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
    "senK": {
        "LabelText": "SenK Module",
        "Tooltip": "Sensitivity Kernel Module Type",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
    "lsmr": {
        "LabelText": "LSMR Solver",
        "Tooltip": "LSMR Solver Type",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },

}

ParallelGridLayout = {
    "travelTime": [0, 0, 1, 1],
    "senK": [0, 1, 1, 1],
    "lsmr": [0, 2, 1, 1],
    "threadNum": [0, 3, 1, 1],
}

InversionItemInfo = {
    "project_path": {
        "LabelText": "Project Path",
        "Tooltip": "Project Path (Determined by SurfData Path)",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "data_path": {
        "LabelText": "SurfData Path",
        "Tooltip": "SurfData Path",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
    "is_synthetic": {
        "LabelText": "Synthetic",
        "Tooltip": "",
        "WidgetType": "MySwitchButton",
        "WidgetLayout": "H"
    },
    "iteration": {
        "LabelText": "Iteration",
        "Tooltip": "Maximum Iteration",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "H"
    },
    "grid_dx": {
        "LabelText": "Grid dx",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "grid_dy": {
        "LabelText": "Grid dy",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "grid_dz": {
        "LabelText": "Grid dz",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "perturbation": {
        "LabelText": "Perturbation",
        "Tooltip": "velocity perturbation for checkerboard",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "weight": {
        "LabelText": "Smooth Weight",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "damp": {
        "LabelText": "LSMR damp",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "min_vel": {
        "LabelText": "Min Velocity",
        "Tooltip": "minimum velocity (a priori information)",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "max_vel": {
        "LabelText": "Max Velocity",
        "Tooltip": "maximum velocity (a priori information)",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "sparsity": {
        "LabelText": "Sparsity",
        "Tooltip": "Sparsity Fraction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "subLayer": {
        "LabelText": "SubLayer",
        "Tooltip": "SabLayers (for computing depth kernel, 2~5)",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "noiseLevel": {
        "LabelText": "Noise Level",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "threshold": {
        "LabelText": "Threshold",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "kmaxRc": {
        "LabelText": "kmaxRc",
        "Tooltip": "Period Number of Rayleigh wave Phase velocity",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "p_Rc": {
        "LabelText": "Periods of Rc",
        "Tooltip": "Periods of Rayleigh wave Phase velocity",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
    "kmaxRg": {
        "LabelText": "kmaxRg",
        "Tooltip": "Period Number of Rayleigh wave Group velocity",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "p_Rg": {
        "LabelText": "Periods of Rg",
        "Tooltip": "Periods of Rayleigh wave Group velocity",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
    "kmaxLc": {
        "LabelText": "kmaxLc",
        "Tooltip": "Period Number of Love wave Phase velocity",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "p_Lc": {
        "LabelText": "Periods of Lc",
        "Tooltip": "Periods of Love wave Phase velocity",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
    "kmaxLg": {
        "LabelText": "kmaxLg",
        "Tooltip": "Period Number of Love wave Group velocity",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "p_Lg": {
        "LabelText": "Periods of Lg",
        "Tooltip": "Periods of Love wave Group velocity",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
}

InversionGridLayout = {
    "is_synthetic": [0, 0, 1, 1],
    "iteration": [0, 1, 1, 1],

    "grid_dx": [1, 0, 1, 1],
    "grid_dy": [1, 1, 1, 1],
    "grid_dz": [1, 2, 1, 1],
    "perturbation": [1, 3, 1, 1],

    "project_path": [2, 0, 1, 4],

    "data_path": [3, 0, 1, 4],

    "weight": [4, 0, 1, 1],
    "damp": [4, 1, 1, 1],
    "min_vel": [4, 2, 1, 1],
    "max_vel": [4, 3, 1, 1],

    "sparsity": [5, 0, 1, 1],
    "subLayer": [5, 1, 1, 1],
    "noiseLevel": [5, 2, 1, 1],
    "threshold": [5, 3, 1, 1],

    "kmaxRc": [6, 0, 1, 1],
    "p_Rc": [6, 1, 1, 3],

    "kmaxRg": [7, 0, 1, 1],
    "p_Rg": [7, 1, 1, 3],

    "kmaxLc": [8, 0, 1, 1],
    "p_Lc": [8, 1, 1, 3],

    "kmaxLg": [9, 0, 1, 1],
    "p_Lg": [9, 1, 1, 3],
}

ModelItemInfo = {
    "nx": {
        "LabelText": "Nx",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "ny": {
        "LabelText": "Ny",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "nz": {
        "LabelText": "Nz",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "originLat": {
        "LabelText": "Origin Lat",
        "Tooltip": "Origin Lar (upper left point [lat, lon])",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "originLon": {
        "LabelText": "Origin Lon",
        "Tooltip": "Origin Lon (upper left point [lat, lon])",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "dLat": {
        "LabelText": "dLat",
        "Tooltip": "Grid Interval in lat direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "dLon": {
        "LabelText": "dLon",
        "Tooltip": "Grid Interval in lon direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
}

ModelGridLayout = {
    "nx": [0, 0, 1, 2],
    "ny": [0, 2, 1, 2],
    "nz": [0, 4, 1, 2],
    "originLat": [1, 0, 1, 3],
    "originLon": [1, 3, 1, 3],
    "dLat": [2, 0, 1, 3],
    "dLon": [2, 3, 1, 3],
}

plotStationItemInfo = {
    "plot_nx": {
        "LabelText": "Nx",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_ny": {
        "LabelText": "Ny",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_nz": {
        "LabelText": "Nz",
        "Tooltip": "Grid Number in (lat lon depth) Direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "plot_originLat": {
        "LabelText": "Origin Lat",
        "Tooltip": "Origin Lar (upper left point [lat, lon])",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "plot_originLon": {
        "LabelText": "Origin Lon",
        "Tooltip": "Origin Lon (upper left point [lat, lon])",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_dLat": {
        "LabelText": "dLat",
        "Tooltip": "Grid Interval in lat direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_dLon": {
        "LabelText": "dLon",
        "Tooltip": "Grid Interval in lon direction",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_station_image_export_type": {
        "LabelText": "Export Image Type",
        "Tooltip": "Grid Interval in lon direction",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
}
plotStationGridLayout = {
    "plot_nx": [0, 0, 1, 1],
    "plot_ny": [0, 1, 1, 1],
    "plot_nz": [0, 2, 1, 1],
    "plot_station_image_export_type": [0, 3, 1, 1],

    "plot_originLat": [1, 0, 1, 1],
    "plot_originLon": [1, 1, 1, 1],
    "plot_dLat": [1, 2, 1, 1],
    "plot_dLon": [1, 3, 1, 1],
}

plotMultiSliceItemInfo = {
    "plot_row": {
        "LabelText": "row",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_col": {
        "LabelText": "col",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_layer": {
        "LabelText": "Layers",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },

    "plot_multi_cmap": {
        "LabelText": "cmap",
        "Tooltip": "",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },

    "plot_multi_vmin": {
        "LabelText": "vmin",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_multi_vmax": {
        "LabelText": "vmax",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_multi_colorbar_direction": {
        "LabelText": "Colorbar Direction",
        "Tooltip": "",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
    "plot_multi_slice_image_export_type": {
        "LabelText": "Export Image Type",
        "Tooltip": "Export Image Type",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
}

plotMultiSliceGridLayout = {
    "plot_row": [0, 0, 1, 1],
    "plot_col": [0, 1, 1, 1],
    "plot_layer": [0, 2, 1, 1],
    "plot_multi_slice_image_export_type": [0, 3, 1, 1],

    "plot_multi_cmap": [1, 0, 1, 1],
    "plot_multi_vmin": [1, 1, 1, 1],
    "plot_multi_vmax": [1, 2, 1, 1],
    "plot_multi_colorbar_direction": [1, 3, 1, 1],
}

plotOrthoSliceItemInfo = {
    "plot_ortho_cmap": {
        "LabelText": "cmap",
        "Tooltip": "",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },

    "plot_ortho_vmin": {
        "LabelText": "vmin",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_ortho_vmax": {
        "LabelText": "vmax",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "plot_ortho_colorbar_direction": {
        "LabelText": "Colorbar Direction",
        "Tooltip": "",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
    "plot_ortho_slice_image_export_type": {
        "LabelText": "Export Image Type",
        "Tooltip": "Export Image Type",
        "WidgetType": "MyComboBox",
        "WidgetLayout": "V"
    },
}

plotOrthoSliceGridLayout = {
    "plot_ortho_colorbar_direction": [0, 0, 1, 1],
    "plot_ortho_slice_image_export_type": [0, 1, 1, 1],

    "plot_ortho_cmap": [1, 0, 1, 1],
    "plot_ortho_vmin": [1, 1, 1, 1],
    "plot_ortho_vmax": [1, 2, 1, 1],
}

SSHItemInfo = {
    "ssh_ip": {
        "LabelText": "IP",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "ssh_port": {
        "LabelText": "Port",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "ssh_username": {
        "LabelText": "Username",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "ssh_password": {
        "LabelText": "Password",
        "Tooltip": "",
        "WidgetType": "MyPasswordLineEdit",
        "WidgetLayout": "V"
    },
    "ssh_key_file_path": {
        "LabelText": "Key Path",
        "Tooltip": "",
        "WidgetType": "MyLineEditPath",
        "WidgetLayout": "V"
    },
    "ssh_remote_root": {
        "LabelText": "Remote Project Root",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
    "ssh_python_path": {
        "LabelText": "Remote Python Interpreter Path",
        "Tooltip": "",
        "WidgetType": "MyLineEdit",
        "WidgetLayout": "V"
    },
}

SSHGridLayout = {
    "ssh_ip": [0, 0, 1, 3],
    "ssh_port": [0, 3, 1, 1],

    "ssh_username": [1, 0, 1, 4],
    "ssh_password": [2, 0, 1, 4],
    "ssh_key_file_path": [3, 0, 1, 4],

    "ssh_remote_root": [0, 0, 1, 4],
    "ssh_python_path": [1, 0, 1, 4],
}
