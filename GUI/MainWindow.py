import warnings

warnings.filterwarnings("ignore")

from PyQt5.QtCore import QTimer
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QApplication, QFrame

from qfluentwidgets import FluentWindow, setFont, SubtitleLabel

from core.CustomWidget import *
from core.utils_fileIO import *

from core.MainInterface import MainInterface
from core.PlotInterface import PlotStationInterface, PlotMultiSliceInterface, PlotOrthoSliceInterface
from core.SSHInterface import SSHInterface


class Widget(QFrame):

    def __init__(self, text: str, parent = None):
        super().__init__(parent = parent)
        self.label = SubtitleLabel(text, self)
        self.hBoxLayout = QHBoxLayout(self)

        setFont(self.label, 24)
        self.label.setAlignment(Qt.AlignCenter)
        self.hBoxLayout.addWidget(self.label, 1, Qt.AlignCenter)
        self.setObjectName(text.replace(' ', '-'))


class MainWindow(FluentWindow):

    def __init__(self, parent = None):
        super().__init__(parent)
        # setThemeColor('#28afe9')
        # setThemeColor("red")

        self.title_label = None
        self.ssh_label = None

        self.initWindow()

        self.mainInterface = MainInterface(self)
        self.PlotStationInterface = PlotStationInterface(self)
        self.PlotMultiSliceInterface = PlotMultiSliceInterface(self)
        self.PlotOrthoSliceInterface = PlotOrthoSliceInterface(self)
        self.SSH_Interface = SSHInterface(self)

        self.addSubInterface(self.mainInterface, FluentIcon.HOME, "Inversion ", isTransparent = True)
        self.addSubInterface(self.PlotStationInterface, FluentIcon.CARE_UP_SOLID, "Obs System", isTransparent = True)
        self.addSubInterface(self.PlotMultiSliceInterface, FluentIcon.VIEW, "Multi Slice", isTransparent = True)
        self.addSubInterface(self.PlotOrthoSliceInterface, FluentIcon.PALETTE, "Ortho Slice", isTransparent = True)
        self.addSubInterface(self.SSH_Interface, FluentIcon.COMMAND_PROMPT, "SSH", isTransparent = True)

        # self.stackedWidget.setCurrentWidget(self.mainInterface)

        Storage.MainWindow = self

        self.has_plotted_station = False
        self.has_plotted_multi = False
        self.has_plotted_ortho = False

        self.initConfig()
        self.stackedWidget.currentChanged.connect(self.on_tab_changed)

    def on_tab_changed(self, index):
        current_widget = self.stackedWidget.widget(index)
        time_delay = 50
        if current_widget == self.PlotStationInterface and not self.has_plotted_station:
            info_bar("info", "Obs System Interface Loading...", "")
            self.has_plotted_station = True
            QTimer.singleShot(time_delay, self.PlotStationInterface.btn_click_plot_update)
        elif current_widget == self.PlotMultiSliceInterface and not self.has_plotted_multi:
            info_bar("info", "Multi Slice Interface Loading...", "")
            self.has_plotted_multi = True
            QTimer.singleShot(time_delay, self.PlotMultiSliceInterface.fileCard.update_file_list)
        elif current_widget == self.PlotOrthoSliceInterface and not self.has_plotted_ortho:
            info_bar("info", "Ortho Slice Interface Loading...", "")
            self.has_plotted_ortho = True
            QTimer.singleShot(time_delay, self.PlotOrthoSliceInterface.fileCard.update_file_list)

    def initConfig(self):
        if os.path.exists("UserLastSetting.json"):
            UserLastSetting = load_json("UserLastSetting.json")
            Storage.ItemDefaultValue.update(UserLastSetting)

        for key, widget in Storage.ItemWidget.items():
            widget.setContent(Storage.ItemDefaultValue.get(key, ""))

        is_checked = Storage.ItemWidget["is_synthetic"].getContent()
        Storage.ItemWidget["is_synthetic"].setContent(not is_checked)
        Storage.ItemWidget["is_synthetic"].setContent(is_checked)

        data_path = Storage.ItemDefaultValue["data_path"]
        solve_surf_data_path_change(data_path)
        btn_click_auto_setting()
        btn_click_main_plot_update()

    def initWindow(self):
        self.resize(1300, 800)
        self.ssh_label = SubtitleLabel("", self)

        self.title_label = SubtitleLabel(" Parallel-DSurfTomo", self)
        self.titleBar.hBoxLayout.insertWidget(1, self.title_label, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        self.titleBar.hBoxLayout.insertWidget(2, self.ssh_label, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)

        self.setWindowIcon(QIcon(":/qfluentwidgets/images/logo.png"))

        desktop = QApplication.desktop().availableGeometry()
        w, h = desktop.width(), desktop.height()
        self.move(w // 2 - self.width() // 2, h // 2 - self.height() // 2)

        self.setMicaEffectEnabled(True)
        self.navigationInterface.setExpandWidth(150)
        self.navigationInterface.setMinimumExpandWidth(500)
        # self.navigationInterface.expand(useAni = False)

    def closeEvent(self, event):
        super().closeEvent(event)

        Storage.interp_model_cache.clear()

        if Storage.is_remote:
            Storage.SSH.close()

        save_user_setting()


if __name__ == "__main__":
    # enable dpi scale
    QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    QApplication.setAttribute(Qt.AA_EnableHighDpiScaling)
    QApplication.setAttribute(Qt.AA_UseHighDpiPixmaps)

    # setTheme(Theme.DARK)
    # setThemeColor('#28afe9')

    app = QApplication(sys.argv)
    w3 = MainWindow()
    w3.showMaximized()
    w3.show()
    app.exec_()
