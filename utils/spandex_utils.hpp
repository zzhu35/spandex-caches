/*

Copyright (c) 2021 University of Illinois Urbana Champaign, RSIM Group
http://rsim.cs.uiuc.edu/

    Modified by Zeran Zhu
    zzhu35@illinois.edu

    April 9 2021

*/

#ifndef __SPANDEX_UTILS_HPP__
#define __SPANDEX_UTILS_HPP__

#include "spandex_types.hpp"
#define __CACHE_TYPES_HPP__
#include "cache_utils.hpp"

inline void write_word_amo(line_t &line, word_t word, word_offset_t w_off, byte_offset_t b_off, hsize_t hsize, amo_t amo)
{
    uint32_t size = BITS_PER_WORD, b_off_tmp = 0;

    b_off_tmp = b_off;

    switch (hsize) {
        case BYTE:
            size = 8; break;
        case HALFWORD:
            size = 16; break;
        case WORD_32:
            size = 32; break;
        default:
            size = 64; break;
    }

    uint32_t w_off_bits = BITS_PER_WORD * w_off;
    uint32_t b_off_bits = 8 * b_off_tmp;
    uint32_t off_bits = w_off_bits + b_off_bits;

    uint32_t word_range_hi = b_off_bits + size - 1;
    uint32_t line_range_hi = off_bits + size - 1;

    bool gt = line.range(line_range_hi, off_bits).to_int() > word.range(word_range_hi, b_off_bits).to_int();
    bool ugt = line.range(line_range_hi, off_bits).to_uint() > word.range(word_range_hi, b_off_bits).to_uint();

    switch (amo)
    {
        case AMO_SWAP :
            line.range(line_range_hi, off_bits) = word.range(word_range_hi, b_off_bits);
            break;
        case AMO_ADD :
            line.range(line_range_hi, off_bits) = line.range(line_range_hi, off_bits).to_int() + word.range(word_range_hi, b_off_bits).to_int();
            break;
        case AMO_AND :
            line.range(line_range_hi, off_bits) = line.range(line_range_hi, off_bits) & ~(word.range(word_range_hi, b_off_bits));
            break;
        case AMO_OR :
            line.range(line_range_hi, off_bits) = line.range(line_range_hi, off_bits) | word.range(word_range_hi, b_off_bits);
            break;
        case AMO_XOR :
            line.range(line_range_hi, off_bits) = line.range(line_range_hi, off_bits) ^ word.range(word_range_hi, b_off_bits);
            break;
        case AMO_MAX :
            if (!gt) line.range(line_range_hi, off_bits) = word.range(word_range_hi, b_off_bits);
            break;
        case AMO_MAXU :
            if (!ugt) line.range(line_range_hi, off_bits) = word.range(word_range_hi, b_off_bits);
            break;
        case AMO_MIN :
            if (gt) line.range(line_range_hi, off_bits) = word.range(word_range_hi, b_off_bits);
            break;
        case AMO_MINU :
            if (ugt) line.range(line_range_hi, off_bits) = word.range(word_range_hi, b_off_bits);
            break;

        default:
            break;
    }


}


inline void calc_amo(line_t& line, line_t& data, coh_msg_t req, word_mask_t word_mask)
{
    // word_mask must contain only one bit set
    int i;
    for (i = 0; i < WORDS_PER_LINE; i++)
    {
        HLS_UNROLL_LOOP("amo");
        if (word_mask & (1 << i)) break;
    }
    wait();
    int old = line.range((i+1)*BITS_PER_WORD-1, i*BITS_PER_WORD).to_int();
    int dataw = data.range((i+1)*BITS_PER_WORD-1, i*BITS_PER_WORD).to_int();

    // @TODO MAX MIN might not work, depending on if to_int() sign_extends

    data = line; // send old data back
    switch (req)
    {
        case REQ_AMO_SWAP:
            old = dataw;
            break;
        case REQ_AMO_ADD:
            old += dataw;
            break;
        case REQ_AMO_AND:
            old &= dataw;
            break;
        case REQ_AMO_OR:
            old |= dataw;
            break;
        case REQ_AMO_XOR:
            old ^= dataw;
            break;
        case REQ_AMO_MAX:
            old = (old > dataw) ? old : dataw;
            break;
        case REQ_AMO_MAXU:
            old = ((unsigned)old > (unsigned)dataw) ? old : dataw;
            break;
        case REQ_AMO_MIN:
            old = (old < dataw) ? old : dataw;
            break;
        case REQ_AMO_MINU:
            old = ((unsigned)old < (unsigned)dataw) ? old : dataw;
            break;
        default:
        break;
    }
    line.range((i+1)*BITS_PER_WORD-1, i*BITS_PER_WORD) = old; // store calculated new word in the line

}

#endif
