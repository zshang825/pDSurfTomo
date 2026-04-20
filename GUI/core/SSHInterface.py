from .CustomWidget import *
from PyQt5.QtWidgets import QSpacerItem

from .Storage import Storage
from .utils_interact import btn_click_ssh_connect, btn_click_ssh_disconnect


class SSHInterface(QWidget):
    def __init__(self, parent = None):
        super().__init__(parent)
        self.setObjectName("SSHInterface")

        self.sshCard = SimpleCardWidget(self)
        self.sshCard.setMaximumWidth(400)
        # self.sshCard.setMaximumHeight(250)

        self.sshProjectCard = SimpleCardWidget(self)
        self.sshProjectCard.setMaximumWidth(400)

        self.gridLayout = QGridLayout(self.sshCard)
        for key in Storage.sshKey:
            if key not in ["ssh_remote_root", "ssh_python_path"]:
                self.gridLayout.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.btn_ssh_connect = PrimaryPushButton("Connect", self)
        self.btn_ssh_connect.setFont(QFont(Storage.LabelFont, 14))
        self.btn_ssh_connect.clicked.connect(btn_click_ssh_connect)

        self.btn_ssh_disconnect = PrimaryPushButton("Disconnect", self)
        self.btn_ssh_disconnect.setFont(QFont(Storage.LabelFont, 14))
        self.btn_ssh_disconnect.clicked.connect(btn_click_ssh_disconnect)

        self.gridLayout.addWidget(self.btn_ssh_connect, 4, 0, 1, 2)
        self.gridLayout.addWidget(self.btn_ssh_disconnect, 4, 2, 1, 2)

        self.gridLayout.setHorizontalSpacing(5)
        self.gridLayout.setVerticalSpacing(10)
        self.gridLayout.setContentsMargins(24, 6, 24, 12)
        self.gridLayout.setColumnStretch(0, 1)
        self.gridLayout.setColumnStretch(1, 1)
        self.gridLayout.setColumnStretch(2, 1)
        self.gridLayout.setColumnStretch(3, 1)

        self.gridLayout_project = QGridLayout(self.sshProjectCard)
        for key in Storage.sshKey:
            if key in ["ssh_remote_root", "ssh_python_path"]:
                self.gridLayout_project.addWidget(MyWidget(key), *Storage.GridLayout[key])

        self.gridLayout_project.setHorizontalSpacing(5)
        self.gridLayout_project.setVerticalSpacing(10)
        self.gridLayout_project.setContentsMargins(24, 6, 24, 12)
        self.gridLayout_project.setColumnStretch(0, 1)
        self.gridLayout_project.setColumnStretch(1, 1)
        self.gridLayout_project.setColumnStretch(2, 1)
        self.gridLayout_project.setColumnStretch(3, 1)

        self.vLayout = QVBoxLayout(self)
        self.vLayout.setSpacing(8)
        self.vLayout.setContentsMargins(12, 0, 12, 6)

        self.vLayout.addWidget(self.sshCard)
        self.vLayout.addWidget(self.sshProjectCard)
        self.vLayout.addSpacerItem(QSpacerItem(0, 0, QSizePolicy.Expanding, QSizePolicy.Expanding))
