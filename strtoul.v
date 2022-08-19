
`timescale 1ns/100ps
//=========================================================================================================
//                                    ------->  Revision History  <------
//=========================================================================================================
//
//   Date     Who   Ver  Changes
//=========================================================================================================
// 12-Aug-22  DWW  1000  Initial creation
//=========================================================================================================


//=========================================================================================================
// strtoul - Determines whether a string represents an ASCII decimal number, an ASCII hex number, or
//           neither.   If it represents a hex or decimal number, that number is decoded into a 64-bit
//           integer.   
//          
// Inputs:  START  = strobe on for one cycle to begin
//          INPSTR = Register that is STR_WIDTH bits wide that contains the right-justified input string
//
// Outputs: STATUS = 0=Not finished, 1=Not numeric, 2=ASCII hex, 3=ASCII decimal
//          RESULT = The decoded unsigned integer
//          
//=========================================================================================================

module strtoul #
(
    parameter STR_WIDTH = 512
)
(
    input                clk, resetn,
    input                START,
    input[STR_WIDTH-1:0] INPSTR,

    output[1:0]          STATUS,
    output[63:0]         RESULT
);

genvar x;
localparam STRLEN     = STR_WIDTH / 8;
localparam LAST_INDEX = STRLEN - 1;

// These are the four possible values that can be in STATUS
localparam STATUS_NONE = 0;
localparam STATUS_NOT  = 1;
localparam STATUS_HEX  = 2;
localparam STATUS_DEC  = 3;

// The current state of the FSM
reg[4:0] state;

// Map a byte array on top of the INPSTR
wire[7:0] inp_char[0:STRLEN-1];
for (x=0; x<STRLEN; x=x+1) assign inp_char[x] = INPSTR[8*(STRLEN-1-x) +: 8];

// This is the index into the string
reg[7:0] index;  

// This is the integer result of our ASCII-to-integer conversion
reg[63:0] result; assign RESULT = result;

// STATUS : 0=Not done, 1=Not-numeric, 2=ASCII Hex, 3=ASCII decimal
reg[1:0] status; assign STATUS = (START == 1) ? STATUS_NONE :
                                 (state == 0) ? status      : STATUS_NONE;
                             
// These two bytes are always the character at the index, and the character after
wire[7:0] c0, c1;
assign c0 = inp_char[index];
assign c1 = inp_char[index + 1];


always @(posedge clk) begin
    
    if (resetn == 0) begin
        status <= STATUS_NOT;
        state  <= 0; 
    end else case(state)

    // Here we are waiting for the signal that says "Go!"
    0:  if (START) begin
            status <= STATUS_NONE;
            index  <= 0;
            result <= 0;
            state  <= 1;
        end

    // We're searching for the first byte that isn't nul or space
    1:  if (c0 == 0 || c0 == " ") begin
            if (index == LAST_INDEX) begin
                status <= STATUS_NOT;
                state  <= 0;
            end
            index <= index + 1;
        end else begin
            state <= 2;
        end

    // If we get here, we found a byte that isn't a nul or a space
    2:  begin
            // If the string begins with "0x"...
            if (index < LAST_INDEX-1 && c0 == "0" && c1 == "x") begin
                status <= STATUS_HEX;
                index  <= index + 2;
                state  <= 16;
            end 

            // Otherwise if the string begins with a decimal digit...
            else if (c0 >= "0" && c0 <= "9") begin
                status <= STATUS_DEC;
                state  <= 10;
            end

            // Otherwise, this isn't a numeric string
            else begin
                status <= STATUS_NOT; 
                state  <= 0;
            end
        end

    // Decode an ASCII base-10 number into an integer
    10: if (index < STRLEN) begin
            if (c0 >= "0" && c0 <= "9")
                result <= (result << 3) + (result << 1) + (c0-48);
            else begin
                state  <= 0;
            end
            index <= index + 1;
        end else state <= 0;


    // Decode an ASCII base-16 number into an integer
    16: if (index < STRLEN) begin
            if (c0 >= "0" && c0 <= "9")
                result <= (result << 4) | (c0-48);
            else if (c0 >= "A" && c0 <= "F")
                result <= (result << 4) | (c0-55);
            else if (c0 >= "a" && c0 <= "f")
                result <= (result << 4) | (c0-87);
            else begin
                state <= 0;
            end
            index <= index + 1;

        end else state <= 0;

    endcase

end

endmodule
//=========================================================================================================


