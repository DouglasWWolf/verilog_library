`timescale 1ns/100ps
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
// This RTL core tokenizes an input string into space and/or comma delimited tokens
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changess
//====================================================================================
// 18-Aug-22  DWW  1000  Initial creation
//====================================================================================

module tokenizer#
(
    parameter AXI_DATA_WIDTH  = 256,
    parameter AXI_ADDR_WIDTH  =  32,
    parameter TOKEN_WIDTH     = 256,
    parameter STR_ADDR_OFFSET = 64'h0,
    parameter OUT_ADDR_OFFSET = 64'h0
    
)
(
    input clk, resetn,

    // The RAM addresses of the input string and the output buffer
    input[AXI_ADDR_WIDTH-1:0] STR_ADDR, OUT_ADDR,

    // This is the first token we parse
    output reg[TOKEN_WIDTH-1:0] FIRST_TOKEN,

    // This will strobe high for one cycle when we should start
    input START,
    
    // This will be high when the tokenization engine is idle
    output IDLE,

    //======================  An AXI Master Interface  =========================

    // "Specify write address"         -- Master --    -- Slave --
    output[AXI_ADDR_WIDTH-1:0]         AXI_AWADDR,   
    output                             AXI_AWVALID,  
    output[2:0]                        AXI_AWPROT,
    output[3:0]                        AXI_AWID,
    output[7:0]                        AXI_AWLEN,
    output[2:0]                        AXI_AWSIZE,
    output[1:0]                        AXI_AWBURST,
    output                             AXI_AWLOCK,
    output[3:0]                        AXI_AWCACHE,
    output[3:0]                        AXI_AWQOS,
    input                                              AXI_AWREADY,


    // "Write Data"                    -- Master --    -- Slave --
    output[AXI_DATA_WIDTH-1:0]         AXI_WDATA,      
    output                             AXI_WVALID,
    output[(AXI_DATA_WIDTH/8)-1:0]     AXI_WSTRB,
    output                             AXI_WLAST,
    input                                              AXI_WREADY,


    // "Send Write Response"           -- Master --    -- Slave --
    input [1:0]                                        AXI_BRESP,
    input                                              AXI_BVALID,
    output                             AXI_BREADY,

    // "Specify read address"          -- Master --    -- Slave --
    output[AXI_ADDR_WIDTH-1:0]         AXI_ARADDR,     
    output                             AXI_ARVALID,
    output[2:0]                        AXI_ARPROT,     
    output                             AXI_ARLOCK,
    output[3:0]                        AXI_ARID,
    output[7:0]                        AXI_ARLEN,
    output[2:0]                        AXI_ARSIZE,
    output[1:0]                        AXI_ARBURST,
    output[3:0]                        AXI_ARCACHE,
    output[3:0]                        AXI_ARQOS,
    input                                              AXI_ARREADY,

    // "Read data back to master"      -- Master --    -- Slave --
    input [AXI_DATA_WIDTH-1:0]                       AXI_RDATA,
    input                                              AXI_RVALID,
    input [1:0]                                        AXI_RRESP,
    input                                              AXI_RLAST,
    output                             AXI_RREADY
    //==========================================================================

);
    // The width of AXI_ARSIZE and AXI_AWSIZE
    localparam AXI_SIZE_WIDTH = 3;
    
    // The width of AXI_ARRESP and AXI_AWRESP
    localparam AXI_RESP_WIDTH = 2;

    //========================================================================================
    //           Define an AXI Master Control Interface for controlling the AXI bus
    //========================================================================================
    reg [AXI_ADDR_WIDTH-1:0] amci_waddr;
    reg [AXI_DATA_WIDTH-1:0] amci_wdata;
    reg [AXI_SIZE_WIDTH-1:0] amci_wsize;
    reg                      amci_write;
    wire[AXI_RESP_WIDTH-1:0] amci_wresp;
    wire                     amci_widle;
    

    wire[AXI_ADDR_WIDTH-1:0] amci_raddr;
    wire[AXI_SIZE_WIDTH-1:0] amci_rsize;
    wire                     amci_read;
    wire[AXI_DATA_WIDTH-1:0] amci_rdata;
    wire[AXI_RESP_WIDTH-1:0] amci_rresp;
    wire                     amci_ridle;
    //========================================================================================


    //========================================================================================
    // Define an interface to the input stream module
    //========================================================================================
    reg [1:0]                istream_cmd;
    reg [AXI_ADDR_WIDTH-1:0] istream_addr;
    wire[7:0]                istream_data;
    wire                     istream_valid;
    //========================================================================================


    //========================================================================================
    // Define an interface to the strtoul (ASCII to integer conversion) module
    //========================================================================================
    reg                      strtoul_start;
    wire[1:0]                strtoul_status;
    wire[63:0]               strtoul_result;
    //========================================================================================


    // Determine how many bytes wide a token is
    localparam TOKEN_BYTES = TOKEN_WIDTH / 8;

    // Commands we send to the character read-stream core
    localparam ISTREAM_START         = 1;
    localparam ISTREAM_GET_NEXT_BYTE = 2;
    
    // States of the tokenizer state machine
    localparam tsm_IDLE                 = 0;
    localparam tsm_START_NEW_TOKEN      = 1;
    localparam tsm_PARSE_TOKEN          = 2;
    localparam tsm_REACHED_END_OF_TOKEN = 3;
    localparam tsm_WAIT_FOR_CONVERSION  = 4;
    localparam tsm_WRITE_TOKEN_TO_RAM   = 5;
    localparam tsm_SKIP_TRAILING_SPACES = 6;
    localparam tsm_SKIP_TRAILING_COMMA  = 7;
    localparam tsm_TOKENIZING_COMPLETE  = 8;
    localparam tsm_FINISH_UP            = 9;

    // The state of the tokenizer state-machine
    reg[3:0] tsm_state;

    // This will always be 0, ASCII ', or ASCII "
    reg[7:0] in_quotes;

    // This is the token currently being parsed
    reg[TOKEN_WIDTH-1:0] token;

    // This is the output address of the next token we parse
    reg[AXI_ADDR_WIDTH-1:0] out_addr;

    // This is the number of tokens that have been output
    reg[7:0] token_count;

    //========================================================================================
    // state machine for parsing tokens
    //========================================================================================
    assign IDLE = (tsm_state == 0) && (START == 0);
    //========================================================================================
    always @(posedge clk) begin

        // These signals should only strobe high for one cycle
        istream_cmd   <= 0;
        amci_write    <= 0;
        strtoul_start <= 0;

        if (resetn == 0) begin
            tsm_state <= tsm_IDLE;
        end else case(tsm_state)

        // When we're told to start, tell the character input-stream to start
        tsm_IDLE:
            if (START) begin
                token_count  <= 0;
                FIRST_TOKEN  <= 0;
                istream_addr <= STR_ADDR + STR_ADDR_OFFSET;
                out_addr     <= OUT_ADDR + OUT_ADDR_OFFSET;
                istream_cmd  <= ISTREAM_START;
                tsm_state    <= tsm_START_NEW_TOKEN;
            end

        // Here we are skipping over any leading spaces before our token
        tsm_START_NEW_TOKEN:

            // If we have a valid character from the input stream...
            if (istream_valid) begin

                // If that character is a space, skip over it
                if (istream_data == " ") istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                
                // If that character is nul, we've hit the end of the input stream
                else if (istream_data == 0) tsm_state <= tsm_TOKENIZING_COMPLETE;
                
                // Otherwise, we're at the first character of a new token
                else begin

                    // For the moment, assume the first character isn't ' or "
                    in_quotes <= 0;
                    
                    // If the first character of the token is ' or "...
                    if (istream_data == 34 || istream_data == 39) begin
                        
                        // Store the type of quotation mark 
                        in_quotes <= istream_data;

                        // And throw away the quotation mark
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                    
                    // Initialize the result field we're parsing our token into
                    token <= 0;

                    // And go parse the token into the "token" register
                    tsm_state <= tsm_PARSE_TOKEN;
                end
            end

        // Here we're going to loop through incoming characters, appending them to our token
        tsm_PARSE_TOKEN:

            // If we have a valid character from the input stream...
            if (istream_valid) begin
                
                // If we're inside of a quoted string...
                if (in_quotes) begin

                    // If we've just hit the closing quote, skip over it, otherwise, append
                    // this character to our token
                    if (istream_data == in_quotes) begin
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                        tsm_state   <= tsm_REACHED_END_OF_TOKEN;
                    end else begin
                        token       <= (token << 8) | istream_data;
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                end
                
                // Otherwise, we're not in a quoted string. 
                else begin
                    
                    // If we just hit a space, comma, or nul, this is the end of this token
                    if (istream_data == " " || istream_data == "," || istream_data == 0)
                        tsm_state   <= tsm_REACHED_END_OF_TOKEN;
                    
                    // Otherwise, append this character to the token, and fetch a new character
                    else begin   
                        token       <= (token << 8) | istream_data;
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                end
            end

        // When we reach the end of a token, start the task that checks
        // to see if the token is an ASCII hex or decimal string, and 
        // (if it is) convert that to a 64-bit integer
        tsm_REACHED_END_OF_TOKEN:
            begin
                strtoul_start <= 1;
                tsm_state     <= tsm_WAIT_FOR_CONVERSION;
            end

        // Here, we wait for the (potential) ASCII-to-integer conversion to complete
        tsm_WAIT_FOR_CONVERSION:

            // If the ASCII-to-integer conversion is complete...
            if (strtoul_status) begin
                
                // If the input token was a numeric ASCII value...
                if (strtoul_status > 1) begin
                    
                    // Replace our token with the integer result
                    token <= strtoul_result;
                    
                    // And mark this token as an integer value
                    token[TOKEN_WIDTH-1] <= 1;
                end

                // Go write this token to RAM
                tsm_state <= tsm_WRITE_TOKEN_TO_RAM;
            end

        tsm_WRITE_TOKEN_TO_RAM:

            // If the AMCI interface is ready for a command...
            if (amci_widle) begin

                // If this is the first token in the string, report it to our user
                if (token_count == 0) FIRST_TOKEN <= token;

                // Keep track of how many tokens we parse
                token_count <= token_count + 1;

                // We're going to write the token to out_addr
                amci_waddr <= out_addr;
                
                // The data we're going to write there is our token
                amci_wdata <= token;
                
                // The size of the AXI write is the length of our token 
                amci_wsize <= $clog2(TOKEN_BYTES);
                
                // Tell the AXI interface to write our data
                amci_write <= 1;

                // Bump the output address for next time
                out_addr <= out_addr + TOKEN_BYTES;

                // And go to the next step of character parsing
                tsm_state  <= tsm_SKIP_TRAILING_SPACES;
            end

        // Here, we skip past any trailing spaces after our token
        tsm_SKIP_TRAILING_SPACES:
            if (istream_valid) begin
                if (istream_data == " ")
                    istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                else
                    tsm_state   <= tsm_SKIP_TRAILING_COMMA;
            end

        // Check to see if there is a trailing comma.  If so, skip over it.
        // One way or another, go start parsing a new token
        tsm_SKIP_TRAILING_COMMA:
            if (istream_valid) begin
                if (istream_data == ",") istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                tsm_state <= tsm_START_NEW_TOKEN;
            end

        // We've parsed the last token, so append an empty token to the output
        tsm_TOKENIZING_COMPLETE:
            if (amci_widle) begin
                amci_waddr <= out_addr;
                amci_wdata <= 0;
                amci_wsize <= $clog2(TOKEN_BYTES);
                amci_write <= 1;
                tsm_state <= tsm_IDLE;
            end

        // Wait for the last write-to-RAM to complete, the return to idle state
        tsm_FINISH_UP:
            if (amci_widle) tsm_state <= tsm_IDLE;

        endcase

    end

    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                     From here down are instantiations of sub-modules
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


    //========================================================================================
    // axi4_noburst_master - Provides bus-mastering services for the AXI bus
    //========================================================================================
    axi4_noburst_master#
    (
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) axi_master
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (AXI_AWADDR),
        .AXI_AWVALID    (AXI_AWVALID),   
        .AXI_AWPROT     (AXI_AWPROT),
        .AXI_AWREADY    (AXI_AWREADY),
        .AXI_AWID       (AXI_AWID),
        .AXI_AWLEN      (AXI_AWLEN),
        .AXI_AWSIZE     (AXI_AWSIZE),
        .AXI_AWBURST    (AXI_AWBURST),
        .AXI_AWLOCK     (AXI_AWLOCK),
        .AXI_AWCACHE    (AXI_AWCACHE),
        .AXI_AWQOS      (AXI_AWQOS),
        
        // AXI W channel
        .AXI_WDATA      (AXI_WDATA),
        .AXI_WVALID     (AXI_WVALID),
        .AXI_WSTRB      (AXI_WSTRB),
        .AXI_WLAST      (AXI_WLAST),
        .AXI_WREADY     (AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (AXI_BRESP),
        .AXI_BVALID     (AXI_BVALID),
        .AXI_BREADY     (AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (AXI_ARADDR), 
        .AXI_ARVALID    (AXI_ARVALID),
        .AXI_ARPROT     (AXI_ARPROT),
        .AXI_ARLOCK     (AXI_ARLOCK),
        .AXI_ARID       (AXI_ARID),
        .AXI_ARLEN      (AXI_ARLEN),
        .AXI_ARSIZE     (AXI_ARSIZE),
        .AXI_ARBURST    (AXI_ARBURST),
        .AXI_ARCACHE    (AXI_ARCACHE),
        .AXI_ARQOS      (AXI_ARQOS),
        .AXI_ARREADY    (AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (AXI_RDATA),
        .AXI_RVALID     (AXI_RVALID),
        .AXI_RRESP      (AXI_RRESP),
        .AXI_RLAST      (AXI_RLAST),
        .AXI_RREADY     (AXI_RREADY),

        // AMCI-write register
        .AMCI_WADDR     (amci_waddr),
        .AMCI_WDATA     (amci_wdata),
        .AMCI_WSIZE     (amci_wsize),
        .AMCI_WRITE     (amci_write),
        .AMCI_WRESP     (amci_wresp),
        .AMCI_WIDLE     (amci_widle),

        // AMCI-read registers
        .AMCI_RADDR     (amci_raddr),
        .AMCI_RDATA     (amci_rdata),
        .AMCI_RSIZE     (amci_rsize),
        .AMCI_READ      (amci_read ),
        .AMCI_RRESP     (amci_rresp),
        .AMCI_RIDLE     (amci_ridle)
    );
    //========================================================================================



    //========================================================================================
    // char_istream : An input stream of 8-bit bytes (i.e. characters)
    //========================================================================================
    char_istream#(.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(AXI_DATA_WIDTH)) istream
    (
        
        // Clock and reset
        .clk        (clk),
        .resetn     (resetn),
        
        // Input stream control
        .CMD        (istream_cmd),
        .ADDR       (istream_addr),
        .VALID      (istream_valid),
        .DATA       (istream_data),
        
        // AMCI interface to the AXI bus
        .AMCI_RADDR (amci_raddr),
        .AMCI_RSIZE (amci_rsize),
        .AMCI_READ  (amci_read),
        .AMCI_RDATA (amci_rdata),
        .AMCI_RRESP (amci_rresp),
        .AMCI_RIDLE (amci_ridle)
    );
    //========================================================================================


    //========================================================================================
    // strtoul : Converts an ASCII string to a 64-bit integer
    //========================================================================================
    strtoul#(.STR_WIDTH(TOKEN_WIDTH)) i_strtoul
    (
        .clk    (clk),
        .resetn (resetn),
        .START  (strtoul_start),
        .INPSTR (token),
        .STATUS (strtoul_status),
        .RESULT (strtoul_result)
    );
    //========================================================================================

endmodule

