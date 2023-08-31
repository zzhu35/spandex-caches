# Copyright (c) 2011-2022 Columbia University, System Level Design Group
# SPDC-License-Identifier: Apache-2.0

VIVADO = $(XILINX_VIVADO)
ESP_ROOT = ../../../..
ACCEL = $(ESP_ROOT)/accelerators/stratus_hls/common/inc

FLAGS ?=
FLAGS += -NOWarn SCK505
FLAGS += -SCTOP sc_main
FLAGS += -DCLOCK_PERIOD=12.5
FLAGS += -DRTL_CACHE
FLAGS += -TOP glbl
FLAGS += -access +R
FLAGS += -ncvlog_args,"-define XILINX_FPGA"

INCDIR ?=
INCDIR += -I$(ACCEL)
INCDIR += -I../systemc/common/caches
INCDIR += -I../systemc/spandex_system_testbench/tb
INCDIR += -I../systemc/utils
INCDIR += -I$(STRATUS_PATH)/share/stratus/include
INCDIR += +incdir+../common/defs
INCDIR += +incdir+../utils/defs
INCDIR += +incdir+.

SYSTEM_TB ?=
SYSTEM_TB += ../systemc/spandex_system_testbench/tb/spandex_system_tb.cpp
SYSTEM_TB += sim/sc_main.cpp

SYSTEM_COSIM_SRC ?=
SYSTEM_COSIM_SRC += sim/spandex_system_wrap.cpp

L2_SRC ?=
L2_SRC += ../l2_spandex/rtl/*.sv

LLC_SRC ?=
LLC_SRC += ../llc_spandex/rtl/*.sv

RTL_SRC ?=
RTL_SRC += $(ESP_ROOT)/rtl/techmap/virtex7/mem/*.v
RTL_SRC += $(VIVADO)/data/verilog/src/glbl.v
RTL_SRC += $(VIVADO)/data/verilog/src/retarget/RAMB*.v
RTL_SRC += $(VIVADO)/data/verilog/src/unisims/RAMB*.v
RTL_SRC += ../utils/rtl/*.sv

system-sim: $(SYSTEM_TB) $(SYSTEM_COSIM_SRC) $(RTL_SRC) $(L2_SRC) $(LLC_SRC)
	cp cache_cfg.svh ../systemc/utils/cache_cfg.hpp
	sed -i 's/`/#/g' ../systemc/utils/cache_cfg.hpp
	ncsc_run -DRTL_SIM $(INCDIR) $(FLAGS) $^

system-sim-gui: $(SYSTEM_TB) $(SYSTEM_COSIM_SRC) $(RTL_SRC) $(L2_SRC) $(LLC_SRC)
	cp cache_cfg.svh ../systemc/utils/cache_cfg.hpp
	sed -i 's/`/#/g' ../systemc/utils/cache_cfg.hpp
	ncsc_run -DRTL_SIM $(INCDIR) $(FLAGS) -GUI $^

clean:
	rm -rf 			\
		*.log 		\
		*.so 		\
		INCA_libs	\
		.simvision	\
		*.key		\
		*.shm		\
		*.err 		\
        *.diag		\
		xcelium.d   \
		../systemc/utils/cache_cfg.hpp

.PHONY: sc-sim sc-sim-gui clean
