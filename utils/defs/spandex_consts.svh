`ifndef __SPANDEX_CONSTS_SVH__
`define __SPANDEX_CONSTS_SVH__

`include "cache_consts.svh"

`define DCS_WIDTH 2

`ifdef COH_MSG_TYPE_WIDTH
`undef COH_MSG_TYPE_WIDTH
`define COH_MSG_TYPE_WIDTH 4
`endif

`ifdef MIX_MSG_TYPE_WIDTH
`undef MIX_MSG_TYPE_WIDTH
`define MIX_MSG_TYPE_WIDTH	(`COH_MSG_TYPE_WIDTH + `DMA_MSG_TYPE_WIDTH)
`endif

`endif // __SPANDEX_CONSTS_SVH__