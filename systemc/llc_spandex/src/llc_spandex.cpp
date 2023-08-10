/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

    Modified by Zeran Zhu, Robert Jin
    zzhu35@illinois.edu
    
    April 9 2021

*/

#include "llc_spandex.hpp"

inline bool llc_spandex::is_amo(coh_msg_t coh_msg)
{
    bool ret = false;
    switch (coh_msg)
    {
        case REQ_AMO_SWAP:
        case REQ_AMO_ADD:
        case REQ_AMO_AND:
        case REQ_AMO_OR:
        case REQ_AMO_XOR:
        case REQ_AMO_MAX:
        case REQ_AMO_MAXU:
        case REQ_AMO_MIN:
        case REQ_AMO_MINU:
            ret = true;
            break;
        default:
        break;
    }
    return ret;

}


inline void llc_spandex::reset_io()
{

    // Reset put-get channels
    llc_req_in.reset_get();
    llc_dma_req_in.reset_get();
    llc_rsp_in.reset_get();
    llc_mem_rsp.reset_get();
    llc_rst_tb.reset_get();
    llc_rsp_out.reset_put();
    llc_dma_rsp_out.reset_put();
    llc_fwd_out.reset_put();
    llc_mem_req.reset_put();
    llc_rst_tb_done.reset_put();
#ifdef STATS_ENABLE
    llc_stats.reset_put();
#endif

    evict_ways_buf = 0;

    /* Reset memories */

    tags.port1.reset();
    states.port1.reset();
    hprots.port1.reset();
    lines.port1.reset();
    owners.port1.reset();
    sharers.port1.reset();
    dirty_bits.port1.reset();
    fcs_prio.port1.reset();

    tags.port2.reset();
    states.port2.reset();
    hprots.port2.reset();
    lines.port2.reset();
    owners.port2.reset();
    sharers.port2.reset();
    dirty_bits.port2.reset();
    fcs_prio.port2.reset();

    tags.port3.reset();
    states.port3.reset();
    hprots.port3.reset();
    lines.port3.reset();
    owners.port3.reset();
    sharers.port3.reset();
    dirty_bits.port3.reset();
    fcs_prio.port3.reset();

    tags.port4.reset();
    states.port4.reset();
    hprots.port4.reset();
    lines.port4.reset();
    owners.port4.reset();
    sharers.port4.reset();
    dirty_bits.port4.reset();
    fcs_prio.port4.reset();

    tags.port5.reset();
    states.port5.reset();
    hprots.port5.reset();
    lines.port5.reset();
    owners.port5.reset();
    sharers.port5.reset();
    dirty_bits.port5.reset();
    fcs_prio.port5.reset();

#if (LLC_WAYS >= 8)

    tags.port6.reset();
    states.port6.reset();
    hprots.port6.reset();
    lines.port6.reset();
    owners.port6.reset();
    sharers.port6.reset();
    dirty_bits.port6.reset();
    fcs_prio.port6.reset();

    tags.port7.reset();
    states.port7.reset();
    hprots.port7.reset();
    lines.port7.reset();
    owners.port7.reset();
    sharers.port7.reset();
    dirty_bits.port7.reset();
    fcs_prio.port7.reset();

    tags.port8.reset();
    states.port8.reset();
    hprots.port8.reset();
    lines.port8.reset();
    owners.port8.reset();
    sharers.port8.reset();
    dirty_bits.port8.reset();
    fcs_prio.port8.reset();

    tags.port9.reset();
    states.port9.reset();
    hprots.port9.reset();
    lines.port9.reset();
    owners.port9.reset();
    sharers.port9.reset();
    dirty_bits.port9.reset();
    fcs_prio.port9.reset();

#if (LLC_WAYS >= 16)

    tags.port10.reset();
    states.port10.reset();
    hprots.port10.reset();
    lines.port10.reset();
    owners.port10.reset();
    sharers.port10.reset();
    dirty_bits.port10.reset();

    tags.port11.reset();
    states.port11.reset();
    hprots.port11.reset();
    lines.port11.reset();
    owners.port11.reset();
    sharers.port11.reset();
    dirty_bits.port11.reset();

    tags.port12.reset();
    states.port12.reset();
    hprots.port12.reset();
    lines.port12.reset();
    owners.port12.reset();
    sharers.port12.reset();
    dirty_bits.port12.reset();

    tags.port13.reset();
    states.port13.reset();
    hprots.port13.reset();
    lines.port13.reset();
    owners.port13.reset();
    sharers.port13.reset();
    dirty_bits.port13.reset();

    tags.port14.reset();
    states.port14.reset();
    hprots.port14.reset();
    lines.port14.reset();
    owners.port14.reset();
    sharers.port14.reset();
    dirty_bits.port14.reset();

    tags.port15.reset();
    states.port15.reset();
    hprots.port15.reset();
    lines.port15.reset();
    owners.port15.reset();
    sharers.port15.reset();
    dirty_bits.port15.reset();

    tags.port16.reset();
    states.port16.reset();
    hprots.port16.reset();
    lines.port16.reset();
    owners.port16.reset();
    sharers.port16.reset();
    dirty_bits.port16.reset();

    tags.port17.reset();
    states.port17.reset();
    hprots.port17.reset();
    lines.port17.reset();
    owners.port17.reset();
    sharers.port17.reset();
    dirty_bits.port17.reset();

#endif
#endif

    evict_ways.port1.reset();
    evict_ways.port2.reset();

    // Reset states
    {
        HLS_DEFINE_PROTOCOL("reset invalidate");
        wait();

        for (int i = 0; i < LLC_LINES; i++) {
            HLS_UNROLL_LOOP(OFF, "states reset");
            states.port1[0][i] = LLC_I;
            wait();
        }
    }
}

inline void llc_spandex::reset_state()
{
    for (int i = 0; i < LLC_WAYS; i++) {
        HLS_UNROLL_LOOP(ON, "reset-bufs");

        tags_buf[i] = 0;
        states_buf[i] = 0;
        lines_buf[i] = 0;
        sharers_buf[i] = 0;
        owners_buf[i] = 0;
        dirty_bits_buf[i] = 0;
        hprots_buf[i] = 0;
        fcs_prio_buf[i] = 0;
    }
    wait();
    for (int i = 0; i < LLC_N_REQS; i++)
    {
        reqs[i].state = LLC_I;
        wait();
    }
    reqs_cnt = LLC_N_REQS;
    set_conflict = false;
    evict_stall = false;
    evict_inprogress = false;

    dma_read_pending = false;
    dma_write_pending = false;
    dma_addr = 0;
    dma_read_length = 0;
    dma_length = 0;
    dma_done = false;
    dma_start = false;
    recall_pending = false;
    recall_valid = false;
    recall_addr = 0;

    for (int i = 0; i < WORDS_PER_LINE; i++)
    {
        fwd_coal_word_mask[i] = 0;
        fwd_coal_temp_dest[i] = 0;
    }


#ifdef LLC_DEBUG
//     dbg_asserts.write(0);
//     dbg_bookmark.write(0);

    dbg_is_rst_to_get.write(0);
    dbg_is_rsp_to_get.write(0);
    dbg_is_req_to_get.write(0);

    dbg_tag_hit.write(0);
    dbg_hit_way.write(0);
    dbg_empty_way_found.write(0);
    dbg_empty_way.write(0);
    dbg_way.write(0);
    dbg_llc_addr.write(0);
    dbg_evict.write(0);

    dbg_length.write(0);
    dbg_dma_length.write(0);
    dbg_dma_done.write(0);
    dbg_dma_addr.write(0);
    dbg_dma_read_pending.write(0);
    dbg_dma_write_pending.write(0);

//     dbg_length.write(0);
#endif

    wait();
}


inline void llc_spandex::read_set(const llc_addr_t base, const llc_way_t way_offset)
{
// #if LLC_WAYS == 32
//     for (int i = 0; i < LLC_LOOKUP_WAYS; i++) {
// #else
//     for (int i = 0; i < LLC_WAYS; i++) {
// #endif
//         HLS_UNROLL_LOOP(ON);

//         tags_buf[i + way_offset]       = tags[base + i + way_offset];
//         states_buf[i + way_offset]     = states[base + i + way_offset];
//         hprots_buf[i + way_offset]     = hprots[base + i + way_offset];
//         lines_buf[i + way_offset]      = lines[base + i + way_offset];
//         owners_buf[i + way_offset]     = owners[base + i + way_offset];
//         sharers_buf[i + way_offset]   = sharers[base + i + way_offset];
//         dirty_bits_buf[i + way_offset] = dirty_bits[base + i + way_offset];
//     }

    tags_buf[0 + way_offset] = tags.port2[0][base + 0 + way_offset];
    states_buf[0 + way_offset] = states.port2[0][base + 0 + way_offset];
    hprots_buf[0 + way_offset] = hprots.port2[0][base + 0 + way_offset];
    lines_buf[0 + way_offset] = lines.port2[0][base + 0 + way_offset];
    owners_buf[0 + way_offset] = owners.port2[0][base + 0 + way_offset];
    sharers_buf[0 + way_offset] = sharers.port2[0][base + 0 + way_offset];
    dirty_bits_buf[0 + way_offset] = dirty_bits.port2[0][base + 0 + way_offset];
    fcs_prio_buf[0 + way_offset] = fcs_prio.port2[0][base + 0 + way_offset];

    tags_buf[1 + way_offset] = tags.port3[0][base + 1 + way_offset];
    states_buf[1 + way_offset] = states.port3[0][base + 1 + way_offset];
    hprots_buf[1 + way_offset] = hprots.port3[0][base + 1 + way_offset];
    lines_buf[1 + way_offset] = lines.port3[0][base + 1 + way_offset];
    owners_buf[1 + way_offset] = owners.port3[0][base + 1 + way_offset];
    sharers_buf[1 + way_offset] = sharers.port3[0][base + 1 + way_offset];
    dirty_bits_buf[1 + way_offset] = dirty_bits.port3[0][base + 1 + way_offset];
    fcs_prio_buf[1 + way_offset] = fcs_prio.port3[0][base + 1 + way_offset];

    tags_buf[2 + way_offset] = tags.port4[0][base + 2 + way_offset];
    states_buf[2 + way_offset] = states.port4[0][base + 2 + way_offset];
    hprots_buf[2 + way_offset] = hprots.port4[0][base + 2 + way_offset];
    lines_buf[2 + way_offset] = lines.port4[0][base + 2 + way_offset];
    owners_buf[2 + way_offset] = owners.port4[0][base + 2 + way_offset];
    sharers_buf[2 + way_offset] = sharers.port4[0][base + 2 + way_offset];
    dirty_bits_buf[2 + way_offset] = dirty_bits.port4[0][base + 2 + way_offset];
    fcs_prio_buf[2 + way_offset] = fcs_prio.port4[0][base + 2 + way_offset];

    tags_buf[3 + way_offset] = tags.port5[0][base + 3 + way_offset];
    states_buf[3 + way_offset] = states.port5[0][base + 3 + way_offset];
    hprots_buf[3 + way_offset] = hprots.port5[0][base + 3 + way_offset];
    lines_buf[3 + way_offset] = lines.port5[0][base + 3 + way_offset];
    owners_buf[3 + way_offset] = owners.port5[0][base + 3 + way_offset];
    sharers_buf[3 + way_offset] = sharers.port5[0][base + 3 + way_offset];
    dirty_bits_buf[3 + way_offset] = dirty_bits.port5[0][base + 3 + way_offset];
    fcs_prio_buf[3 + way_offset] = fcs_prio.port5[0][base + 3 + way_offset];

#if (LLC_WAYS >= 8)

    tags_buf[4 + way_offset] = tags.port6[0][base + 4 + way_offset];
    states_buf[4 + way_offset] = states.port6[0][base + 4 + way_offset];
    hprots_buf[4 + way_offset] = hprots.port6[0][base + 4 + way_offset];
    lines_buf[4 + way_offset] = lines.port6[0][base + 4 + way_offset];
    owners_buf[4 + way_offset] = owners.port6[0][base + 4 + way_offset];
    sharers_buf[4 + way_offset] = sharers.port6[0][base + 4 + way_offset];
    dirty_bits_buf[4 + way_offset] = dirty_bits.port6[0][base + 4 + way_offset];
    fcs_prio_buf[4 + way_offset] = fcs_prio.port6[0][base + 4 + way_offset];

    tags_buf[5 + way_offset] = tags.port7[0][base + 5 + way_offset];
    states_buf[5 + way_offset] = states.port7[0][base + 5 + way_offset];
    hprots_buf[5 + way_offset] = hprots.port7[0][base + 5 + way_offset];
    lines_buf[5 + way_offset] = lines.port7[0][base + 5 + way_offset];
    owners_buf[5 + way_offset] = owners.port7[0][base + 5 + way_offset];
    sharers_buf[5 + way_offset] = sharers.port7[0][base + 5 + way_offset];
    dirty_bits_buf[5 + way_offset] = dirty_bits.port7[0][base + 5 + way_offset];
    fcs_prio_buf[5 + way_offset] = fcs_prio.port7[0][base + 5 + way_offset];

    tags_buf[6 + way_offset] = tags.port8[0][base + 6 + way_offset];
    states_buf[6 + way_offset] = states.port8[0][base + 6 + way_offset];
    hprots_buf[6 + way_offset] = hprots.port8[0][base + 6 + way_offset];
    lines_buf[6 + way_offset] = lines.port8[0][base + 6 + way_offset];
    owners_buf[6 + way_offset] = owners.port8[0][base + 6 + way_offset];
    sharers_buf[6 + way_offset] = sharers.port8[0][base + 6 + way_offset];
    dirty_bits_buf[6 + way_offset] = dirty_bits.port8[0][base + 6 + way_offset];
    fcs_prio_buf[6 + way_offset] = fcs_prio.port8[0][base + 6 + way_offset];

    tags_buf[7 + way_offset] = tags.port9[0][base + 7 + way_offset];
    states_buf[7 + way_offset] = states.port9[0][base + 7 + way_offset];
    hprots_buf[7 + way_offset] = hprots.port9[0][base + 7 + way_offset];
    lines_buf[7 + way_offset] = lines.port9[0][base + 7 + way_offset];
    owners_buf[7 + way_offset] = owners.port9[0][base + 7 + way_offset];
    sharers_buf[7 + way_offset] = sharers.port9[0][base + 7 + way_offset];
    dirty_bits_buf[7 + way_offset] = dirty_bits.port9[0][base + 7 + way_offset];
    fcs_prio_buf[7 + way_offset] = fcs_prio.port9[0][base + 7 + way_offset];

#if (LLC_WAYS >= 16)

    tags_buf[8 + way_offset] = tags.port10[0][base + 8 + way_offset];
    states_buf[8 + way_offset] = states.port10[0][base + 8 + way_offset];
    hprots_buf[8 + way_offset] = hprots.port10[0][base + 8 + way_offset];
    lines_buf[8 + way_offset] = lines.port10[0][base + 8 + way_offset];
    owners_buf[8 + way_offset] = owners.port10[0][base + 8 + way_offset];
    sharers_buf[8 + way_offset] = sharers.port10[0][base + 8 + way_offset];
    dirty_bits_buf[8 + way_offset] = dirty_bits.port10[0][base + 8 + way_offset];

    tags_buf[9 + way_offset] = tags.port11[0][base + 9 + way_offset];
    states_buf[9 + way_offset] = states.port11[0][base + 9 + way_offset];
    hprots_buf[9 + way_offset] = hprots.port11[0][base + 9 + way_offset];
    lines_buf[9 + way_offset] = lines.port11[0][base + 9 + way_offset];
    owners_buf[9 + way_offset] = owners.port11[0][base + 9 + way_offset];
    sharers_buf[9 + way_offset] = sharers.port11[0][base + 9 + way_offset];
    dirty_bits_buf[9 + way_offset] = dirty_bits.port11[0][base + 9 + way_offset];

    tags_buf[10 + way_offset] = tags.port12[0][base + 10 + way_offset];
    states_buf[10 + way_offset] = states.port12[0][base + 10 + way_offset];
    hprots_buf[10 + way_offset] = hprots.port12[0][base + 10 + way_offset];
    lines_buf[10 + way_offset] = lines.port12[0][base + 10 + way_offset];
    owners_buf[10 + way_offset] = owners.port12[0][base + 10 + way_offset];
    sharers_buf[10 + way_offset] = sharers.port12[0][base + 10 + way_offset];
    dirty_bits_buf[10 + way_offset] = dirty_bits.port12[0][base + 10 + way_offset];

    tags_buf[11 + way_offset] = tags.port13[0][base + 11 + way_offset];
    states_buf[11 + way_offset] = states.port13[0][base + 11 + way_offset];
    hprots_buf[11 + way_offset] = hprots.port13[0][base + 11 + way_offset];
    lines_buf[11 + way_offset] = lines.port13[0][base + 11 + way_offset];
    owners_buf[11 + way_offset] = owners.port13[0][base + 11 + way_offset];
    sharers_buf[11 + way_offset] = sharers.port13[0][base + 11 + way_offset];
    dirty_bits_buf[11 + way_offset] = dirty_bits.port13[0][base + 11 + way_offset];

    tags_buf[12 + way_offset] = tags.port14[0][base + 12 + way_offset];
    states_buf[12 + way_offset] = states.port14[0][base + 12 + way_offset];
    hprots_buf[12 + way_offset] = hprots.port14[0][base + 12 + way_offset];
    lines_buf[12 + way_offset] = lines.port14[0][base + 12 + way_offset];
    owners_buf[12 + way_offset] = owners.port14[0][base + 12 + way_offset];
    sharers_buf[12 + way_offset] = sharers.port14[0][base + 12 + way_offset];
    dirty_bits_buf[12 + way_offset] = dirty_bits.port14[0][base + 12 + way_offset];

    tags_buf[13 + way_offset] = tags.port15[0][base + 13 + way_offset];
    states_buf[13 + way_offset] = states.port15[0][base + 13 + way_offset];
    hprots_buf[13 + way_offset] = hprots.port15[0][base + 13 + way_offset];
    lines_buf[13 + way_offset] = lines.port15[0][base + 13 + way_offset];
    owners_buf[13 + way_offset] = owners.port15[0][base + 13 + way_offset];
    sharers_buf[13 + way_offset] = sharers.port15[0][base + 13 + way_offset];
    dirty_bits_buf[13 + way_offset] = dirty_bits.port15[0][base + 13 + way_offset];

    tags_buf[14 + way_offset] = tags.port16[0][base + 14 + way_offset];
    states_buf[14 + way_offset] = states.port16[0][base + 14 + way_offset];
    hprots_buf[14 + way_offset] = hprots.port16[0][base + 14 + way_offset];
    lines_buf[14 + way_offset] = lines.port16[0][base + 14 + way_offset];
    owners_buf[14 + way_offset] = owners.port16[0][base + 14 + way_offset];
    sharers_buf[14 + way_offset] = sharers.port16[0][base + 14 + way_offset];
    dirty_bits_buf[14 + way_offset] = dirty_bits.port16[0][base + 14 + way_offset];

    tags_buf[15 + way_offset] = tags.port17[0][base + 15 + way_offset];
    states_buf[15 + way_offset] = states.port17[0][base + 15 + way_offset];
    hprots_buf[15 + way_offset] = hprots.port17[0][base + 15 + way_offset];
    lines_buf[15 + way_offset] = lines.port17[0][base + 15 + way_offset];
    owners_buf[15 + way_offset] = owners.port17[0][base + 15 + way_offset];
    sharers_buf[15 + way_offset] = sharers.port17[0][base + 15 + way_offset];
    dirty_bits_buf[15 + way_offset] = dirty_bits.port17[0][base + 15 + way_offset];

#endif
#endif


#ifdef LLC_DEBUG
    for (int i = 0; i < LLC_LOOKUP_WAYS; i++) {
        HLS_UNROLL_LOOP(ON, "buf-output-unroll");
        dbg_tags_buf[i + way_offset]	  = tags_buf[i];
        dbg_states_buf[i + way_offset]     = states_buf[i];
        dbg_hprots_buf[i + way_offset]     = hprots_buf[i];
        dbg_lines_buf[i + way_offset]	  = lines_buf[i];
        dbg_sharers_buf[i + way_offset]   = sharers_buf[i];
        dbg_owners_buf[i + way_offset]     = owners_buf[i];
        dbg_dirty_bits_buf[i + way_offset] = dirty_bits_buf[i];
    }
#endif
}


void llc_spandex::lookup(llc_tag_t tag, llc_way_t &way, bool &evict)
{
    bool tag_hit = false, empty_way_found = false, evict_valid = false;
    llc_way_t hit_way = 0, empty_way = 0, evict_way_valid = 0;

    evict = false;

    /*
     * Hit and empty way policy: If any, the empty way selected is the closest to 0.
     */

    for (int i = LLC_WAYS - 1; i >= 0; i--) {
        HLS_UNROLL_LOOP(ON);

        if (tags_buf[i] == tag && states_buf[i] != LLC_I) {
            tag_hit = true;
            hit_way = i;
        }

        if (states_buf[i] == LLC_I) {
            empty_way_found = true;
            empty_way = i;
        }
    }

    /*
     * Eviction policy: FIFO like.
     * - Starting from evict_ways[set] evict first VALID line if any
     * - Otherwise starting from evict_ways[set] evict first line not SD if any
     * - Otherwise evict evict_ways[set] way (it is in SD state). This will cause a stall.
     */

    for (int i = LLC_WAYS - 1; i >= 0; i--) {
        HLS_UNROLL_LOOP(ON);

        llc_way_t way = (llc_way_t) i + evict_ways_buf;

        if (states_buf[way] == LLC_V && fcs_prio_buf[way] == 0) {
            evict_valid = true;
            evict_way_valid = way;
        }

    }

    if (tag_hit == true) {
        way = hit_way;
    } else if (empty_way_found == true) {
        way = empty_way;
    } else if (evict_valid) {
        way = evict_way_valid;
        evict = true;
    } else {
        way = evict_ways_buf;
        evict = true;
    }

#ifdef LLC_DEBUG
    {
        HLS_DEFINE_PROTOCOL("lookup_dbg");
        dbg_tag_hit.write(tag_hit);
        dbg_hit_way.write(hit_way);
        dbg_empty_way_found.write(empty_way_found);
        dbg_empty_way.write(empty_way);
        dbg_way.write(way);
        dbg_evict.write(evict);
    }
#endif
}



inline void llc_spandex::send_mem_req(bool hwrite, line_addr_t addr, hprot_t hprot, line_t line)
{
    SEND_MEM_REQ;

    llc_mem_req_t mem_req;
    mem_req.hwrite = hwrite;
    mem_req.addr = addr;
    mem_req.hsize = WORD;
    mem_req.hprot = hprot;
    mem_req.line = line;
    do {wait();}
    while (!llc_mem_req.nb_can_put());
    llc_mem_req.nb_put(mem_req);
}

inline void llc_spandex::get_mem_rsp(line_t &line)
{
    GET_MEM_RSP;

    llc_mem_rsp_t mem_rsp;
    while (!llc_mem_rsp.nb_can_get())
        wait();
    llc_mem_rsp.nb_get(mem_rsp);
    line = mem_rsp.line;
}


#ifdef STATS_ENABLE
inline void llc_spandex::send_stats(bool stats)
{
    SEND_STATS;
    do {wait();}
    while (!llc_stats.nb_can_put());
    llc_stats.nb_put(stats);
}
#endif

inline void llc_spandex::send_rsp_out(coh_msg_t coh_msg, line_addr_t addr, line_t line, cache_id_t req_id,
                              cache_id_t dest_id, invack_cnt_t invack_cnt, word_offset_t word_offset, word_mask_t word_mask)
{
    SEND_RSP_OUT;
    llc_rsp_out_t<CACHE_ID_WIDTH> rsp_out;
    rsp_out.coh_msg = coh_msg;
    rsp_out.addr = addr;
    rsp_out.line = line;
    rsp_out.req_id = req_id;
    rsp_out.dest_id = dest_id;
    rsp_out.invack_cnt = invack_cnt;
    rsp_out.word_offset = word_offset;
    rsp_out.word_mask = word_mask;
    while (!llc_rsp_out.nb_can_put())
        wait();
    llc_rsp_out.nb_put(rsp_out);
}

inline void llc_spandex::send_fwd_out(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, cache_id_t dest_id, word_mask_t word_mask)
{
    SEND_FWD_OUT;
    llc_fwd_out_t fwd_out;

    fwd_out.coh_msg = coh_msg;
    fwd_out.addr = addr;
    fwd_out.req_id = req_id;
    fwd_out.dest_id = dest_id;
    fwd_out.word_mask = word_mask;
    while (!llc_fwd_out.nb_can_put())
        wait();
    llc_fwd_out.nb_put(fwd_out);
}

inline void llc_spandex::send_dma_rsp_out(coh_msg_t coh_msg, line_addr_t addr, line_t line, llc_coh_dev_id_t req_id,
                           cache_id_t dest_id, invack_cnt_t invack_cnt, word_offset_t word_offset)
{
    SEND_DMA_RSP_OUT;
    llc_rsp_out_t<LLC_COH_DEV_ID_WIDTH> rsp_out;
    rsp_out.coh_msg = coh_msg;
    rsp_out.addr = addr;
    rsp_out.line = line;
    rsp_out.req_id = req_id;
    rsp_out.dest_id = dest_id;
    rsp_out.invack_cnt = invack_cnt;
    rsp_out.word_offset = word_offset;
    while (!llc_dma_rsp_out.nb_can_put())
        wait();
    llc_dma_rsp_out.nb_put(rsp_out);
}

inline void llc_spandex::send_fwd_out_data(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, cache_id_t dest_id, word_mask_t word_mask, line_t data)
{
    SEND_FWD_OUT;
    llc_fwd_out_t fwd_out;

    fwd_out.coh_msg = coh_msg;
    fwd_out.addr = addr;
    fwd_out.req_id = req_id;
    fwd_out.dest_id = dest_id;
    fwd_out.word_mask = word_mask;
    fwd_out.line = data;
    while (!llc_fwd_out.nb_can_put())
        wait();
    llc_fwd_out.nb_put(fwd_out);
}

inline bool llc_spandex::send_fwd_with_owner_mask(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, word_mask_t word_mask, line_t data)
{
    fwd_coal_send_count = 0;
    for (int i = 0; i < WORDS_PER_LINE; i++) {
        if (word_mask & (1 << i)) {
            int owner = data.range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD).to_int();
            if (owner != req_id || coh_msg == FWD_RVK_O) { // skip if requestor already owns word, still send if revoke
                bool coal = false;
                for (int j = 0; j < fwd_coal_send_count; j++)
                {
                    if (fwd_coal_temp_dest[j] == owner)
                    {
                        fwd_coal_word_mask[j] = fwd_coal_word_mask[j] | (1 << i);
                        coal = true;
                        break;
                    }
                    wait();
                }
                // new forward dest
                if (!coal)
                {
                    fwd_coal_temp_dest[fwd_coal_send_count] = owner;
                    fwd_coal_word_mask[fwd_coal_send_count] = 0 | (1 << i);
                    fwd_coal_send_count = fwd_coal_send_count + 1;
                }
            }
        }
        wait();
    }
    for (int i = 0; i < fwd_coal_send_count; i++)
    {
        HLS_DEFINE_PROTOCOL();
        send_fwd_out(coh_msg, addr, req_id, fwd_coal_temp_dest[i], fwd_coal_word_mask[i]);
        fwd_coal_word_mask[i] = 0;
        wait();
    }
    return fwd_coal_send_count > 0;
}

inline bool llc_spandex::send_fwd_with_owner_mask_data(mix_msg_t coh_msg, line_addr_t addr, cache_id_t req_id, word_mask_t word_mask, line_t data, line_t data_out)
{
    fwd_coal_send_count = 0;
    for (int i = 0; i < WORDS_PER_LINE; i++) {
        if (word_mask & (1 << i)) {
            int owner = data.range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD).to_int();
            if (owner != req_id || coh_msg == FWD_RVK_O) { // skip if requestor already owns word, still send if revoke
                bool coal = false;
                for (int j = 0; j < fwd_coal_send_count; j++)
                {
                    if (fwd_coal_temp_dest[j] == owner)
                    {
                        fwd_coal_word_mask[j] = fwd_coal_word_mask[j] | (1 << i);
                        coal = true;
                        break;
                    }
                    wait();
                }
                // new forward dest
                if (!coal)
                {
                    fwd_coal_temp_dest[fwd_coal_send_count] = owner;
                    fwd_coal_word_mask[fwd_coal_send_count] = 0 | (1 << i);
                    fwd_coal_send_count = fwd_coal_send_count + 1;
                }
            }
        }
        wait();
    }
    for (int i = 0; i < fwd_coal_send_count; i++)
    {
        send_fwd_out_data(coh_msg, addr, req_id, fwd_coal_temp_dest[i], fwd_coal_word_mask[i], data_out);
        fwd_coal_word_mask[i] = 0;
        wait();
    }
    return fwd_coal_send_count > 0;
}

inline int llc_spandex::send_inv_with_sharer_list(line_addr_t addr, sharers_t sharer_list)
{
    HLS_DEFINE_PROTOCOL("inv_all_sharers");
    int cnt = 0;
    for (int i = 0; i < MAX_N_L2; i++) {
        if (sharer_list & (1 << i)) {
            send_fwd_out(FWD_INV_SPDX, addr, 0, i, WORD_MASK_ALL);
            cnt++;
        }
        wait();
    }
    return cnt;
}



// write reqs buf
void llc_spandex::fill_reqs(mix_msg_t msg, cache_id_t req_id, addr_breakdown_llc_t addr_br, llc_tag_t tag_estall, llc_way_t way_hit,
		   llc_unstable_state_t state, hprot_t hprot, word_t word, line_t line, word_mask_t word_mask, sc_uint<LLC_REQS_BITS> reqs_i)
{
    LLC_FILL_REQS;

    reqs[reqs_i].msg         = msg;
    reqs[reqs_i].tag	     = addr_br.tag;
    reqs[reqs_i].tag_estall  = tag_estall;
    reqs[reqs_i].set	     = addr_br.set;
    reqs[reqs_i].way	     = way_hit;
    reqs[reqs_i].w_off       = addr_br.w_off;
    reqs[reqs_i].b_off       = addr_br.b_off;
    reqs[reqs_i].state	     = state;
    reqs[reqs_i].hprot	     = hprot;
    reqs[reqs_i].invack_cnt  = MAX_N_L2;
    reqs[reqs_i].word	     = word;
    reqs[reqs_i].line	     = line;
    reqs[reqs_i].word_mask   = word_mask;
    reqs[reqs_i].req_id      = req_id;
    reqs[reqs_i].is_amo      = false;
    reqs_cnt--;
}


// lookup reqs buf
void llc_spandex::reqs_lookup(addr_breakdown_llc_t br, sc_uint<LLC_REQS_BITS> &reqs_hit_i)
{
    LLC_REQS_LOOKUP;

    for (unsigned int i = 0; i < LLC_N_REQS; ++i) {
        LLC_REQS_LOOKUP_LOOP;

        if (reqs[i].tag == br.tag && reqs[i].set == br.set && reqs[i].state != LLC_I) {
            reqs_hit_i = i;
        }
    }

#ifdef LLC_DEBUG
    // @TODO
    // reqs_hit_req_dbg.write(reqs_hit);
    // reqs_hit_i_req_dbg.write(reqs_hit_i);
#endif
    // REQS_LOOKUP_ASSERT;
}

bool llc_spandex::reqs_peek_req(addr_breakdown_llc_t br, sc_uint<LLC_REQS_BITS> &reqs_empty_i)
{
    LLC_REQS_PEEK_REQ;

    set_conflict = false;

    for (unsigned int i = 0; i < LLC_N_REQS; ++i) {
        LLC_REQS_PEEK_REQ_LOOP;

        if (reqs[i].state == LLC_I)
            reqs_empty_i = i;

        if (reqs[i].tag == br.tag && reqs[i].set == br.set && reqs[i].state != LLC_I)
            set_conflict = true;
    }

#ifdef LLC_DEBUG
    // @TODO
    // peek_reqs_i_dbg.write(reqs_i);
#endif

    return set_conflict;
}




/*
 * Processes
 */

void llc_spandex::ctrl()
{
    // -----------------------------
    // RESET
    // -----------------------------

    // Reset all signals and channels
    {
        HLS_DEFINE_PROTOCOL("reset-io");

        this->reset_io();
    }

    // Reset state memory
    {
        HLS_DEFINE_PROTOCOL("reset_state-1");

        this->reset_state();
    }


    while (true) {

        bool is_rst_to_resume = false;
        bool is_flush_to_resume = false;
        bool is_rst_to_get = false;
        bool is_rsp_to_get = false;
        bool is_req_to_get = false;
        bool is_dma_read_to_resume = false;
        bool is_dma_write_to_resume = false;
        bool is_dma_req_to_get = false;

        bool rst_in = false;
        llc_rsp_in_t rsp_in;
        llc_req_in_t<CACHE_ID_WIDTH> req_in;

        bool can_get_rst_tb = false;
        bool can_get_rsp_in = false;
        bool can_get_req_in = false;
        bool can_get_dma_in = false;

        bool update_evict_ways = false;

        bool look;
        bool other_owner;
        line_breakdown_t<llc_tag_t, llc_set_t> line_br;
        llc_set_t set;
        llc_way_t way;
        bool evict;
        llc_addr_t base;
        llc_addr_t llc_addr;
        line_addr_t addr_evict;
        addr_t addr_evict_real;
        word_mask_t word_owner_mask;
        word_mask_t word_no_owner_mask;

        // -----------------------------
        // Check input channels
        // -----------------------------

        {
            HLS_DEFINE_PROTOCOL("proto-llc-io-check");
            bool do_get_req = false;
            bool do_get_dma_req = false;

            can_get_rst_tb = llc_rst_tb.nb_can_get();
            can_get_rsp_in = llc_rsp_in.nb_can_get();
            can_get_req_in = llc_req_in.nb_can_get();
            can_get_dma_in = llc_dma_req_in.nb_can_get();

            if (can_get_rsp_in) {
                // Response
                is_rsp_to_get = true;

            } else if (recall_pending) {
                if (!recall_valid) {
                    // Response (could be related to the recall or not)
                    if (can_get_rsp_in) {
                        is_rsp_to_get = true;
                    }

                } else {
                    if (dma_read_pending) is_dma_read_to_resume = true;
                    else if (dma_write_pending) is_dma_write_to_resume = true;
                }

            } else if (rst_stall) {
                // Pending reset
                is_rst_to_resume = true;

            } else if (flush_stall) {
                // Pending flush
                is_flush_to_resume = true;

            } else if (can_get_rst_tb && !dma_read_pending && !dma_write_pending) {
                // Reset or flush
                is_rst_to_get = true;

            } else if (can_get_req_in || evict_stall || set_conflict) {
                if (evict_stall) {
                    req_in = llc_req_stall;
                } else if (set_conflict) {
                    req_in = llc_req_conflict;
                } else {
                    do_get_req = true;
                }
                is_req_to_get = true;

            } else if (dma_read_pending) {
                // Pending DMA read

                is_dma_read_to_resume = true;

            } else if (dma_write_pending) {
                // Pending DMA write

                if (can_get_dma_in) {
                    is_dma_write_to_resume = true;
                    do_get_dma_req = true;
                }

            } else if (can_get_dma_in) {
                // New DMA request
                is_dma_req_to_get = true;
                do_get_dma_req = true;
            }

            if (is_rsp_to_get) {
                llc_rsp_in.nb_get(rsp_in);
            }

            if (is_rst_to_get) {
                llc_rst_tb.nb_get(rst_in);
            }

            if (do_get_req) {
                llc_req_in.nb_get(req_in);
            }

            if (do_get_dma_req) {
                llc_dma_req_in.nb_get(dma_req_in);
            }

        }

#ifdef LLC_DEBUG
        dbg_is_rsp_to_get.write(is_rsp_to_get);
        dbg_is_req_to_get.write(is_req_to_get);

        for (int i = 0; i < LLC_N_REQS; i++)
        {
            HLS_UNROLL_LOOP(ON);

            reqs_dbg[i] = reqs[i];
        }
        dbg_evict_stall = evict_stall;
        dbg_evict_inprogress = evict_inprogress;
        dbg_set_conflict = set_conflict;
        dbg_is_dma_read_to_resume.write(is_dma_read_to_resume);
        dbg_is_dma_write_to_resume.write(is_dma_write_to_resume);
        dbg_is_dma_req_to_get.write(is_dma_req_to_get);
        dbg_dma_done.write(dma_done);
        dbg_recall_addr.write(recall_addr);
        dbg_recall_pending.write(recall_pending);
        dbg_recall_valid.write(recall_valid);
        dbg_dma_read_pending.write(dma_read_pending);
        dbg_dma_write_pending.write(dma_write_pending);

        dbg_llc_req_conflict = llc_req_conflict;
        dbg_llc_req_stall = llc_req_stall;
#endif

        // -----------------------------
        // Lookup cache
        // -----------------------------
        look = is_flush_to_resume || is_rsp_to_get || is_req_to_get || is_dma_req_to_get || (is_dma_read_to_resume && !recall_pending) || (is_dma_write_to_resume && !recall_pending);

        // Pick right set

        if (is_flush_to_resume){
            set = rst_flush_stalled_set;
            rst_flush_stalled_set++;
            if (rst_flush_stalled_set == 0) {
                rst_stall = false;
                flush_stall = false;
            }

        } else if (is_rst_to_resume) {
            set = rst_flush_stalled_set;
            // Update current set
            rst_flush_stalled_set++;
            if (rst_flush_stalled_set == 0) {
                rst_stall = false;
                flush_stall = false;
            }
        } else if (is_rsp_to_get) {
            line_br.llc_line_breakdown(rsp_in.addr);
            set = line_br.set;

        } else if (is_req_to_get) {
            line_br.llc_line_breakdown(req_in.addr);
            set = line_br.set;
        } else if (is_dma_req_to_get || is_dma_read_to_resume || is_dma_write_to_resume) {
            if (is_dma_req_to_get) dma_addr = dma_req_in.addr;

            line_br.llc_line_breakdown(dma_addr);
            set = line_br.set;
        }

        // Compute llc_address based on set
        base = set << LLC_WAY_BITS;
#ifdef LLC_DEBUG
        dbg_llc_addr.write(llc_addr);
#endif
        // Read all ways from set into buffer
        if (look) {

            HLS_DEFINE_PROTOCOL("read-cache");

            wait();
            read_set(base, 0);
            evict_ways_buf = evict_ways.port2[0][set];
#if LLC_WAYS == 32
            wait();
            read_set(base, 1);
#endif

#ifdef LLC_DEBUG
            dbg_evict_ways_buf = evict_ways_buf;
#endif
        }


        // Select select way and determine potential eviction
        lookup(line_br.tag, way, evict);

        // Compute llc_address based on selected way
        llc_addr = base + way;
        // Compute memory address to use in case of eviction
        addr_evict = (tags_buf[way] << LLC_SET_BITS) + set;
        addr_evict_real = addr_evict << OFFSET_BITS;

        // -----------------------------
        // Process current request
        // -----------------------------
        // handle reset flush
        if (is_flush_to_resume) {
            // partial flush (only VALID DATA lines)
            for (int way = 0; way < LLC_WAYS; way++) {
                line_addr_t line_addr = (tags_buf[way] << LLC_SET_BITS) | (set);

                if (states_buf[way] == LLC_V && hprots_buf[way] == DATA) {
                    HLS_DEFINE_PROTOCOL("is_flush_to_resume");
                    if (dirty_bits_buf[way]) {
                        send_mem_req(WRITE, line_addr, hprots_buf[way], lines_buf[way]);
                    }

                    wait();

                    llc_addr_t llc_addr = base + way;

                    states.port1[0][llc_addr]     = LLC_I;
                    sharers.port1[0][llc_addr]    = 0;
                    dirty_bits.port1[0][llc_addr] = 0;
                    owners.port1[0][llc_addr]     = 0;
                } else {
                    wait();
                }
            }
        }
        else if (is_rst_to_get) {

            if (!rst_in) {
                // reset
                HLS_DEFINE_PROTOCOL("is_reset");
                this->reset_state();

            } else {
                // flush
                flush_stall = true;
                rst_flush_stalled_set = 0;
            }
        }
        else if (is_rsp_to_get) {

            // @TODO handle responses
            addr_breakdown_llc_t addr_br_real;
            sc_uint<LLC_REQS_BITS> reqs_hit_i;
            addr_br_real.breakdown(rsp_in.addr << OFFSET_BITS);
            reqs_lookup(addr_br_real, reqs_hit_i);
            switch (rsp_in.coh_msg) {
                case RSP_INV_ACK_SPDX:
                {
                    reqs[reqs_hit_i].invack_cnt--;
                    sharers_buf[reqs[reqs_hit_i].way] &= ~(1 << rsp_in.req_id); // clears sharer bit

                    if (reqs[reqs_hit_i].invack_cnt == 0) {
                        switch (reqs[reqs_hit_i].state) {
                            case LLC_SO:
                            {
                                if (reqs[reqs_hit_i].msg == REQ_O) {
                                    HLS_DEFINE_PROTOCOL("send-rsp-800");
                                    send_rsp_out(RSP_O, rsp_in.addr, 0, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                }
                                else {
                                    HLS_DEFINE_PROTOCOL("send-rsp-804");
                                    send_rsp_out(RSP_Odata, rsp_in.addr, reqs[reqs_hit_i].line, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                }
                                states_buf[reqs[reqs_hit_i].way] = LLC_V;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                            }
                            break;
                            case LLC_SV:
                            {
                                if (reqs[reqs_hit_i].msg == REQ_WT || reqs[reqs_hit_i].msg == REQ_WTfwd) {
                                    HLS_DEFINE_PROTOCOL("send-rsp-813");
                                    send_rsp_out(RSP_O, rsp_in.addr, 0, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                }
                                else if (reqs[reqs_hit_i].is_amo) {
                                    HLS_DEFINE_PROTOCOL("send-rsp-817");
                                    calc_amo(lines_buf[reqs[reqs_hit_i].way], reqs[reqs_hit_i].line, req_in.coh_msg, req_in.word_mask);
                                    send_rsp_out(RSP_WTdata, rsp_in.addr, reqs[reqs_hit_i].line, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                } else {
                                    // nothing
                                }
                                lines_buf[reqs[reqs_hit_i].way] = reqs[reqs_hit_i].line;
                                states_buf[reqs[reqs_hit_i].way] = LLC_V;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                if (recall_pending && rsp_in.addr == recall_addr) recall_valid = true;
#ifdef LLC_DEBUG
                                dbg_recall_valid.write(recall_valid);
#endif
                            }
                            break;
                            case LLC_SWB:
                            {
                                HLS_DEFINE_PROTOCOL("send-mem-821");
                                send_mem_req(WRITE, rsp_in.addr, reqs[reqs_hit_i].hprot, reqs[reqs_hit_i].line);
                                states_buf[reqs[reqs_hit_i].way] = LLC_I;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                evict_inprogress = false;
                            }
                            break;
                            case LLC_SI:
                            {
                                states_buf[reqs[reqs_hit_i].way] = LLC_I;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                evict_inprogress = false;
                            }
                            break;
                            default:
                            {
                                // nothing
                            }
                            break;
                        }

                    }
                }
                break;

                case RSP_RVK_O:
                {
                    for (int i = 0; i < WORDS_PER_LINE; i++) {
                        HLS_UNROLL_LOOP(ON, "rvk-wb");
                        if (owners_buf[reqs[reqs_hit_i].way] & (1 << i) & rsp_in.word_mask) {
                            // // found a matching bit in mask
                            // if (rsp_in.req_id.to_int() == lines_buf[reqs[reqs_hit_i].way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD).to_int()) // if owner id == req id
                            // {
                                lines_buf[reqs[reqs_hit_i].way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = rsp_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD); // write back new data
                                owners_buf[reqs[reqs_hit_i].way] = owners_buf[reqs[reqs_hit_i].way] & (~ (1 << i)); // clear owner bit
                                dirty_bits_buf[reqs[reqs_hit_i].way] = 1;
                                sharers_buf[reqs[reqs_hit_i].way] |= 1 << rsp_in.req_id;
                            // }
                        }
                    }
                    switch (reqs[reqs_hit_i].state) {
                        case LLC_OS:
                        {
                            if (owners_buf[reqs[reqs_hit_i].way] == 0)
                            {
                                // change state
                                states_buf[reqs[reqs_hit_i].way] = LLC_S;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                sharers_buf[reqs[reqs_hit_i].way] |= 1 << reqs[reqs_hit_i].req_id;
                            }
                        }
                        break;
                        case LLC_OV:
                        {
                            if (owners_buf[reqs[reqs_hit_i].way] == 0)
                            {
                                if (reqs[reqs_hit_i].msg == REQ_WT) {
                                    HLS_DEFINE_PROTOCOL("send-rsp-813");
                                    send_rsp_out(RSP_O, rsp_in.addr, 0, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                }
                                else if (reqs[reqs_hit_i].is_amo) {
                                    HLS_DEFINE_PROTOCOL("send-rsp-817");
                                    calc_amo(lines_buf[reqs[reqs_hit_i].way], reqs[reqs_hit_i].line, req_in.coh_msg, req_in.word_mask);
                                    send_rsp_out(RSP_WTdata, rsp_in.addr, reqs[reqs_hit_i].line, reqs[reqs_hit_i].req_id, reqs[reqs_hit_i].req_id, 0, 0, reqs[reqs_hit_i].word_mask);
                                } else {
                                    // nothing
                                }
                                states_buf[reqs[reqs_hit_i].way] = LLC_V;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                if (recall_pending && rsp_in.addr == recall_addr) recall_valid = true;
#ifdef LLC_DEBUG
                                dbg_recall_valid.write(recall_valid);
#endif
                            }
                        
                        }
                        break;
                        case LLC_OWB:
                        {
                            if (owners_buf[reqs[reqs_hit_i].way] == 0)
                            {
                                // wb and goto I
                                {
                                    HLS_DEFINE_PROTOCOL("send-mem-875");
                                    send_mem_req(WRITE, rsp_in.addr, reqs[reqs_hit_i].hprot, lines_buf[reqs[reqs_hit_i].way]);
                                }
                                states_buf[reqs[reqs_hit_i].way] = LLC_I;
                                reqs[reqs_hit_i].state = LLC_I;
                                reqs_cnt++;
                                evict_inprogress = false;
                            }
                        }
                        break;
                        default:
                        {
                            // nothing
                        }
                        break;
                    }

                }
                break;
                default:
                break;
            }
        }


        // Process new request
        else if (is_req_to_get) {

            addr_breakdown_llc_t addr_br_real;
            sc_uint<LLC_REQS_BITS> reqs_hit_i, reqs_empty_i;
            addr_breakdown_llc_t evict_addr_br;
            evict_addr_br.breakdown(addr_evict_real);
            addr_br_real.breakdown(req_in.addr << OFFSET_BITS);
            set_conflict = reqs_peek_req(evict_addr_br, reqs_hit_i) || reqs_peek_req(addr_br_real, reqs_empty_i) || (reqs_cnt == 0);
            reqs_lookup(addr_br_real, reqs_hit_i);
            evict_stall = evict_inprogress;

            if (evict_stall || set_conflict) // optimize
            {
                // attempt to resolve requests that hit in transient state
                switch (req_in.coh_msg) {
                case REQ_S:
                {
                    // if (sharers_buf[reqs[reqs_hit_i].way] & (1 << req_in.req_id)) { // only allow relaxed rsp_s if private cache has a pending inv
                    //         switch (reqs[reqs_hit_i].state) {
                    //                 case LLC_SI: // to solve reqs vs inv deadlock on LLC_SX due to silent ecivtion
                    //                 {
                    //                         HLS_DEFINE_PROTOCOL("deadlock-solver-1");
                    //                         send_rsp_out(RSP_S, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                    //                         send_fwd_out(FWD_INV_SPDX, req_in.addr, 0, req_in.req_id, WORD_MASK_ALL);
                    //                         reqs[reqs_hit_i].invack_cnt++;
                    //                         evict_stall = false;
                    //                 }
                    //                 break;
                    //                 case LLC_SO: // to solve reqs vs inv deadlock on LLC_SX due to silent ecivtion
                    //                 {
                    //                         HLS_DEFINE_PROTOCOL("deadlock-solver-2");
                    //                         send_rsp_out(RSP_S, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                    //                         send_fwd_out(FWD_INV_SPDX, req_in.addr, 0, req_in.req_id, WORD_MASK_ALL);
                    //                         reqs[reqs_hit_i].invack_cnt++;
                    //                         set_conflict = false;
                    //                 }
                    //                 break;
                    //                 default:
                    //                 break;
                    //         }
                    // }
                }
                break;
                default:
                break;
                }
                // failed to resolve request
                if (set_conflict) llc_req_conflict = req_in;
                if (evict_stall) llc_req_stall = req_in;
            } else {

                if (evict) {
                    LLC_EVICT;

                    fcs_prio_buf[way] = 0;

                    if (way == evict_ways_buf) {
                        update_evict_ways = true;
                        evict_ways_buf++;
                    }

                    switch (states_buf[way])
                    {
                        // here we made sure that this set is all in stable state
                        // because any request conflict in unstable buffer has been blocked by set_conflict
                        case LLC_V:
                        {
                            if (owners_buf[way] == 0)
                            {
                                if (dirty_bits_buf[way])
                                {
                                    HLS_DEFINE_PROTOCOL("send_mem_req-2");
                                    send_mem_req(WRITE, addr_evict, hprots_buf[way], lines_buf[way]);
                                }
                                states_buf[way] = LLC_I;
                            }
                            else
                            {
                                (void)send_fwd_with_owner_mask(FWD_RVK_O, addr_evict, req_in.req_id, owners_buf[way], lines_buf[way]);
                                fill_reqs(FWD_RVK_O, req_in.req_id, evict_addr_br, 0, way, LLC_OWB, hprots_buf[way], 0, lines_buf[way], owners_buf[way], reqs_empty_i); // save this request in reqs buffer
                                evict_stall = true;
                                evict_inprogress = true;
                            }
                        }
                        break;
                        case LLC_S:
                        {
                            int cnt = send_inv_with_sharer_list(addr_evict, sharers_buf[way]);
                            if (dirty_bits_buf[way])
                                fill_reqs(FWD_INV_SPDX, req_in.req_id, evict_addr_br, 0, way, LLC_SWB, hprots_buf[way], 0, lines_buf[way], owners_buf[way], reqs_empty_i); // save this request in reqs buffer
                            else
                                fill_reqs(FWD_INV_SPDX, req_in.req_id, evict_addr_br, 0, way, LLC_SI, hprots_buf[way], 0, lines_buf[way], owners_buf[way], reqs_empty_i); // save this request in reqs buffer
                            reqs[reqs_empty_i].invack_cnt = cnt;
                            evict_stall = true;
                            evict_inprogress = true;
                        }
                        break;
                        default:
                        break;
                    }
                }
                // set pending eviction and skip request
                if (evict_stall)
                {
                    llc_req_stall = req_in;
                } else if (is_amo(req_in.coh_msg)) {
                    // if in owned state
                    dirty_bits_buf[way] = 1;
                    switch (states_buf[way])
                    {
                        case LLC_I:
                        {
                            // if in invalid, read out data and perform amo
                            HLS_DEFINE_PROTOCOL("send_mem_req-948");
                            send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                            get_mem_rsp(lines_buf[way]);
                            calc_amo(lines_buf[way], req_in.line, req_in.coh_msg, req_in.word_mask);
                            send_rsp_out(RSP_WTdata, req_in.addr, req_in.line, req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask); // send old data out
                            hprots_buf[way]     = req_in.hprot;
                            tags_buf[way]       = line_br.tag;
                            dirty_bits_buf[way] = 0;
                            states_buf[way]     = LLC_V;
                        }
                        break;
                        case LLC_V:
                        {
                            // if amo is on not owned word, we are lucky
                            if ((owners_buf[way] & req_in.word_mask) == 0)
                            {
                                calc_amo(lines_buf[way], req_in.line, req_in.coh_msg, req_in.word_mask);
                                send_rsp_out(RSP_WTdata, req_in.addr, req_in.line, req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask); // send old data out
                            } else {
                                // send rvko
                                // @TODO this might need thinking
                                send_fwd_with_owner_mask(FWD_RVK_O, req_in.addr, req_in.req_id, req_in.word_mask, 0);
                                fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_OV, hprots_buf[way], 0, req_in.line, owners_buf[way], reqs_empty_i); // save this request in reqs buffer
                                reqs[reqs_empty_i].is_amo = true;
                            }
                        }
                        break;
                        case LLC_S:
                        {
                            int cnt = send_inv_with_sharer_list(req_in.addr, sharers_buf[way]);
                            fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_SV, req_in.hprot, 0, req_in.line, req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                            reqs[reqs_empty_i].invack_cnt = cnt;
                            reqs[reqs_empty_i].is_amo = true;
                        }
                        break;

                        default:
                        break;
                    }
                } else {

                    switch (req_in.coh_msg) {

                        case REQ_V:

                        // LLC_REQV;
                        switch (states_buf[way]) {
                            case LLC_I:
                            {
                                HLS_DEFINE_PROTOCOL("send_mem_req-948");
                                send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                get_mem_rsp(lines_buf[way]);
                                send_rsp_out(RSP_V, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 0;
                                states_buf[way]     = LLC_V;
                                owners_buf[way]     = 0;
                            }
                            break;
                            case LLC_V:
                            {
                                        // REQV_IV;

                                    word_owner_mask = owners_buf[way] & req_in.word_mask;
                                    word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                    if (word_owner_mask) {
                                        // if owner exist
                                        send_fwd_with_owner_mask(FWD_REQ_V, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way]);
                                    }
                                    
                                    if (word_no_owner_mask) {
                                        // if left over words exist
                                        HLS_DEFINE_PROTOCOL("send_rsp_974");
                                        send_rsp_out(RSP_V, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                    }
                                }
                            break;
                            case LLC_S:
                            {
                                // REQV_S;
                                HLS_DEFINE_PROTOCOL("send_rsp_982");
                                send_rsp_out(RSP_V, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                            }
                            break;
                            default:
                                GENERIC_ASSERT;
                        }

                        break;

                        case REQ_S :
                        // LLC_REQS;

                        switch (states_buf[way]) {

                            case LLC_I :
                            {
                                // REQS_IV;
                                HLS_DEFINE_PROTOCOL("send_mem_req_1000");
                                send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                get_mem_rsp(lines_buf[way]);
                                send_rsp_out(RSP_S, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 0;
                                states_buf[way]     = LLC_S;
                                sharers_buf[way]    = 1 << req_in.req_id;
                            }
                            break;
                            case LLC_V :
                            {
                                // REQS_IV;

                                word_owner_mask = owners_buf[way] & req_in.word_mask;
                                word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                other_owner = false;
                                if (word_owner_mask) {
                                    other_owner = send_fwd_with_owner_mask(FWD_REQ_S, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way]);
                                    if (other_owner) {
                                        fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_OS, req_in.hprot, 0, lines_buf[way], req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                                    }
                                }
                                // send rsp for those words without owners
                                if (word_no_owner_mask) {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1027");
                                    send_rsp_out(RSP_S, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                    // if other_owner is false, then it means no transient state in reqs, and we can change state and shares here
                                    if(!other_owner){
                                        states_buf[way] = LLC_S;
                                        sharers_buf[way] = 1 << req_in.req_id;
                                    }
                                }

                            }
                            break;

                            case LLC_S :
                            {
                                // REQS_S;
                                HLS_DEFINE_PROTOCOL("send_rsp_1039");
                                send_rsp_out(RSP_S, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                sharers_buf[way] = sharers_buf[way] | (1 << req_in.req_id);
                            }
                            break;

                            default :
                                GENERIC_ASSERT;
                        }

                        break;

                        case REQ_O :

                        // LLC_REQO;

                        switch (states_buf[way]) {

                            case LLC_I :
                            {

                                if (req_in.word_mask != WORD_MASK_ALL) {
                                    HLS_DEFINE_PROTOCOL("send_mem_req_1059");
                                    send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                    get_mem_rsp(lines_buf[way]);
                                }
                                owners_buf[way] = req_in.word_mask;
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                    }
                                }
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 0;
                                states_buf[way] = LLC_V;
                                {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1078");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                }
                            }
                            break;
                            case LLC_V :
                            {
                                // REQO_V;
                                word_owner_mask = owners_buf[way] & req_in.word_mask;
                                word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                if (word_owner_mask) {
                                    send_fwd_with_owner_mask(FWD_REQ_O, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way]);
                                }
                                if (word_no_owner_mask) {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1100");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                }
                                // update owner
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                    }
                                }
                                owners_buf[way] |= req_in.word_mask;

                            }
                            break;

                            case LLC_S :
                            {
                                // assume word_mask > 0
                                // REQO_S;
                                // invalidate
                                int cnt = 0;
                                // special case, cannot call inline helper
                                for (int i = 0; i < MAX_N_L2; i++) {
                                    HLS_DEFINE_PROTOCOL("send_fwd_1116");
                                    if (sharers_buf[way] & (1 << i)) {
                                        if (req_in.req_id == i)
                                        {
                                            // upgrade
                                        }
                                        else
                                        {
                                            send_fwd_out(FWD_INV_SPDX, req_in.addr, req_in.req_id, i, req_in.word_mask);
                                            cnt ++;
                                        }
                                    }
                                    wait();
                                }

                                states_buf[way] = LLC_V;
                                for (int i = 0; i < WORDS_PER_LINE; i++)
                                {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i))
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                }
                                owners_buf[way] = req_in.word_mask;

                                if (cnt == 0) {
                                    // only upgrade
                                    // @TODO send original data
                                    HLS_DEFINE_PROTOCOL("send_rsp_1198");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                }
                                else
                                {
                                    // wait for invack
                                    fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_SO, req_in.hprot, 0, lines_buf[way], req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                                    reqs[reqs_empty_i].invack_cnt = cnt;
                                }
                            }
                            break;

                            default :
                                GENERIC_ASSERT;
                        }

                        break;

                        case REQ_WT :

                        // LLC_REQWT;

                        switch (states_buf[way]) {

                            case LLC_I :
                            {
                                {
                                    HLS_DEFINE_PROTOCOL("send_men_1140");
                                    send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                    get_mem_rsp(lines_buf[way]);
                                }

                                // write new data
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask-1151");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                    }
                                }
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 1;
                                states_buf[way] = LLC_V;
                                {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1157");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);

                                }
                            }
                            break;
                            case LLC_V :
                            {
                                word_owner_mask = owners_buf[way] & req_in.word_mask;
                                word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                if (word_owner_mask) {
                                    send_fwd_with_owner_mask(FWD_REQ_O, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way]);
                                }
                                if (word_no_owner_mask) {
                                    HLS_DEFINE_PROTOCOL("req_wt send rsp_o in llc_v");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                }
                                // write new data
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask-1176");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                        owners_buf[way] = owners_buf[way] & (~ (1 << i)); // clear owner bit
                                    }
                                }
                                dirty_bits_buf[way] = 1;
                            }
                            break;
                            case LLC_S :
                            {
                                // REQWT_S;
                                // invalidate
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask-1176");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                    }
                                }
                                int cnt = send_inv_with_sharer_list(req_in.addr, sharers_buf[way]);
                                fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_SV, req_in.hprot, 0, lines_buf[way], req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                                reqs[reqs_empty_i].invack_cnt = cnt;
                                dirty_bits_buf[way] = 1;
                            }
                            break;

                            default :
                                GENERIC_ASSERT;
                        }

                        break;

                        case REQ_WTfwd :

                        fcs_prio_buf[way] = 1;

                        switch (states_buf[way]) {

                            case LLC_I :
                            {
                                {
                                    HLS_DEFINE_PROTOCOL("send_men_req_wtfwd");
                                    send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                    get_mem_rsp(lines_buf[way]);
                                }

                                // write new data
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask-1151");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                    }
                                }
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 1;
                                states_buf[way] = LLC_V;
                                {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1157");
                                    send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);

                                }
                            }
                            break;
                            case LLC_V :
                            {
                                word_owner_mask = owners_buf[way] & req_in.word_mask;
                                word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                if (word_owner_mask) {
                                    send_fwd_with_owner_mask_data(FWD_WTfwd, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way], req_in.line);
                                }
                                if (word_no_owner_mask) {
                                    for (int i = 0; i < WORDS_PER_LINE; i++) {
                                        HLS_UNROLL_LOOP(ON, "set-ownermask-1176");
                                        if (word_no_owner_mask & (1 << i)) {
                                            lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                        }
                                    }
                                    {
                                        HLS_DEFINE_PROTOCOL("req_wtfwd send rsp o when llc_v");
                                        send_rsp_out(RSP_O, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                    }
                                }
                                dirty_bits_buf[way] = 1;
                            }
                            break;
                            case LLC_S :
                            {
                                // REQWTfwd_S;
                                // invalidate
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask-1176");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD);
                                    }
                                }
                                int cnt = send_inv_with_sharer_list(req_in.addr, sharers_buf[way]);
                                fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_SV, req_in.hprot, 0, lines_buf[way], req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                                reqs[reqs_empty_i].invack_cnt = cnt;
                                dirty_bits_buf[way] = 1;
                            }
                            break;

                            default :
                                GENERIC_ASSERT;
                        }

                        break;

                        case REQ_Odata :

                        // Read with ReqOdata
                        if (req_in.hprot == INSTR)
                        {
                            fcs_prio_buf[way] = 1;
                        }

                        // LLC_REQO;

                        switch (states_buf[way]) {

                            case LLC_I :
                            {
                                {
                                    HLS_DEFINE_PROTOCOL("send_men_1219");
                                    send_mem_req(READ, req_in.addr, req_in.hprot, 0);
                                    get_mem_rsp(lines_buf[way]);
                                }
                                {
                                    HLS_DEFINE_PROTOCOL("send_rsp_1238");
                                    send_rsp_out(RSP_Odata, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                }
                                owners_buf[way] = req_in.word_mask;
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                    }
                                }
                                hprots_buf[way]     = req_in.hprot;
                                tags_buf[way]       = line_br.tag;
                                dirty_bits_buf[way] = 0;
                                states_buf[way] = LLC_V;
                            }
                            break;
                            case LLC_V :
                            {
                                // REQO_V;
                                word_owner_mask = owners_buf[way] & req_in.word_mask;
                                word_no_owner_mask = req_in.word_mask & ~owners_buf[way];
                                if (word_owner_mask) {
                                    send_fwd_with_owner_mask(FWD_REQ_Odata, req_in.addr, req_in.req_id, word_owner_mask, lines_buf[way]);
                                }
                                if (word_no_owner_mask){
                                    HLS_DEFINE_PROTOCOL("send_rsp_1249");
                                    send_rsp_out(RSP_Odata, req_in.addr, lines_buf[way], req_in.req_id, req_in.req_id, 0, 0, word_no_owner_mask);
                                }
                                // update owner
                                for (int i = 0; i < WORDS_PER_LINE; i++) {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i)) {
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                    }
                                }
                                owners_buf[way] |= req_in.word_mask;
                            }
                            break;

                            case LLC_S :
                            {
                                // REQOdata_S;
                                // invalidate
                                int cnt = 0;
                                line_t temp = lines_buf[way];
                                // @TODO optimize
                                // special case, cannot call inline helper
                                for (int i = 0; i < MAX_N_L2; i++) {
                                    HLS_DEFINE_PROTOCOL("send_fwd_1116");
                                    if (sharers_buf[way] & (1 << i)) {
                                        if (req_in.req_id == i)
                                        {
                                            // upgrade
                                            sharers_buf[way] &= ~(1 << i);
                                        }
                                        else
                                        {
                                            send_fwd_out(FWD_INV_SPDX, req_in.addr, req_in.req_id, i, req_in.word_mask);
                                            cnt ++;
                                        }
                                    }
                                    wait();
                                }

                                states_buf[way] = LLC_V;
                                for (int i = 0; i < WORDS_PER_LINE; i++)
                                {
                                    HLS_UNROLL_LOOP(ON, "set-ownermask");
                                    if (req_in.word_mask & (1 << i))
                                        lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD) = req_in.req_id;
                                }
                                owners_buf[way] = req_in.word_mask;

                                if (cnt == 0) {
                                    // only upgrade
                                    HLS_DEFINE_PROTOCOL("send_rsp_1198");
                                    send_rsp_out(RSP_Odata, req_in.addr, temp, req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);
                                }
                                else
                                {
                                    // wait for invack
                                    fill_reqs(req_in.coh_msg, req_in.req_id, addr_br_real, 0, way, LLC_SO, req_in.hprot, 0, temp, req_in.word_mask, reqs_empty_i); // save this request in reqs buffer
                                    reqs[reqs_empty_i].invack_cnt = cnt;
                                }
                            }
                            break;

                            default :
                                GENERIC_ASSERT;
                        }
                        break;

                    
                        case REQ_WB :
                        word_owner_mask = owners_buf[way] & req_in.word_mask;
                        // send response
                        {
                            HLS_DEFINE_PROTOCOL("send_rsp_1330");
                            send_rsp_out(RSP_WB_ACK, req_in.addr, 0, req_in.req_id, req_in.req_id, 0, 0, req_in.word_mask);

                        }
                        if (word_owner_mask == 0) break; // in stable states, no owner, no need to do anything
                        for (int i = 0; i < WORDS_PER_LINE; i++) {
                            HLS_UNROLL_LOOP(ON, "check-wb-ownermask");
                            if (word_owner_mask & (1 << i)) {
                                // found a mathcing bit in mask
                                if (req_in.req_id == lines_buf[way].range(CACHE_ID_WIDTH - 1 + i * BITS_PER_WORD, i * BITS_PER_WORD)) // if owner id == req id
                                {
                                    lines_buf[way].range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD) = req_in.line.range((i + 1) * BITS_PER_WORD - 1, i * BITS_PER_WORD); // write back new data
                                    owners_buf[way] = owners_buf[way] & (~ (1 << i)); // clear owner bit
                                    dirty_bits_buf[way] = 1;
                                }
                            }
                        }
                        break;

                        default :
                        GENERIC_ASSERT;
                    }
                }
            }
        }

        else if (is_dma_req_to_get || is_dma_read_to_resume || is_dma_write_to_resume) {

            bool evict_dirty = false;

            if (is_dma_req_to_get) {
                DMA_BURST;

                if (dma_req_in.coh_msg == REQ_DMA_READ_BURST) {
                    dma_read_pending = true;
                    is_dma_read_to_resume = true;
                } else {
                    dma_write_pending = true;
                    is_dma_write_to_resume = true;
                }

                dma_read_length = dma_req_in.line.range(BITS_PER_LINE - 1, BITS_PER_LINE - ADDR_BITS).to_uint();
                dma_length = 0;
                dma_done = false;
                dma_start = true;

            }

            addr_breakdown_llc_t evict_addr_br;
            evict_addr_br.breakdown(addr_evict_real);
            sc_uint<LLC_REQS_BITS> reqs_empty_i;

#ifdef LLC_DEBUG
            dbg_is_dma_read_to_resume.write(is_dma_read_to_resume);
            dbg_is_dma_write_to_resume.write(is_dma_write_to_resume);
            dbg_is_dma_req_to_get.write(is_dma_req_to_get);
            dbg_dma_done.write(dma_done);
            dbg_recall_addr.write(recall_addr);
            dbg_recall_pending.write(recall_pending);
            dbg_recall_valid.write(recall_valid);
#endif

            if (reqs_cnt == 0 || reqs_peek_req(evict_addr_br, reqs_empty_i))
            {
                // nothing
            }
            else
            {
                if (!recall_valid && !recall_pending) {
#ifdef LLC_DEBUG
                    dbg_evict_addr.write(addr_evict);
#endif
                // Recall (may or may not evict depending on miss/hit)
                    if (states_buf[way] == LLC_V && owners_buf[way] != 0)
                    {
                        send_fwd_with_owner_mask(FWD_RVK_O, addr_evict, dma_req_in.req_id, owners_buf[way], 0);
                        fill_reqs(req_in.coh_msg, req_in.req_id, evict_addr_br, 0, way, LLC_OV, hprots_buf[way], 0, req_in.line, owners_buf[way], reqs_empty_i);
                        recall_addr = addr_evict;
                        recall_pending = true;
#ifdef LLC_DEBUG
                        dbg_recall_pending.write(recall_pending);
#endif
                    }
                    else if (states_buf[way] == LLC_S && dma_req_in.coh_msg == REQ_DMA_WRITE_BURST) {
                        int cnt = send_inv_with_sharer_list(addr_evict, sharers_buf[way]);
                        fill_reqs(req_in.coh_msg, req_in.req_id, evict_addr_br, 0, way, LLC_SV, hprots_buf[way], 0, req_in.line, owners_buf[way], reqs_empty_i);
                        reqs[reqs_empty_i].invack_cnt = cnt;
                        recall_addr = addr_evict;
                        recall_pending = true;
#ifdef LLC_DEBUG
                        dbg_recall_pending.write(recall_pending);
#endif
                    }

                }

                if (!recall_pending || recall_valid) {

                    if (dirty_bits_buf[way]) evict_dirty = true;

                    // if (evict || recall_valid) {
                    //         owners_buf[way] = 0;
                    //         sharers_buf[way] = 0;
                    // }

                    if (evict) {
                        // Eviction

                        LLC_EVICT;

                        if (way == evict_ways_buf) {
                            update_evict_ways = true;
                            evict_ways_buf++;
                        }

                        if (evict_dirty) {
                            HLS_DEFINE_PROTOCOL("send_mem_req-6");
                            send_mem_req(WRITE, addr_evict, hprots_buf[way], lines_buf[way]);
                        }

                        states_buf[way] = LLC_I;

                    } else if (recall_valid) {
                        // states_buf[way] = LLC_V;
                    }

                    // Recall complete
                    recall_pending = false;
                    recall_valid = false;

                    if (is_dma_read_to_resume) {
                        LLC_DMA_READ_BURST;

                        dma_length_t valid_words;
                        word_offset_t dma_read_woffset;
                        invack_cnt_t dma_info;

                        if (dma_start)
                            dma_read_woffset = dma_req_in.word_offset;
                        else
                            dma_read_woffset = 0;

                        dma_length += WORDS_PER_LINE - dma_read_woffset;

                        if (dma_length >= dma_read_length)
                            dma_done = true;

                        if (dma_start & dma_done)
                            valid_words = dma_read_length;
                        else if (dma_start)
                            valid_words = dma_length;
                        else if (dma_length > dma_read_length)
                            valid_words = WORDS_PER_LINE - (dma_length - dma_read_length);
                        else
                            valid_words = WORDS_PER_LINE;

                        if (states_buf[way] == LLC_I) {

                            DMA_READ_I;
                            HLS_DEFINE_PROTOCOL("send_mem_req-7");
                            send_mem_req(READ, dma_addr, dma_req_in.hprot, 0);
                            get_mem_rsp(lines_buf[way]);
                        }

                        dma_info[0] = dma_done;
                        dma_info.range(WORD_BITS, 1) = (valid_words - 1);

                        {
                            HLS_DEFINE_PROTOCOL("send_dma_rsp_out");
                            send_dma_rsp_out(RSP_DATA_DMA, dma_addr, lines_buf[way],
                                    dma_req_in.req_id, 0, dma_info, dma_read_woffset);
                        }

                        if (states_buf[way] == LLC_I) {
                            hprots_buf[way]     = DATA;
                            tags_buf[way]       = line_br.tag;
                            states_buf[way]     = LLC_V;
                            dirty_bits_buf[way] = 0;
                        }

                    } else { // is_dma_write_to_resume
                        LLC_DMA_WRITE_BURST;

                        word_offset_t dma_write_woffset = dma_req_in.word_offset;
                        dma_length_t valid_words = dma_req_in.valid_words + 1;
                        bool misaligned;

                        misaligned = (dma_write_woffset != 0 || valid_words != WORDS_PER_LINE);

                        if (states_buf[way] == LLC_I) {

                            DMA_WRITE_I;

                            if (misaligned) {
                                HLS_DEFINE_PROTOCOL("send_mem_req-8");
                                send_mem_req(READ, dma_addr, dma_req_in.hprot, 0);
                                get_mem_rsp(lines_buf[way]);
                            }

                        }

                        if (misaligned) {
                            int word_cnt = 0;

                            for (int i = 0; i < WORDS_PER_LINE; i++) {

                                HLS_UNROLL_LOOP(ON, "misaligned-dma-start-unroll");

                                if (word_cnt < valid_words && i >= dma_write_woffset) {
                                    write_word(lines_buf[way], read_word(dma_req_in.line, i), i, 0, WORD);
                                    word_cnt++;
                                }

                            }

                        } else {

                            lines_buf[way] = dma_req_in.line;

                        }

                        lines_buf[way] = lines_buf[way];
                        dirty_bits_buf[way] = 1;

                        if (states_buf[way] == LLC_I) {
                            states_buf[way] = LLC_V;
                            hprots_buf[way] = DATA;
                            tags_buf[way] = line_br.tag;
                        }

                        if (dma_req_in.hprot) {

                            dma_done = true;

                        }
                    }

    #ifdef LLC_DEBUG
                    dbg_length.write(dma_read_length);
                    dbg_dma_length.write(dma_length);
                    dbg_dma_done.write(dma_done);
                    dbg_dma_addr.write(dma_addr);
    #endif
                    dma_addr++;
                    dma_start   = false;

                    if (dma_done) {
                        dma_read_pending = false;
                        dma_write_pending = false;
                    }
                }
            }
        }

        // Complete reset/flush
        if (is_flush_to_resume || is_rst_to_resume) {
            if (!flush_stall && !rst_stall) {
                HLS_DEFINE_PROTOCOL("rst_flush_done");
                do {wait();}
                while (!llc_rst_tb_done.nb_can_put());
                llc_rst_tb_done.nb_put(1);
            }
        }

        // -----------------------------
        // Update cache
        // -----------------------------

        // update memory
        // Resume reset
        if (is_rst_to_resume) {

            evict_ways.port1[0][set] = 0;

            for (int way = 0; way < LLC_WAYS; way++) { // do not unroll
                const int idx = base + way;

                states.port1[0][idx]     = LLC_I;
                dirty_bits.port1[0][idx] = 0;
                sharers.port1[0][idx]    = 0;

            }
        }
        else if (is_rsp_to_get || is_req_to_get || is_dma_req_to_get || is_dma_read_to_resume || is_dma_write_to_resume) {

            tags.port1[0][llc_addr]       = tags_buf[way];
            states.port1[0][llc_addr]     = states_buf[way];
            lines.port1[0][llc_addr]      = lines_buf[way];
            hprots.port1[0][llc_addr]     = hprots_buf[way];
            owners.port1[0][llc_addr]     = owners_buf[way];
            sharers.port1[0][llc_addr]    = sharers_buf[way];
            dirty_bits.port1[0][llc_addr] = dirty_bits_buf[way];
            fcs_prio.port1[0][llc_addr]   = fcs_prio_buf[way];

            if (update_evict_ways)
                evict_ways.port1[0][set] = evict_ways_buf;

            // Uncomment for additional debug info during behavioral simulation
            // const line_addr_t new_addr_evict = (tags_buf[way] << LLC_SET_BITS) + set;
            // std::cout << std::hex << "*** way: " << way << " set: " <<  set << " addr: " << new_addr_evict << " state: " << states[llc_addr] << " line: " << lines[llc_addr] << std::endl;

        }


        {
            HLS_DEFINE_PROTOCOL("end-of-loop-break-rw-protocol");
            wait();
        }
    }
}
