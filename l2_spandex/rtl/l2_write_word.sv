`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

module l2_write_word(
    input logic clk,
    input logic rst,
    input word_t write_word_word_in,
    input word_offset_t write_word_w_off_in,
    input byte_offset_t write_word_b_off_in,
    input hsize_t write_word_hsize_in,
    input line_t write_word_line_in,

    output line_t write_word_line_out
    );

    logic[6:0] size, b_off_tmp, w_off_bits, b_off_bits, off_bits, word_range_hi, line_range_hi;

    always_comb begin
        size = `BITS_PER_WORD;
        b_off_tmp = 0;
`ifdef BIG_ENDIAN
        if (write_word_hsize_in == `BYTE) begin
            b_off_tmp = `BYTES_PER_WORD - 1 - write_word_b_off_in;
            size = 8;
        end else if (write_word_hsize_in == `HALFWORD) begin
            b_off_tmp = `BYTES_PER_WORD - 2 - write_word_b_off_in;
            size = 16;
        end else if (`BYTE_BITS == 2) begin
            size = 32;
        end else if (write_word_hsize_in == `WORD_32) begin
            b_off_tmp = `BYTES_PER_WORD - 4 - write_word_b_off_in;
            size = 32;
        end else begin
            size = 64;
        end
`else
    b_off_tmp = write_word_b_off_in;
    if (write_word_hsize_in == `BYTE) begin
        size = 8;
    end else if (write_word_hsize_in == `HALFWORD) begin
        size = 16;
    end else if (write_word_hsize_in == `WORD_32) begin
        size = 32;
    end else begin
        size = 64;
    end
`endif
        w_off_bits = `BITS_PER_WORD * write_word_w_off_in;
        b_off_bits = 8 * b_off_tmp;
        off_bits = w_off_bits + b_off_bits;

        word_range_hi = b_off_bits + size - 1;
        line_range_hi = off_bits + size - 1;
        write_word_line_out = write_word_line_in;

        if (write_word_hsize_in == `BYTE) begin
            write_word_line_out[off_bits +: 8] = write_word_word_in[b_off_bits +: 8];
        end else if (write_word_hsize_in == `HALFWORD) begin
            write_word_line_out[off_bits +: 16] = write_word_word_in[b_off_bits +: 16];
        end else if (write_word_hsize_in == `WORD_32) begin
            write_word_line_out[off_bits +: 32] = write_word_word_in[b_off_bits +: 32];
        end else if (`BYTE_BITS != 2) begin
            write_word_line_out[off_bits +: 64] = write_word_word_in[b_off_bits +: 64];
        end

end

endmodule
