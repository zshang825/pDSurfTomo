from PyQt5.QtWidgets import QTableWidgetItem

from .CustomWidget import *
from .utils_interact import *
from qfluentwidgets import HeaderCardWidget, ScrollArea, TableWidget, TextEdit, setFont


class ParallelConfigCard(HeaderCardWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setBorderRadius(8)
        self.setTitle("ParallelConfig")
        setFont(self.headerLabel, 20, QFont.DemiBold)

        self.layout = QGridLayout(self)

        for key in Storage.ParallelKey:
            self.layout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.layout.setHorizontalSpacing(10)
        self.layout.setVerticalSpacing(8)
        self.layout.setContentsMargins(0, 0, 0, 0)

        self.layout.setColumnStretch(0, 1)
        self.layout.setColumnStretch(1, 1)
        self.layout.setColumnStretch(2, 1)
        self.layout.setColumnStretch(3, 1)
        # self.layout.setColumnStretch(4, 1)

        self.viewLayout.addLayout(self.layout)
        self.viewLayout.setContentsMargins(24, 6, 24, 12)


class InversionConfigCard(HeaderCardWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setBorderRadius(8)
        self.setTitle("InversionConfig")
        setFont(self.headerLabel, 20, QFont.DemiBold)

        self.layout = QGridLayout(self)

        for key in Storage.InversionKey:
            self.layout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.layout.setHorizontalSpacing(10)
        self.layout.setVerticalSpacing(8)
        self.layout.setContentsMargins(0, 0, 0, 0)

        self.layout.setColumnStretch(0, 1)
        self.layout.setColumnStretch(1, 1)
        self.layout.setColumnStretch(2, 1)
        self.layout.setColumnStretch(3, 1)
        # self.layout.setColumnStretch(4, 1)

        self.viewLayout.addLayout(self.layout)
        self.viewLayout.setContentsMargins(24, 6, 24, 12)


class ParameterCard(ScrollArea):
    def __init__(self, parent = None):
        super(ParameterCard, self).__init__(parent)

        self.view = QWidget(self)
        self.vBoxLayout = QVBoxLayout(self.view)

        self.parallel_config_card = ParallelConfigCard(self)
        self.inversion_config_card = InversionConfigCard(self)

        self.setWidget(self.view)
        self.setWidgetResizable(True)

        self.vBoxLayout.setSpacing(8)
        self.vBoxLayout.setContentsMargins(0, 0, 0, 0)
        self.vBoxLayout.addWidget(self.parallel_config_card)
        self.vBoxLayout.addWidget(self.inversion_config_card)

        self.enableTransparentBackground()


class ModelCard(SimpleCardWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setBorderRadius(8)

        self.gridlayout = QGridLayout()
        for key in Storage.ModelKey:
            self.gridlayout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.btn_import_model = PrimaryPushButton("Import Initial Model", self)
        self.btn_import_model.setFont(QFont(Storage.LabelFont, 14))
        self.btn_import_model.clicked.connect(self.btn_click_import_model)

        self.btn_auto_setting = PrimaryPushButton("Auto Setting", self)
        self.btn_auto_setting.setFont(QFont(Storage.LabelFont, 14))
        self.btn_auto_setting.clicked.connect(self.btn_click_auto_setting)

        self.btn_plot_update = PrimaryPushButton("Plot Update", self)
        self.btn_plot_update.setFont(QFont(Storage.LabelFont, 14))
        self.btn_plot_update.clicked.connect(self.btn_click_plot_update)

        # self.btn_add_row = PrimaryPushButton("Add Row", self)
        # self.btn_add_row.setFont(QFont(Storage.LabelFont, 14))
        # self.btn_add_row.clicked.connect(self.btn_click_add_row)
        #
        # self.btn_remove_row = PrimaryPushButton("Remove Row", self)
        # self.btn_remove_row.setFont(QFont(Storage.LabelFont, 14))
        # self.btn_remove_row.clicked.connect(self.btn_click_remove_row)

        self.gridlayout.addWidget(self.btn_import_model, *[3, 0, 1, 6])
        self.gridlayout.addWidget(self.btn_auto_setting, *[4, 0, 1, 3])
        self.gridlayout.addWidget(self.btn_plot_update, *[4, 3, 1, 3])
        # self.gridlayout.addWidget(self.btn_add_row, *[5, 0, 1, 3])
        # self.gridlayout.addWidget(self.btn_remove_row, *[5, 3, 1, 3])
        self.gridlayout.setHorizontalSpacing(10)
        self.gridlayout.setVerticalSpacing(8)
        self.gridlayout.setContentsMargins(0, 0, 0, 0)

        self.gridlayout.setColumnStretch(0, 1)
        self.gridlayout.setColumnStretch(1, 1)
        self.gridlayout.setColumnStretch(2, 1)
        self.gridlayout.setColumnStretch(3, 1)
        self.gridlayout.setColumnStretch(4, 1)
        self.gridlayout.setColumnStretch(5, 1)

        self.tableWidget = TableWidget(self)
        self.tableWidget.setBorderVisible(False)
        self.tableWidget.setBorderRadius(8)
        self.tableWidget.setWordWrap(False)

        self.layout = QVBoxLayout(self)
        self.layout.setSpacing(8)
        self.layout.setContentsMargins(24, 6, 24, 12)
        self.layout.addLayout(self.gridlayout)
        self.layout.addWidget(self.tableWidget)

    def updateModelFromTable(self):
        row_count = self.tableWidget.rowCount()
        col_count = self.tableWidget.columnCount()

        data = []

        for row in range(row_count):
            row_data = []
            for col in range(col_count):
                item = self.tableWidget.item(row, col)
                if item is not None:
                    val = item.text()
                else:
                    val = "0"

                row_data.append(float(val))
            data.append(row_data)
        model = np.array(data)
        Storage.depth, Storage.vel_1d = model[:, 0], model[:, 1]

    def clearModelTable(self):
        self.tableWidget.setEditTriggers(self.tableWidget.NoEditTriggers)
        self.tableWidget.setRowCount(0)
        self.tableWidget.setColumnCount(0)

    def insert_row(self, row_idx, depth = "", velocity = ""):
        item_depth = QTableWidgetItem(depth)
        item_depth.setFont(QFont(Storage.LabelFont, 12))
        item_depth.setTextAlignment(Qt.AlignmentFlag.AlignCenter)

        item_velocity = QTableWidgetItem(velocity)
        item_velocity.setFont(QFont(Storage.LabelFont, 12))
        item_velocity.setTextAlignment(Qt.AlignmentFlag.AlignCenter)

        self.tableWidget.setItem(row_idx, 0, item_depth)
        self.tableWidget.setItem(row_idx, 1, item_velocity)
        Storage.ItemWidget["nz"].widget.setText(f"{self.tableWidget.rowCount()}")

    def btn_click_add_row(self):
        row_idx = self.tableWidget.rowCount()
        self.tableWidget.insertRow(row_idx)
        self.insert_row(row_idx)

    def btn_click_remove_row(self):
        self.tableWidget.removeRow(self.tableWidget.rowCount() - 1)
        Storage.ItemWidget["nz"].widget.setText(f"{self.tableWidget.rowCount()}")

    def solve_choose_init_model_file(self, filepath):
        model = load_json(filepath)
        depth, vel_1d = model["depth"], model["vel_1d"]
        Storage.depth, Storage.vel_1d = model["depth"], model["vel_1d"]

        self.tableWidget.clear()
        self.tableWidget.setRowCount(len(depth))
        self.tableWidget.setColumnCount(2)
        self.tableWidget.setHorizontalHeaderLabels(["Depth\n(km)", "Vs\n(km/s)"])
        self.tableWidget.horizontalHeader().setStyleSheet("QHeaderView::section { font-size: 16px; font-family:consolas; color:#000000}")
        self.tableWidget.horizontalHeader().setDefaultAlignment(Qt.AlignmentFlag.AlignCenter)
        self.tableWidget.verticalHeader().setDefaultAlignment(Qt.AlignmentFlag.AlignCenter)

        for i, (depz, vel) in enumerate(zip(depth, vel_1d)):
            self.insert_row(i, f"{depz:.2f}", f"{vel:.3f}")

    def btn_click_import_model(self):
        filefilter = "Model Info File (*.json);;  All Files (*.*)"
        filepath, _ = QFileDialog.getOpenFileName(self, caption = "Open File", filter = filefilter,
                                                  directory = Storage.localProjectPath)

        if len(filepath) == 0:
            return
        self.solve_choose_init_model_file(filepath)

    def btn_click_auto_setting(self):
        btn_click_auto_setting()

    def btn_click_plot_update(self):
        btn_click_main_plot_update()


class PlotCard(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        # self.setBorderRadius(8)

        self.stationPlotWidget = PlotWidget(self)
        self.modelPlotWidget = PlotWidget(self)

        self.vLayout = QVBoxLayout(self)
        self.vLayout.setSpacing(8)
        self.vLayout.setContentsMargins(0, 0, 0, 0)

        self.vLayout.addWidget(self.stationPlotWidget)
        self.vLayout.addWidget(self.modelPlotWidget)

    def updatePlotStation(self):
        self.stationPlotWidget.fig.clear()

        self.stationPlotWidget.ax = self.stationPlotWidget.fig.add_subplot(111)
        self.stationPlotWidget.ax.tick_params(labelsize = 12)
        self.stationPlotWidget.ax.xaxis.set_major_formatter("{x:.1f}°")
        self.stationPlotWidget.ax.yaxis.set_major_formatter("{x:.1f}°")

        plot_inv_grid(self.stationPlotWidget.fig, self.stationPlotWidget.ax,
                      is_plot_grid_point = True,
                      is_plot_image = False)

        self.stationPlotWidget.fig.canvas.draw()

    def clearPlotStation(self):
        self.stationPlotWidget.fig.clear()
        self.stationPlotWidget.fig.canvas.draw()

    def clearPlotInitModel(self):
        self.modelPlotWidget.fig.clear()
        self.modelPlotWidget.fig.canvas.draw()

    def updatePlotInitModel(self):
        self.modelPlotWidget.fig.clear()

        self.modelPlotWidget.ax = self.modelPlotWidget.fig.add_subplot(111, projection = "3d")
        self.modelPlotWidget.ax.tick_params(labelsize = 12, pad = -1.5)
        self.modelPlotWidget.ax.xaxis.set_major_formatter("{x:.1f}°")
        self.modelPlotWidget.ax.yaxis.set_major_formatter("{x:.1f}°")

        plot_init_model_3d(self.modelPlotWidget.fig, self.modelPlotWidget.ax)

        self.modelPlotWidget.fig.canvas.draw()


class LogCard(TextEdit):
    def __init__(self, parent = None):
        super().__init__(parent)
        # self.setMinimumHeight(300)
        self.setMaximumHeight(250)
        self.setReadOnly(True)
        self.setFont(QFont("consolas", 12))

    def addStdOut(self, text):
        text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
        # html_text = text.replace("<", "&lt;").replace(">", "&gt;")
        # html = f"<div style='white-space:pre-wrap;'>{html_text}</div><br>"

        html = f"<div style='white-space:pre-wrap;'>{text}</div><br>"
        self.insertHtml(html)
        self.ensureCursorVisible()

    def addStdErr(self, text):
        text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
        # html_text = text.replace("<", "&lt;").replace(">", "&gt;")
        # html = f"<div style='color:red; white-space:pre-wrap;'>{html_text}</div><br>"

        html = f"<div style='color:red; white-space:pre-wrap;'>{text}</div><br>"
        self.insertHtml(html)
        self.ensureCursorVisible()

    def addLog(self, text):
        self.insertPlainText(text)
        self.ensureCursorVisible()


class InversionButtonCard(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)

        self.btn_generate_config = PrimaryPushButton("Generate Config", self)
        self.btn_run = PrimaryPushButton("Run", self)
        self.btn_stop = PrimaryPushButton("Stop", self)

        self.btn_generate_config.setFont(QFont(Storage.LabelFont, 16))
        self.btn_run.setFont(QFont(Storage.LabelFont, 16))
        self.btn_stop.setFont(QFont(Storage.LabelFont, 16))

        self.btn_generate_config.clicked.connect(btn_click_generate_config)
        self.btn_run.clicked.connect(btn_click_run)
        self.btn_stop.clicked.connect(btn_click_stop)

        self.layout = QGridLayout(self)
        self.layout.setSpacing(8)
        self.layout.setContentsMargins(0, 0, 0, 1)
        self.layout.addWidget(self.btn_generate_config, *[0, 0, 1, 2])
        self.layout.addWidget(self.btn_run, *[1, 0, 1, 1])
        self.layout.addWidget(self.btn_stop, *[1, 1, 1, 1])


class MainInterface(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setObjectName("MainInterface")

        # Left Layout
        self.model_card = ModelCard(self)

        # Middle Layout
        self.parameter_card = ParameterCard(self)
        self.log_card = LogCard(self)

        # Right Layout
        self.plot_card = PlotCard(self)
        self.button_card = InversionButtonCard(self)

        self.middleVLayout = QVBoxLayout()
        self.middleVLayout.setSpacing(8)
        self.middleVLayout.setContentsMargins(0, 0, 0, 0)
        self.middleVLayout.addWidget(self.parameter_card)
        self.middleVLayout.addWidget(self.log_card)

        self.rightVLayout = QVBoxLayout()
        self.rightVLayout.setSpacing(8)
        self.rightVLayout.setContentsMargins(0, 0, 0, 0)
        self.rightVLayout.addWidget(self.plot_card)
        self.rightVLayout.addWidget(self.button_card)

        self.hLayout = QHBoxLayout(self)
        self.hLayout.setSpacing(8)
        self.hLayout.setContentsMargins(12, 0, 12, 6)

        self.hLayout.addWidget(self.model_card, stretch = 1)
        self.hLayout.addLayout(self.middleVLayout, stretch = 3)
        self.hLayout.addLayout(self.rightVLayout, stretch = 2)

        Storage.Signal.stdOutSignal.connect(self.log_card.addStdOut)
        Storage.Signal.stdErrSignal.connect(self.log_card.addStdErr)
        Storage.Signal.plotUpdateSignal.connect(self.plot_card.updatePlotStation)
        Storage.Signal.plotUpdateSignal.connect(self.plot_card.updatePlotInitModel)

        Storage.Signal.plotMainStationSignal.connect(self.plot_card.updatePlotStation)
        Storage.Signal.plotMainInitModelSignal.connect(self.plot_card.updatePlotInitModel)
        Storage.Signal.clearPlotMainStationSignal.connect(self.plot_card.clearPlotStation)
        Storage.Signal.clearPlotMainInitModelSignal.connect(self.plot_card.clearPlotInitModel)

        Storage.Signal.initModelFileSelectSignal.connect(self.model_card.solve_choose_init_model_file)
        Storage.Signal.clearVelocityTableSignal.connect(self.model_card.clearModelTable)

        Storage.Signal.updateInvResultSignal.connect(update_inv_file)
        Storage.Signal.infoBarSignal.connect(info_bar)
