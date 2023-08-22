`timescale 1ps / 1ps
`include "spandex_consts.svh"
`include "spandex_types.svh"

// TODO: Make function!
module l2_write_word_amo(
    input logic clk,
    input logic rst,
    input word_t write_word_amo_word_in,
    input word_offset_t write_word_amo_w_off_in,
    input byte_offset_t write_word_amo_b_off_in,
    input hsize_t write_word_amo_hsize_in,
    input line_t write_word_amo_line_in,
    input amo_t write_word_amo_amo_in,

    output line_t write_word_amo_line_out
    );

    logic[6:0] size, b_off_tmp, w_off_bits, b_off_bits, off_bits, word_range_hi, line_range_hi;

    word_t u_line, u_word;
    sword_t s_line, s_word;
    logic gt, ugt;

    assign gt = (s_line > s_word) ? 1'b1 : 1'b0;
    assign ugt = (u_line > u_word) ? 1'b1 : 1'b0;

    always_comb begin
        b_off_tmp = write_word_amo_b_off_in;
        u_line = 0;
        u_word = 0;
        s_line = 0;
        s_word = 0;

        // Calculate size - which is the number of bits which
        // we have to atomically read-modify-write.
        if (write_word_amo_hsize_in == `BYTE) begin
            size = 8;
        end else if (write_word_amo_hsize_in == `HALFWORD) begin
            size = 16;
        end else if (write_word_amo_hsize_in == `WORD_32) begin
            size = 32;
        end else begin
            size = 64;
        end

        // Calculate off_bits - which is the bit offset at which
        // we have to atomically read-modify-write.
        w_off_bits = `BITS_PER_WORD * write_word_amo_w_off_in;
        b_off_bits = 8 * b_off_tmp;
        off_bits = w_off_bits + b_off_bits;
        
        // Read the words of concern (AMO can only be 32-bit or 64-bit words in Ariane),
        // into seperate registers that we can do the operation with.
        // *_line corresponds to the valid bits in the input line that is updated upon,
        // and *_word corresponds to the valid bits in the input word that is atomically updated.
        if (write_word_amo_hsize_in == `WORD_32) begin
            s_line = write_word_amo_line_in[off_bits +: 32];
            u_line = write_word_amo_line_in[off_bits +: 32];
            s_word = write_word_amo_word_in[b_off_bits +: 32];
            u_word = write_word_amo_word_in[b_off_bits +: 32];
        end else begin
            s_line = write_word_amo_line_in[off_bits +: 64];
            u_line = write_word_amo_line_in[off_bits +: 64];
            s_word = write_word_amo_word_in[b_off_bits +: 64];
            u_word = write_word_amo_word_in[b_off_bits +: 64];
        end

        write_word_amo_line_out = write_word_amo_line_in;

        case(write_word_amo_amo_in)
            `AMO_SWAP : begin
                if (write_word_amo_hsize_in == `WORD_32) begin
                    write_word_amo_line_out[off_bits +: 32] = s_word;
                end else begin
                    write_word_amo_line_out[off_bits +: 64] = s_word;
                end
            end
            `AMO_ADD : begin
                if (write_word_amo_hsize_in == `WORD_32) begin
                    write_word_amo_line_out[off_bits +: 32] = s_line + s_word;
                end else begin
                    write_word_amo_line_out[off_bits +: 64] = s_line + s_word;
                end
            end
            `AMO_AND : begin
                // TODO: Check why Spandex code was & ~
                if (write_word_amo_hsize_in == `WORD_32) begin
                    write_word_amo_line_out[off_bits +: 32] = s_line & ~s_word;
                end else begin
                    write_word_amo_line_out[off_bits +: 64] = s_line & ~s_word;
                end
            end
            `AMO_OR : begin
                if (write_word_amo_hsize_in == `WORD_32) begin
                    write_word_amo_line_out[off_bits +: 32] = s_line | s_word;
                end else begin
                    write_word_amo_line_out[off_bits +: 64] = s_line | s_word;
                end
            end
            `AMO_XOR : begin
                if (write_word_amo_hsize_in == `WORD_32) begin
                    write_word_amo_line_out[off_bits +: 32] = s_line ^ s_word;
                end else begin
                    write_word_amo_line_out[off_bits +: 64] = s_line ^ s_word;
                end
            end
            `AMO_MAX : begin
                if (!gt) begin
                    if (write_word_amo_hsize_in == `WORD_32) begin
                        write_word_amo_line_out[off_bits +: 32] = s_word;
                    end else begin
                        write_word_amo_line_out[off_bits +: 64] = s_word;
                    end
                end
            end
            `AMO_MAXU : begin
                if (!ugt) begin
                    if (write_word_amo_hsize_in == `WORD_32) begin
                        write_word_amo_line_out[off_bits +: 32] = s_word;
                    end else begin
                        write_word_amo_line_out[off_bits +: 64] = s_word;
                    end
                end
            end
            `AMO_MIN : begin
                if (gt) begin
                    if (write_word_amo_hsize_in == `WORD_32) begin
                        write_word_amo_line_out[off_bits +: 32] = s_word;
                    end else begin
                        write_word_amo_line_out[off_bits +: 64] = s_word;
                    end
                end
            end
            `AMO_MINU : begin
                if (ugt) begin
                    if (write_word_amo_hsize_in == `WORD_32) begin
                        write_word_amo_line_out[off_bits +: 32] = s_word;
                    end else begin
                        write_word_amo_line_out[off_bits +: 64] = s_word;
                    end
                end
            end
        endcase
    end

endmodule
