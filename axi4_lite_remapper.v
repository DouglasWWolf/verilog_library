//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 20-Sep-22  DWW  1000  Initial creation
//====================================================================================


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
// This module maps an AXI network into the specified AXI address space.   It is
// especially useful when the AXI busses of two different FPGAs have been bridged
// together and you wish to hoist the AXI-Lite register addresses on the remote system
// into some pre-selected region of local AXI address space.
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

module axi4_lite_remapper#
(
    parameter integer AXI_DATA_WIDTH   = 32,
    parameter integer AXI_ADDR_WIDTH   = 32,
    parameter integer REMOTE_BASE_ADDR = 32'h0000_0000,
    parameter integer LOCAL_BASE_ADDR  = 32'h4000_0000
)
(
    // This clock doesn't actually do anything, and is just here to prevent
    // Vivado from complaining that our module looks like it has AXI interfaces
    // but doesn't have a clock
    input clk,

    //=================== An AXI-Lite Slave Interface ==========================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[AXI_ADDR_WIDTH-1:0]               S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output reg                                              S_AXI_AWREADY,
    input[2:0]                              S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[AXI_DATA_WIDTH-1:0]               S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output reg                                              S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output reg[1:0]                                             S_AXI_BRESP,
    output reg                                              S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[AXI_ADDR_WIDTH-1:0]                               S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,     
    output reg                                              S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output reg[AXI_DATA_WIDTH-1:0]                          S_AXI_RDATA,
    output reg                                              S_AXI_RVALID,
    output reg[1:0]                                         S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //==========================================================================



    //===================  An AXI-Lite Master Interface  =======================

    // "Specify write address"          -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     M_AXI_AWADDR,   
    output reg                          M_AXI_AWVALID,  
    output reg [2:0]                    M_AXI_AWPROT,
    input                                               M_AXI_AWREADY,

    // "Write Data"                     -- Master --    -- Slave --
    output reg [AXI_DATA_WIDTH-1:0]     M_AXI_WDATA,      
    output reg                          M_AXI_WVALID,
    output reg [(AXI_DATA_WIDTH/8)-1:0] M_AXI_WSTRB,
    input                                               M_AXI_WREADY,

    // "Send Write Response"            -- Master --    -- Slave --
    input      [1:0]                                    M_AXI_BRESP,
    input                                               M_AXI_BVALID,
    output reg                          M_AXI_BREADY,

    // "Specify read address"           -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     M_AXI_ARADDR,     
    output reg                          M_AXI_ARVALID,
    output reg [2:0]                    M_AXI_ARPROT,     
    input                                               M_AXI_ARREADY,

    // "Read data back to master"       -- Master --    -- Slave --
    input [AXI_DATA_WIDTH-1:0]                          M_AXI_RDATA,
    input                                               M_AXI_RVALID,
    input [1:0]                                         M_AXI_RRESP,
    output reg                          M_AXI_RREADY
    //==========================================================================

);

    // This is the delta between the base address of the remote register block and 
    // the base address of where we wish to map that register block into local AXI
    // address space.
    localparam ADDR_OFFSET = (LOCAL_BASE_ADDR - REMOTE_BASE_ADDR);

    // Any time an input signal changes, change the corresponding output signal
    always @(*) begin
    
        M_AXI_AWADDR  <= S_AXI_AWADDR - ADDR_OFFSET;
        M_AXI_AWVALID <= S_AXI_AWVALID;
        M_AXI_AWPROT  <= S_AXI_AWPROT;
        S_AXI_AWREADY <= M_AXI_AWREADY;

        M_AXI_WDATA   <= S_AXI_WDATA;
        M_AXI_WVALID  <= S_AXI_WVALID;
        M_AXI_WSTRB   <= S_AXI_WSTRB;
        S_AXI_WREADY  <= M_AXI_WREADY;

        S_AXI_BRESP   <= M_AXI_BRESP;
        S_AXI_BVALID  <= M_AXI_BVALID;
        M_AXI_BREADY  <= S_AXI_BREADY;

        M_AXI_ARADDR  <= S_AXI_ARADDR - ADDR_OFFSET;
        M_AXI_ARVALID <= S_AXI_ARVALID;
        M_AXI_ARPROT  <= S_AXI_ARPROT;
        S_AXI_ARREADY <= M_AXI_ARREADY;

        S_AXI_RDATA   <= M_AXI_RDATA;
        S_AXI_RVALID  <= M_AXI_RVALID;
        S_AXI_RRESP   <= M_AXI_RRESP;
        M_AXI_RREADY  <= S_AXI_RREADY;
    end

endmodule