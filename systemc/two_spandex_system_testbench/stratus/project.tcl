############################################################
# Design Parameters
############################################################

#
# Source the common configurations
#
source ../../common/syn/caches.tcl

#
# Timing constraints
#
if {$TECH eq "virtex7"} {
    set CLOCK_PERIOD 20.0
    set_attr default_input_delay      0.1
}
if {$TECH eq "zynq7000"} {
    set CLOCK_PERIOD 20.0
    set_attr default_input_delay      0.1
}
if {$TECH eq "virtexu"} {
    set CLOCK_PERIOD 12.8
    set_attr default_input_delay      0.1
}
if {$TECH eq "virtexup"} {
#    set CLOCK_PERIOD 12.8
    set CLOCK_PERIOD 6.4
    set_attr default_input_delay      0.1
}
if {$TECH eq "cmos32soi"} {
    set CLOCK_PERIOD 1000.0
    set_attr default_input_delay      100.0
}
if {$TECH eq "gf12"} {
    set CLOCK_PERIOD 1000.0
    set_attr default_input_delay      100.0
}

if {$TECH eq "virtex7"} {
    set LLC_CLOCK_PERIOD 10.0
    set_attr default_input_delay      0.1
}
if {$TECH eq "zynq7000"} {
    set LLC_CLOCK_PERIOD 10.0
    set_attr default_input_delay      0.1
}
if {$TECH eq "virtexu"} {
    set LLC_CLOCK_PERIOD 8.0
    set_attr default_input_delay      0.1
}
if {$TECH eq "virtexup"} {
    # set LLC_CLOCK_PERIOD 6.4
    set LLC_CLOCK_PERIOD 3.2
    set_attr default_input_delay      0.1
}
if {$TECH eq "cmos32soi"} {
    set LLC_CLOCK_PERIOD 1000.0
    set_attr default_input_delay      100.0
}
if {$TECH eq "gf12"} {
    set LLC_CLOCK_PERIOD 1000.0
    set_attr default_input_delay      100.0
}

#
# System level modules to be synthesized
#
define_hls_module l2_spandex ../../l2_spandex/src/l2_spandex.cpp
define_hls_module llc_spandex ../../llc_spandex/src/llc_spandex.cpp

#
# Testbench or system level modules
#
define_system_module tb  ../tb/two_spandex_system_tb.cpp \
                         ../tb/system.cpp \
                         ../tb/sc_main.cpp
                         
######################################################################
# HLS and Simulation configurations
######################################################################

# Add more HLS configuration here if needed:
# set params_set(n) "sets ways word_off_bits byte_off_bits address_bits endian"

# Leon3 default
# set params_set(0) "512 4 2 2 32 BIG_ENDIAN"
# Ariane default
set params_set(0) "512 4 1 3 32 LITTLE_ENDIAN"
# Ibex default
# set params_set(2) "512 4 2 2 32 LITTLE_ENDIAN"

# TODO: this synthesizes both hls projects with the same clock period, which is not how it will actually be done in practice
set_attr clock_period $CLOCK_PERIOD

foreach ps [array names params_set] {

    set sets   [lindex $params_set($ps) 0]
    set ways   [lindex $params_set($ps) 1]
    set wbits  [lindex $params_set($ps) 2]
    set bbits  [lindex $params_set($ps) 3]
    set abits  [lindex $params_set($ps) 4]
    set endian [lindex $params_set($ps) 5]

    set words_per_line [expr 1 << $wbits]
    set bits_per_word [expr (1 << $bbits) * 8]

    if {$endian == "BIG_ENDIAN"} {set endian_str "be"} {set endian_str "le"}

    set pars "_1024LLCSETS_8LLCWAYS_${sets}L2SETS_${ways}L2WAYS_${words_per_line}x${bits_per_word}LINE_${abits}ADDR_${endian_str}"
    
    set iocfg "IOCFG$pars"

    define_io_config * $iocfg -DLLC_SETS=1024 -DLLC_WAYS=8 -DL2_SETS=$sets -DL2_WAYS=$ways -DADDR_BITS=$abits -DBYTE_BITS=$bbits -DWORD_BITS=$wbits -DENDIAN_$endian

    define_system_config tb "TESTBENCH$pars" -io_config $iocfg

    define_sim_config "BEHAV$pars" "l2_spandex BEH" "llc_spandex BEH" "tb TESTBENCH$pars" -io_config $iocfg

    foreach cfg [list BASIC] {

	    set cname "$cfg$pars"

	    define_hls_config l2_spandex $cname --clock_period=$CLOCK_PERIOD $COMMON_HLS_FLAGS -DHLS_DIRECTIVES_$cfg -io_config $iocfg
        
        define_hls_config llc_spandex $cname --clock_period=$LLC_CLOCK_PERIOD $COMMON_HLS_FLAGS -DHLS_DIRECTIVES_$cfg -io_config $iocfg

	    # if {$TECH_IS_XILINX == 1} {
	    #    define_sim_config "$cname\_V" "l2_spandex RTL_V $cname" "llc_spandex RTL_V $cname" "tb TESTBENCH$pars" -verilog_top_modules glbl -io_config $iocfg
	    # } else {
	    #    define_sim_config "$cname\_V" "l2_spandex RTL_V $cname" "llc_spandex RTL_V $cname" "tb TESTBENCH$pars" -io_config $iocfg
	    # }
    }
}

set SOURCE_INCLUDES "-I../../l2_spandex/src -I../../llc_spandex/src"

#
# Compile Flags
#
set_attr hls_cc_options "$INCLUDES $CACHE_INCLUDES $SOURCE_INCLUDES -I../../utils -DCLOCK_PERIOD=$CLOCK_PERIOD -D__CUDACC__"

#
# Simulation Options
#
use_systemc_simulator xcelium
set_attr cc_options "$INCLUDES  $CACHE_INCLUDES $SOURCE_INCLUDES -I../../utils -DCLOCK_PERIOD=$CLOCK_PERIOD -D__CUDACC__ -DEN_COVERAGE"
# enable_waveform_logging -vcd
set_attr end_of_sim_command "make saySimPassed"
