`timescale 1ns / 1ps


//=========================================================================================================
// ascii() - Returns the ASCII character that corresponds to the input nybble
//=========================================================================================================
function [7:0] ascii(input[3:0] nybble);
    ascii = nybble > 9 ? nybble + 87 : nybble + 48;
endfunction
//=========================================================================================================


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
                    // is divisible by four, output an underscore separator
                    else if (NOSEP == 0 && dst_idx && digits_out[1:0] == 0) begin
                        result[dst_idx-1] <= "_";
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
 






//=========================================================================================================
// to_ascii_bin: FSM that converts a 64-bit number to ASCII binary
//
// The output RESULT field should be large enough to accommidate <OUTPUT_WIDTH> 8-bit characters
//=========================================================================================================
module to_ascii_bin#(parameter OUTPUT_WIDTH = 36)
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
    localparam MAX_INP_DIGITS = 64;

    reg[7:0] result[0:OUTPUT_WIDTH-1];     // Holds the resulting ASCII characters
    reg      value[0:MAX_INP_DIGITS-1];    // Holds the input value, one nybble per slot
    reg      state;
    reg[6:0] src_idx, digits_out, last_src_idx;
    reg[7:0] dst_idx;


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
                    for (i=0; i<MAX_INP_DIGITS; i=i+1) value[i] <= VALUE[(MAX_INP_DIGITS-1-i)];
                        
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
                    // is divisible by four, output an underscore separator
                    else if (NOSEP == 0 && dst_idx && digits_out[2:0] == 0) begin
                        result[dst_idx-1] <= "_";
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






//======================================================================================================================
// double_dabble() - Implements the classic "double dabble" binary-to-BCD algorithm
//======================================================================================================================
module double_dabble#(parameter INPUT_WIDTH=1,  parameter DECIMAL_DIGITS=1)
(
    input                         CLK, RESETN,
    input [INPUT_WIDTH-1:0]       BINARY,
    input                         START,
    output [DECIMAL_DIGITS*4-1:0] BCD,
    output                        DONE
);
   
    localparam s_IDLE              = 3'b000;
    localparam s_SHIFT             = 3'b001;
    localparam s_CHECK_SHIFT_INDEX = 3'b010;
    localparam s_ADD               = 3'b011;
    localparam s_CHECK_DIGIT_INDEX = 3'b100;
   
    reg[2:0] state;
   
    // The vector that contains the output BCD
    reg[DECIMAL_DIGITS*4-1:0]   bcd;
    
    // The vector that contains the input binary value being shifted.
    reg[INPUT_WIDTH-1:0]        binary;
      
    // Keeps track of which Decimal Digit we are indexing
    reg[DECIMAL_DIGITS-1:0]     digit_index;
    
    // Keeps track of which loop iteration we are on.
    // Number of loops performed = INPUT_WIDTH
    reg[7:0]                    loop_count;
    wire[3:0]                   bcd_digit;
    
    always @(posedge CLK) begin
        if (RESETN == 0) begin
            state <= s_IDLE;
        end else case (state) 
  
        // Stay in this state until START comes along
        s_IDLE :
            if (START) begin
                binary      <= BINARY;
                bcd         <= 0;
                loop_count  <= 0;
                digit_index <= 0;
                state       <= s_SHIFT;
            end

  
        // Always shift the BCD Vector until we have shifted all bits through
        // Shift the most significant bit of binary into bcd lowest bit.
        s_SHIFT :
            begin
                bcd     <= bcd << 1;
                bcd[0]  <= binary[INPUT_WIDTH-1];
                binary  <= binary << 1;
                state   <= s_CHECK_SHIFT_INDEX;
            end          
         
  
        // Check if we are done with shifting in binary vector
        s_CHECK_SHIFT_INDEX :
            if (loop_count == INPUT_WIDTH-1) begin
               state       <= s_IDLE;
            end else begin
                loop_count <= loop_count + 1;
                state      <= s_ADD;
            end
                
  
        // Break down each BCD Digit individually.  Check them one-by-one to
        // see if they are greater than 4.  If they are, increment by 3.
        // Put the result back into bcd Vector.  
        s_ADD :
            begin
                if (bcd_digit > 4) 
                    bcd[(digit_index*4)+:4] <= bcd_digit + 3;  
                state <= s_CHECK_DIGIT_INDEX; 
            end       
         
         
        // Check if we are done incrementing all of the BCD Digits
        s_CHECK_DIGIT_INDEX :
            if (digit_index == DECIMAL_DIGITS-1) begin
                digit_index <= 0;
                state       <= s_SHIFT;
            end else begin
                digit_index <= digit_index + 1;
                state       <= s_ADD;
            end
         
        default :
            state <= s_IDLE;
            
        endcase
    end 
 
   
  assign bcd_digit = bcd[digit_index*4 +: 4];
  assign BCD       = bcd;
  assign DONE      = (state == s_IDLE && START == 0);
      
endmodule 
//======================================================================================================================




//=========================================================================================================
// to_ascii_dec: FSM that converts a 64-bit number to ASCII decimal
//
// The output RESULT field should be large enough to accommidate <OUTPUT_WIDTH> 8-bit characters
//=========================================================================================================
module to_ascii_dec#(parameter OUTPUT_WIDTH = 20)
(
    input                      CLK, RESETN,
    input[63:0]                VALUE,
    input[7:0]                 FIELD_WIDTH,
    input                      NOSEP,
    input                      START,
    output[OUTPUT_WIDTH*8-1:0] RESULT,
    output                     IDLE
);


    integer i; genvar x;
    
    // A 64-bit number will have no more than 20 decimal digits
    localparam MAX_INP_DIGITS = 20;

    reg[7:0] result[0:OUTPUT_WIDTH-1];     // Holds the resulting ASCII characters
    reg[3:0] value[0:MAX_INP_DIGITS-1];    // Holds the input value, one nybble per slot
    reg[2:0] state;
    reg[4:0] src_idx, digit_number;
    reg[7:0] dst_idx, first_pad_idx;

    //=====================================================================================================
    // is_mult_3() - A function that determines if a number is a multiple of three
    //=====================================================================================================
    function  is_mult_3(input[7:0] number);
        is_mult_3 = (number== 3 || number== 6 || number== 9 ||
                     number==12 || number==15 || number==18);
    endfunction
    //=====================================================================================================


    //=====================================================================================================
    // State machine that converts binary to bcd
    //=====================================================================================================
    reg                        dd_start;
    wire[MAX_INP_DIGITS*4-1:0] dd_result;
    wire                       dd_done;
    double_dabble#(.INPUT_WIDTH(64), .DECIMAL_DIGITS(20)) dd
    (
        .CLK        (CLK),
        .RESETN     (RESETN),
        .BINARY     (VALUE),
        .START      (dd_start),
        .BCD        (dd_result),
        .DONE       (dd_done)
    );
    //=====================================================================================================

    //=====================================================================================================
    // FSM that converts the 64-bit number in VALUE to a series of ASCII digits right justified in both
    // "result" and "RESULT"
    //=====================================================================================================
    always @(posedge CLK) begin
        dd_start <= 0;
        if (RESETN == 0) begin
            state <= 0;
        end else case(state)
            0:  if (START) begin

                    // Clear the result character buffer to all zeros
                    for (i=0; i<OUTPUT_WIDTH; i=i+1) result[i] <= 0;
                        
                    // As we copy characters from "value" to "result", start at the rightmost characters
                    src_idx        <= MAX_INP_DIGITS - 1;
                    dst_idx        <= OUTPUT_WIDTH - 1;

                    // Digits are numbered from right to left
                    digit_number   <= 1;

                    // Compute the index in the "result" array where we can start space-padding
                    first_pad_idx  <= OUTPUT_WIDTH - FIELD_WIDTH;

                    // Start the conversion from binary to BCD
                    dd_start       <= 1;

                    // And go to the next state
                    state          <= 1;
                end

            // Wait for the conversion from binary to BCD to complete, then unpack the BCD result 
            // into the value[] array
            1:  if (dd_done) begin
                    for (i=0; i<MAX_INP_DIGITS; i=i+1) value[i] <= dd_result[4*(MAX_INP_DIGITS-1-i) +: 4];
                    state <= 2;
                end

            2:  begin
                    // Copy the current nybble from the source value to the ASCII result array
                    result[dst_idx] <= ascii(value[src_idx]);
                   
                    // If we just copied the final digit, we're done
                    if (src_idx == 0 || dst_idx == 0) begin
                        dst_idx <= 0;
                        state   <= 3;
                    end
                        
                    // Otherwise, if we're supposed to output separators, and this digit index 
                    // is a multiple of 3, output a "," separator
                    else if (NOSEP == 0 && dst_idx && is_mult_3(digit_number)) begin
                        result[dst_idx-1] <= ",";
                        dst_idx           <= dst_idx - 2;
                        
                    // Otherwise, just point to the next destination in "result[]"
                    end else dst_idx <= dst_idx - 1;

                    // Point to the next source nybble in "value[]"
                    src_idx <= src_idx - 1;
                        
                    // Keep track of how many digits we have output
                    digit_number <= digit_number + 1;
                end

            // Convert all leading "0" or "," characters to either 0 or ASCII "space"
            3:  begin
                    if (dst_idx == OUTPUT_WIDTH-1)
                        state <= 0;
                    else if (result[dst_idx] == "0" || result[dst_idx] == ",")
                        result[dst_idx] = (dst_idx < first_pad_idx) ? 0: " ";
                    else if (result[dst_idx])
                        state <= 0;
                    dst_idx <= dst_idx + 1;
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
 
