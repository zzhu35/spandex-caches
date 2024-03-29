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
INCDIR += -I../systemc/llc_spandex/tb
INCDIR += -I../systemc/l2_spandex/tb
INCDIR += -I../systemc/utils
INCDIR += -I$(STRATUS_PATH)/share/stratus/include
INCDIR += +incdir+../common/defs
INCDIR += +incdir+../utils/defs
INCDIR += +incdir+.

L2_TB ?=
L2_TB +=../systemc/l2_spandex/tb/l2_spandex_tb.cpp
L2_TB += sim/sc_main.cpp

L2_COSIM_SRC ?=
L2_COSIM_SRC += sim/l2_spandex_wrap.cpp

L2_SRC ?=
L2_SRC += rtl/*.sv

RTL_SRC ?=
RTL_SRC += $(ESP_ROOT)/rtl/techmap/virtex7/mem/*.v
RTL_SRC += $(ESP_ROOT)/rtl/cores/ariane/ariane/src/common_cells/src/sram.sv
RTL_SRC += $(VIVADO)/data/verilog/src/glbl.v
RTL_SRC += $(VIVADO)/data/verilog/src/retarget/RAMB*.v
RTL_SRC += $(VIVADO)/data/verilog/src/unisims/RAMB*.v
RTL_SRC += ../utils/rtl/*.sv

l2-sim: $(L2_TB) $(L2_COSIM_SRC) $(RTL_SRC) $(L2_SRC)
	cp cache_cfg.svh ../systemc/utils/cache_cfg.hpp
	sed -i 's/`/#/g' ../systemc/utils/cache_cfg.hpp
	sed -i 's/BIG_ENDIAN/ENDIAN_BIG_ENDIAN/g' ../systemc/utils/cache_cfg.hpp
	sed -i 's/LITTLE_ENDIAN/ENDIAN_LITTLE_ENDIAN/g' ../systemc/utils/cache_cfg.hpp
	ncsc_run -DRTL_SIM $(INCDIR) $(FLAGS) $^

l2-sim-gui: $(L2_TB) $(L2_COSIM_SRC) $(RTL_SRC) $(L2_SRC)
	cp cache_cfg.svh ../systemc/utils/cache_cfg.hpp
	sed -i 's/`/#/g' ../systemc/utils/cache_cfg.hpp
	sed -i 's/BIG_ENDIAN/ENDIAN_BIG_ENDIAN/g' ../systemc/utils/cache_cfg.hpp
	sed -i 's/LITTLE_ENDIAN/ENDIAN_LITTLE_ENDIAN/g' ../systemc/utils/cache_cfg.hpp
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
