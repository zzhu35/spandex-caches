/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

    Modified by Zeran Zhu
    zzhu35@illinois.edu

    April 9 2021

*/


#ifndef __SPANDEX_TYPES_HPP__
#define __SPANDEX_TYPES_HPP__


#include <stdint.h>
#include <sstream>
#include "math.h"
#include "systemc.h"
#include "spandex_consts.hpp"

/*
 * Cache data types
 */

typedef sc_uint<CPU_MSG_TYPE_WIDTH>	cpu_msg_t; // CPU bus requests
typedef sc_uint<COH_MSG_TYPE_WIDTH>	coh_msg_t; // Requests without DMA, Forwards, Responses
typedef sc_uint<MIX_MSG_TYPE_WIDTH>	mix_msg_t; // Requests if including DMA
typedef sc_uint<HSIZE_WIDTH>		hsize_t;
typedef sc_uint<HPROT_WIDTH>    	hprot_t;
typedef sc_uint<DCS_WIDTH>          dcs_t;
typedef sc_uint<INVACK_CNT_WIDTH>	invack_cnt_t;
typedef sc_uint<INVACK_CNT_CALC_WIDTH>	invack_cnt_calc_t;
typedef sc_uint<ADDR_BITS>		addr_t;
typedef sc_uint<LINE_ADDR_BITS>		line_addr_t;
typedef sc_uint<L2_ADDR_BITS>           l2_addr_t;
typedef sc_uint<LLC_ADDR_BITS>          llc_addr_t;
typedef sc_uint<BITS_PER_WORD>		word_t;
typedef sc_biguint<BITS_PER_LINE>	line_t;
typedef sc_uint<L2_TAG_BITS>		l2_tag_t;
typedef sc_uint<LLC_TAG_BITS>		llc_tag_t;
typedef sc_uint<L2_SET_BITS>		l2_set_t;
typedef sc_uint<LLC_SET_BITS>		llc_set_t;
#if (L2_WAY_BITS == 1)
typedef sc_uint<2> l2_way_t;
#else
typedef sc_uint<L2_WAY_BITS> l2_way_t;
#endif
typedef sc_uint<LLC_WAY_BITS>		    llc_way_t;
typedef sc_uint<OFFSET_BITS>		    offset_t;
typedef sc_uint<WORD_BITS>		    word_offset_t;
typedef sc_uint<WORDS_PER_LINE>             word_mask_t;
typedef sc_uint<MAX_RETRY_BITS>		retry_t;
typedef sc_uint<ARIANE_AMO_BITS>		amo_t;
typedef sc_uint<BYTE_BITS>		    byte_offset_t;
typedef sc_uint<STABLE_STATE_BITS>	    state_t;
typedef sc_uint<SPX_STABLE_STATE_BITS>		spx_state_t;
typedef sc_uint<LLC_STABLE_STATE_BITS>      llc_state_t;
typedef sc_uint<UNSTABLE_STATE_BITS>        unstable_state_t;
typedef sc_uint<LLC_UNSTABLE_STATE_BITS>    llc_unstable_state_t;
typedef sc_uint<CACHE_ID_WIDTH>             cache_id_t;
typedef sc_uint<LLC_COH_DEV_ID_WIDTH>   llc_coh_dev_id_t;
typedef sc_uint<MAX_N_L2_BITS>		    owner_t;
typedef sc_uint<MAX_N_L2>		    sharers_t;
typedef sc_uint<DMA_BURST_LENGTH_BITS>  dma_length_t;

/*
 * L2 cache coherence channels types
 */

/* L1 to L2 */

// L1 request
class l2_cpu_req_t
{

public:

    cpu_msg_t	cpu_msg;	// r, w, r atom., w atom., flush
    hsize_t	hsize;
    hprot_t	hprot;
    addr_t	addr;
    word_t	word;
    amo_t	amo;
    bool    aq;
    bool    rl;
    bool    dcs_en;
    bool    use_owner_pred;
    dcs_t   dcs;
    cache_id_t pred_cid;


    l2_cpu_req_t() :
    cpu_msg(0),
    hsize(0),
    hprot(0),
    addr(0),
    word(0),
    amo(0),
    aq(0),
    rl(0),
    dcs_en(0),
    use_owner_pred(0),
    dcs(0),
    pred_cid(0)
    {}

    inline l2_cpu_req_t& operator  = (const l2_cpu_req_t& x) {
        cpu_msg = x.cpu_msg;
        hsize   = x.hsize;
        hprot   = x.hprot;
        addr    = x.addr;
        word    = x.word;
        amo     = x.amo;
        aq      = x.aq;
        rl      = x.rl;
        dcs_en  = x.dcs_en;
        use_owner_pred = x.use_owner_pred;
        dcs     = x.dcs;
        pred_cid = x.pred_cid;
        return *this;
    }
    inline bool operator  == (const l2_cpu_req_t& x) const {
        return (x.cpu_msg == cpu_msg	&&
            x.hsize   == hsize	&&
            x.hprot   == hprot	&&
            x.addr    == addr	&&
            x.word    == word   &&
            x.amo     == amo    &&
            x.aq      == aq     &&
            x.rl      == rl     &&
            x.dcs_en  == dcs_en    &&
            x.use_owner_pred == use_owner_pred    &&
            x.dcs     == dcs    &&
            x.pred_cid == pred_cid);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_cpu_req_t& x, const std::string & name) {
        sc_trace(tf, x.cpu_msg , name + ".cpu_msg ");
        sc_trace(tf, x.hsize,    name + ".hsize");
        sc_trace(tf, x.hprot,    name + ".hprot");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.word,     name + ".word");
        sc_trace(tf, x.amo,      name + ".amo");
        sc_trace(tf, x.aq,       name + ".aq");
        sc_trace(tf, x.rl,       name + ".rl");
        sc_trace(tf, x.dcs_en,   name + ".dcs_en");
        sc_trace(tf, x.use_owner_pred, name + ".use_owner_pred");
        sc_trace(tf, x.dcs,      name + ".dcs");
        sc_trace(tf, x.pred_cid, name + ".pred_cid");
    }
    inline friend ostream & operator<<(ostream& os, const l2_cpu_req_t& x) {
        os << hex << "("
           << "cpu_msg: "   << x.cpu_msg
           << ", hsize: "   << x.hsize
           << ", hprot: "   << x.hprot
           << ", addr: "    << x.addr
           << ", word: "    << x.word
           << ", amo: "     << x.amo
           << ", aq: "      << x.aq
           << ", rl: "      << x.rl
           << ", dcs_en: "  << x.dcs_en
           << ", use_owner_pred: " << x.use_owner_pred
           << ", dcs: "     << x.dcs
           << ", pred_cid: "<< x.pred_cid  << ")";
        return os;
    }
};

/* L2 to L1 */

// read data response
class l2_rd_rsp_t
{
public:
    line_t line;

    l2_rd_rsp_t() :
    line(0)
    {}

    inline l2_rd_rsp_t& operator  = (const l2_rd_rsp_t& x) {
        line    = x.line;
        return *this;
    }
    inline bool operator == (const l2_rd_rsp_t& x) const {
        return (x.line == line);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_rd_rsp_t& x, const std::string & name) {
        sc_trace(tf, x.line , name + ".line ");
    }
    inline friend ostream & operator<<(ostream& os, const l2_rd_rsp_t& x) {
        os << hex << "("
           << "line:";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << " " << x.line.range(base + BITS_PER_WORD - 1, base);
        }
        os << ")";
        return os;
    }
};

// invalidate address
typedef line_addr_t l2_inval_t;

/* L2/LLC to L2 */

// forwards
class l2_fwd_in_t
{

public:

    mix_msg_t	coh_msg; // fwd-gets, fwd-getm, fwd-invalidate
    line_addr_t	addr;
    cache_id_t  req_id;
    line_t      line;
    word_mask_t word_mask;

    l2_fwd_in_t() :
    coh_msg(0),
    addr(0),
    req_id(0),
    line(0),
    word_mask(0)
    { }

    inline l2_fwd_in_t& operator  = (const l2_fwd_in_t& x) {
        coh_msg = x.coh_msg;
        addr    = x.addr;
        req_id  = x.req_id;
        line    = x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator  == (const l2_fwd_in_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.addr    == addr       &&
            x.req_id  == req_id &&
            x.line    == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_fwd_in_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg , name + ".coh_msg ");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.req_id,     name + ".req_id");
        sc_trace(tf, x.line,     name + ".line");
        sc_trace(tf, x.word_mask,     name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const l2_fwd_in_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", addr: "  << x.addr
           << ", req_id: "  << x.req_id
           << ", line: " << x.line
           << ", word_mask:" << x.word_mask << ")";
        return os;
    }
};

// responses
class l2_rsp_in_t
{

public:

    coh_msg_t		coh_msg;	// data, e-data, inv-ack, put-ack
    line_addr_t		addr;
    line_t		line;
    word_mask_t 	word_mask;
    invack_cnt_t	invack_cnt;

    l2_rsp_in_t() :
    coh_msg(0),
    addr(0),
    line(0),
    word_mask(0),
    invack_cnt(0)
    {}

    inline l2_rsp_in_t& operator  = (const l2_rsp_in_t& x) {
        coh_msg    = x.coh_msg;
        addr       = x.addr;
        line       = x.line;
        word_mask  = x.word_mask;
        invack_cnt = x.invack_cnt;
        return *this;
    }
    inline bool operator     == (const l2_rsp_in_t& x) const {
        return (x.coh_msg    == coh_msg &&
            x.addr       == addr    &&
            x.line      == line   &&
            x.word_mask == word_mask &&
            x.invack_cnt == invack_cnt);
    }
    inline friend void sc_trace(sc_trace_file	*tf, const l2_rsp_in_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg ,   name + ".cpu_msg ");
        sc_trace(tf, x.addr,       name + ".addr");
        sc_trace(tf, x.line,      name + ".line");
        sc_trace(tf, x.word_mask,      name + ".word_mask");
        sc_trace(tf, x.invack_cnt, name + ".invack_cnt");
    }
    inline friend ostream & operator<<(ostream& os, const l2_rsp_in_t& x) {
        os << hex << "("
           << "coh_msg: "    << x.coh_msg
           << ", addr: "       << x.addr
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask: " << x.word_mask;
        os << ", invack_cnt: " << x.invack_cnt << ")";
        return os;
    }
};

template <unsigned REQ_ID_WIDTH>
class llc_rsp_out_t
{

public:

    coh_msg_t		coh_msg; // data, e-data, inv-ack, rsp-data-dma
    line_addr_t		addr;
    line_t		line;
    invack_cnt_t	invack_cnt; // used to mark last line of RSP_DATA_DMA
    sc_uint<REQ_ID_WIDTH> req_id;
    cache_id_t          dest_id;
    word_offset_t       word_offset;
    word_mask_t word_mask;

    llc_rsp_out_t() :
    coh_msg(0),
    addr(0),
    line(0),
    invack_cnt(0),
    req_id(0),
    dest_id(0),
    word_offset(0),
    word_mask(0)
    {}

    inline llc_rsp_out_t& operator  = (const llc_rsp_out_t& x) {
        coh_msg     = x.coh_msg;
        addr        = x.addr;
        line        = x.line;
        invack_cnt  = x.invack_cnt;
        req_id      = x.req_id;
        dest_id     = x.dest_id;
        word_offset = x.word_offset;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator     == (const llc_rsp_out_t& x) const {
        return (x.coh_msg     == coh_msg    &&
            x.addr        == addr       &&
            x.line        == line       &&
            x.invack_cnt  == invack_cnt &&
            x.req_id      == req_id     &&
            x.dest_id     == dest_id    &&
            x.word_offset == word_offset &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file	*tf, const llc_rsp_out_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg ,    name + ".cpu_msg ");
        sc_trace(tf, x.addr,        name + ".addr");
        sc_trace(tf, x.line,        name + ".line");
        sc_trace(tf, x.invack_cnt,  name + ".invack_cnt");
        sc_trace(tf, x.req_id,      name + ".req_id");
        sc_trace(tf, x.dest_id,     name + ".dest_id");
        sc_trace(tf, x.word_offset, name + ".word_offset");
        sc_trace(tf, x.word_mask, name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const llc_rsp_out_t& x) {
        os << hex << "(coh_msg: ";
        switch (x.coh_msg) {
            case RSP_S : os << "RSP_S"; break;
            case RSP_Odata : os << "RSP_Odata"; break;
            case RSP_INV_ACK_SPDX : os << "RSP_INV_ACK_SPDX"; break;
            case RSP_NACK : os << "RSP_NACK"; break;
            case RSP_RVK_O : os << "RSP_RVK_O"; break;
            case RSP_V : os << "RSP_V"; break;
            case RSP_O : os << "RSP_O"; break;
            case RSP_WT : os << "RSP_WT"; break;
            case RSP_WTdata : os << "RSP_WTdata"; break;
            default: os << "UNKNOWN"; break;
        }
        os << ", addr: "       << x.addr
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", invack_cnt: " << x.invack_cnt
           << ", req_id: " << x.req_id
           << ", dest_id: " << x.dest_id
           << ", word_mask: " << x.word_mask
           << ", word_offset: " << x.word_offset << ")";
        return os;
    }
};

class llc_fwd_out_t
{

public:

    mix_msg_t		coh_msg;	// fwd_gets, fwd_getm, fwd_inv
    line_addr_t		addr;
    cache_id_t          req_id;
    cache_id_t          dest_id;
    line_t      line;
    word_mask_t word_mask;

    llc_fwd_out_t() :
    coh_msg(0),
    addr(0),
    req_id(0),
    dest_id(0),
    line(0),
    word_mask(0)
    {}

    inline llc_fwd_out_t& operator  = (const llc_fwd_out_t& x) {
        coh_msg    = x.coh_msg;
        addr       = x.addr;
        req_id     = x.req_id;
        dest_id    = x.dest_id;
        line       = x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator     == (const llc_fwd_out_t& x) const {
        return (x.coh_msg    == coh_msg &&
            x.addr       == addr    &&
            x.req_id     == req_id &&
            x.dest_id    == dest_id &&
            x.line       == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file	*tf, const llc_fwd_out_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg ,   name + ".cpu_msg ");
        sc_trace(tf, x.addr,       name + ".addr");
        sc_trace(tf, x.req_id, name + ".req_id");
        sc_trace(tf, x.dest_id, name + ".dest_id");
        sc_trace(tf, x.line, name + ".line");
        sc_trace(tf, x.word_mask, name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const llc_fwd_out_t& x) {
        os << hex << "(coh_msg: ";
        switch (x.coh_msg) {
            case FWD_REQ_V : os << "FWD_REQ_V"; break;
            case FWD_REQ_S : os << "FWD_REQ_S"; break;
            case FWD_REQ_O : os << "FWD_REQ_O"; break;
            case FWD_REQ_Odata : os << "FWD_REQ_Odata"; break;
            case FWD_RVK_O : os << "FWD_RVK_O"; break;
            case FWD_INV_SPDX : os << "FWD_INV"; break;
            case FWD_WTfwd : os << "FWD_WTfwd"; break;
            default: os << "UNKNOWN"; break;
        }
        os << ", addr: "       << x.addr
           << ", req_id: " << x.req_id
           << ", line: " << x.line
           << ", word_mask: " << x.word_mask
           << ", dest_id: " << x.dest_id << ")";
        return os;
    }
};

/* L2 to L2/LLC */

// requests
class l2_req_out_t
{

public:

    coh_msg_t	coh_msg;	// gets, getm, puts, putm
    hprot_t	hprot;
    line_addr_t	addr;
    line_t	line;
    word_mask_t word_mask;

    l2_req_out_t() :
    coh_msg(coh_msg_t(0)),
    hprot(0),
    addr(0),
    line(0),
    word_mask(0)
    {}

    inline l2_req_out_t& operator  = (const l2_req_out_t& x) {
        coh_msg = x.coh_msg;
        hprot   = x.hprot;
        addr    = x.addr;
        line    = x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator  == (const l2_req_out_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.hprot   == hprot	&&
            x.addr    == addr	&&
            x.line	  == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_req_out_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg , name + ".coh_msg ");
        sc_trace(tf, x.hprot,    name + ".hprot");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.line,    name + ".line");
        sc_trace(tf, x.word_mask,    name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const l2_req_out_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", hprot: " << x.hprot
           << ", addr: " << x.addr
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask: " << x.word_mask;
        os << ")";
        return os;
    }
};

template <unsigned REQ_ID_WIDTH>
class llc_req_in_t
{

public:

    mix_msg_t	  coh_msg;
    hprot_t	  hprot; // used for dma write burst end (0) and non-aligned addr (1)
    line_addr_t	  addr;
    line_t	  line; // used for dma burst length too
    sc_uint<REQ_ID_WIDTH> req_id;
    word_offset_t word_offset;
    word_offset_t valid_words;
    word_mask_t   word_mask;

    llc_req_in_t() :
    coh_msg(coh_msg_t(0)),
    hprot(0),
    addr(0),
    line(0),
    req_id(0),
    word_offset(0),
    valid_words(0),
    word_mask(0)
    {}

    inline llc_req_in_t& operator  = (const llc_req_in_t& x) {
        coh_msg     = x.coh_msg;
        hprot       = x.hprot;
        addr        = x.addr;
        line        = x.line;
        req_id      = x.req_id;
        word_offset = x.word_offset;
        valid_words = x.valid_words;
        word_mask   = x.word_mask;
        return *this;
    }
    inline bool operator  == (const llc_req_in_t& x) const {
        return (x.coh_msg     == coh_msg     &&
            x.hprot       == hprot       &&
            x.addr        == addr        &&
            x.line        == line        &&
            x.req_id      == req_id      &&
            x.word_offset == word_offset &&
            x.valid_words == valid_words &&
                    x.word_mask   == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const llc_req_in_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg,     name + ".coh_msg ");
        sc_trace(tf, x.hprot,       name + ".hprot");
        sc_trace(tf, x.addr,        name + ".addr");
        sc_trace(tf, x.line,        name + ".line");
        sc_trace(tf, x.req_id,      name + ".req_id");
        sc_trace(tf, x.word_offset, name + ".word_offset");
        sc_trace(tf, x.valid_words, name + ".valid_words");
        sc_trace(tf, x.word_mask,   name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const llc_req_in_t& x) {
        os << hex << "(coh_msg: ";
        switch (x.coh_msg) {
            case REQ_S : os << "REQ_S"; break;
            case REQ_Odata : os << "REQ_Odata"; break;
            case REQ_WT : os << "REQ_WT"; break;
            case REQ_WB : os << "REQ_WB"; break;
            case REQ_O : os << "REQ_O"; break;
            case REQ_V : os << "REQ_V"; break;
            case REQ_WTdata : os << "REQ_WTdata"; break;
            case REQ_AMO_ADD : os << "REQ_AMO_ADD"; break;
            case REQ_AMO_AND : os << "REQ_AMO_AND"; break;
            case REQ_AMO_OR : os << "REQ_AMO_OR"; break;
            case REQ_AMO_XOR : os << "REQ_AMO_XOR"; break;
            case REQ_AMO_MAX : os << "REQ_AMO_MAX"; break;
            case REQ_AMO_MAXU : os << "REQ_AMO_MAXU"; break;
            case REQ_AMO_MIN : os << "REQ_AMO_MIN"; break;
            case REQ_AMO_MINU : os << "REQ_AMO_MINU"; break;
            case REQ_WTfwd : os << "REQ_WTfwd"; break;
            default: os << "UNKNOWN"; break;
        }
        os << ", hprot: " << x.hprot
           << ", addr: " << x.addr
           << ", req_id: " << x.req_id
           << ", word_offset: " << x.word_offset
           << ", valid_words: " << x.valid_words
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask: " << x.word_mask;
        os << ")";
        return os;
    }
};

// responses
class l2_rsp_out_t
{

public:

    coh_msg_t	coh_msg;	// gets, getm, puts, putm
    cache_id_t  req_id;
    sc_uint<2>  to_req;
    line_addr_t	addr;
    line_t	line;
    word_mask_t word_mask;

    l2_rsp_out_t() :
    coh_msg(coh_msg_t(0)),
    req_id(0),
    to_req(0),
    addr(0),
    line(0),
    word_mask(0)
    {}

    inline l2_rsp_out_t& operator  = (const l2_rsp_out_t& x) {
        coh_msg = x.coh_msg;
        req_id   = x.req_id;
        to_req   = x.to_req;
        addr    = x.addr;
        line    = x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator  == (const l2_rsp_out_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.req_id   == req_id	&&
            x.to_req   == to_req	&&
            x.addr    == addr	&&
            x.line	  == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_rsp_out_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg , name + ".coh_msg ");
        sc_trace(tf, x.req_id,    name + ".req_id");
        sc_trace(tf, x.to_req,    name + ".to_req");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.line,    name + ".line");
        sc_trace(tf, x.word_mask,    name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const l2_rsp_out_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", req_id: " << x.req_id
           << ", to_req: " << x.to_req
           << ", addr: " << x.addr
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask " << x.word_mask;
        os << ")";
        return os;
    }
};

// responses
class l2_fwd_out_t
{

public:

    coh_msg_t	coh_msg;	// gets, getm, puts, putm
    cache_id_t  req_id;
    sc_uint<2>  to_req;
    line_addr_t	addr;
    line_t	line;
    word_mask_t word_mask;

    l2_fwd_out_t() :
    coh_msg(coh_msg_t(0)),
    req_id(0),
    to_req(0),
    addr(0),
    line(0),
    word_mask(0)
    {}

    inline l2_fwd_out_t& operator  = (const l2_fwd_out_t& x) {
        coh_msg = x.coh_msg;
        req_id   = x.req_id;
        to_req   = x.to_req;
        addr    = x.addr;
        line    = x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator  == (const l2_fwd_out_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.req_id   == req_id	&&
            x.to_req   == to_req	&&
            x.addr    == addr	&&
            x.line	  == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const l2_fwd_out_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg , name + ".coh_msg ");
        sc_trace(tf, x.req_id,    name + ".req_id");
        sc_trace(tf, x.to_req,    name + ".to_req");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.line,    name + ".line");
        sc_trace(tf, x.word_mask,    name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const l2_fwd_out_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", req_id: " << x.req_id
           << ", to_req: " << x.to_req
           << ", addr: " << x.addr
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask " << x.word_mask;
        os << ")";
        return os;
    }
};

class llc_rsp_in_t
{

public:

    coh_msg_t coh_msg;
    line_addr_t	addr;
    line_t	line;
    cache_id_t  req_id;
    word_mask_t word_mask;

    llc_rsp_in_t() :
    coh_msg(0),
    addr(0),
    line(0),
    req_id(0),
    word_mask(0)
    {}

    inline llc_rsp_in_t& operator  = (const llc_rsp_in_t& x) {
        coh_msg = x.coh_msg;
        addr    = x.addr;
        line    = x.line;
        req_id  = x.req_id;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator  == (const llc_rsp_in_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.addr    == addr	&&
            x.line	  == line       &&
            x.req_id  == req_id &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const llc_rsp_in_t& x, const std::string & name) {
        sc_trace(tf, x.coh_msg,  name + ".coh_msg");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.line,     name + ".line");
        sc_trace(tf, x.req_id,   name + ".req_id");
        sc_trace(tf, x.word_mask, name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const llc_rsp_in_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", addr: " << x.addr
           << ", req_id: " << x.req_id
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask: " << x.word_mask;
        os << ")";
        return os;
    }
};

/* LLC to Memory */

// requests
class llc_mem_req_t
{

public:

    bool	hwrite;	// r, w, r atom., w atom., flush
    hsize_t	hsize;
    hprot_t	hprot;
    line_addr_t	addr;
    line_t	line;

    llc_mem_req_t() :
    hwrite(0),
    hsize(0),
    hprot(0),
    addr(0),
    line(0)
    {}

    inline llc_mem_req_t& operator  = (const llc_mem_req_t& x) {
        hwrite = x.hwrite;
        hsize   = x.hsize;
        hprot   = x.hprot;
        addr    = x.addr;
        line    = x.line;
        return *this;
    }
    inline bool operator  == (const llc_mem_req_t& x) const {
        return (x.hwrite == hwrite	&&
            x.hsize   == hsize	&&
            x.hprot   == hprot	&&
            x.addr    == addr	&&
            x.line    == line);
    }
    inline friend void sc_trace(sc_trace_file *tf, const llc_mem_req_t& x, const std::string & name) {
        sc_trace(tf, x.hwrite , name + ".hwrite ");
        sc_trace(tf, x.hsize,    name + ".hsize");
        sc_trace(tf, x.hprot,    name + ".hprot");
        sc_trace(tf, x.addr,     name + ".addr");
        sc_trace(tf, x.line,     name + ".line");
    }
    inline friend ostream & operator<<(ostream& os, const llc_mem_req_t& x) {
        os << hex << "("
           << "hwrite: "   << x.hwrite
           << ", hsize: "   << x.hsize
           << ", hprot: "   << x.hprot
           << ", addr: "    << x.addr
           << ", line: "    << x.line << ")";
        return os;
    }
};

// responses

typedef l2_rd_rsp_t llc_mem_rsp_t;

/*
 * Ongoing transaction buffer tuypes
 */

// write buffer entry
class wb_t
{
public:
    bool valid;
    l2_tag_t tag;
    l2_set_t set;
    l2_way_t way;
    hprot_t hprot;
    word_mask_t word_mask;
    line_t line;
    bool    dcs_en;
    bool    use_owner_pred;
    cache_id_t pred_cid;


    wb_t() :
    valid(0),
    tag(0),
    set(0),
    way(0),
    hprot(0),
    line(0),
    word_mask(0),
    dcs_en(0),
    use_owner_pred(0),
    pred_cid(0)
    {}

    inline wb_t& operator = (const wb_t& x) {
        valid			= x.valid;
        tag			= x.tag;
        set			= x.set;
        way			= x.way;
        hprot			= x.hprot;
        word_mask			= x.word_mask;
        line			= x.line;
        dcs_en = x.dcs_en;
        use_owner_pred = x.use_owner_pred;
        pred_cid = x.pred_cid;

        return *this;
    }
    inline bool operator     == (const wb_t& x) const {
        return false;
    }
    inline friend void sc_trace(sc_trace_file *tf, const wb_t& x, const std::string & name) {

    }
    inline friend ostream & operator<<(ostream& os, const wb_t& x) {
        return os;
    }

};


// ongoing request buffer
class reqs_buf_t
{

public:

    cpu_msg_t           cpu_msg;
    l2_tag_t		tag;
    l2_tag_t            tag_estall;
    l2_set_t		set;
    l2_way_t            way;
    hsize_t             hsize;
    word_offset_t	w_off;
    byte_offset_t	b_off;
    unstable_state_t	state;
    hprot_t		hprot;
    invack_cnt_calc_t	invack_cnt;
    word_t		word;
    line_t		line;
    word_mask_t word_mask;
    retry_t 	retry;
    bool	type;

    reqs_buf_t() :
    cpu_msg(0),
    tag(0),
    tag_estall(0),
    set(0),
    way(0),
    hsize(0),
    w_off(0),
    b_off(0),
    state(0),
    hprot(0),
    invack_cnt(0),
    word(0),
    line(0),
    word_mask(0),
    type(0)
    {}

    inline reqs_buf_t& operator = (const reqs_buf_t& x) {
        cpu_msg			= x.cpu_msg;
        tag			= x.tag;
        tag_estall		= x.tag_estall;
        set			= x.set;
        way			= x.way;
        hsize			= x.hsize;
        w_off			= x.w_off;
        b_off			= x.b_off;
        state			= x.state;
        hprot			= x.hprot;
        invack_cnt		= x.invack_cnt;
        word			= x.word;
        line			= x.line;
        word_mask = x.word_mask;
        type = x.type;

        return *this;
    }
    inline bool operator     == (const reqs_buf_t& x) const {
        return (x.cpu_msg    == cpu_msg		&&
            x.tag	     == tag		&&
            x.tag_estall == tag_estall	&&
            x.set	     == set		&&
            x.way	     == way		&&
            x.hsize	     == hsize		&&
            x.w_off	     == w_off		&&
            x.b_off	     == b_off		&&
            x.state	     == state		&&
            x.hprot	     == hprot		&&
            x.invack_cnt == invack_cnt	&&
            x.word	     == word		&&
            x.word_mask == word_mask &&
            x.line	     == line &&
            x.type == type);
    }
    inline friend void sc_trace(sc_trace_file *tf, const reqs_buf_t& x, const std::string & name) {
        sc_trace(tf, x.cpu_msg , name + ".cpu_msg ");
        sc_trace(tf, x.tag , name + ".tag");
        sc_trace(tf, x.tag_estall , name + ".tag_estall");
        sc_trace(tf, x.set , name + ".set");
        sc_trace(tf, x.way , name + ".way");
        sc_trace(tf, x.hsize , name + ".hsize");
        sc_trace(tf, x.w_off , name + ".w_off");
        sc_trace(tf, x.b_off , name + ".b_off");
        sc_trace(tf, x.state , name + ".state");
        sc_trace(tf, x.hprot , name + ".hprot");
        sc_trace(tf, x.invack_cnt , name + ".invack_cnt");
        sc_trace(tf, x.word , name + ".word");
        sc_trace(tf, x.line , name + ".line");
    }
    inline friend ostream & operator<<(ostream& os, const reqs_buf_t& x) {
        os << hex << "("
           << "cpu_msg: " << x.cpu_msg
           << "tag: " << x.tag
           << "tag_estall: " << x.tag_estall
           << ", set: "<< x.set
           << ", way: " << x.way
           << ", hsize: " << x.hsize
           << ", w_off: " << x.w_off
           << ", b_off: " << x.b_off
           << ", state: " << x.state
           << ", hprot: " << x.hprot
           << ", invack_cnt: " << x.invack_cnt
           << ", word: " << x.word
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ")";
        return os;
    }
};


class llc_reqs_buf_t
{

public:

    mix_msg_t           msg;
    cache_id_t 		req_id;
    llc_tag_t		tag;
    llc_tag_t            tag_estall;
    llc_set_t		set;
    llc_way_t            way;
    word_offset_t	w_off;
    byte_offset_t	b_off;
    llc_unstable_state_t	state;
    hprot_t		hprot;
    invack_cnt_calc_t	invack_cnt;
    word_t		word;
    line_t		line;
    word_mask_t word_mask;
    bool is_amo;

    llc_reqs_buf_t() :
    msg(0),
    tag(0),
    tag_estall(0),
    set(0),
    way(0),
    w_off(0),
    b_off(0),
    state(0),
    hprot(0),
    invack_cnt(0),
    word(0),
    line(0),
    word_mask(0),
    is_amo(0)
    {}

    inline llc_reqs_buf_t& operator = (const llc_reqs_buf_t& x) {
        msg			= x.msg;
        tag			= x.tag;
        tag_estall		= x.tag_estall;
        set			= x.set;
        way			= x.way;
        w_off			= x.w_off;
        b_off			= x.b_off;
        state			= x.state;
        hprot			= x.hprot;
        invack_cnt		= x.invack_cnt;
        word			= x.word;
        line			= x.line;
        word_mask = x.word_mask;
        return *this;
    }
    inline bool operator     == (const llc_reqs_buf_t& x) const {
        return (x.msg    == msg		&&
            x.tag	     == tag		&&
            x.tag_estall == tag_estall	&&
            x.set	     == set		&&
            x.way	     == way		&&
            x.w_off	     == w_off		&&
            x.b_off	     == b_off		&&
            x.state	     == state		&&
            x.hprot	     == hprot		&&
            x.invack_cnt == invack_cnt	&&
            x.word	     == word		&&
            x.line	     == line &&
            x.word_mask == word_mask);
    }
    inline friend void sc_trace(sc_trace_file *tf, const llc_reqs_buf_t& x, const std::string & name) {
        sc_trace(tf, x.msg , name + ".msg ");
        sc_trace(tf, x.tag , name + ".tag");
        sc_trace(tf, x.tag_estall , name + ".tag_estall");
        sc_trace(tf, x.set , name + ".set");
        sc_trace(tf, x.way , name + ".way");
        sc_trace(tf, x.w_off , name + ".w_off");
        sc_trace(tf, x.b_off , name + ".b_off");
        sc_trace(tf, x.state , name + ".state");
        sc_trace(tf, x.hprot , name + ".hprot");
        sc_trace(tf, x.invack_cnt , name + ".invack_cnt");
        sc_trace(tf, x.word , name + ".word");
        sc_trace(tf, x.line , name + ".line");
        sc_trace(tf, x.word_mask, name + ".word_mask");
    }
    inline friend ostream & operator<<(ostream& os, const llc_reqs_buf_t& x) {
        os << hex << "("
           << "msg: " << x.msg
           << "tag: " << x.tag
           << "tag_estall: " << x.tag_estall
           << ", set: "<< x.set
           << ", way: " << x.way
           << ", w_off: " << x.w_off
           << ", b_off: " << x.b_off
           << ", state: " << x.state
           << ", hprot: " << x.hprot
           << ", invack_cnt: " << x.invack_cnt
           << ", word: " << x.word
           << ", line: ";
        for (int i = WORDS_PER_LINE-1; i >= 0; --i) {
            int base = i*BITS_PER_WORD;
            os << x.line.range(base + BITS_PER_WORD - 1, base) << " ";
        }
        os << ", word_mask: " << x.word_mask;
        os << ")";
        return os;
    }
};

// forward stall backup
class fwd_stall_backup_t
{

public:

    coh_msg_t coh_msg;
    line_addr_t addr;

    fwd_stall_backup_t() :
    coh_msg(0),
    addr(0)
    {}

    inline fwd_stall_backup_t& operator = (const fwd_stall_backup_t& x) {
        coh_msg	= x.coh_msg;
        addr	= x.addr;
        return *this;
    }
    inline bool operator == (const fwd_stall_backup_t& x) const {
        return (x.coh_msg == coh_msg	&&
            x.addr	  == addr);
    }
    inline friend ostream & operator<<(ostream& os, const fwd_stall_backup_t& x) {
        os << hex << "("
           << "coh_msg: " << x.coh_msg
           << ", addr: " << x.addr    << ")";
        return os;
    }
};

// addr breakdown
class addr_breakdown_t
{

public:

    addr_t              line;
    line_addr_t         line_addr;
    addr_t              word;
    l2_tag_t            tag;
    l2_set_t            set;
    word_offset_t       w_off;
    byte_offset_t       b_off;

    addr_breakdown_t() :
    line(0),
    line_addr(0),
    word(0),
    tag(0),
    set(0),
    w_off(0),
    b_off(0)
    {}

    inline addr_breakdown_t& operator = (const addr_breakdown_t& x) {
        line	  = x.line;
        line_addr = x.line_addr;
        word	  = x.word;
        tag	  = x.tag;
        set	  = x.set;
        w_off	  = x.w_off;
        b_off	  = x.b_off;
        return *this;
    }
    inline bool operator == (const addr_breakdown_t& x) const {
        return (x.line	    == line		&&
            x.line_addr == line_addr	&&
            x.word	    == word		&&
            x.tag	    == tag		&&
            x.set	    == set		&&
            x.w_off	    == w_off		&&
            x.b_off	    == b_off);
    }
    inline friend ostream & operator<<(ostream& os, const addr_breakdown_t& x) {
        os << hex << "("
           << "line: "      << x.line
           << "line_addr: " << x.line_addr
           << ", word: "    << x.word
           << ", tag: "     << x.tag
           << ", set: "     << x.set
           << ", w_off: "   << x.w_off
           << ", b_off: "   << x.b_off << ")";
        return os;
    }

    void tag_incr(int a) {
        line	  += a * L2_TAG_OFFSET;
        line_addr += a * L2_SETS;
        word	  += a * L2_TAG_OFFSET;
        tag	  += a;
    }

    void set_incr(int a) {
        line += a * SET_OFFSET;
        line_addr += a;
        word += a * SET_OFFSET;
        set  += a;
    }

    void tag_decr(int a) {
        line	  -= a * L2_TAG_OFFSET;
        line_addr -= a * L2_SETS;
        word	  -= a * L2_TAG_OFFSET;
        tag	  -= a;
    }

    void set_decr(int a) {
        line -= a * SET_OFFSET;
        line_addr -= a;
        word -= a * SET_OFFSET;
        set  -= a;
    }

    void breakdown(addr_t addr)
    {
        line = addr;
        line_addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
        word  = addr;
        tag   = addr.range(TAG_RANGE_HI, L2_TAG_RANGE_LO);
        set   = addr.range(L2_SET_RANGE_HI, SET_RANGE_LO);
        w_off = addr.range(W_OFF_RANGE_HI, W_OFF_RANGE_LO);
        b_off = addr.range(B_OFF_RANGE_HI, B_OFF_RANGE_LO);

        line.range(OFF_RANGE_HI, OFF_RANGE_LO)	   = 0;
        word.range(B_OFF_RANGE_HI, B_OFF_RANGE_LO) = 0;
    }
};

// addr breakdown
class addr_breakdown_llc_t
{

public:

    addr_t              line;
    line_addr_t         line_addr;
    addr_t              word;
    llc_tag_t            tag;
    llc_set_t            set;
    word_offset_t       w_off;
    byte_offset_t       b_off;

    addr_breakdown_llc_t() :
    line(0),
    line_addr(0),
    word(0),
    tag(0),
    set(0),
    w_off(0),
    b_off(0)
    {}

    inline addr_breakdown_llc_t& operator = (const addr_breakdown_llc_t& x) {
        line	  = x.line;
        line_addr = x.line_addr;
        word	  = x.word;
        tag	  = x.tag;
        set	  = x.set;
        w_off	  = x.w_off;
        b_off	  = x.b_off;
        return *this;
    }
    inline bool operator == (const addr_breakdown_llc_t& x) const {
        return (x.line	    == line		&&
            x.line_addr == line_addr	&&
            x.word	    == word		&&
            x.tag	    == tag		&&
            x.set	    == set		&&
            x.w_off	    == w_off		&&
            x.b_off	    == b_off);
    }
    inline friend ostream & operator<<(ostream& os, const addr_breakdown_llc_t& x) {
        os << hex << "("
           << "line: "      << x.line
           << "line_addr: " << x.line_addr
           << ", word: "    << x.word
           << ", tag: "     << x.tag
           << ", set: "     << x.set
           << ", w_off: "   << x.w_off
           << ", b_off: "   << x.b_off << ")";
        return os;
    }

    void tag_incr(int a) {
        line	  += a * LLC_TAG_OFFSET;
        line_addr += a * LLC_SETS;
        word	  += a * LLC_TAG_OFFSET;
        tag	  += a;
    }

    void set_incr(int a) {
        line += a * SET_OFFSET;
        line_addr += a;
        word += a * SET_OFFSET;
        set  += a;
    }

    void tag_decr(int a) {
        line	  -= a * LLC_TAG_OFFSET;
        line_addr -= a * LLC_SETS;
        word	  -= a * LLC_TAG_OFFSET;
        tag	  -= a;
    }

    void set_decr(int a) {
        line -= a * SET_OFFSET;
        line_addr -= a;
        word -= a * SET_OFFSET;
        set  -= a;
    }

    void breakdown(addr_t addr)
    {
        line = addr;
        line_addr = addr.range(TAG_RANGE_HI, SET_RANGE_LO);
        word  = addr;
        tag   = addr.range(TAG_RANGE_HI, LLC_TAG_RANGE_LO);
        set   = addr.range(LLC_SET_RANGE_HI, SET_RANGE_LO);
        w_off = addr.range(W_OFF_RANGE_HI, W_OFF_RANGE_LO);
        b_off = addr.range(B_OFF_RANGE_HI, B_OFF_RANGE_LO);

        line.range(OFF_RANGE_HI, OFF_RANGE_LO)	   = 0;
        word.range(B_OFF_RANGE_HI, B_OFF_RANGE_LO) = 0;
    }
};

// line breakdown
template <class tag_t, class set_t>
class line_breakdown_t
{

public:

    tag_t       tag;
    set_t       set;

    line_breakdown_t() :
    tag(0),
    set(0)
    {}

    inline line_breakdown_t& operator = (const line_breakdown_t& x) {
        tag    = x.tag;
        set    = x.set;
        return *this;
    }
    inline bool operator == (const line_breakdown_t& x) const {
        return (x.tag	== tag		&&
            x.set	== set);
    }
    inline friend ostream & operator<<(ostream& os, const line_breakdown_t& x) {
        os << hex << "("
           << ", tag: "   << x.tag
           << ", set: "   << x.set << ")";
        return os;
    }

    void tag_incr(int a) {
        tag += a;
    }

    void set_incr(int a) {
        set += a;
    }

    void tag_decr(int a) {
        tag -= a;
    }

    void set_decr(int a) {
        set -= a;
    }

    void l2_line_breakdown(line_addr_t addr)
    {
        tag   = addr.range(ADDR_BITS - OFFSET_BITS - 1, L2_SET_BITS);
        set   = addr.range(L2_SET_BITS - 1, 0);
    }

    void llc_line_breakdown(line_addr_t addr)
    {
        tag   = addr.range(ADDR_BITS - OFFSET_BITS - 1, LLC_SET_BITS);
        set   = addr.range(LLC_SET_BITS - 1, 0);
    }
};

#endif // __SPANDEX_TYPES_HPP__
