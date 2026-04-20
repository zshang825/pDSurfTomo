import glob

import re

from PyQt5.QtCore import QRegExp, QDir
from PyQt5.QtGui import QDoubleValidator, QRegExpValidator, QFont
from PyQt5.QtWidgets import (QHBoxLayout, QVBoxLayout, QGridLayout, QSizePolicy, QFileDialog, QCompleter, QDirModel,
                             QWidget, QListWidgetItem, QSlider)

from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt5agg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure
from qfluentwidgets import (StrongBodyLabel, SwitchButton, LineEdit, PasswordLineEdit, ComboBox, EditableComboBox, ListWidget, PrimaryPushButton,
                            SpinBox, ClickableSlider, SimpleCardWidget,
                            ToolTipFilter, ToolTipPosition, Action, FluentIcon)
from qfluentwidgets.components.widgets.line_edit import CompleterMenu

from .utils_interact import *

class MyLabel(StrongBodyLabel):

    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key

        self.setText(Storage.ItemInfo[key]["LabelText"])
        self.setFont(QFont(Storage.LabelFont, Storage.LabelFontSize))
        self.setToolTip(Storage.ItemInfo[key]["Tooltip"])
        self.installEventFilter(ToolTipFilter(self, position = ToolTipPosition.RIGHT))
        if key in ["project_path"]:
            self.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)


class MySwitchButton(SwitchButton):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key

        self.setOnText("")
        self.setOffText("")

        self.checkedChanged.connect(self.solve_checked_change)
        # self.setChecked(Storage.ItemDefaultValue[key])

    def syn_grid_lineEdit_show(self):
        Storage.ItemWidget["grid_dx"].show()
        Storage.ItemWidget["grid_dy"].show()
        Storage.ItemWidget["grid_dz"].show()
        Storage.ItemWidget["perturbation"].show()

    def syn_grid_lineEdit_hide(self):
        Storage.ItemWidget["grid_dx"].hide()
        Storage.ItemWidget["grid_dy"].hide()
        Storage.ItemWidget["grid_dz"].hide()
        Storage.ItemWidget["perturbation"].hide()

    def solve_checked_change(self):
        if self.checked:
            self.syn_grid_lineEdit_show()
        else:
            self.syn_grid_lineEdit_hide()


class MyCompleterMenu(CompleterMenu):
    def __init__(self, lineEdit: LineEdit):
        super().__init__(lineEdit)
        self.currentDir = ""

    def _onCompletionItemSelected(self, text, row):
        all_text = os.path.join(self.currentDir, text)
        self.lineEdit.setText(all_text)
        self.activated.emit(text)

        if 0 <= row < len(self.indexes):
            self.indexActivated.emit(self.indexes[row])


class MyPasswordLineEdit(PasswordLineEdit):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key
        # self.setText(Storage.ItemDefaultValue[key])


class MyLineEdit(LineEdit):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key

        # self.setText(Storage.ItemDefaultValue[key])
        # self.setCursorPosition(0)

        if key in Storage.InversionReadOnlyKey:
            self.setReadOnly(True)

        if key not in ["data_path", "project_path",
                       "plot_layer",
                       "plot_multi_vmin", "plot_multi_vmax", "plot_ortho_vmin", "plot_ortho_vmax",
                       "ssh_ip", "ssh_port", "ssh_username", "ssh_password", "ssh_key_file_path", "ssh_remote_root", "ssh_python_path"]:
            validator = QDoubleValidator(self)
            self.setValidator(validator)

        if key in ["nx", "ny", "nz", "originLat", "originLon", "dLat", "dLon"]:
            self.textChanged.connect(self.solve_model_parameter_changed)

        if key in ["ssh_remote_root"]:
            self.textChanged.connect(self.solve_remote_root_change)

    def focusInEvent(self, e):
        super().focusInEvent(e)
        if self.key in Storage.InversionReadOnlyKey:
            info_bar("info", title = "This field ReadOnly", content = "")

    def solve_model_parameter_changed(self):
        Storage.ItemWidget[f"plot_{self.key}"].setContent(self.text().strip())

    def solve_remote_root_change(self):
        solve_remote_root_change(self.text().strip())


class MyLineEditPath(LineEdit):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key
        self.filepath = ""

        # self.setText(Storage.ItemDefaultValue[key])
        # self.setCursorPosition(0)

        action = Action(FluentIcon.FOLDER, "", triggered = self.SolveActionFileOpen)
        self.addAction(action, LineEdit.TrailingPosition)

        self.process_special_need()

    def process_special_need(self):
        if self.key.startswith("p_"):
            regex = QRegExp("^(-?\\d*\\.?\\d+)(\\s+-?\\d*\\.?\\d+)*$")
            validator = QRegExpValidator(regex, self)
            self.setValidator(validator)

            self.editingFinished.connect(self.solve_period_change)

        if self.key in ["data_path"]:
            completer = QCompleter(self)
            completer.setModel(QDirModel(completer))
            completer.setCaseSensitivity(Qt.CaseSensitive)
            completer.setFilterMode(Qt.MatchContains)
            # completer.setCompletionMode(QCompleter.PopupCompletion)
            # completer.setMaxVisibleItems(10)

            self.setCompleter(completer)
            self.setCompleterMenu(MyCompleterMenu(self))

            self.textChanged.connect(self.solve_surf_data_path_text_change)
            self.editingFinished.connect(self.solve_surf_data_path_edit_finished)

    def solve_surf_data_path_text_change(self):
        self._completerMenu.currentDir = os.path.dirname(self.text())

    def solve_surf_data_path_edit_finished(self):
        solve_surf_data_path_change(self.text().strip())

    def solve_period_change(self):
        kmax_key = self.key.replace("p_", "kmax")
        kmax_num = Storage.ItemWidget[kmax_key].getContent("int")
        kmax_num = 0 if isinstance(kmax_num, str) else kmax_num

        period = self.text().strip().split()
        if len(period) != kmax_num:
            info_bar("error", "The number of periods must match the SurfData file", "", duration = 3000)

    def SolveActionFileOpen(self):
        if self.key in ["data_path"]:
            filefilter = "SurfData File (*.dat);;  All Files (*.*)"
            directory = ""
        elif self.key.startswith("p_"):
            filefilter = "Model Info File (*.json);;  All Files (*.*)"
            directory = Storage.localProjectPath
        elif self.key in ["ssh_key_file_path"]:
            filefilter = "SSH Key File (id_*);;  All Files (*.*)"
            directory = os.path.join(os.path.expanduser("~"), ".ssh")
        else:
            filefilter = ""

        filepath, _ = QFileDialog.getOpenFileName(self, caption = "Open File", directory = directory, filter = filefilter)

        if len(filepath) == 0:
            return

        filepath = QDir.toNativeSeparators(QDir.cleanPath(filepath))
        self.filepath = filepath

        if self.key.startswith("p_"):
            solve_choose_period_file(filepath)
        else:
            self.setText(filepath)


class MyEditableComboBox(EditableComboBox):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key

        items = Storage.ComboBoxItems[key]
        self.addItems(items)
        self.setCurrentText(f"{Storage.max_thread // 2}")
        self.currentTextChanged.connect(self.solve_text_change)

    def solve_text_change(self, text):
        if len(text) == 0:
            return
        if int(self.currentText()) > Storage.max_thread:
            info_bar("warning", f"Max System CPU ThreadNum is {Storage.max_thread}", "")
            self.setText(f"{Storage.max_thread}")


class MyComboBox(ComboBox):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key

        items = Storage.ComboBoxItems[key]
        self.addItems(items)
        self.currentIndexChanged.connect(self.solve_index_change)

        if self.key == "travelTime":
            self.lastItem = {"senK": "", "lsmr": ""}

    def solve_index_change(self, index):
        if self.key == "plot_multi_colorbar_direction":
            Storage.Signal.MultiColorbarChangeSignal.emit()
        elif self.key == "plot_ortho_colorbar_direction":
            Storage.Signal.OrthoColorbarChangeSignal.emit()
        elif self.key == "travelTime":
            if self.text() == "Default":
                self.lastItem["senK"] = Storage.ItemWidget["senK"].getContent()
                self.lastItem["lsmr"] = Storage.ItemWidget["lsmr"].getContent()

                Storage.ItemWidget["senK"].widget.addItem("Default")

                Storage.ItemWidget["senK"].setContent("Default")
                Storage.ItemWidget["lsmr"].setContent("Default")
                Storage.ItemWidget["senK"].widget.setEnabled(False)
                Storage.ItemWidget["lsmr"].widget.setEnabled(False)
            else:
                Storage.ItemWidget["senK"].widget.removeItem(2)

                Storage.ItemWidget["senK"].setContent(self.lastItem["senK"])
                Storage.ItemWidget["lsmr"].setContent(self.lastItem["lsmr"])
                Storage.ItemWidget["senK"].widget.setEnabled(True)
                Storage.ItemWidget["lsmr"].widget.setEnabled(True)


class PlotWidget(SimpleCardWidget):
    def __init__(self, parent = None, constrained_layout = True):
        super().__init__(parent)
        self.setBorderRadius(8)
        self.fig = Figure(constrained_layout = constrained_layout)
        self.canvas = FigureCanvas(self.fig)
        self.toolbar = NavigationToolbar(self.canvas, self)
        self.ax = None

        self.vLayout = QVBoxLayout(self)
        self.vLayout.setSpacing(0)
        self.vLayout.setContentsMargins(5, 5, 5, 5)
        self.vLayout.addWidget(self.toolbar)
        self.vLayout.addWidget(self.canvas)


class MySlider(QWidget):
    def __init__(self, parent = None, labelContent = "", tickInterval = 1):
        super().__init__(parent)
        self.labelContent = labelContent

        # self.setBorderRadius(8)
        # self.setMaximumHeight(75)

        self.label = StrongBodyLabel(f"{labelContent}: 0", self)
        self.label.setFont(QFont("consolas", 16))

        self.slider = ClickableSlider(Qt.Horizontal)
        self.slider.setPageStep(1)
        self.slider.setMinimum(0)
        self.slider.setMaximum(0)
        self.slider.setTickPosition(QSlider.TicksBelow)
        self.slider.setTickInterval(tickInterval)
        self.slider.valueChanged.connect(self.on_slider_changed)
        # self.slider.valueChanged.connect(self.slider_update_value)

        self.spin_box = SpinBox()
        self.spin_box.setMinimum(0)
        self.spin_box.setMaximum(0)
        self.spin_box.valueChanged.connect(self.on_spin_box_changed)

        self.layout = QGridLayout(self)
        self.layout.addWidget(self.label, 0, 0, 1, 1)
        self.layout.addWidget(self.slider, 0, 1, 1, 3)
        self.layout.addWidget(self.spin_box, 0, 4, 1, 1)

        self.layout.setHorizontalSpacing(30)
        self.layout.setVerticalSpacing(10)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setColumnStretch(0, 1)
        self.layout.setColumnStretch(1, 1)
        self.layout.setColumnStretch(2, 1)
        self.layout.setColumnStretch(3, 1)
        self.layout.setColumnStretch(4, 1)
        self.layout.setColumnStretch(5, 1)


    def on_slider_changed(self, val):
        self.set_label(val)

        self.spin_box.blockSignals(True)
        self.spin_box.setValue(val)
        self.spin_box.blockSignals(False)

        Storage.Signal.plotOrthoSliceSignal.emit(val, self.labelContent)

    def on_spin_box_changed(self, val):
        self.set_label(val)

        self.slider.blockSignals(True)
        self.slider.setValue(val)
        self.slider.blockSignals(False)

        Storage.Signal.plotOrthoSliceSignal.emit(val, self.labelContent)

    def set_label(self, idx):
        self.label.setText(f"{self.labelContent}: {idx}")

    def setMinimum(self, val):
        self.spin_box.setMinimum(val)
        self.slider.setMinimum(val)

    def setMaximum(self, val):
        self.spin_box.setMaximum(val)
        self.slider.setMaximum(val)

    def set_Min_Max_num(self, min_val, max_val):
        self.setMinimum(min_val)
        self.setMaximum(max_val)

    def setValue(self, val):
        self.slider.setValue(val)


class FileListWidget(SimpleCardWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setBorderRadius(8)
        self.setMaximumWidth(150)

        self.current_project_path = ""

        self.layout = QVBoxLayout(self)
        self.fileList = ListWidget()
        self.btn_update_file_list = PrimaryPushButton("Update\nFileList", self)
        self.btn_update_file_list.setFont(QFont(Storage.LabelFont, 16))
        self.btn_update_file_list.clicked.connect(self.btn_click_update_file_list_and_cache)
        self.layout.addWidget(self.fileList)
        self.layout.addWidget(self.btn_update_file_list)

    def get_current_file_list(self):
        current_file_list = []
        for i in range(self.fileList.count()):
            item = self.fileList.item(i)
            current_file_list.append(item.text().strip())
        return current_file_list

    def get_current_filepath(self):
        project_path = Storage.filelist_current_project_path
        filename = self.fileList.currentItem().text()
        return os.path.join(project_path, "InvResult", filename)

    def get_filepath_by_idx(self, idx):
        project_path = Storage.filelist_current_project_path
        filename = self.fileList.item(idx).text()
        return os.path.join(project_path, "InvResult", filename)

    def btn_click_update_file_list_and_cache(self):
        self.fileList.clear()
        Storage.interp_model_cache.clear()
        self.update_file_list()

    def btn_click_update_file_list(self):
        self.fileList.clear()
        self.update_file_list()

    def update_file_list(self):
        if Storage.filelist_current_project_path == "":
            Storage.filelist_current_project_path = Storage.localProjectPath

        if Storage.filelist_current_project_path != Storage.localProjectPath:
            Storage.filelist_current_project_path = Storage.localProjectPath
            Storage.interp_model_cache.clear()
            Storage.Signal.clearFileListSignal.emit()
            Storage.Signal.updateFileListSignal.emit()
            return

        project_path = Storage.filelist_current_project_path
        inv_file_dir = os.path.join(project_path, "InvResult")
        inv_file_all = glob.glob(os.path.join(inv_file_dir, "vs*"))
        inv_file_all = [os.path.basename(filepath) for filepath in inv_file_all]

        if len(inv_file_all) == 0:
            Storage.Signal.clearFileListSignal.emit()
            Storage.interp_model_cache.clear()
            return

        # for i in range(self.fileList.count() - 1, -1, -1):
        #     item_text = self.fileList.item(i).text()
        #     if item_text not in inv_file_all:
        #         key = self.get_filepath_by_idx(i)
        #         Storage.interp_model_cache.pop(key, None)
        #         self.fileList.takeItem(i)

        def get_sort_key(filename):
            key = filename.split("_")[-1]
            if "mask" in key:
                return -2
            elif "true" in key:
                return -1
            elif "init" in key:
                return 0
            else:
                return int(m.group(1)) if (m := re.search(r'(\d+)', key)) else -3

        new_file_list = list(set(inv_file_all) - set(self.get_current_file_list()))
        new_file_list = sorted(new_file_list, key = lambda x: get_sort_key(x))

        for filepath in new_file_list:
            item = QListWidgetItem(filepath)
            self.fileList.addItem(item)

        if self.fileList.count() > 0 and self.fileList.currentRow() == -1:
            self.fileList.setCurrentRow(self.fileList.count() - 1)


WidgetMap = {
    "MyComboBox": MyComboBox,
    "MyEditableComboBox": MyEditableComboBox,
    "MyLineEdit": MyLineEdit,
    "MyLineEditPath": MyLineEditPath,
    "MySwitchButton": MySwitchButton,
    "MyPasswordLineEdit": MyPasswordLineEdit,

}


class MyWidget(QWidget):
    def __init__(self, key, parent = None):
        super().__init__(parent)
        self.key = key
        self.label = MyLabel(key, parent)

        if Storage.ItemInfo[key]["WidgetLayout"] == "H":
            self.layout = QHBoxLayout(self)
            self.layout.setSpacing(0)
            self.label.setText(f"{Storage.ItemInfo[key]['LabelText']}: ")
        else:
            self.layout = QVBoxLayout(self)
            self.layout.setSpacing(3)

        self.widget = WidgetMap[Storage.ItemInfo[key]["WidgetType"]](key, parent)  # type: Union[MyComboBox, MyEditableComboBox, MyLineEdit, MyLineEditPath, MyPasswordLineEdit, MySwitchButton]

        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.addWidget(self.label, alignment = Qt.AlignLeft)
        self.layout.addWidget(self.widget)

        Storage.ItemWidget[key] = self

    def getContent(self, dtype = "str"):
        if isinstance(self.widget, MySwitchButton):
            return self.widget.checked
        elif isinstance(self.widget, (MyLineEdit, MyLineEditPath, MyPasswordLineEdit)):
            if self.widget.text().strip() == "":
                return self.widget.text().strip()

            if dtype == "int":
                return int(self.widget.text().strip())
            elif dtype == "float":
                return float(self.widget.text().strip())
            else:
                return self.widget.text().strip()

        elif isinstance(self.widget, (MyComboBox, MyEditableComboBox)):
            return self.widget.currentText().strip()
        else:
            raise ValueError("Unknown Widget Type")

    def setContent(self, content):
        if isinstance(self.widget, MySwitchButton):
            self.widget.setChecked(content)
        elif isinstance(self.widget, (MyLineEdit, MyLineEditPath, MyPasswordLineEdit)):
            self.widget.setText(content)
        elif isinstance(self.widget, (MyComboBox, MyEditableComboBox)):
            self.widget.setCurrentText(content)
        else:
            raise ValueError("Unknown Widget Type")
