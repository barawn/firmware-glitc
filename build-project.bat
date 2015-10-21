SET vivado=C:\Xilinx\Vivado\2015.2\bin\vivado.bat
rmdir /s /q glitc-project
%vivado% -mode batch -source build-project.tcl
