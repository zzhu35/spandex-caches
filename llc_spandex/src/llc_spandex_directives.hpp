/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

	Modified by Zeran Zhu
	zzhu35@illinois.edu
	
	April 9 2021

*/

#ifndef __LLC_SPANDEX_DIRECTIVES_HPP__
#define __LLC_SPANDEX_DIRECTIVES_HPP__

#define LLC_WAYS_UNROLL (LLC_WAYS/8)

#define LLC_FLATTEN_REGS			\
    HLS_FLATTEN_ARRAY(tags_buf);			\
    HLS_FLATTEN_ARRAY(states_buf);		\
    HLS_FLATTEN_ARRAY(lines_buf);		\
    HLS_FLATTEN_ARRAY(hprots_buf);		\
    HLS_FLATTEN_ARRAY(sharers_buf);		\
    HLS_FLATTEN_ARRAY(owners_buf);		\
    HLS_FLATTEN_ARRAY(dirty_bits_buf);   \
    HLS_FLATTEN_ARRAY(fcs_prio_buf);   \
    HLS_FLATTEN_ARRAY(reqs);            \
    HLS_FLATTEN_ARRAY(fwd_coal_word_mask); \
    HLS_FLATTEN_ARRAY(fwd_coal_temp_dest)

#define LLC_MAP_MEMORY                                                                       \
    HLS_MAP_TO_MEMORY(tags, IMP_MEM_NAME_STRING(llc_spandex, tags, LLC_SETS, LLC_WAYS));             \
    HLS_MAP_TO_MEMORY(states, IMP_MEM_NAME_STRING(llc_spandex, states, LLC_SETS, LLC_WAYS));         \
    HLS_MAP_TO_MEMORY(lines, IMP_MEM_NAME_STRING(llc_spandex, lines, LLC_SETS, LLC_WAYS));           \
    HLS_MAP_TO_MEMORY(hprots, IMP_MEM_NAME_STRING(llc_spandex, hprots, LLC_SETS, LLC_WAYS));         \
    HLS_MAP_TO_MEMORY(owners, IMP_MEM_NAME_STRING(llc_spandex, owners, LLC_SETS, LLC_WAYS));         \
    HLS_MAP_TO_MEMORY(sharers, IMP_MEM_NAME_STRING(llc_spandex, sharers, LLC_SETS, LLC_WAYS));       \
    HLS_MAP_TO_MEMORY(dirty_bits, IMP_MEM_NAME_STRING(llc_spandex, dirty_bits, LLC_SETS, LLC_WAYS)); \
    HLS_MAP_TO_MEMORY(evict_ways, IMP_MEM_NAME_STRING(llc_spandex, evict_ways, LLC_SETS, LLC_WAYS)); \
    HLS_MAP_TO_MEMORY(fcs_prio, IMP_MEM_NAME_STRING(llc_spandex, fcs_prio, LLC_SETS, LLC_WAYS))

#ifdef LLC_DEBUG_TURN_OFF_HERE

#define LLC_RESET_STATES						\
    bookmark_tmp |= BM_LLC_RESET_STATES;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Reset states.")

#define LLC_FLUSH						\
    bookmark_tmp |= BM_LLC_FLUSH;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Flush.")

#define FLUSH_DIRTY_LINE					\
    bookmark_tmp |= BM_FLUSH_DIRTY_LINE;			\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Flush dirty line.")

#define LLC_EVICT						\
    bookmark_tmp |= BM_LLC_EVICT;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict.")

#define RECALL_EM							\
    bookmark_tmp |= BM_RECALL_EM;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Recall EM.")

#define RECALL_S							\
    bookmark_tmp |= BM_RECALL_S;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Recall S.")

#define EVICT_EM							\
    bookmark_tmp |= BM_EVICT_EM;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict EM.")

#define EVICT_S							\
    bookmark_tmp |= BM_EVICT_S;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict S.")

#define EVICT_V							\
    bookmark_tmp |= BM_EVICT_V;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict V.")

#define SEND_MEM_REQ							\
    bookmark_tmp |= BM_LLC_SEND_MEM_REQ;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send mem req.")

#define GET_MEM_RSP							\
    bookmark_tmp |= BM_LLC_GET_MEM_RSP;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get mem rsp.")

#define GET_REQ_IN							\
    bookmark_tmp |= BM_LLC_GET_REQ_IN;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get req in.")

#define GET_DMA_REQ_IN							\
    bookmark_tmp |= BM_LLC_GET_DMA_REQ_IN;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get dma req in.")

#define LLC_GET_RSP_IN							\
    bookmark_tmp |= BM_LLC_GET_RSP_IN;					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get rsp in.")

#define SEND_RSP_OUT							\
    bookmark_tmp |= BM_LLC_SEND_RSP_OUT;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send rsp out.")

#define SEND_DMA_RSP_OUT                                                \
    bookmark_tmp |= BM_LLC_SEND_DMA_RSP_OUT;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send dma rsp out.")

#define SEND_FWD_OUT							\
    bookmark_tmp |= BM_LLC_SEND_FWD_OUT;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send fwd out.")

#define SEND_STATS							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send stats.")

#define LLC_REQS \
    bookmark_tmp |= BM_LLC_REQS

#define LLC_GETM \
    bookmark_tmp |= BM_LLC_GETM

#define LLC_PUTS \
    bookmark_tmp |= BM_LLC_PUTS

#define LLC_PUTM \
    bookmark_tmp |= BM_LLC_PUTM

#define DMA_BURST \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA burst.")

#define LLC_DMA_READ					\
    bookmark_tmp |= BM_LLC_DMA_READ;			\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA read.")

#define LLC_DMA_READ_BURST				\
    bookmark_tmp |= BM_LLC_DMA_READ;			\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA read burst.")

#define LLC_DMA_WRITE						\
    bookmark_tmp |= BM_LLC_DMA_WRITE;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA write.")

#define LLC_DMA_WRITE_BURST					\
    bookmark_tmp |= BM_LLC_DMA_WRITE;				\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA write burst.")

#define GENERIC_ASSERT \
    asserts_tmp |= AS_GENERIC

#define REQS_IV							 \
    bookmark_tmp |= BM_GETS_IV

#define REQS_S							 \
    bookmark_tmp |= BM_GETS_S;					 \
    if (sharers_buf[way] == 0) asserts_tmp |= AS_GETS_S_NOSHARE; \
    if ((sharers_buf[way] & (1 << req_in.req_id)) != 0)		 \
	asserts_tmp |= AS_GETS_S_ALREADYSHARE

#define REQS_O				     \
    bookmark_tmp |= BM_GETS_EM;			\
    if (owner_buf[way] == req_in.req_id)	\
	asserts_tmp |= AS_GETS_EM_ALREADYOWN

#define GETS_SD \
    bookmark_tmp |= BM_GETS_SD; \
    if ((sharers_buf[way] & (1 << req_in.req_id)) != 0)	\
	asserts_tmp |= AS_GETS_SD_ALREADYSHARE

#define GETM_IV \
    bookmark_tmp |= BM_GETM_IV

#define GETM_S \
    bookmark_tmp |= BM_GETM_S

#define GETM_E \
    bookmark_tmp |= BM_GETM_E;		    \
    if (owner_buf[way] == req_in.req_id)  \
	asserts_tmp |= AS_GETM_EM_ALREADYOWN

#define GETM_M \
    bookmark_tmp |= BM_GETM_M;		    \
    if (owner_buf[way] == req_in.req_id)  \
	asserts_tmp |= AS_GETM_EM_ALREADYOWN

#define GETM_SD \
    bookmark_tmp |= BM_GETM_SD

#define PUTS_IVM				\
    bookmark_tmp |= BM_PUTS_IVM

#define PUTS_S \
    bookmark_tmp |= BM_PUTS_S

#define PUTS_E \
    bookmark_tmp |= BM_PUTS_E

#define PUTS_SD \
    bookmark_tmp |= BM_PUTS_SD

#define PUTM_IV					\
    bookmark_tmp |= BM_PUTM_IV

#define PUTM_S \
    bookmark_tmp |= BM_PUTM_S

#define PUTM_EM \
    bookmark_tmp |= BM_PUTM_EM

#define PUTM_SD \
    bookmark_tmp |= BM_PUTM_SD

#define DMA_READ_SD \
    bookmark_tmp |= BM_DMA_READ_SD

#define DMA_READ_I \
    bookmark_tmp |= BM_DMA_READ_I

#define DMA_READ_NOTSD \
    bookmark_tmp |= BM_DMA_READ_NOTSD

#define DMA_WRITE_SD \
    bookmark_tmp |= BM_DMA_WRITE_SD

#define DMA_WRITE_I \
    bookmark_tmp |= BM_DMA_WRITE_I

#define DMA_WRITE_NOTSD \
    bookmark_tmp |= BM_DMA_WRITE_NOTSD

#define PRESERVE_SIGNALS						\
    HLS_PRESERVE_SIGNAL(dbg_is_rst_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_is_rsp_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_is_req_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_tag_hit, true);				\
    HLS_PRESERVE_SIGNAL(dbg_hit_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_empty_way_found, true);			\
    HLS_PRESERVE_SIGNAL(dbg_empty_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_way, true);					\
    HLS_PRESERVE_SIGNAL(dbg_llc_addr, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict_valid, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict_way_not_sd, true);			\
    HLS_PRESERVE_SIGNAL(dbg_evict_addr, true);				\
    HLS_PRESERVE_SIGNAL(dbg_flush_set, true);				\
    HLS_PRESERVE_SIGNAL(dbg_flush_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_tags_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_states_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_hprots_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_lines_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_sharers_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_owners_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_dirty_bits_buf, true);			\
    HLS_PRESERVE_SIGNAL(dbg_evict_ways_buf, true);           \
    HLS_PRESERVE_SIGNAL(reqs_dbg, true); \
    HLS_PRESERVE_SIGNAL(dbg_evict_stall, true); \
    HLS_PRESERVE_SIGNAL(dbg_evict_inprogress, true); \
    HLS_PRESERVE_SIGNAL(dbg_llc_req_conflict, true); \
    HLS_PRESERVE_SIGNAL(dbg_llc_req_stall, true); \
    HLS_PRESERVE_SIGNAL(dbg_set_conflict, true)


#else

#define LLC_RESET_STATES						\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Reset states.")

#define LLC_FLUSH						\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Flush.")

#define FLUSH_DIRTY_LINE					\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Flush dirty line.")

#define LLC_EVICT						\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict.")

#define RECALL_EM							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Recall EM.")

#define RECALL_S							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Recall S.")

#define EVICT_EM							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict EM.")

#define EVICT_S							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict S.")

#define EVICT_V							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Evict V.")

#define SEND_MEM_REQ							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send mem req.")

#define GET_MEM_RSP							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get mem rsp.")

#define GET_REQ_IN							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get req in.")

#define GET_DMA_REQ_IN							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get dma req in.")

#define LLC_GET_RSP_IN							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Get rsp in.")

#define SEND_RSP_OUT							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send rsp out.")

#define SEND_DMA_RSP_OUT							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send dma rsp out.")

#define SEND_FWD_OUT							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send fwd out.")

#define SEND_STATS							\
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "Send stats.")

#define LLC_FILL_REQS							\
    HLS_CONSTRAIN_LATENCY(0, HLS_ACHIEVABLE, "llc-fill-reqs-latency"); \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC Fill reqs.")

#define LLC_PUT_REQS					\
    HLS_CONSTRAIN_LATENCY(0, HLS_ACHIEVABLE, "llc-put-reqs-latency"); \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC Put reqs.")

#define LLC_REQS_LOOKUP							\
    HLS_CONSTRAIN_LATENCY(0, HLS_ACHIEVABLE, "llc-reqs-lookup-latency"); \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC Reqs lookup rsp.")

#define LLC_REQS_LOOKUP_LOOP				\
    HLS_UNROLL_LOOP(ON, "llc-reqs-lookup-loop-unroll")

#define LLC_REQS_PEEK_REQ							\
    HLS_CONSTRAIN_LATENCY(0, HLS_ACHIEVABLE, "llc-reqs-peek-req-latency"); \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC Reqs peek req.")

#define LLC_REQS_PEEK_REQ_LOOP					\
    HLS_UNROLL_LOOP(ON, "llc-reqs-peek-req-loop-unroll")

#define LLC_REQS_PEEK_FWD							\
    HLS_CONSTRAIN_LATENCY(0, HLS_ACHIEVABLE, "llc-reqs-peek-fwd-latency"); \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC Reqs peek fwd.")

#define LLC_REQS_PEEK_FWD_LOOP					\
    HLS_UNROLL_LOOP(ON, "llc-reqs-peek-fwd-loop-unroll")

#define LLC_GETS
#define LLC_GETM
#define LLC_PUTS
#define LLC_PUTM

#define DMA_BURST \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA burst.")

#define LLC_DMA_READ \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA read.")

#define LLC_DMA_READ_BURST \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA read burst.")

#define LLC_DMA_WRITE \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA write.")

#define LLC_DMA_WRITE_BURST \
    if (RPT_RTL) CACHE_REPORT_TIME(sc_time_stamp(), "LLC DMA write burst.")

#define GENERIC_ASSERT

#define GETS_IV

#define GETS_S

#define GETS_EM

#define GETS_SD

#define GETM_IV

#define GETM_S

#define GETM_E

#define GETM_M

#define GETM_SD

#define PUTS_IVM

#define PUTS_S

#define PUTS_E

#define PUTS_SD

#define PUTM_IV

#define PUTM_S

#define PUTM_EM

#define PUTM_SD

#define DMA_READ_SD

#define DMA_READ_I

#define DMA_READ_NOTSD

#define DMA_WRITE_SD

#define DMA_WRITE_I

#define DMA_WRITE_NOTSD

#ifdef LLC_DEBUG

#define PRESERVE_SIGNALS \
    HLS_PRESERVE_SIGNAL(dbg_is_rst_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_is_rsp_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_is_req_to_get, true);			\
    HLS_PRESERVE_SIGNAL(dbg_tag_hit, true);				\
    HLS_PRESERVE_SIGNAL(dbg_hit_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_empty_way_found, true);			\
    HLS_PRESERVE_SIGNAL(dbg_empty_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_way, true);					\
    HLS_PRESERVE_SIGNAL(dbg_llc_addr, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict_valid, true);				\
    HLS_PRESERVE_SIGNAL(dbg_evict_way_not_sd, true);			\
    HLS_PRESERVE_SIGNAL(dbg_evict_addr, true);				\
    HLS_PRESERVE_SIGNAL(dbg_flush_set, true);				\
    HLS_PRESERVE_SIGNAL(dbg_flush_way, true);				\
    HLS_PRESERVE_SIGNAL(dbg_tags_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_states_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_hprots_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_lines_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_sharers_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_owners_buf, true);				\
    HLS_PRESERVE_SIGNAL(dbg_dirty_bits_buf, true);			\
    HLS_PRESERVE_SIGNAL(dbg_evict_ways_buf, true);           \
    HLS_PRESERVE_SIGNAL(reqs_dbg, true); \
    HLS_PRESERVE_SIGNAL(dbg_evict_stall, true); \
    HLS_PRESERVE_SIGNAL(dbg_evict_inprogress, true); \
    HLS_PRESERVE_SIGNAL(dbg_length, true); \
    HLS_PRESERVE_SIGNAL(dbg_dma_length, true); \
    HLS_PRESERVE_SIGNAL(dbg_dma_done, true); \
    HLS_PRESERVE_SIGNAL(dbg_dma_addr, true); \
    HLS_PRESERVE_SIGNAL(dbg_recall_addr, true); \
    HLS_PRESERVE_SIGNAL(dbg_recall_pending, true); \
    HLS_PRESERVE_SIGNAL(dbg_recall_valid, true); \
    HLS_PRESERVE_SIGNAL(dbg_dma_read_pending, true); \
    HLS_PRESERVE_SIGNAL(dbg_dma_write_pending, true); \
    HLS_PRESERVE_SIGNAL(dbg_is_dma_read_to_resume, true); \
    HLS_PRESERVE_SIGNAL(dbg_is_dma_write_to_resume, true); \
    HLS_PRESERVE_SIGNAL(watch_dog, true); \
    HLS_PRESERVE_SIGNAL(dbg_is_dma_req_to_get, true); \
    HLS_PRESERVE_SIGNAL(dbg_llc_req_conflict, true); \
    HLS_PRESERVE_SIGNAL(dbg_llc_req_stall, true); \
    HLS_PRESERVE_SIGNAL(dbg_set_conflict, true)
#else
#define PRESERVE_SIGNALS
#endif

#endif

#endif /* __LLC_DIRECTIVES_HPP_ */
