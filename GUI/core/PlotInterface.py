from .CustomWidget import *
from .utils_plot import *
from .utils_fileIO import *


class Plot_Interactive_Observation_System:
    def __init__(self, fig: plt.Figure):

        self.fig = fig
        self.ax = None
        self.is_layout_init = False

        self.fig.canvas.mpl_connect("button_press_event", self.on_click)

        self.infoLabel = None

        self.selected_source = None
        self.connection_lines = []

        self.station = None
        self.src_to_rcv = None

    def plot(self):
        if not self.is_layout_init:
            self.ax = self.fig.add_subplot(111)
            self.is_layout_init = True

        plot_inv_grid(self.fig, self.ax,
                      station_marker_size = 100,
                      is_plot_image = True,
                      is_plot_grid_point = False,
                      is_plot_station = True,
                      param_key_prefix = "plot_")

        self.infoLabel = self.ax.text(0.5, 0.975, "Click Info",
                                      fontsize = 12,
                                      va = 'center', ha = 'center',
                                      bbox = dict(boxstyle = "round", facecolor = "wheat", alpha = 0.8),
                                      transform = self.ax.transAxes, )
        self.infoLabel.set_visible(False)

        self.ax.tick_params(labelsize = 14)
        self.ax.xaxis.set_major_formatter("{x:.1f}°")
        self.ax.yaxis.set_major_formatter("{x:.1f}°")

    def clear(self):
        if self.is_layout_init:
            self.clear_connections()
            self.fig.clear()
            self.is_layout_init = False

    def on_click(self, event):
        if event.inaxes != self.ax:
            return

        click_lon, click_lat = event.xdata, event.ydata

        nearest_source = None
        min_distance = float('inf')

        all_sources = Storage.src_to_rcv.keys()

        for source in all_sources:
            lat, lon = source
            distance = ((lon - click_lon) ** 2 + (lat - click_lat) ** 2) ** 0.5

            dLat, dLon = 0.05, 0.05
            tolerance = np.mean([dLat, dLon])

            if distance < min_distance and distance < tolerance:
                min_distance = distance
                nearest_source = source

        if nearest_source:
            self.toggle_source_connections(nearest_source)
            self.fig.canvas.draw_idle()

    def toggle_source_connections(self, source):
        if self.src_to_rcv is None:
            self.src_to_rcv = Storage.src_to_rcv

        lat, lon = source

        if self.selected_source == source:
            self.infoLabel.set_visible(False)
            self.clear_connections()
            self.selected_source = None
            return

        self.infoLabel.set_visible(True)
        self.infoLabel.set_text(f"Source ({source[0]:.2f}, {source[1]:.2f})  RayPathNumber: {len(self.src_to_rcv[source])}")

        self.clear_connections()

        self.selected_source = source

        if source in self.src_to_rcv:
            receivers = self.src_to_rcv[source]

            for receiver in receivers:
                rec_lat, rec_lon = receiver
                line, = self.ax.plot([lon, rec_lon],
                                     [lat, rec_lat],
                                     'gray',
                                     linestyle = '--',
                                     linewidth = 1.5,
                                     alpha = 0.7,
                                     zorder = 1)
                self.connection_lines.append(line)

        self.highlight_selected_source(source)

    def clear_connections(self):
        for line in self.connection_lines:
            line.remove()
        self.connection_lines = []

    def highlight_selected_source(self, source):
        lat, lon = source
        highlight = self.ax.scatter([lon], [lat], s = 200,
                                    marker = "o",
                                    facecolors = "none", edgecolors = "blue",
                                    linewidth = 2, )
        self.connection_lines.append(highlight)


class PlotStationInterface(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setObjectName("PlotStationInterface")

        self.settingCard = SimpleCardWidget(self)
        self.settingCard.setBorderRadius(8)
        self.settingCard.setMaximumHeight(150)

        self.gridLayout = QGridLayout(self.settingCard)
        for key in Storage.plotStationKey:
            self.gridLayout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.btn_plot_update = PrimaryPushButton("Plot Update", self)
        self.btn_plot_update.setFont(QFont(Storage.LabelFont, 14))
        self.btn_plot_update.clicked.connect(self.btn_click_plot_update)

        self.btn_image_export = PrimaryPushButton("Image Export", self)
        self.btn_image_export.setFont(QFont(Storage.LabelFont, 14))
        self.btn_image_export.clicked.connect(self.btn_click_image_export)

        self.gridLayout.addWidget(self.btn_plot_update, 0, 4, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)
        self.gridLayout.addWidget(self.btn_image_export, 1, 4, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)

        self.gridLayout.setHorizontalSpacing(30)
        self.gridLayout.setVerticalSpacing(10)
        self.gridLayout.setContentsMargins(24, 6, 24, 12)
        self.gridLayout.setColumnStretch(0, 1)
        self.gridLayout.setColumnStretch(1, 1)
        self.gridLayout.setColumnStretch(2, 1)
        self.gridLayout.setColumnStretch(3, 1)
        self.gridLayout.setColumnStretch(4, 1)

        self.stationPlotWidget = PlotWidget(self)

        self.vLayout = QVBoxLayout(self)

        self.vLayout.setSpacing(8)
        self.vLayout.setContentsMargins(12, 0, 12, 6)
        self.vLayout.addWidget(self.stationPlotWidget)
        self.vLayout.addWidget(self.settingCard)

        self.interactive_fig = Plot_Interactive_Observation_System(self.stationPlotWidget.fig)

        Storage.Signal.clearPlotInterfaceSignal.connect(self.plotClear)

    def plotClear(self):
        self.interactive_fig.clear()
        self.interactive_fig.fig.canvas.draw()

    def btn_click_plot_update(self):
        if not Storage.MainWindow.has_plotted_station:
            return

        try:
            if Storage.station is None:
                raise FileExistsError("SurfData File not exist")
            self.interactive_fig.clear()
            self.interactive_fig.plot()
            self.interactive_fig.fig.canvas.draw()

        except Exception as e:
            info_bar("error", "Error", traceback.format_exc(), "vertical", duration = -1)
            traceback.print_exc()

    def btn_click_image_export(self):
        suffix = Storage.ItemWidget["plot_station_image_export_type"].getContent().lower()
        filename = f"Station.{suffix}"
        save_image(self.stationPlotWidget.fig, filename, Storage.image_dpi)


class PlotMultiSliceInterface(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setObjectName("PlotMultiSliceInterface")

        self.last_row_col = [0, 0]
        self.is_layout_changed = False
        self.is_first_show = True

        self.settingCard = SimpleCardWidget(self)
        self.settingCard.setBorderRadius(8)
        self.settingCard.setMaximumHeight(150)

        self.gridLayout = QGridLayout(self.settingCard)
        for key in Storage.plotMultiSliceKey:
            self.gridLayout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.btn_plot_update = PrimaryPushButton("Plot Update", self)
        self.btn_plot_update.setFont(QFont(Storage.LabelFont, 14))
        self.btn_plot_update.clicked.connect(self.btn_click_plot_update)

        self.btn_image_export = PrimaryPushButton("Image Export", self)
        self.btn_image_export.setFont(QFont(Storage.LabelFont, 14))
        self.btn_image_export.clicked.connect(self.btn_click_image_export)

        self.gridLayout.addWidget(self.btn_plot_update, 0, 4, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)
        self.gridLayout.addWidget(self.btn_image_export, 1, 4, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)

        self.gridLayout.setHorizontalSpacing(30)
        self.gridLayout.setVerticalSpacing(10)
        self.gridLayout.setContentsMargins(24, 6, 24, 12)
        self.gridLayout.setColumnStretch(0, 1)
        self.gridLayout.setColumnStretch(1, 1)
        self.gridLayout.setColumnStretch(2, 1)
        self.gridLayout.setColumnStretch(3, 1)
        self.gridLayout.setColumnStretch(4, 1)

        self.MultiSlicePlotWidget = PlotWidget(self)

        self.fileCard = FileListWidget(self)
        self.fileCard.fileList.currentItemChanged.connect(self.solve_file_list_click)
        # self.fileCard.fileList.itemClicked.connect(self.solve_file_list_click)

        self.vLayout = QVBoxLayout()
        self.vLayout.addWidget(self.MultiSlicePlotWidget)
        self.vLayout.addWidget(self.settingCard)
        self.vLayout.setContentsMargins(0, 0, 0, 0)
        self.vLayout.setSpacing(8)

        self.hLayout = QHBoxLayout(self)
        self.hLayout.addWidget(self.fileCard)
        self.hLayout.addLayout(self.vLayout)

        self.hLayout.setSpacing(8)
        self.hLayout.setContentsMargins(12, 0, 12, 6)

        Storage.Signal.MultiColorbarChangeSignal.connect(lambda: setattr(self, "is_layout_changed", True))
        Storage.Signal.updateFileListSignal.connect(self.fileCard.btn_click_update_file_list)

        Storage.Signal.clearPlotInterfaceSignal.connect(self.plotClear)
        Storage.Signal.clearFileListSignal.connect(self.fileCard.fileList.clear)

    def plotClear(self):
        self.MultiSlicePlotWidget.fig.clear()
        self.MultiSlicePlotWidget.fig.canvas.draw()

        self.is_layout_changed = True

    def plot_mutil_slice(self):
        row = Storage.ItemWidget["plot_row"].getContent("int")
        col = Storage.ItemWidget["plot_col"].getContent("int")

        current_row_col = [row, col]
        if current_row_col != self.last_row_col or self.is_layout_changed:
            self.last_row_col = current_row_col

            self.MultiSlicePlotWidget.fig.clear()
            self.MultiSlicePlotWidget.fig.set_constrained_layout(True)
            if row * col == 1:
                self.MultiSlicePlotWidget.ax = [self.MultiSlicePlotWidget.fig.subplots(row, col)]
            else:
                self.MultiSlicePlotWidget.ax = self.MultiSlicePlotWidget.fig.subplots(row, col).flatten()
            self.is_layout_changed = True

        filepath = self.fileCard.get_current_filepath()
        vs = Storage.interp_model_cache[filepath]

        plot_multi_slice(vs, self.MultiSlicePlotWidget.fig, self.MultiSlicePlotWidget.ax)

        if self.is_layout_changed:
            self.MultiSlicePlotWidget.fig.canvas.draw()
            self.MultiSlicePlotWidget.fig.set_constrained_layout(False)
            self.is_layout_changed = False

    def btn_click_plot_update(self):
        if not Storage.MainWindow.has_plotted_multi:
            return
        try:
            update_plot_cache()
            update_model_cache(self.fileCard.get_current_filepath())
            self.plot_mutil_slice()

            self.MultiSlicePlotWidget.fig.canvas.draw()
            self.MultiSlicePlotWidget.fig.canvas.flush_events()
            # self.MultiSlicePlotWidget.fig.canvas.draw_idle()
        except Exception as e:
            info_bar("error", "Error", traceback.format_exc(), "vertical", duration = -1)
            traceback.print_exc()

    def btn_click_image_export(self):
        plot_layer = Storage.ItemWidget["plot_layer"].getContent()
        layer = "_".join(plot_layer.strip().split())
        suffix = Storage.ItemWidget["plot_multi_slice_image_export_type"].getContent().lower()
        filename = f"MultiSlice_{layer}.{suffix}"
        save_image(self.MultiSlicePlotWidget.fig, filename, Storage.image_dpi)

    def solve_file_list_click(self, currentItem):
        if currentItem is None:
            return
        self.btn_click_plot_update()



class PlotOrthoSliceInterface(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setObjectName("PlotOrthoSliceInterface")

        self.is_layout_init = False
        self.is_first_show = True

        self.settingCard = SimpleCardWidget(self)
        self.settingCard.setBorderRadius(8)
        self.settingCard.setMaximumHeight(150)

        self.gridLayout = QGridLayout(self.settingCard)
        for key in Storage.plotOrthoSliceKey:
            self.gridLayout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.btn_plot_update = PrimaryPushButton("Plot Update", self)
        self.btn_plot_update.setFont(QFont(Storage.LabelFont, 14))
        self.btn_plot_update.clicked.connect(self.btn_click_plot_update)

        self.btn_image_export = PrimaryPushButton("Image Export", self)
        self.btn_image_export.setFont(QFont(Storage.LabelFont, 14))
        self.btn_image_export.clicked.connect(self.btn_click_image_export)
        self.gridLayout.addWidget(self.btn_plot_update, 0, 3, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)
        self.gridLayout.addWidget(self.btn_image_export, 1, 3, 1, 1, alignment = Qt.AlignmentFlag.AlignBottom)

        self.gridLayout.setHorizontalSpacing(30)
        self.gridLayout.setVerticalSpacing(10)
        self.gridLayout.setContentsMargins(24, 6, 24, 12)
        self.gridLayout.setColumnStretch(0, 1)
        self.gridLayout.setColumnStretch(1, 1)
        self.gridLayout.setColumnStretch(2, 1)
        self.gridLayout.setColumnStretch(3, 1)
        self.gridLayout.setColumnStretch(4, 1)

        self.sliderCard = SimpleCardWidget(self)
        self.sliderCard.setBorderRadius(8)
        self.sliderCard.setMaximumHeight(150)

        self.sliderLayout = QVBoxLayout(self.sliderCard)
        self.slider_xy = MySlider(self, "Depth Slice", tickInterval = 1)
        self.slider_xz = MySlider(self, "Lon Slice", tickInterval = 1)
        self.slider_yz = MySlider(self, "Lat Slice", tickInterval = 1)
        self.sliderLayout.addWidget(self.slider_xy)
        self.sliderLayout.addWidget(self.slider_xz)
        self.sliderLayout.addWidget(self.slider_yz)

        self.sliderLayout.setContentsMargins(24, 6, 24, 12)
        self.sliderLayout.setSpacing(5)

        self.OrthoSlicePlotWidget = PlotWidget(self, constrained_layout = False)

        self.fileCard = FileListWidget(self)
        self.fileCard.fileList.currentItemChanged.connect(self.solve_file_list_click)
        # self.fileCard.fileList.itemClicked.connect(self.solve_file_list_click)

        self.vLayout = QVBoxLayout()
        self.vLayout.setSpacing(8)
        self.vLayout.setContentsMargins(0, 0, 0, 0)

        self.vLayout.addWidget(self.OrthoSlicePlotWidget)
        self.vLayout.addWidget(self.settingCard)
        self.vLayout.addWidget(self.sliderCard)

        self.hLayout = QHBoxLayout(self)
        self.hLayout.setSpacing(8)
        self.hLayout.setContentsMargins(12, 0, 12, 6)

        self.hLayout.addWidget(self.fileCard)
        self.hLayout.addLayout(self.vLayout)

        Storage.Signal.plotOrthoSliceSignal.connect(self.solve_slider_change)
        Storage.Signal.OrthoColorbarChangeSignal.connect(lambda: setattr(self, "is_layout_init", False))
        Storage.Signal.updateFileListSignal.connect(self.fileCard.btn_click_update_file_list)
        Storage.Signal.clearPlotInterfaceSignal.connect(self.plotClear)
        Storage.Signal.clearFileListSignal.connect(self.fileCard.fileList.clear)

    def plotClear(self):
        self.OrthoSlicePlotWidget.fig.clear()
        self.OrthoSlicePlotWidget.fig.canvas.draw()
        self.is_layout_init = False

    def get_ax_list(self, plot_type_list):
        ax_list = []
        for plot_type in plot_type_list:
            if plot_type == "xy":
                ax_list.append(self.OrthoSlicePlotWidget.ax[0])
            elif plot_type == "xz":
                ax_list.append(self.OrthoSlicePlotWidget.ax[1])
            elif plot_type == "yz":
                ax_list.append(self.OrthoSlicePlotWidget.ax[2])
        return ax_list

    def get_interp_model_idx(self, plot_type_list):
        idx_list = []
        for plot_type in plot_type_list:
            if plot_type == "xy":
                idx_list.append(int(self.slider_xy.slider.value()))
            elif plot_type == "xz":
                idx = int(self.slider_xz.slider.value())
                idx_list.append(model_idx_to_interp_idx(idx))
            elif plot_type == "yz":
                idx = int(self.slider_yz.slider.value())
                idx_list.append(model_idx_to_interp_idx(idx))
        return idx_list

    def solve_slider_change(self, idx, slide_type):
        if Storage.station is None:
            info_bar("error", "Error", "SurfData File not exist")
            return

        plot_type = []
        if slide_type == "Depth Slice":
            plot_type.append("xy")
        elif slide_type == "Lon Slice":
            plot_type.append("xz")
        elif slide_type == "Lat Slice":
            plot_type.append("yz")

        idx_list = self.get_interp_model_idx(plot_type)
        ax_list = self.get_ax_list(plot_type)
        filepath = self.fileCard.get_current_filepath()
        interp_model = Storage.interp_model_cache[filepath]

        plot_ortho_slice(interp_model, plot_type, idx_list, self.OrthoSlicePlotWidget.fig, ax_list)

        # self.OrthoSlicePlotWidget.fig.canvas.draw()
        # self.OrthoSlicePlotWidget.fig.canvas.flush_events()
        self.OrthoSlicePlotWidget.fig.canvas.draw_idle()

    def plot_ortho_slice(self):
        nx = Storage.ItemWidget["nx"].getContent("int")
        ny = Storage.ItemWidget["ny"].getContent("int")
        nz = Storage.ItemWidget["nz"].getContent("int")

        if not self.is_layout_init:
            self.OrthoSlicePlotWidget.fig.clear()
            gs = self.OrthoSlicePlotWidget.fig.add_gridspec(
                    2, 2,
                    height_ratios = [1, 1],
                    width_ratios = [1.5, 1],
                    wspace = 0.25, hspace = 0.4,
                    # left = 0.1, right = 0.95,
                    # bottom = 0.05, top = 0.95
            )

            ax_xy = self.OrthoSlicePlotWidget.fig.add_subplot(gs[:, 0])
            ax_xz = self.OrthoSlicePlotWidget.fig.add_subplot(gs[0, 1])
            ax_yz = self.OrthoSlicePlotWidget.fig.add_subplot(gs[1, 1])

            self.OrthoSlicePlotWidget.ax = [ax_xy, ax_xz, ax_yz]

            # all idx: [0, nx - 1], inversion area: [1, nx - 2]
            # all idx: [0, ny - 1], inversion area: [1, ny - 2]
            # all idx: [0, nz - 1], inversion area: [0, nz - 2]
            self.slider_xy.set_Min_Max_num(0, nz - 2)
            self.slider_xz.set_Min_Max_num(1, ny - 2)
            self.slider_yz.set_Min_Max_num(1, nx - 2)
            self.slider_xy.slider.setValue((nz - 1) // 2)
            self.slider_xz.slider.setValue((ny - 2) // 2)
            self.slider_yz.slider.setValue((nx - 2) // 2)

            self.is_layout_init = True

        filepath = self.fileCard.get_current_filepath()
        interp_model = Storage.interp_model_cache[filepath]
        plot_type = ["xy", "xz", "yz"]
        idx_list = self.get_interp_model_idx(plot_type)
        ax_list = self.get_ax_list(plot_type)

        plot_ortho_slice(interp_model, plot_type, idx_list, self.OrthoSlicePlotWidget.fig, ax_list)

    def btn_click_plot_update(self):
        if not Storage.MainWindow.has_plotted_ortho:
            return
        try:
            update_plot_cache()
            update_model_cache(self.fileCard.get_current_filepath())
            self.plot_ortho_slice()
            self.OrthoSlicePlotWidget.fig.canvas.draw()
            self.OrthoSlicePlotWidget.fig.canvas.flush_events()
            # self.OrthoSlicePlotWidget.fig.canvas.draw_idle()
        except Exception as e:
            info_bar("error", "Error", traceback.format_exc(), "vertical", duration = -1)
            traceback.print_exc()

    def btn_click_image_export(self):
        idx_xy = self.slider_xy.slider.value()
        idx_xz = self.slider_xz.slider.value()
        idx_yz = self.slider_yz.slider.value()
        suffix = Storage.ItemWidget["plot_ortho_slice_image_export_type"].getContent().lower()
        filename = f"OrthoSlice_{idx_xy}_{idx_xz}_{idx_yz}.{suffix}"
        save_image(self.OrthoSlicePlotWidget.fig, filename, Storage.image_dpi)

    def solve_file_list_click(self, currentItem):
        if currentItem is None:
            return
        self.btn_click_plot_update()