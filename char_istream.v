`timescale 1ns / 1ps


//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 10-Aug-22  DWW  1000  Initial creation
//====================================================================================


//====================================================================================
// This module feeds 8-bit bytes to the output DATA port any time the user issues the 
// GET_NEXT_BYTE command.   VALID is high when there is valid data on the DATA port.
//
// The first AXI_DATA_WIDTH bits-wide word is initially loaded from RAM with the START
// command.
//
// A command is one cycle wide; if the user holds the CMD register in state 
// GET_NEXT_BYTE for two consecutive clock cycles, two consecutive bytes will
// be fetched.
//
// Be aware that DATA is <usually> valid on the cycle after a GET_NEXT_BYTE command, 
// but not always.   Use the VALID flag to determine if DATA is valid.
//=====================================================================================


module char_istream#
(
    parameter integer AXI_DATA_WIDTH = 256,
    parameter integer AXI_ADDR_WIDTH = 32
)
(
    input clk, resetn,

    //=================================================================================
    //                A command interface for our connected client
    //=================================================================================
    input [1:0]                CMD,
    input [AXI_ADDR_WIDTH-1:0] ADDR,
    output                     VALID,
    output[7:0]                DATA,
    //=================================================================================
    

    //=================================================================================
    //             An AMCI interface for fetching data from RAM
    //=================================================================================
    output reg[AXI_ADDR_WIDTH-1:0] AMCI_RADDR,
    output[2:0]                    AMCI_RSIZE,
    output reg                     AMCI_READ,
    input[AXI_DATA_WIDTH-1:0]      AMCI_RDATA,
    input[1:0]                     AMCI_RRESP,
    input                          AMCI_RIDLE
    //=================================================================================
);


    genvar x;
    localparam AXI_DATA_BYTES = AXI_DATA_WIDTH / 8;
    localparam FULL_WIDTH     = $clog2(AXI_DATA_BYTES);

    localparam START          = 1;
    localparam GET_NEXT_BYTE  = 2;
    localparam NO_CHAR        = 8'hFF;
    localparam INVALID_INDEX  = AXI_DATA_BYTES + 1;

    
    // The state of the "stream characters" state machine
    reg[1:0] scstate;

    // The word fetched from RAM that is currently being processed
    reg[AXI_DATA_WIDTH-1:0] ram_word;
    
    // The address of the next RAM word we need to fetch
    reg[AXI_ADDR_WIDTH-1:0] ram_addr;
    
    // This is going to get mapped to "ram_word"
    wire[7:0] ram_char[0:AXI_DATA_BYTES-1];

    // Turn "ram_char" into an array of bytes on top of ram_word
    for (x=0; x<AXI_DATA_BYTES; x=x+1) assign ram_char[x] = ram_word[8*x +: 8];

    // This is the index (in ram_char) of the next data-byte that will be output
    reg[7:0] char_idx;

    // DATA is driven by one of these, depending on the value of CMD
    reg[7:0] this_char, next_char;

    // This is part of what controls the VALID port
    reg valid;

    // Our data-reads will be full bus-width reads
    assign AMCI_RSIZE = FULL_WIDTH; 

    // We're not outputting valid data during either a START command or on a GET_NEXT_BYTE 
    // command that we have insufficient data to fulfill.
    assign VALID = (valid && ~(CMD == START) && ~(CMD == GET_NEXT_BYTE && char_idx == INVALID_INDEX));
    
    // There is nothing in this algorithm that relies on the existence of the NO_CHAR 
    // character.  We output the NO_CHAR character only because it's easy to see in the
    // Vivado ILA at debug time.  This RTL code would not be affected if we remove the 
    // outputting of NO_CHAR when VALID is inactive.
    assign DATA = (VALID == 0)           ? NO_CHAR   :
                  (CMD == GET_NEXT_BYTE) ? next_char : this_char;

    //=================================================================================
    // This is the state machine that actually performs tokenization
    //=================================================================================
    always @(posedge clk) begin
        
        // When this is raised, it should strobe high for exactly one clock-cycle
        AMCI_READ <= 0;

        if (resetn == 0) begin
            valid      <= 0;
            scstate    <= 0;
        end else case(scstate)
        
            // Here we're idle and waiting to receive a command
            // If we receive a START command, go fetch the first word from RAM
            0:  if (CMD == START) begin
                    valid   <= 0;
                    scstate <= 1; 
                end 
                
                // Otherwise, if we receive a GET_NEXT_BYTE command...
                else if (CMD == GET_NEXT_BYTE) begin

                    // If we don't have enough data to satisfy the request...
                    if (char_idx == INVALID_INDEX) begin
                        
                        // Make sure the VALID line stays low and go fetch a the next RAM word
                        valid   <= 0;
                        scstate <= 2;
                    
                    // We get here if we DO have enough data to satisfy the request
                    end else begin
                        this_char <= next_char;
                        next_char <= ram_char[char_idx];
                        char_idx  <= char_idx + 1;
                    end

                end
            

            // Start a read of the RAM address specified at the interface
            1:  if (AMCI_RIDLE) begin
                    AMCI_RADDR <= ADDR;
                    AMCI_READ  <= 1;
                    ram_addr   <= ADDR + AXI_DATA_BYTES;
                    scstate    <= 2;
                end

                
            // If the AXI read from RAM has completed...
            2:  if (AMCI_RIDLE) begin
                    
                    // Fetch the word we just read from RAM
                    ram_word <= AMCI_RDATA;
                    
                    // Pre-fetch the next RAM word that we're going to need
                    AMCI_RADDR <= ram_addr;
                    AMCI_READ  <= 1;

                    // Bump the RAM address we read for next time
                    ram_addr <= ram_addr + AXI_DATA_BYTES;

                    // "DATA" is now valid
                    this_char <= AMCI_RDATA[ 7:0];
                    next_char <= AMCI_RDATA[15:8];
                    valid     <= 1;
                    char_idx  <= 2;

                    // And go back to idle state
                    scstate <= 0;
                end 
        endcase
    end

endmodule
