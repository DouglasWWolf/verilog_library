`timescale 1ns / 1ps

//=========================================================================================================
// to_ascii_hex: FSM that converts a 64-bit number to ASCII hex
//
// The output RESULT field should be large enough to accommidate <OUTPUT_WIDTH> 8-bit characters
//=========================================================================================================
module to_ascii_hex#(parameter OUTPUT_WIDTH = 19)
(
    input                      CLK, RESETN,
    input[63:0]                VALUE,
    input[7:0]                 DIGITS_OUT,
    input                      NOSEP,
    input                      START,
    output[OUTPUT_WIDTH*8-1:0] RESULT,
    output                     IDLE
);

    integer i; genvar x;
    localparam MAX_INP_DIGITS = 16;

    reg[7:0] result[0:OUTPUT_WIDTH-1];     // Holds the resulting ASCII characters
    reg[3:0] value[0:MAX_INP_DIGITS-1];    // Holds the input value, one nybble per slot
    reg      state;
    reg[4:0] src_idx, digits_out, last_src_idx;
    reg[7:0] dst_idx;

    //=============================================================================
    // ascii() - Returns the ASCII character that corresponds to the input nybble
    //=============================================================================
    function [7:0] ascii(input[3:0] nybble);
        ascii = nybble > 9 ? nybble + 87 : nybble + 48;
    endfunction
    //=============================================================================

    //=====================================================================================================
    // FSM that converts the 64-bit number in VALUE to a series of ASCII digits right justified in both
    // "result" and "RESULT"
    //=====================================================================================================
    always @(posedge CLK) begin
        if (RESETN == 0) begin
            state <= 0;
        end else case(state)
            0:  if (START) begin
                    // Clear the result character buffer to all zeros
                    for (i=0; i<OUTPUT_WIDTH; i=i+1) result[i] <= 0;
                        
                    // Convert the packed input VALUE into an unpacked array of 4-bit values
                    for (i=0; i<MAX_INP_DIGITS; i=i+1) value[i] <= VALUE[4*(MAX_INP_DIGITS-1-i) +: 4];
                        
                    // As we copy characters from "value" to "result", start at the rightmost characters
                    src_idx        <= MAX_INP_DIGITS - 1;
                    dst_idx        <= OUTPUT_WIDTH - 1;

                    // Compute the index of the last digit we will read in and output
                    last_src_idx   <= MAX_INP_DIGITS - (DIGITS_OUT == 0 ? 8: DIGITS_OUT);
                        
                    // When we get to the next state, we will be handling the first output digit
                    digits_out     <= 1;

                    // And go to the next state
                    state          <= 1;
                end

            1:  begin
                    // Copy the current nybble from the source value to the ASCII result array
                    result[dst_idx] <= ascii(value[src_idx]);
                   
                    // If we just copied the final digit, we're done
                    if (src_idx == last_src_idx || dst_idx == 0) state = 0;
                        
                    // Otherwise, if we're supposed to output separators, and this digit index 
                    // is divisible by four, output a ":" separator
                    else if (NOSEP == 0 && dst_idx && digits_out[1:0] == 0) begin
                        result[dst_idx-1] <= ":";
                        dst_idx           <= dst_idx - 2;
                        
                    // Otherwise, just point to the next destination in "result[]"
                    end else dst_idx <= dst_idx - 1;

                    // Point to the next source nybble in "value[]"
                    src_idx <= src_idx - 1;
                        
                    // Keep track of how many digits we have output
                    digits_out <= digits_out + 1;

                end

        endcase
    end
    //=====================================================================================================

    // Tell the outside world when we're idle;
    assign IDLE = (state == 0 && START == 0);

    // This maps our unpacked "result[]" array back into the packed RESULT output
    for (x=0; x<OUTPUT_WIDTH; x=x+1) begin
        assign RESULT[x*8 +: 8] = result[OUTPUT_WIDTH-1-x];
    end

endmodule
//=========================================================================================================
 
