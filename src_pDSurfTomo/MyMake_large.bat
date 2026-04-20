@echo off
del ..\bin\pDSurfTomo.exe
gnumake -f Makefile_large
del *.o
del *.mod
copy pDSurfTomo.exe ..\bin\pDSurfTomo.exe