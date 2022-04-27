`timescale 1ns / 1ps
`define SYSCLOCK_FREQ 100000000

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






//======================================================================================================================
// clock_divider() - Generates a clock that changes state every 500 microsoconds (rising edge every 1 ms)
//======================================================================================================================
module seven_seg_clock_divider(input I_CLK, output O_CLK);
    
    // We're going generatate a 1 millisecond clock
    localparam DIVIDER = `SYSCLOCK_FREQ / 1000 / 2;
    
    // Determine how wide the counter needs to be based on the size of the divider
    localparam COUNTER_WIDTH = $clog2(DIVIDER);
    
    reg [COUNTER_WIDTH-1 : 0] counter = 0;
    reg o_clk = 0;

    always @(posedge I_CLK) begin
        if (counter == DIVIDER)
          begin
            o_clk <= ~o_clk;
            counter <= 0;
          end
        else
            counter <= counter + 1;
    end
    
    assign O_CLK = o_clk;
endmodule    
//======================================================================================================================




//======================================================================================================================
// module seven_seg() - Drives two four-digit 7-segment displays
//
// Behavior of the STYLE parameter:
//
//   For STYLE 0 thru 3 - the lower 16-bits of VALUE are displayed on the right display, 
//                        and the upper-16 bits of VALUE are displayed on the left display
//
//   0 = VALUE should be displayed hex on both displays
//   1 = Left display is in hex, right display is in decimal
//   2 = Left display is in decimal, right display is in hex
//   3 = Both displays are in decimal
//   4 = All 32-bits of value are displayed as a single value in decimal
//======================================================================================================================
module seven_seg#(STYLE=3)
(
    input CLK, [31:0]VALUE,
    output [7:0]CATHODE, [7:0]ANODE
);

    // This is the set of bits that is being driven out to the displays
    reg [31:0]  nybbles = 0;
    
    // Bitmap of which LED segments are lit for the current 7-seg
    reg [7:0]   cathode = 0;
    
    // A bitmap of which 7-segs are active (only 1 is active at a time)
    reg [7:0]   anode = 0;

    // A slow clock (roughly 1ms) for scanning across each 7-seg    
    wire        slow_clk;
    
    // A clock divider to slow down the rate and which we paint the 7-segment digits    
    seven_seg_clock_divider u1(.I_CLK(CLK), .O_CLK(slow_clk));
    
       
    // A binary-to-BCD converter
    reg [31:0] bcd_input = 0;
    reg  bin_to_bcd_start = 0;
    wire bin_to_bcd_done;
    wire [31:0] bcd_result;   

    // Binary to BCD decoding engine
    double_dabble#(.INPUT_WIDTH(32), .DECIMAL_DIGITS(8)) bin2bcd
    (
        .CLK    (CLK),
        .RESETN (RESETN),
        .BINARY (bcd_input),
        .START  (bin_to_bcd_start),
        .BCD    (bcd_result),
        .DONE   (bin_to_bcd_done)
    );
    
    // In STYLE 0, we simply drive VALUE directly out to the displays in hex
    generate if (STYLE == 0)
        always @(posedge CLK) begin
            nybbles = VALUE;
        end
    endgenerate    

    // In STYLE, the right-hand display is in decimal
    generate if (STYLE == 1) begin
        reg is_idle = 1;
        always @(posedge CLK) begin
            bin_to_bcd_start <= 0;
            if (is_idle) begin
                if (bcd_input != VALUE[15:0]) begin
                    is_idle <= 0;
                    bcd_input <= VALUE[15:0];
                    bin_to_bcd_start <= 1;
                end
            end else if (bin_to_bcd_done) begin
                is_idle <= 1;
                nybbles[31:16] <= VALUE[31:16];
                nybbles[15: 0] <= bcd_result[15:0];
            end
        end
    end
    endgenerate

    // In STYLE 2, the left-hand display is in decimal
    generate if (STYLE == 2) begin
        reg is_idle = 1;
        always @(posedge CLK) begin
            bin_to_bcd_start <= 0;
            if (is_idle) begin
                if (bcd_input != VALUE[31:16]) begin
                    is_idle <= 0;
                    bcd_input <= VALUE[31:16];
                    bin_to_bcd_start <= 1;
                end
            end else if (bin_to_bcd_done) begin
                is_idle <= 1;
                nybbles[31:16] <= bcd_result[15:0];
                nybbles[15: 0] <= VALUE[15:0];
            end
        end
    end
    endgenerate


    // In STYLE 3, both displays are in decimal
    generate if (STYLE == 3) begin
        localparam LO_WORD = 1;
        localparam HI_WORD = 2;
        reg[1:0] state = 0;
        reg[1:0] initialized;
        reg[15:0] old_lo, old_hi;
        
        always @(posedge CLK) begin
            bin_to_bcd_start <= 0;
            
            case (state)
                0:  if (!initialized[0] || old_lo != VALUE[15:0]) begin
                        old_lo            <= VALUE[15:0];
                        bcd_input         <= VALUE[15:0];
                        bin_to_bcd_start  <= 1;
                        initialized[0]    <= 1;
                        state             <= 1;
                    end else if (!initialized[1] || old_hi != VALUE[31:16]) begin
                        old_hi            <= VALUE[31:16];
                        bcd_input         <= VALUE[31:16];
                        bin_to_bcd_start  <= 1;
                        initialized[1]    <= 1;
                        state             <= 2;
                    end

                1:  if (bin_to_bcd_done) begin
                        nybbles[15: 0] <= bcd_result[15:0];
                        state          <= 0;
                    end
            
                2:  if (bin_to_bcd_done) begin
                        nybbles[31:16] <= bcd_result[15:0];
                        state          <= 0;
                    end
            endcase
        end
    end
    endgenerate


    // In STYLE 4, all 32 bits of value are considered a single value to be displayed in decimal
    generate if (STYLE == 4) begin    
        reg is_idle = 1;
        always @(posedge CLK) begin
            if (is_idle) begin
                if (bcd_input != VALUE) begin
                    is_idle <= 0;
                    bcd_input <= VALUE;
                    bin_to_bcd_start = 1;
                end
            end else if (bin_to_bcd_done) begin
                is_idle <= 1;
                nybbles <= bcd_result;
            end
        end
    end
    endgenerate
    
    
    /*
        This block copies "nybbles" to "shifting_value" and drives
        each nybble to the appropriate anode
    */
     reg [31:0] shifting_value;
     always @(posedge slow_clk) begin
        if (anode == 0) begin
            shifting_value <= nybbles;
            anode          <= 1;
        end else begin
            shifting_value <= shifting_value >> 4;
            anode          <= anode << 1;
        end   
     end
     
     
    
    /*
        This process determines which bits have to be on to represent the single hex digit
        that is encoded in the lower four bits of "shifting_value"
    */
    always @(posedge CLK)
    begin
        case (shifting_value[3:0])
            4'h0       : cathode = 8'b00111111;
            4'h1       : cathode = 8'b00000110;
            4'h2       : cathode = 8'b01011011;
            4'h3       : cathode = 8'b01001111;
            4'h4       : cathode = 8'b01100110;
            4'h5       : cathode = 8'b01101101;
            4'h6       : cathode = 8'b01111101;
            4'h7       : cathode = 8'b00000111;
            4'h8       : cathode = 8'b01111111;
            4'h9       : cathode = 8'b01100111;
            4'hA       : cathode = 8'b01110111;
            4'hB       : cathode = 8'b01111100;
            4'hC       : cathode = 8'b00111001;
            4'hD       : cathode = 8'b01011110;
            4'hE       : cathode = 8'b01111001;
            4'hF       : cathode = 8'b01110001;
        endcase
    end


    
    // Both CATHODE and ANODE are active-low
    assign CATHODE = ~cathode;
    assign ANODE   = ~anode;

endmodule
//======================================================================================================================
