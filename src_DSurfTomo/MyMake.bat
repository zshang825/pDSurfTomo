@echo off
del ..\bin\DSurfTomo.exe
gnumake
del *.o
del *.mod
copy DSurfTomo.exe ..\bin\DSurfTomo.exe