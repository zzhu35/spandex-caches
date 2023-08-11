VIVADO = $(XILINX_VIVADO)
ESP_ROOT = ../../../..
WORKAREA ?= .
PROJECT = l2_spandex

CC_OPTS += -full64 -nc -sverilog -kdb -debug_access+all
CC_OPTS += '+define+XILINX_FPGA'
CC_OPTS += '+warn=noSIOB'
CC_OPTS += '+warn=noPCWM-W'
CC_OPTS += '+warn=noIPC'

INCDIR ?=
INCDIR += '+incdir+../common/defs'
INCDIR += '+incdir+.'

L2_SRC ?=
L2_SRC += rtl/*.sv
L2_SRC += ../common/rtl/*.sv

MEM_SRC ?= 
MEM_SRC += $(ESP_ROOT)/rtl/techmap/unisim/mem/*.v
MEM_SRC += $(VIVADO)/data/verilog/src/glbl.v
MEM_SRC += $(VIVADO)/data/verilog/src/retarget/RAMB*.v
MEM_SRC += $(VIVADO)/data/verilog/src/unisims/RAMB*.v

L2_TB ?= 
L2_TB += tb/l2_tb_top.sv

DUMP_VPD?=

all: clean l2-compile l2-run

l2-compile: $(L2_TB) $(L2_SRC) $(MEM_SRC)
	$(VCS_HOME)/bin/vcs $^ $(INCDIR) $(CC_OPTS) -o $(WORKAREA)/$(PROJECT).simv

l2-run:
	$(WORKAREA)/$(PROJECT).simv

clean:
	rm -rf *DB DVEfiles *novas* csrc *simv *daidir \
			*log *Log ucli.key *vpd *fsdb \
			check_fsearch_db fsearch.stat \
			verdi_config_file \
			../systemc/common/caches/cache_cfg.hpp \
			work.lib*

.PHONY: clean
