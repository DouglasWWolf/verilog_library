`timescale 1ns / 1ps

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//    This RTL core is a demonstration of how to use the AXI4-Lite slave
//
//    This core lets the user store two 32-bit numbers and reports their sum
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 18-Aug-22  DWW  1000  Initial creation
//====================================================================================


module axi4_lite_slave_example
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
    input                                   S_AXI_RREADY
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
    reg[2:0] read_state, write_state;

    // The state machines are idle when they're in state 0 when their "start" signals are low
    assign ashi_widle = (ashi_write == 0) && (write_state == 0);
    assign ashi_ridle = (ashi_read  == 0) && (read_state  == 0);

    // We're going to store data for two 32-bit registers
    reg[31:0] axi_register[0:1];

    // Some convenient human readable names for the AXI registers
    localparam REG_OP1 = 0;     // Operand 1
    localparam REG_OP2 = 1;     // Operand 2
    localparam REG_SUM = 2;     // Sum of the two operands

    // These are the valid values for ashi_rresp and ashi_wresp
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    localparam DECERR = 3;

    // An AXI slave is gauranteed a minimum of 128 bytes of address space
    // (128 bytes is 32 32-bit registers)
    localparam ADDR_MASK = 7'h7F;

    //==========================================================================
    // World's simplest state machine for handling write requests
    //==========================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            write_state       <= 0;
            axi_register[REG_OP1] <= 0;
            axi_register[REG_OP2] <= 0;
        
        // If we're not in reset, and a write-request has occured...        
        end else if (ashi_write) begin
       
            // Assume for the moment that the result will be OKAY
            ashi_wresp <= OKAY;              
            
            // Convert the byte address into a register index
            case ((ashi_waddr & ADDR_MASK) >> 2)
                
                // If they're writing to REG_OP1, store the data
                REG_OP1: axi_register[REG_OP1] <= ashi_wdata;
                
                // If they're writing to REG_OP2, store the data
                REG_OP2: axi_register[REG_OP2] <= ashi_wdata;
                
                // If they're writing to REG_SUM.. ooops!  Slave Error!
                REG_SUM: ashi_wresp <= SLVERR;
                
                // Writes to any other register are a decode-error
                default: ashi_wresp <= DECERR;
            endcase
        end
    end
    //==========================================================================



    //==========================================================================
    // World's simplest state machine for handling read requests
    //==========================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            read_state <= 0;
        
        // If we're not in reset, and a read-request has occured...        
        end else if (ashi_read) begin
       
            // Assume for the moment that the result will be OKAY
            ashi_rresp <= OKAY;              
            
            // Convert the byte address into a register index
            case ((ashi_raddr & ADDR_MASK) >> 2)
                
                // If they're reading REG_OP1, hand it to them
                REG_OP1: ashi_rdata <= axi_register[REG_OP1];

                // If they're reading REG_OP2, hand it to them
                REG_OP2: ashi_rdata <= axi_register[REG_OP2];

                // If they're reading REG_SUM, hand them the sum
                REG_SUM: ashi_rdata <= axi_register[REG_OP1] + axi_register[REG_OP2];

                // Reads of any other register are a decode-error
                default: ashi_rresp <= DECERR;
            endcase
        end
    end
    //==========================================================================





    //==========================================================================
    // This connects us to an AXI4-Lite slave core
    //==========================================================================
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

        // AMCI-read registers
        .ASHI_RADDR     (ashi_raddr),
        .ASHI_RDATA     (ashi_rdata),
        .ASHI_READ      (ashi_read ),
        .ASHI_RRESP     (ashi_rresp),
        .ASHI_RIDLE     (ashi_ridle)
    );
    //==========================================================================

endmodule






