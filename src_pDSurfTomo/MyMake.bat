@echo off
del ..\bin\pDSurfTomo.exe
gnumake
del *.o
del *.mod
copy pDSurfTomo.exe ..\bin\pDSurfTomo.exe