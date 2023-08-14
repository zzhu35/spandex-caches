/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu, Robert Jin
	zzhu35@illinois.edu
	
	April 9 2021

*/

#ifndef __SPANDEX_CONSTS_HPP__
#define __SPANDEX_CONSTS_HPP__


#include "cache_consts.hpp"

#ifdef  COH_MSG_TYPE_WIDTH
#undef  COH_MSG_TYPE_WIDTH
#define COH_MSG_TYPE_WIDTH 4
#endif

// write buffer
#define N_WB 4
#define WB_BITS 2
#define WB_BITS_P1 3
// Ongoing transaction buffers
#define N_REQS		4	// affects REQS_BITS
#define REQS_BITS	2	// depends on N_REQS
#define REQS_BITS_P1	3	// depends on N_REQS + 1


// Ongoing transaction buffers
#define LLC_N_REQS		4	// affects LLC_REQS_BITS
#define LLC_REQS_BITS   	(ilog2(LLC_N_REQS))	// depends on LLC_N_REQS
#define LLC_REQS_BITS_P1	(LLC_REQS_BITS + 1)	// depends on LLC_N_REQS + 1

#define SPX_NUM_STATE       8
#define SPX_STABLE_STATE_BITS   ilog2(SPX_NUM_STATE)
#define LLC_STABLE_STATE_BITS	2
#define LLC_UNSTABLE_STATE_BITS	4	// depends on # of unstable states

#define WORDS_PER_LINE		(1 << WORD_BITS)
#define WORD_MASK_ALL       ((1 << WORDS_PER_LINE) - 1)
#define DCS_WIDTH               2

// DeNovo states
#define SPX_I       0
#define SPX_MAX_V   (SPX_S - 1)
#define SPX_S       (SPX_NUM_STATE - 2)
#define SPX_R       (SPX_NUM_STATE - 1)

// DeNovo Transient state
#define SPX_IV      1
#define SPX_II      2
#define SPX_RI      3
#define SPX_AMO     4
#define SPX_IV_DCS  5
#define SPX_XR      6
#define SPX_XRV     7
#define SPX_IS      8


// LLC states
#define LLC_I       0
#define LLC_V       1
#define LLC_S       2

// LLC unstable states
#define LLC_IV      1
#define LLC_IS      2
#define LLC_IO      3
#define LLC_SO      4
#define LLC_SV      5
#define LLC_OS      6
#define LLC_OV      7
#define LLC_SWB     8
#define LLC_OWB     9
#define LLC_SI      10
#define LLC_WB      11

#define MAX_RETRY 4
#define MAX_RETRY_BITS ilog2(MAX_RETRY)

// CPU DCS
#define DCS_ReqWTfwd    1
#define DCS_ReqV        1
#define DCS_ReqOdata    2


#define ARIANE_AMO_BITS 6


// requests (L2/TU to L3)
#define REQ_S          0 // same as gets
#define REQ_Odata      1 // same as getm
#define REQ_WT         2
#define REQ_WB         3 // same as putm
#define REQ_O          4
#define REQ_V          5
#define REQ_WTdata     6
#define REQ_AMO_SWAP    REQ_WTdata
#define REQ_AMO_ADD     7 // ADD
#define REQ_AMO_AND     8 // CLR
#define REQ_AMO_OR      9 // SET
#define REQ_AMO_XOR     10 // EOR
#define REQ_AMO_MAX     11 // SMAX
#define REQ_AMO_MAXU    12 // UMAX
#define REQ_AMO_MIN     13 // SMIN
#define REQ_AMO_MINU    14 // UMIN
#define REQ_WTfwd       15

/* Legacy DMA support */
#ifdef  REQ_DMA_READ_BURST
#undef  REQ_DMA_READ_BURST
#define REQ_DMA_READ_BURST  0x1E
#endif

#ifdef  REQ_DMA_WRITE_BURST
#undef  REQ_DMA_WRITE_BURST
#define REQ_DMA_WRITE_BURST 0x1F
#endif


// forwards (L3 to L2/TU)
#define FWD_REQ_S      0 // same as fwd_gets
#define FWD_REQ_Odata  1 // same as fwd_getm
#define FWD_INV_SPDX   2 // same as fwd_inv
#define FWD_WB_ACK     3 // same as fwd_putack
#define FWD_RVK_O      4 // same as getm_llc
#define FWD_REQ_V      7 // non existent in ESP
#define FWD_REQ_O      6
#define FWD_WTfwd      5

// response (L2/TU to L2/TU, L2/TU to L3, L3 to L2/TU)
#define RSP_S          0
#define RSP_Odata      1 // same as fwd_req_odata
#define RSP_INV_ACK_SPDX    2 // same as fwd_inv_spdx
#define RSP_NACK       3
#define RSP_RVK_O      4 // same as fwd_rvk_o
#define RSP_V          5
#define RSP_O          6 // same as fwd_req_o
#define RSP_WT         7
#define RSP_WTdata     8
#define RSP_WB_ACK     9

// AMOS
#define AMO_SWAP    48      // 0b110000 // SWAP
#define AMO_ADD     32      // 0b100000 // ADD
#define AMO_AND     33      // 0b100001 // CLR
#define AMO_OR      35      // 0b100011 // SET
#define AMO_XOR     34      // 0b100010 // EOR
#define AMO_MAX     36      // 0b100100 // SMAX
#define AMO_MAXU    38      // 0b100110 // UMAX
#define AMO_MIN     37      // 0b100101 // SMIN
#define AMO_MINU    39      // 0b100111 // UMIN

#endif
