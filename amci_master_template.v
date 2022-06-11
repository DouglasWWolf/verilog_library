`timescale 1ns / 1ps

//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 10-May-22  DWW  1000  Initial creation
//====================================================================================


module controller0#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 32
)
(
    input CLK, RESETN, 

    //================= The AMCI (AXI Master Control Interface) ================
    output wire[97:0] AMCI_MOSI,    // AMCI Master Out, Slave In
    input  wire[37:0] AMCI_MISO     // AMCI Master In, Slave Out
    //==========================================================================
);

    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //      From here to the next marker is standard AMCI template code
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


    //==========================================================================
    // Registers for performing AXI4-Lite write transactions
    //==========================================================================
    reg[AXI_ADDR_WIDTH-1:0] amci_waddr;
    reg[AXI_DATA_WIDTH-1:0] amci_wdata;
    reg[1:0]                amci_wresp;
    reg                     amci_write;
    reg                     amci_widle;
    //==========================================================================

    //==========================================================================
    // Registers for performing AXI4-Lite read transactions
    //==========================================================================
    reg[AXI_ADDR_WIDTH-1:0] amci_raddr;
    reg[AXI_DATA_WIDTH-1:0] amci_rdata;
    reg[1:0]                amci_rresp;
    reg                     amci_read;
    reg                     amci_ridle;
    //==========================================================================



    //=========================================================================================================
    // Break out the AMCI_MISO and AMCI_MISO interfaces into discrete ports
    //=========================================================================================================
    localparam AMCI_WADDR_OFFSET = 0;   localparam pa1 = AMCI_WADDR_OFFSET + AXI_ADDR_WIDTH;
    localparam AMCI_WDATA_OFFSET = pa1; localparam pa2 = AMCI_WDATA_OFFSET + AXI_DATA_WIDTH;
    localparam AMCI_RADDR_OFFSET = pa2; localparam pa3 = AMCI_RADDR_OFFSET + AXI_ADDR_WIDTH;
    localparam AMCI_WRITE_OFFSET = pa3; localparam pa4 = AMCI_WRITE_OFFSET + 1;
    localparam AMCI_READ_OFFSET  = pa4; localparam pa5 = AMCI_READ_OFFSET  + 1;

    localparam AMCI_RDATA_OFFSET = 0;   localparam pb1 = AMCI_RDATA_OFFSET + AXI_DATA_WIDTH;
    localparam AMCI_WIDLE_OFFSET = pb1; localparam pb2 = AMCI_WIDLE_OFFSET + 1;
    localparam AMCI_RIDLE_OFFSET = pb2; localparam pb3 = AMCI_RIDLE_OFFSET + 1;
    localparam AMCI_WRESP_OFFSET = pb3; localparam pb4 = AMCI_WRESP_OFFSET + 2;
    localparam AMCI_RRESP_OFFSET = pb4; localparam pb5 = AMCI_RRESP_OFFSET + 2;

    wire[AXI_ADDR_WIDTH-1:0] AMCI_WADDR = AMCI_MOSI[AMCI_WADDR_OFFSET +: AXI_ADDR_WIDTH];
    wire[AXI_DATA_WIDTH-1:0] AMCI_WDATA = AMCI_MOSI[AMCI_WDATA_OFFSET +: AXI_DATA_WIDTH];
    wire[AXI_ADDR_WIDTH-1:0] AMCI_RADDR = AMCI_MOSI[AMCI_RADDR_OFFSET +: AXI_ADDR_WIDTH];
    wire AMCI_WRITE                     = AMCI_MOSI[AMCI_WRITE_OFFSET +: 1];
    wire AMCI_READ                      = AMCI_MOSI[AMCI_READ_OFFSET  +: 1];

    wire[AXI_DATA_WIDTH-1:0] AMCI_RDATA = AMCI_MISO[AMCI_RDATA_OFFSET +: AXI_DATA_WIDTH];
    wire                     AMCI_WIDLE = AMCI_MISO[AMCI_WIDLE_OFFSET +: 1];
    wire                     AMCI_RIDLE = AMCI_MISO[AMCI_RIDLE_OFFSET +: 1];
    wire                     AMCI_WRESP = AMCI_MISO[AMCI_WRESP_OFFSET +: 2];
    wire                     AMCI_RRESP = AMCI_MISO[AMCI_RRESP_OFFSET +: 2];
    //=========================================================================================================


    //=========================================================================================================
    // Wire the "write-to-slave" FSM inputs and outputs to the module ports
    //=========================================================================================================
    always @(*) begin
        amci_widle <= AMCI_WIDLE;
        amci_wresp <= AMCI_WRESP;
    end

    assign AMCI_WADDR = amci_waddr;
    assign AMCI_WDATA = amci_wdata;
    assign AMCI_WRITE = amci_write;
    //=========================================================================================================

    //=========================================================================================================
    // Wire the "read-from-slave" FSM inputs and outputs to the module ports
    //=========================================================================================================
    always @(*) begin
        amci_ridle <= AMCI_RIDLE;
        amci_rresp <= AMCI_RRESP;
        amci_rdata <= AMCI_RDATA;
    end

    assign AMCI_RADDR = amci_raddr;
    assign AMCI_READ  = amci_read;
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                 End of standard AMCI template code
    //
    //                Module specific code below this point
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


endmodule