`timescale 1ns / 1ps

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//                                       Host-to-FPGA IPC Core
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><


//=========================================================================================================
//                               ------->  Revision History  <------
//=========================================================================================================
//
//   Date     Who   Ver  Changes
//=========================================================================================================
// 20-Aug-22  DWW  1000  Initial creation
//=========================================================================================================

module h2f_ipc_core #
(
    // The width of the AXI Master address bus, in bits
    parameter       M_AXI_ADDR_WIDTH = 64,

    // The width of the AXI Master data bus, in bits
    parameter       M_AXI_DATA_WIDTH = 256,

    // Width of a parsed token.  For efficiency, should match M_AXI_DATA_WIDTH
    parameter       TOKEN_WIDTH = 256,

    // The maximum number string entries in our input queue
    parameter[31:0] INPUT_Q_SIZE = 16,   

    // The maximum length of an input string, including nul.  Must be a power of 2
    parameter[31:0] INPUT_STR_MAXLEN = 256,
    
    // The address of the start of our RAM buffer
    parameter[64:0] RAM_START = 64'hC000_0000    
)
(
    input clk, resetn,

    //================== This is an AXI4-Lite slave interface ==================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,
    input[2:0]                              S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,     
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //==========================================================================


    //======================  An AXI Master Interface  =========================

    // "Specify write address"         -- Master --    -- Slave --
    output[M_AXI_ADDR_WIDTH-1:0]       M_AXI_AWADDR,   
    output                             M_AXI_AWVALID,  
    output[2:0]                        M_AXI_AWPROT,
    output[3:0]                        M_AXI_AWID,
    output[7:0]                        M_AXI_AWLEN,
    output[2:0]                        M_AXI_AWSIZE,
    output[1:0]                        M_AXI_AWBURST,
    output                             M_AXI_AWLOCK,
    output[3:0]                        M_AXI_AWCACHE,
    output[3:0]                        M_AXI_AWQOS,
    input                                              M_AXI_AWREADY,


    // "Write Data"                    -- Master --    -- Slave --
    output[M_AXI_DATA_WIDTH-1:0]       M_AXI_WDATA,      
    output                             M_AXI_WVALID,
    output[(M_AXI_DATA_WIDTH/8)-1:0]   M_AXI_WSTRB,
    output                             M_AXI_WLAST,
    input                                              M_AXI_WREADY,


    // "Send Write Response"           -- Master --    -- Slave --
    input [1:0]                                        M_AXI_BRESP,
    input                                              M_AXI_BVALID,
    output                             M_AXI_BREADY,

    // "Specify read address"          -- Master --    -- Slave --
    output[M_AXI_ADDR_WIDTH-1:0]       M_AXI_ARADDR,     
    output                             M_AXI_ARVALID,
    output[2:0]                        M_AXI_ARPROT,     
    output                             M_AXI_ARLOCK,
    output[3:0]                        M_AXI_ARID,
    output[7:0]                        M_AXI_ARLEN,
    output[2:0]                        M_AXI_ARSIZE,
    output[1:0]                        M_AXI_ARBURST,
    output[3:0]                        M_AXI_ARCACHE,
    output[3:0]                        M_AXI_ARQOS,
    input                                              M_AXI_ARREADY,

    // "Read data back to master"      -- Master --    -- Slave --
    input[M_AXI_DATA_WIDTH-1:0]                        M_AXI_RDATA,
    input                                              M_AXI_RVALID,
    input[1:0]                                         M_AXI_RRESP,
    input                                              M_AXI_RLAST,
    output                             M_AXI_RREADY
    //==========================================================================
 );

    //==========================================================================
    // We'll communicate with the AXI4-Lite Slave core with these signals.
    //==========================================================================
    // AXI Slave Handler Interface for write requests
    wire[31:0]  ashi_waddr;     // Input:  Write-address
    wire[31:0]  ashi_wdata;     // Input:  Write-data
    wire        ashi_write;     // Input:  1 = Handle a write request
    reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
    wire        ashi_widle;     // Output: 1 = Write state machine is idle

    // AXI Slave Handler Interface for read requests
    wire[31:0]  ashi_raddr;     // Input:  Read-address
    wire        ashi_read;      // Input:  1 = Handle a read request
    reg[31:0]   ashi_rdata;     // Output: Read data
    reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
    wire        ashi_ridle;     // Output: 1 = Read state machine is idle
    //==========================================================================



    // The state of our two state machines
    reg[2:0] slv_read_state, slv_write_state;

    // The state machines are idle when they're in state 0 when their "start" signals are low
    assign ashi_widle = (ashi_write == 0) && (slv_write_state == 0);
    assign ashi_ridle = (ashi_read  == 0) && (slv_read_state  == 0);

    // Some convenient human readable names for the AXI registers
    localparam REG_Q_WADDR_H = 0; // Read only
    localparam REG_Q_WADDR_L = 1; // Read only
    localparam REG_Q_WRITE   = 2; // Write only

    // These are the valid values for ashi_rresp and ashi_wresp
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    localparam DECERR = 3;

    // An AXI slave is gauranteed a minimum of 128 bytes of address space
    // (128 bytes is 32 32-bit registers)
    localparam ADDR_MASK = 7'h7F;

    // An address that represents "No address available"
    localparam[63:0] NO_ADDR = 64'hFFFF_FFFF_FFFF_FFFF;

    // The queue index where the next incoming entry will be written
    reg[31:0] input_q_windex;
     
    // The queue index where the next entry will be read from
    reg[31:0] input_q_rindex;

    // The number of entries written to and read from the input queue
    reg[63:0] input_q_entries_written, input_q_entries_read;

    // This flag will be high any time the input queue is full
    wire input_q_full = (input_q_entries_written - input_q_entries_read) == INPUT_Q_SIZE;

    // At any given moment this is where the next input string should be written
    wire[63:0] next_input_addr = input_q_full ? NO_ADDR : RAM_START + (input_q_windex << $clog2(INPUT_STR_MAXLEN));

    // When a user reads the REG_Q_WADDR_H register, the address of the next input gets latched here.  We
    // do this so that the user read of REG_Q_WADDR_H and REG_Q_WADDR_L is atomic
    reg[63:0] latched_addr;


    //===============================================================================================
    // Handler for AXI slave read requests
    //===============================================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            slv_read_state <= 0;
            latched_addr   <= NO_ADDR;
        
        // If we're not in reset, and a read-request has occured...        
        end else case (slv_read_state)
       
        // Here we're waiting to be told that an AXI master is reading us
        0:  if (ashi_read) begin
                
                // By default, our response to the AXI master is OKAY
                ashi_rresp <= OKAY;              
                
                // Find out which register they're trying to read
                case ((ashi_raddr & ADDR_MASK) >> 2)

                    // If they want the high 32 bits of the next address to write to...
                    REG_Q_WADDR_H:
                        begin
                            latched_addr <= next_input_addr;
                            ashi_rdata   <= next_input_addr[63:32];
                        end

                    // If they want the low 32-bits of the next address to write to ...
                    REG_Q_WADDR_L:
                        ashi_rdata <= latched_addr[31:0];

                    // Anything else is a "decode error"
                    default: ashi_rresp <= DECERR;

                endcase
            end
        endcase
    end
    //===============================================================================================


    //===============================================================================================
    // Handler for AXI slave write requests
    //===============================================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            slv_write_state         <= 0;
            input_q_windex          <= 0;
            input_q_entries_written <= 0;
        
        // If we're not in reset...
        end else case (slv_write_state)
       
        // Here we're waiting to be told that an AXI master is writing to us
        0:  if (ashi_write) begin
                
                // By default, our response to the AXI master is OKAY
                ashi_wresp <= OKAY;              
                
                // Find out which register they're trying to write to
                case ((ashi_waddr & ADDR_MASK) >> 2)

                    // Is the user telling us they wrote a string into the queue?
                    REG_Q_WRITE:

                        // If they weren't allowed to do so, issue a SLVERR
                        if (latched_addr == NO_ADDR)
                            ashi_wresp <= SLVERR;
                        
                        // Otherwise, we need to take note of this new queue entry, so:
                        else begin

                            // Increment the queue's "write index" using circular arithmetic
                            input_q_windex <= (input_q_windex == INPUT_Q_SIZE-1) ? 0 : input_q_windex +1;
                            
                            // And keep track of how many queue entries have been written
                            input_q_entries_written <= input_q_entries_written + 1;

                        end
    
                    // Anything else is a "decode error"
                    default: ashi_wresp <= DECERR;

                endcase
            end
        endcase
    end
    //===============================================================================================


    //===============================================================================================
    //                      Define an interface to the tokenizer
    //===============================================================================================
    reg [M_AXI_ADDR_WIDTH-1:0] tokenizer_str_addr;
    reg [M_AXI_ADDR_WIDTH-1:0] tokenizer_out_addr;
    wire[TOKEN_WIDTH-1:0]      tokenizer_first_token;
    reg                        tokenizer_start;
    wire                       tokenizer_idle;
    //===============================================================================================

    
    //===============================================================================================
    // This state machine and associated data are the "read" side of the circular input queue.
    //
    // When a new input string is detected waiting in the queue, this state machine parses that 
    // string into tokens and notifies the client that a new message is available to execute
    //===============================================================================================
    reg[2:0] dispatcher_state;

    always @(posedge clk) begin

        // When this is active, it should strobe high for exactly one clock cycle
        tokenizer_start <= 0;

        if (resetn == 0) begin
            dispatcher_state <= 0;
        end else case (dispatcher_state)
        
        // If there is a new input string waiting to be tokenized and dispatched...
        0:  if (input_q_entries_written != input_q_entries_read) begin
                tokenizer_str_addr <= RAM_START + (input_q_rindex << $clog2(INPUT_STR_MAXLEN));
                tokenizer_out_addr <= RAM_START + (INPUT_STR_MAXLEN * INPUT_Q_SIZE);
                tokenizer_start    <= 1;
                dispatcher_state   <= 1;
            end

        // Wait for tokenization process to complete, then...
        1:  if (tokenizer_idle) begin

                // Increment the queue's "read index" using circular arithmetic
                input_q_rindex <= (input_q_rindex == INPUT_Q_SIZE-1) ? 0 : input_q_rindex +1;
                            
                // Keep track of how many queue entries have been read
                input_q_entries_read <= input_q_entries_read + 1;

                // And go back to waiting for input strings to arrive in the queue
                dispatcher_state <= 0;
            end

        endcase
    end
    //===============================================================================================



       //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
       //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
       //                     From here down are instantiations of sub-modules
       //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
       //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>



    //===============================================================================================
    // This connects us to an AXI4-Lite slave core
    //===============================================================================================
    axi4_lite_slave axi_slave
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (S_AXI_AWADDR),
        .AXI_AWVALID    (S_AXI_AWVALID),   
        .AXI_AWPROT     (S_AXI_AWPROT),
        .AXI_AWREADY    (S_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (S_AXI_WDATA),
        .AXI_WVALID     (S_AXI_WVALID),
        .AXI_WSTRB      (S_AXI_WSTRB),
        .AXI_WREADY     (S_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (S_AXI_BRESP),
        .AXI_BVALID     (S_AXI_BVALID),
        .AXI_BREADY     (S_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (S_AXI_ARADDR), 
        .AXI_ARVALID    (S_AXI_ARVALID),
        .AXI_ARPROT     (S_AXI_ARPROT),
        .AXI_ARREADY    (S_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (S_AXI_RDATA),
        .AXI_RVALID     (S_AXI_RVALID),
        .AXI_RRESP      (S_AXI_RRESP),
        .AXI_RREADY     (S_AXI_RREADY),

        // ASHI write-request registers
        .ASHI_WADDR     (ashi_waddr),
        .ASHI_WDATA     (ashi_wdata),
        .ASHI_WRITE     (ashi_write),
        .ASHI_WRESP     (ashi_wresp),
        .ASHI_WIDLE     (ashi_widle),

        // ASHI read-request registers
        .ASHI_RADDR     (ashi_raddr),
        .ASHI_RDATA     (ashi_rdata),
        .ASHI_READ      (ashi_read ),
        .ASHI_RRESP     (ashi_rresp),
        .ASHI_RIDLE     (ashi_ridle)
    );
    //===============================================================================================


    //========================================================================================
    // axi4_noburst_master - Provides bus-mastering services for the AXI bus
    //========================================================================================
    tokenizer#
    (
        .AXI_ADDR_WIDTH (M_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (M_AXI_DATA_WIDTH),
        .TOKEN_WIDTH    (TOKEN_WIDTH)
    ) tokenizer_inst
    (
        // Clock and reset
        .clk            (clk),
        .resetn         (resetn),

        // Tokenizer control
        .STR_ADDR       (tokenizer_str_addr),
        .OUT_ADDR       (tokenizer_out_addr),
        .FIRST_TOKEN    (tokenizer_first_token),
        .START          (tokenizer_start),
        .IDLE           (tokenizer_idle),
    
        // AXI AW channel
        .AXI_AWADDR     (M_AXI_AWADDR),
        .AXI_AWVALID    (M_AXI_AWVALID),   
        .AXI_AWPROT     (M_AXI_AWPROT),
        .AXI_AWREADY    (M_AXI_AWREADY),
        .AXI_AWID       (M_AXI_AWID),
        .AXI_AWLEN      (M_AXI_AWLEN),
        .AXI_AWSIZE     (M_AXI_AWSIZE),
        .AXI_AWBURST    (M_AXI_AWBURST),
        .AXI_AWLOCK     (M_AXI_AWLOCK),
        .AXI_AWCACHE    (M_AXI_AWCACHE),
        .AXI_AWQOS      (M_AXI_AWQOS),
        
        // AXI W channel
        .AXI_WDATA      (M_AXI_WDATA),
        .AXI_WVALID     (M_AXI_WVALID),
        .AXI_WSTRB      (M_AXI_WSTRB),
        .AXI_WLAST      (M_AXI_WLAST),
        .AXI_WREADY     (M_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M_AXI_BRESP),
        .AXI_BVALID     (M_AXI_BVALID),
        .AXI_BREADY     (M_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M_AXI_ARADDR), 
        .AXI_ARVALID    (M_AXI_ARVALID),
        .AXI_ARPROT     (M_AXI_ARPROT),
        .AXI_ARLOCK     (M_AXI_ARLOCK),
        .AXI_ARID       (M_AXI_ARID),
        .AXI_ARLEN      (M_AXI_ARLEN),
        .AXI_ARSIZE     (M_AXI_ARSIZE),
        .AXI_ARBURST    (M_AXI_ARBURST),
        .AXI_ARCACHE    (M_AXI_ARCACHE),
        .AXI_ARQOS      (M_AXI_ARQOS),
        .AXI_ARREADY    (M_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M_AXI_RDATA),
        .AXI_RVALID     (M_AXI_RVALID),
        .AXI_RRESP      (M_AXI_RRESP),
        .AXI_RLAST      (M_AXI_RLAST),
        .AXI_RREADY     (M_AXI_RREADY)
    );
    //========================================================================================



endmodule






