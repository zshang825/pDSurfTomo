from .ui_config import *

from PyQt5.QtCore import pyqtSignal, QObject

class MySignal(QObject):
    stdOutSignal = pyqtSignal(str)
    stdErrSignal = pyqtSignal(str)
    plotUpdateSignal = pyqtSignal()
    plotMainStationSignal = pyqtSignal()
    plotMainInitModelSignal = pyqtSignal()
    clearPlotMainStationSignal = pyqtSignal()
    clearPlotMainInitModelSignal = pyqtSignal()

    initModelFileSelectSignal = pyqtSignal(str)
    clearVelocityTableSignal = pyqtSignal()
    periodFileSelectSignal = pyqtSignal(str)

    plotOrthoSliceSignal = pyqtSignal(int, str)

    MultiColorbarChangeSignal = pyqtSignal()
    OrthoColorbarChangeSignal = pyqtSignal()

    updateFileListSignal = pyqtSignal()

    clearPlotInterfaceSignal = pyqtSignal()

    clearFileListSignal = pyqtSignal()

    updateInvResultSignal = pyqtSignal()

    infoBarSignal = pyqtSignal(str, str, str)

class Storage:
    Signal = MySignal()

    MainWindow = None

    SSH = None
    process = None
    stdOutStream = None
    stdErrStream = None
    local_pid = None
    remote_pid = None

    LabelFont = "consolas"
    LabelFontSize = 12

    is_running = False

    # Extract boundaries for plotting purposes using an alphashape (generalized convex hull)
    # - alpha = 0 produces a standard convex hull.
    # - Larger alpha values produce tighter, more finely detailed boundaries.
    # - Tune this parameter according to your station distribution. Starting with 2.0 is suggested.
    convex_hull_alpha = 2.0

    n_interp_point_lat = 9
    n_interp_point_lon = 9
    interp_model_cache = {}
    interp_model_mask = None
    src_lat = None
    src_lon = None
    interp_lat = None
    interp_lon = None
    station_boundary = None

    is_remote = False
    max_thread = os.cpu_count()

    is_first_info_remote_inversion = True
    is_first_info_image_export = True


    filelist_current_project_path = ""

    # image
    image_dpi = 300

    # model
    depth = None
    vel_1d = None

    # Surf Data Config
    pad = 1

    station = None
    src_to_rcv = None
    n_periods = None
    max_src_rcv = None

    localRoot = os.path.normpath(os.path.join(os.getcwd(), ".."))
    localProjectPath = ""

    remoteRoot = ""
    remoteProjectPath = ""

    iteration = 0
    lastLocalProjectPath = ""
    lastRemoteProjectPath = ""
    lastInvType = ""

    InversionReadOnlyKey = ["project_path", "nz", "kmaxRc", "kmaxRg", "kmaxLc", "kmaxLg"]
    ComboBoxItems = {
        "senK": ["Disba", "Parallel"],
        "travelTime": ["Parallel", "Default"],
        "lsmr": ["SciPy", "CuPy", "Default"],
        "threadNum": [str(2 ** i) for i in range(3, 10) if 2 ** i <= os.cpu_count()],

        "plot_multi_cmap": ["BlueDarkRed18", "jet", "seismic", "coolwarm"],
        "plot_ortho_cmap": ["BlueDarkRed18", "jet", "seismic", "coolwarm"],

        "plot_multi_colorbar_direction": ["horizontal", "vertical"],
        "plot_ortho_colorbar_direction": ["horizontal", "vertical"],

        "plot_station_image_export_type": ["PNG", "JPG", "SVG"],
        "plot_multi_slice_image_export_type": ["PNG", "JPG", "SVG"],
        "plot_ortho_slice_image_export_type": ["PNG", "JPG", "SVG"],
    }

    ItemDefaultValue = ItemDefaultValue
    ItemWidget = {}

    ParallelKey = ParallelItemInfo.keys()
    InversionKey = InversionItemInfo.keys()
    ModelKey = ModelItemInfo.keys()
    plotStationKey = plotStationItemInfo.keys()
    plotMultiSliceKey = plotMultiSliceItemInfo.keys()
    plotOrthoSliceKey = plotOrthoSliceItemInfo.keys()
    sshKey = SSHItemInfo.keys()

    ItemInfo = {**ParallelItemInfo, **InversionItemInfo,
                **ModelItemInfo, **plotStationItemInfo,
                **plotMultiSliceItemInfo, **plotOrthoSliceItemInfo,
                **SSHItemInfo}
    GridLayout = {**ParallelGridLayout, **InversionGridLayout,
                  **ModelGridLayout, **plotStationGridLayout,
                  **plotMultiSliceGridLayout, **plotOrthoSliceGridLayout,
                  **SSHGridLayout}
