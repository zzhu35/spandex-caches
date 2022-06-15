# Spandex Caches

## Overview
This repository contains the SystemC implementation of the Spandex caches. It can be included as a sub-module in the [ESP](http://github.com/sld-columbia/esp) repostiory, and selected in the ESP SoC generator as the Level 2 (L2) or Last Level Caches (LLC).

### Features
The caches are an implementation of the Spandex protocol (described in [this paper](http://rsim.cs.illinois.edu/Pubs/18-ISCA-Spandex.pdf)) and Fine-grain Coherence Specialization (described in [this paper](http://rsim.cs.illinois.edu/Pubs/fine-grained-coherence-arxiv-20210823.pdf)). The caches optimize data movement in heterogeneous system-on-chip's — both between caches and to off-chip memory.

### More related readings:
* [DeNovo: Rethinking the Memory Hierarchy for Disciplined Parallelism](http://rsim.cs.illinois.edu/denovo/Pubs/11-pact-denovo.pdf)
* [Agile SoC Development with Open ESP](https://sld.cs.columbia.edu/pubs/mantovani_iccad20.pdf)

## Usage
**Note:** All commands below must be run from the `$(ESP_ROOT)/socs/<platform>` folder, unless indicated otherwise.

For details on how to use ESP, refer to their detailed guide on [building a single core SoC](https://www.esp.cs.columbia.edu/docs/singlecore/singlecore-guide/). This tutorial will teach you how to build an SoC using the ESP SoC generator GUI, simulate it, generate a bitstream, and evaluate baremetal and linux applications on an FPGA. 

#### Bare minimum submodules to run all the steps below:
```
git submodule update --init --recursive rtl/caches/esp-caches/  rtl/caches/spandex-caches/ accelerators/stratus_hls/common/inc/ accelerators/chisel/hw rtl/cores/ariane/ariane soft/ariane/riscv-tests/ soft/ariane/linux/ soft/ariane/riscv-pk soft/ariane/opensbi
```

#### Generating the RTL from the SystemC caches
* `make l2_spandex-hls llc_spandex-hls`: This command generates the RTL for both the L2 and LLC.
  - Once complete (takes about 2-3 hours), the generated RTL for your caches will be placed in `$(ESP_ROOT)/tech/<tech>/sccs/`.
  - Replace `hls` with `distclean` in the command to clean the output.
  - **Note:** The SystemC caches are generated for 32kB (512 sets and 4 ways of 16B caches lines) L2 cache and 128kB (1024 sets and 8 ways of 16B caches lines) Last Level cache by default. If you wish to different sizes, you need to modify the project.tcl file for the respective cache and modify/add configurations. For example, for the L2 cache, modify/add configurations [at this line](l2_spandex/stratus/project.tcl#L60).
  
#### Generate the SoC with Spandex caches:
* `make esp-xconfig` for the ESP SoC generator, and check the `Use Caches` box in the GUI and select `Spandex HLS` from the `Implementation` dropdown.
* `make socketgen-distclean socketgen` to clean the currently generated socket RTL, and replace with new socket RTL that instantiates the Spandex caches.
* **Note:** The current version of Spandex caches will support only the Ariane CPU.

#### Simulate RTL test:
* `make xmsim-gui` will simulate the baremetal test present in `$(ESP_ROOT)/socs/<platform>/systest.c`.
* **Note:** If you are seeing an error related `asic_*` files, please delete the 7 `asic_*` related files at the end of `$(ESP_ROOT)/utils/flist/vhdl.flist`.
* **Note:** If you are using Xcelium for simulation, please follow [the extra step here](https://www.esp.cs.columbia.edu/docs/setup/setup-guide/#patching-ariane-for-xcelium-simulator).
* **Note:** If you are running the simulation for the first time in your repository, you can save time by copying the `$(ESP_ROOT)/.cache` from any other repository that has run an RTL simulation before. If you do not, the `.cache` folder will be automatically generated (one-time process) during `make xmsim-gui`, however, it will take up to 1 hour.

#### Evaluating baremetal on FPGA:
* `make vivado-syn` after the socket RTL generation step will run design synthesis, implementation and bitstream generation targetting the board whose `socs` folder you are in.
* `make fpga-program` will program the FPGA with the bitstream.
* `make soft` will compile your baremetal test, i.e., `$(ESP_ROOT)/socs/<platform>/systest.c` and the compiled binary will be placed at `$(ESP_ROOT)/socs/<platform>/soft-build/ariane/systest.exe`.
* `make fpga-run` will download your compiled binary onto the board and release the CPU reset.
* To view the prints via UART, open a minicom on a new shell with `minicom -D /dev/ttyUSB1 -b 38400`. To close the UART, hit `ctrl+a`, followed by `x`. **Note:** you might need change the tty port as per your system.
* **Note:** `make soft` will also compile your ROM image which is placed at `$(ESP_ROOT)/socs/<platform>/soft-build/ariane/prom.exe`. This file will also be downloaded to your board during `make fpga-run`.

#### Evaluating Linux on FPGA:
* Before we build the Linux image, we will need the generate the `sysroot` that contains the file system.
  - This can be done by executing `$(ESP_ROOT)/utils/toolchain/build_riscv_toolchain.sh`.
  - This will install the RISCV tool-chain, LibC libraries and the `$(ESP_ROOT)/soft/ariane/sysroot` in your repository. You have the option to skip any/all of these, if you have installed them earlier.
  - This is a one-time process that can take more than 1 hour. After the first time, the `$(ESP_ROOT)/soft/ariane/sysroot` can copied to newer repositories, as long as you don't change the Linux kernel version.
* `make linux` will compile your Linux image. The compiled binary is placed at `$(ESP_ROOT)/socs/<platform>/soft-build/ariane/linux-build/vmlinux`.
* After programming the FPGA as in the baremetal case, you can download the Linux image with `make fpga-run-linux`.
* **Note:** At the moment, Linux is supported on single core Ariane.

#### Evaluating Accelerators:
* If the accelerator of interest is a SystemC accelerator, we can run HLS for the accelerator using `make <acc>_stratus-hls`. Once complete (takes about 2-3 hours), the generated RTL for your caches will be placed in `$(ESP_ROOT)/tech/<tech>/accs/`.
* In the ESP SoC generator, you will now be able to choose the accelerators of your choice in the tiles. You can also choose to have private caches in the accelerator tiles.
* The accelerator hardware is located at `$(ESP_ROOT)/accelerators/stratus_hls/<acc>_stratus/hw`. And, the accelerator software is located at `$(ESP_ROOT)/accelerators/stratus_hls/<acc>_stratus/sw` — both baremetal and Linux application.
* `make <acc>_stratus-baremetal` will compile the accelerator's baremetal application.
* `make <acc>_stratus-app` will compile the accelerator's Linux application. Run `make linux` again to update the Linux image with the new app.
* `TEST_PROGRAM=./soft-build/ariane/baremetal/<acc>_stratus.exe make xmsim-gui` will run the accelerator's baremetal application in RTL simulation.
* `TEST_PROGRAM=./soft-build/ariane/baremetal/<acc>_stratus.exe make fpga-run` will run the accelerator's baremetal application on the FPGA.
* To run the accelerator's Linux application, reboot Linux, and execute the binary at `/applications/test/<acc>_stratus.exe` in the OS.

## Structure
```
spandex-caches
|   README.md    
+---l2_spandex
|   |
|   +---src
|   |       ...      
|   +---tb
|           ...
|   +---stratus
|   |   |   project.tcl
|   |   |   Makefile -> esp-caches
|   |   memlist.txt
+---llc_spandex
|   |
|   +---src
|   |       ...      
|   +---tb
|           ...
|   +---stratus
|   |   |   project.tcl
|   |   |   Makefile -> esp-caches
|   |   memlist.txt
+---utils
|   |   spandex_consts.hpp
|   |   spandex_types.hpp
|   |   spandex_utils.hpp
+---common -> esp-caches
```
* The `src` folders in both the design folders contains the SystemC design source files.
* The `tb` folders in both the design folders contains the SystemC testbench source files.
* The `project.tcl` contains the options used for HLS using Stratus HLS. **Note:** this is where we can add our choice of cache sizes to be synthesized.
* The `memlist.txt` contains the list of memory modules generated for HLS. **Note:** Only the combinations present in this file can be used as options in the `project.tcl`, and hence in the ESP SoC generator.
* The `utils` folder contains Spandex specific defines, types and helper functions.
* The `common` folder is reused from the `esp-caches` repostiory and contains ESP specific defines, types and helper functions. **Note:** To generate your caches with additional debug/bookmark signals, there is a `L2_DEBUG` and `LLC_DEBUG` flag in `common/caches/cache_consts.hpp`.
