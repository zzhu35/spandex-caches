`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module llc_interfaces (
    input logic clk,
    input logic rst,
    input logic llc_req_in_valid,
    input logic llc_req_in_ready_int,
    input logic llc_dma_req_in_valid,
    input logic llc_dma_req_in_ready_int,
    input logic llc_rsp_in_valid,
    input logic llc_rsp_in_ready_int,
    input logic llc_mem_rsp_valid,
    input logic llc_mem_rsp_ready_int,
    input logic llc_rst_tb_valid, 
    input logic llc_rst_tb_ready_int,
    input logic llc_rst_tb_i,
    input logic llc_rsp_out_ready,
    input logic llc_rsp_out_valid_int,
    input logic llc_dma_rsp_out_ready,
    input logic llc_dma_rsp_out_valid_int,
    input logic llc_fwd_out_ready,
    input logic llc_fwd_out_valid_int,
    input logic llc_mem_req_ready,
    input logic llc_mem_req_valid_int,
    input logic llc_rst_tb_done_ready, 
    input logic llc_rst_tb_done_valid_int,
    input logic llc_rst_tb_done_o,

    input logic set_req_from_conflict,
    input logic set_req_conflict,

    llc_req_in_t.in llc_req_in_i,
    llc_dma_req_in_t.in llc_dma_req_in_i,
    llc_rsp_in_t.in llc_rsp_in_i,
    llc_mem_rsp_t.in llc_mem_rsp_i,
    llc_rsp_out_t.in llc_rsp_out_o,
    llc_dma_rsp_out_t.in llc_dma_rsp_out_o,
    llc_fwd_out_t.in llc_fwd_out_o,
    llc_mem_req_t.in llc_mem_req_o,

    output logic llc_req_in_ready,
    output logic llc_req_in_valid_int,
    output logic llc_dma_req_in_ready,
    output logic llc_dma_req_in_valid_int,
    output logic llc_rsp_in_ready,
    output logic llc_rsp_in_valid_int,
    output logic llc_mem_rsp_ready,
    output logic llc_mem_rsp_valid_int,
    output logic llc_rst_tb_ready, 
    output logic llc_rst_tb_valid_int,
    output logic llc_rsp_out_valid,
    output logic llc_rsp_out_ready_int,
    output logic llc_dma_rsp_out_valid,
    output logic llc_dma_rsp_out_ready_int,
    output logic llc_fwd_out_valid,
    output logic llc_fwd_out_ready_int,
    output logic llc_mem_req_valid,
    output logic llc_mem_req_ready_int,
    output logic llc_rst_tb_done_valid, 
    output logic llc_rst_tb_done_ready_int,
    output logic llc_rst_tb_done,
    output logic llc_rst_tb, 
    output line_addr_t req_in_addr,
    output line_addr_t rsp_in_addr,

    llc_req_in_t.out llc_req_in,
    llc_rsp_out_t.out llc_rsp_out,
    llc_dma_rsp_out_t.out llc_dma_rsp_out,
    llc_fwd_out_t.out llc_fwd_out,
    llc_mem_req_t.out llc_mem_req,
    llc_dma_req_in_t.out llc_dma_req_in,
    llc_rsp_in_t.out llc_rsp_in,
    llc_mem_rsp_t.out llc_mem_rsp,
    llc_dma_req_in_t.out llc_dma_req_in_next,
    llc_mem_rsp_t.out llc_mem_rsp_next
    );

    //REQ IN
    logic llc_req_in_valid_tmp;
    llc_req_in_t llc_req_in_tmp();
    llc_req_in_t llc_req_in_next();

    interface_controller llc_req_in_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_req_in_ready_int),
        .valid_in(llc_req_in_valid),
        .ready_out(llc_req_in_ready),
        .valid_out(llc_req_in_valid_int),
        .valid_tmp(llc_req_in_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_req_in_tmp.coh_msg <= 0;
            llc_req_in_tmp.hprot <= 0;
            llc_req_in_tmp.addr <= 0;
            llc_req_in_tmp.line <= 0;
            llc_req_in_tmp.req_id <= 0;
            llc_req_in_tmp.word_offset <= 0;
            llc_req_in_tmp.valid_words <= 0;
            llc_req_in_tmp.word_mask <= 0;
        end else if (llc_req_in_valid && llc_req_in_ready && !llc_req_in_ready_int) begin
            llc_req_in_tmp.coh_msg <= llc_req_in_i.coh_msg;
            llc_req_in_tmp.hprot <= llc_req_in_i.hprot;
            llc_req_in_tmp.addr <= llc_req_in_i.addr;
            llc_req_in_tmp.line <= llc_req_in_i.line;
            llc_req_in_tmp.req_id <= llc_req_in_i.req_id;
            llc_req_in_tmp.word_offset <= llc_req_in_i.word_offset;
            llc_req_in_tmp.valid_words <= llc_req_in_i.valid_words;
            llc_req_in_tmp.word_mask <= llc_req_in_i.word_mask;
        end
    end

    assign llc_req_in_next.coh_msg = (!llc_req_in_valid_tmp) ? llc_req_in_i.coh_msg : llc_req_in_tmp.coh_msg;
    assign llc_req_in_next.hprot = (!llc_req_in_valid_tmp) ? llc_req_in_i.hprot : llc_req_in_tmp.hprot;
    assign llc_req_in_next.addr = (!llc_req_in_valid_tmp) ? llc_req_in_i.addr : llc_req_in_tmp.addr;
    assign llc_req_in_next.line = (!llc_req_in_valid_tmp) ? llc_req_in_i.line : llc_req_in_tmp.line;
    assign llc_req_in_next.req_id = (!llc_req_in_valid_tmp) ? llc_req_in_i.req_id : llc_req_in_tmp.req_id;
    assign llc_req_in_next.word_offset = (!llc_req_in_valid_tmp) ? llc_req_in_i.word_offset : llc_req_in_tmp.word_offset;
    assign llc_req_in_next.valid_words = (!llc_req_in_valid_tmp) ? llc_req_in_i.valid_words : llc_req_in_tmp.valid_words;
    assign llc_req_in_next.word_mask = (!llc_req_in_valid_tmp) ? llc_req_in_i.word_mask : llc_req_in_tmp.word_mask;

    //DMA REQ IN
    logic llc_dma_req_in_valid_tmp;
    llc_dma_req_in_t llc_dma_req_in_tmp();

    interface_controller llc_dma_req_in_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_dma_req_in_ready_int),
        .valid_in(llc_dma_req_in_valid),
        .ready_out(llc_dma_req_in_ready),
        .valid_out(llc_dma_req_in_valid_int),
        .valid_tmp(llc_dma_req_in_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_dma_req_in_tmp.coh_msg <= 0;
            llc_dma_req_in_tmp.hprot <= 0;
            llc_dma_req_in_tmp.addr <= 0;
            llc_dma_req_in_tmp.line <= 0;
            llc_dma_req_in_tmp.req_id <= 0;
            llc_dma_req_in_tmp.word_offset <= 0;
            llc_dma_req_in_tmp.valid_words <= 0;
        end else if (llc_dma_req_in_valid && llc_dma_req_in_ready && !llc_dma_req_in_ready_int) begin
            llc_dma_req_in_tmp.coh_msg <= llc_dma_req_in_i.coh_msg;
            llc_dma_req_in_tmp.hprot <= llc_dma_req_in_i.hprot;
            llc_dma_req_in_tmp.addr <= llc_dma_req_in_i.addr;
            llc_dma_req_in_tmp.line <= llc_dma_req_in_i.line;
            llc_dma_req_in_tmp.req_id <= llc_dma_req_in_i.req_id;
            llc_dma_req_in_tmp.word_offset <= llc_dma_req_in_i.word_offset;
            llc_dma_req_in_tmp.valid_words <= llc_dma_req_in_i.valid_words;
        end
    end

    assign llc_dma_req_in_next.coh_msg = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.coh_msg : llc_dma_req_in_tmp.coh_msg;
    assign llc_dma_req_in_next.hprot = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.hprot : llc_dma_req_in_tmp.hprot;
    assign llc_dma_req_in_next.addr = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.addr : llc_dma_req_in_tmp.addr;
    assign llc_dma_req_in_next.line = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.line : llc_dma_req_in_tmp.line;
    assign llc_dma_req_in_next.req_id = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.req_id : llc_dma_req_in_tmp.req_id;
    assign llc_dma_req_in_next.word_offset = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.word_offset : llc_dma_req_in_tmp.word_offset;
    assign llc_dma_req_in_next.valid_words = (!llc_dma_req_in_valid_tmp) ? llc_dma_req_in_i.valid_words : llc_dma_req_in_tmp.valid_words;

    //RSP IN
    logic llc_rsp_in_valid_tmp;
    llc_rsp_in_t llc_rsp_in_tmp();
    llc_rsp_in_t llc_rsp_in_next();

    interface_controller llc_rsp_in_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_rsp_in_ready_int),
        .valid_in(llc_rsp_in_valid),
        .ready_out(llc_rsp_in_ready),
        .valid_out(llc_rsp_in_valid_int),
        .valid_tmp(llc_rsp_in_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_rsp_in_tmp.coh_msg <= 0;
            llc_rsp_in_tmp.addr <= 0;
            llc_rsp_in_tmp.line <= 0;
            llc_rsp_in_tmp.req_id <= 0;
            llc_rsp_in_tmp.word_mask <= 0;
        end else if (llc_rsp_in_valid && llc_rsp_in_ready && !llc_rsp_in_ready_int ) begin
            llc_rsp_in_tmp.coh_msg <= llc_rsp_in_i.coh_msg;
            llc_rsp_in_tmp.addr <= llc_rsp_in_i.addr;
            llc_rsp_in_tmp.line <= llc_rsp_in_i.line;
            llc_rsp_in_tmp.req_id <= llc_rsp_in_i.req_id;
            llc_rsp_in_tmp.word_mask <= llc_rsp_in_i.word_mask;
        end
    end

    assign llc_rsp_in_next.coh_msg = (!llc_rsp_in_valid_tmp) ? llc_rsp_in_i.coh_msg : llc_rsp_in_tmp.coh_msg;
    assign llc_rsp_in_next.addr = (!llc_rsp_in_valid_tmp) ? llc_rsp_in_i.addr : llc_rsp_in_tmp.addr;
    assign llc_rsp_in_next.line = (!llc_rsp_in_valid_tmp) ? llc_rsp_in_i.line : llc_rsp_in_tmp.line;
    assign llc_rsp_in_next.req_id = (!llc_rsp_in_valid_tmp) ? llc_rsp_in_i.req_id : llc_rsp_in_tmp.req_id;
    assign llc_rsp_in_next.word_mask = (!llc_rsp_in_valid_tmp) ? llc_rsp_in_i.word_mask : llc_rsp_in_tmp.word_mask;

    //MEM RSP IN
    logic llc_mem_rsp_valid_tmp;
    llc_mem_rsp_t llc_mem_rsp_tmp();

    interface_controller llc_mem_rsp_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_mem_rsp_ready_int),
        .valid_in(llc_mem_rsp_valid),
        .ready_out(llc_mem_rsp_ready),
        .valid_out(llc_mem_rsp_valid_int),
        .valid_tmp(llc_mem_rsp_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_mem_rsp_tmp.line <= 0;
        end else if (llc_mem_rsp_valid && llc_mem_rsp_ready && !llc_mem_rsp_ready_int) begin
            llc_mem_rsp_tmp.line <= llc_mem_rsp_i.line;
        end
    end

    assign llc_mem_rsp_next.line = (!llc_mem_rsp_valid_tmp) ? llc_mem_rsp_i.line : llc_mem_rsp_tmp.line;

    //RST TB IN 
    logic llc_rst_tb_tmp; 
    logic llc_rst_tb_next; 
    logic llc_rst_tb_valid_tmp; 

    interface_controller llc_rst_tb_intf(
        .clk(clk), 
        .rst(rst), 
        .ready_in(llc_rst_tb_ready_int), 
        .valid_in(llc_rst_tb_valid), 
        .ready_out(llc_rst_tb_ready), 
        .valid_out(llc_rst_tb_valid_int), 
        .valid_tmp(llc_rst_tb_valid_tmp)
    ); 
   
    always_ff @(posedge clk or negedge rst) begin 
        if(!rst) begin 
            llc_rst_tb_tmp <= 0; 
        end else if (llc_rst_tb_valid && llc_rst_tb_ready && !llc_rst_tb_ready_int) begin
            llc_rst_tb_tmp <= llc_rst_tb_i; 
        end
    end

    assign llc_rst_tb_next = (!llc_rst_tb_valid_tmp) ? llc_rst_tb_i : llc_rst_tb_tmp; 

    //LLC RSP OUT
    llc_rsp_out_t llc_rsp_out_tmp();

    interface_controller llc_rsp_out_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_rsp_out_ready),
        .valid_in(llc_rsp_out_valid_int),
        .ready_out(llc_rsp_out_ready_int),
        .valid_out(llc_rsp_out_valid),
        .valid_tmp(llc_rsp_out_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            llc_rsp_out_tmp.coh_msg <= 0;
            llc_rsp_out_tmp.addr <= 0;
            llc_rsp_out_tmp.line <= 0;
            llc_rsp_out_tmp.invack_cnt <= 0;
            llc_rsp_out_tmp.req_id <= 0;
            llc_rsp_out_tmp.dest_id <= 0;
            llc_rsp_out_tmp.word_offset <= 0;
            llc_rsp_out_tmp.word_mask <= 0;
        end else if (llc_rsp_out_valid_int && llc_rsp_out_ready_int && !llc_rsp_out_ready) begin
            llc_rsp_out_tmp.coh_msg <= llc_rsp_out_o.coh_msg;
            llc_rsp_out_tmp.addr <= llc_rsp_out_o.addr;
            llc_rsp_out_tmp.line <= llc_rsp_out_o.line;
            llc_rsp_out_tmp.invack_cnt <= llc_rsp_out_o.invack_cnt;
            llc_rsp_out_tmp.req_id <= llc_rsp_out_o.req_id;
            llc_rsp_out_tmp.dest_id <= llc_rsp_out_o.dest_id;
            llc_rsp_out_tmp.word_offset <= llc_rsp_out_o.word_offset;
            llc_rsp_out_tmp.word_mask <= llc_rsp_out_o.word_mask;
        end
    end

    assign llc_rsp_out.coh_msg = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.coh_msg : llc_rsp_out_tmp.coh_msg;
    assign llc_rsp_out.addr = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.addr : llc_rsp_out_tmp.addr;
    assign llc_rsp_out.line = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.line : llc_rsp_out_tmp.line;
    assign llc_rsp_out.invack_cnt = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.invack_cnt : llc_rsp_out_tmp.invack_cnt;
    assign llc_rsp_out.req_id = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.req_id : llc_rsp_out_tmp.req_id;
    assign llc_rsp_out.dest_id = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.dest_id : llc_rsp_out_tmp.dest_id;
    assign llc_rsp_out.word_offset = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.word_offset : llc_rsp_out_tmp.word_offset;
    assign llc_rsp_out.word_mask = (!llc_rsp_out_valid_tmp) ? llc_rsp_out_o.word_mask : llc_rsp_out_tmp.word_mask;

    //LLC DMA RSP OUT
    llc_dma_rsp_out_t llc_dma_rsp_out_tmp();

    interface_controller llc_dma_rsp_out_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_dma_rsp_out_ready),
        .valid_in(llc_dma_rsp_out_valid_int),
        .ready_out(llc_dma_rsp_out_ready_int),
        .valid_out(llc_dma_rsp_out_valid),
        .valid_tmp(llc_dma_rsp_out_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            llc_dma_rsp_out_tmp.coh_msg <= 0;
            llc_dma_rsp_out_tmp.addr <= 0;
            llc_dma_rsp_out_tmp.line <= 0;
            llc_dma_rsp_out_tmp.invack_cnt <= 0;
            llc_dma_rsp_out_tmp.req_id <= 0;
            llc_dma_rsp_out_tmp.dest_id <= 0;
            llc_dma_rsp_out_tmp.word_offset <= 0;
        end else if (llc_dma_rsp_out_valid_int && llc_dma_rsp_out_ready_int && !llc_dma_rsp_out_ready) begin
            llc_dma_rsp_out_tmp.coh_msg <= llc_dma_rsp_out_o.coh_msg;
            llc_dma_rsp_out_tmp.addr <= llc_dma_rsp_out_o.addr;
            llc_dma_rsp_out_tmp.line <= llc_dma_rsp_out_o.line;
            llc_dma_rsp_out_tmp.invack_cnt <= llc_dma_rsp_out_o.invack_cnt;
            llc_dma_rsp_out_tmp.req_id <= llc_dma_rsp_out_o.req_id;
            llc_dma_rsp_out_tmp.dest_id <= llc_dma_rsp_out_o.dest_id;
            llc_dma_rsp_out_tmp.word_offset <= llc_dma_rsp_out_o.word_offset;
        end
    end

    assign llc_dma_rsp_out.coh_msg = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.coh_msg : llc_dma_rsp_out_tmp.coh_msg;
    assign llc_dma_rsp_out.addr = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.addr : llc_dma_rsp_out_tmp.addr;
    assign llc_dma_rsp_out.line = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.line : llc_dma_rsp_out_tmp.line;
    assign llc_dma_rsp_out.invack_cnt = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.invack_cnt : llc_dma_rsp_out_tmp.invack_cnt;
    assign llc_dma_rsp_out.req_id = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.req_id : llc_dma_rsp_out_tmp.req_id;
    assign llc_dma_rsp_out.dest_id = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.dest_id : llc_dma_rsp_out_tmp.dest_id;
    assign llc_dma_rsp_out.word_offset = (!llc_dma_rsp_out_valid_tmp) ? llc_dma_rsp_out_o.word_offset : llc_dma_rsp_out_tmp.word_offset;

    //LLC FWD OUT
    llc_fwd_out_t llc_fwd_out_tmp();

    interface_controller llc_fwd_out_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_fwd_out_ready),
        .valid_in(llc_fwd_out_valid_int),
        .ready_out(llc_fwd_out_ready_int),
        .valid_out(llc_fwd_out_valid),
        .valid_tmp(llc_fwd_out_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            llc_fwd_out_tmp.coh_msg <= 0;
            llc_fwd_out_tmp.addr <= 0;
            llc_fwd_out_tmp.req_id <= 0;
            llc_fwd_out_tmp.dest_id <= 0;
            llc_fwd_out_tmp.line <= 0;
            llc_fwd_out_tmp.word_mask <= 0;
        end else if (llc_fwd_out_valid_int && llc_fwd_out_ready_int && !llc_fwd_out_ready) begin
            llc_fwd_out_tmp.coh_msg <= llc_fwd_out_o.coh_msg;
            llc_fwd_out_tmp.addr <= llc_fwd_out_o.addr;
            llc_fwd_out_tmp.req_id <= llc_fwd_out_o.req_id;
            llc_fwd_out_tmp.dest_id <= llc_fwd_out_o.dest_id;
            llc_fwd_out_tmp.line <= llc_fwd_out_o.line;
            llc_fwd_out_tmp.word_mask <= llc_fwd_out_o.word_mask;
        end
    end

    assign llc_fwd_out.coh_msg = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.coh_msg : llc_fwd_out_tmp.coh_msg;
    assign llc_fwd_out.addr = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.addr : llc_fwd_out_tmp.addr;
    assign llc_fwd_out.req_id = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.req_id : llc_fwd_out_tmp.req_id;
    assign llc_fwd_out.dest_id = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.dest_id : llc_fwd_out_tmp.dest_id;
    assign llc_fwd_out.line = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.line : llc_fwd_out_tmp.line;
    assign llc_fwd_out.word_mask = (!llc_fwd_out_valid_tmp) ? llc_fwd_out_o.word_mask : llc_fwd_out_tmp.word_mask;

    //LLC MEM REQ
    llc_mem_req_t llc_mem_req_tmp();

    interface_controller llc_mem_req_intf(
        .clk(clk),
        .rst(rst),
        .ready_in(llc_mem_req_ready),
        .valid_in(llc_mem_req_valid_int),
        .ready_out(llc_mem_req_ready_int),
        .valid_out(llc_mem_req_valid),
        .valid_tmp(llc_mem_req_valid_tmp)
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            llc_mem_req_tmp.hwrite <= 0;
            llc_mem_req_tmp.hsize <= 0;
            llc_mem_req_tmp.hprot <= 0;
            llc_mem_req_tmp.addr <= 0;
            llc_mem_req_tmp.line <= 0;
        end else if (llc_mem_req_valid_int && llc_mem_req_ready_int && !llc_mem_req_ready) begin
            llc_mem_req_tmp.hwrite <= llc_mem_req_o.hwrite;
            llc_mem_req_tmp.hsize <= llc_mem_req_o.hsize;
            llc_mem_req_tmp.hprot <= llc_mem_req_o.hprot;
            llc_mem_req_tmp.addr <= llc_mem_req_o.addr;
            llc_mem_req_tmp.line <= llc_mem_req_o.line;
        end
    end

    assign llc_mem_req.hwrite = (!llc_mem_req_valid_tmp) ? llc_mem_req_o.hwrite : llc_mem_req_tmp.hwrite;
    assign llc_mem_req.hsize = (!llc_mem_req_valid_tmp) ? llc_mem_req_o.hsize : llc_mem_req_tmp.hsize;
    assign llc_mem_req.hprot = (!llc_mem_req_valid_tmp) ? llc_mem_req_o.hprot : llc_mem_req_tmp.hprot;
    assign llc_mem_req.addr = (!llc_mem_req_valid_tmp) ? llc_mem_req_o.addr : llc_mem_req_tmp.addr;
    assign llc_mem_req.line = (!llc_mem_req_valid_tmp) ? llc_mem_req_o.line : llc_mem_req_tmp.line;

    //LLC RST TB DONE
    logic llc_rst_tb_done_tmp; 
    
    interface_controller llc_rst_tb_done_intf(
        .clk(clk), 
        .rst(rst), 
        .ready_in(llc_rst_tb_done_ready), 
        .valid_in(llc_rst_tb_done_valid_int), 
        .ready_out(llc_rst_tb_done_ready_int), 
        .valid_out(llc_rst_tb_done_valid), 
        .valid_tmp(llc_rst_tb_done_valid_tmp)
    ); 

    always_ff @(posedge clk or negedge rst) begin 
        if (!rst) begin 
            llc_rst_tb_done_tmp <= 0; 
        end else if (llc_rst_tb_done_valid_int && llc_rst_tb_done_ready_int && !llc_rst_tb_done_ready) begin 
            llc_rst_tb_done_tmp <= llc_rst_tb_done_o; 
        end 
    end

    assign llc_rst_tb_done = (!llc_rst_tb_done_valid_tmp) ? llc_rst_tb_done_o : llc_rst_tb_done_tmp; 

    //read from interfaces

   //llc req in
    llc_req_in_t llc_req_conflict();
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_req_in.coh_msg <= 0;
            llc_req_in.hprot <= 0;
            llc_req_in.addr <= 0;
            llc_req_in.line <= 0;
            llc_req_in.req_id <= 0;
            llc_req_in.word_offset <= 0;
            llc_req_in.valid_words <= 0;
            llc_req_in.word_mask <= 0;
       end else if (set_req_from_conflict) begin
            llc_req_in.coh_msg <= llc_req_conflict.coh_msg;
            llc_req_in.hprot <= llc_req_conflict.hprot;
            llc_req_in.addr <= llc_req_conflict.addr;
            llc_req_in.line <= llc_req_conflict.line;
            llc_req_in.req_id <= llc_req_conflict.req_id;
            llc_req_in.word_offset <= llc_req_conflict.word_offset;
            llc_req_in.valid_words <= llc_req_conflict.valid_words;
            llc_req_in.word_mask <= llc_req_conflict.word_mask;
        end else if (llc_req_in_valid_int && llc_req_in_ready_int) begin
            llc_req_in.coh_msg <= llc_req_in_next.coh_msg;
            llc_req_in.hprot <= llc_req_in_next.hprot;
            llc_req_in.addr <= llc_req_in_next.addr;
            llc_req_in.line <= llc_req_in_next.line;
            llc_req_in.req_id <= llc_req_in_next.req_id;
            llc_req_in.word_offset <= llc_req_in_next.word_offset;
            llc_req_in.valid_words <= llc_req_in_next.valid_words;
            llc_req_in.word_mask <= llc_req_in_next.word_mask;
        end
    end

    //req in stalled
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_req_conflict.coh_msg <= 0;
            llc_req_conflict.hprot <= 0;
            llc_req_conflict.addr <= 0;
            llc_req_conflict.line <= 0;
            llc_req_conflict.req_id <= 0;
            llc_req_conflict.word_offset <= 0;
            llc_req_conflict.valid_words <= 0;
            llc_req_conflict.word_mask <= 0;
       end else if (set_req_conflict) begin
            llc_req_conflict.coh_msg <= llc_req_in.coh_msg;
            llc_req_conflict.hprot <= llc_req_in.hprot;
            llc_req_conflict.addr <= llc_req_in.addr;
            llc_req_conflict.line <= llc_req_in.line;
            llc_req_conflict.req_id <= llc_req_in.req_id;
            llc_req_conflict.word_offset <= llc_req_in.word_offset;
            llc_req_conflict.valid_words <= llc_req_in.valid_words;
            llc_req_conflict.word_mask <= llc_req_in.word_mask;
        end
    end

    //dma req in
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_dma_req_in.coh_msg <= 0;
            llc_dma_req_in.hprot <= 0;
            llc_dma_req_in.addr <= 0;
            llc_dma_req_in.line <= 0;
            llc_dma_req_in.req_id <= 0;
            llc_dma_req_in.word_offset <= 0;
            llc_dma_req_in.valid_words <= 0;
        end else if (llc_dma_req_in_valid_int && llc_dma_req_in_ready_int) begin
            llc_dma_req_in.coh_msg <= llc_dma_req_in_next.coh_msg;
            llc_dma_req_in.hprot <= llc_dma_req_in_next.hprot;
            llc_dma_req_in.addr <= llc_dma_req_in_next.addr;
            llc_dma_req_in.line <= llc_dma_req_in_next.line;
            llc_dma_req_in.req_id <= llc_dma_req_in_next.req_id;
            llc_dma_req_in.word_offset <= llc_dma_req_in_next.word_offset;
            llc_dma_req_in.valid_words <= llc_dma_req_in_next.valid_words;
        end
    end

    //llc rsp in
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_rsp_in.coh_msg <= 0;
            llc_rsp_in.addr <= 0;
            llc_rsp_in.line <= 0;
            llc_rsp_in.req_id <= 0;
            llc_rsp_in.word_mask <= 0;
        end else if (llc_rsp_in_valid_int && llc_rsp_in_ready_int) begin
            llc_rsp_in.coh_msg <= llc_rsp_in_next.coh_msg;
            llc_rsp_in.addr <= llc_rsp_in_next.addr;
            llc_rsp_in.line <= llc_rsp_in_next.line;
            llc_rsp_in.req_id <= llc_rsp_in_next.req_id;
            llc_rsp_in.word_mask <= llc_rsp_in_next.word_mask;
         end
    end

    //mem rsp
    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            llc_mem_rsp.line <= 0;
        end else if (llc_mem_rsp_valid_int && llc_mem_rsp_ready_int) begin
            llc_mem_rsp.line <= llc_mem_rsp_next.line;
        end
    end

    assign req_in_addr = set_req_from_conflict ? llc_req_conflict.addr : (llc_req_in_valid_tmp ? llc_req_in_tmp.addr : llc_req_in_i.addr);
    assign rsp_in_addr = (llc_rsp_in_valid_tmp) ? llc_rsp_in_tmp.addr : llc_rsp_in_i.addr;

    //rst tb 
    always_ff @(posedge clk or negedge rst) begin 
        if(!rst) begin 
            llc_rst_tb <= 0; 
        end else if (llc_rst_tb_valid_int && llc_rst_tb_ready_int) begin
            llc_rst_tb <= llc_rst_tb_next; 
        end
    end
    
endmodule
