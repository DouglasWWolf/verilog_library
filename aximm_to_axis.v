//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 22-Feb-24  DWW     1  Initial creation
//====================================================================================

/*

    This module converts the W-channel of an AXI-MM interface into an AXI stream.

    In order to use this converter, you really only need to hook up the following
    signals:

    clk
    resetn,
    S_AXI_WDATA
    S_AXI_WVALID
    S_AXI_WREADY

    If your application cares about these signals, you can hook them up and
    they will be propogated into the output stream
    
    S_AXI_WSTRB
    S_AXI_WLAST

    If your application cares about receiving write-acknowledgements on the
    B-channel of S_AXI, you should hook up these signals as well:
    
    S_AXI_BRESP
    S_AXI_BVALID
    S_AXI_BREADY

*/

module aximm_to_axis # (parameter DW=512, parameter AW=64)
(
    input clk, resetn,

    //=================  This is the main AXI4-slave interface  ================
    
    // "Specify write address"              -- Master --    -- Slave --
    input[AW-1:0]                           S_AXI_AWADDR,
    input                                   S_AXI_AWVALID,
    input[3:0]                              S_AXI_AWID,
    input[7:0]                              S_AXI_AWLEN,
    input[2:0]                              S_AXI_AWSIZE,
    input[1:0]                              S_AXI_AWBURST,
    input                                   S_AXI_AWLOCK,
    input[3:0]                              S_AXI_AWCACHE,
    input[3:0]                              S_AXI_AWQOS,
    input[2:0]                              S_AXI_AWPROT,
    output                                                  S_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    input[DW-1:0]                           S_AXI_WDATA,
    input[DW/8-1:0]                         S_AXI_WSTRB,
    input                                   S_AXI_WVALID,
    input                                   S_AXI_WLAST,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[AW-1:0]                           S_AXI_ARADDR,
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,
    input                                   S_AXI_ARLOCK,
    input[3:0]                              S_AXI_ARID,
    input[7:0]                              S_AXI_ARLEN,
    input[1:0]                              S_AXI_ARBURST,
    input[3:0]                              S_AXI_ARCACHE,
    input[3:0]                              S_AXI_ARQOS,
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[DW-1:0]                                          S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    output                                                  S_AXI_RLAST,
    input                                   S_AXI_RREADY,
    
    //==========================================================================


    //==========================================================================
    //                            AXI Stream Output
    //==========================================================================
    output [  DW-1:0] AXIS_OUT_TDATA,
    output [DW/8-1:0] AXIS_OUT_TKEEP,
    output            AXIS_OUT_TLAST,
    output            AXIS_OUT_TVALID,
    input             AXIS_OUT_TREADY
    //==========================================================================
);


// We always accept and discard anything on the W-channel
assign S_AXI_AWREADY = 1;

// We never accept read-requests on the AR channel
assign S_AXI_ARREADY = 0;

// We never send read-data on the R channel
assign S_AXI_RVALID = 0;

// Our output data-stream is the W-channel of the input interface
assign AXIS_OUT_TDATA  = S_AXI_WDATA;
assign AXIS_OUT_TKEEP  = S_AXI_WSTRB;
assign AXIS_OUT_TLAST  = S_AXI_WLAST;
assign AXIS_OUT_TVALID = S_AXI_WVALID;
assign S_AXI_WREADY    = AXIS_OUT_TREADY;

// Write acknowledgements on the B-channel will always be "OKAY"
assign S_AXI_BRESP = 0;

// The number of bursts of data received, and the number of them that we have acknowledged
reg[15:0] bursts_rcvd, bursts_ackd;

// BVALID is asserted while we have acknowledgemts we still need to send
assign S_AXI_BVALID = (bursts_ackd != bursts_rcvd);

// Count the number of bursts we receive.  That's how many acks we need to send
always @(posedge clk) begin
    if (resetn == 0)
        bursts_rcvd <= 0;
    else if (S_AXI_WVALID & S_AXI_WREADY & S_AXI_WLAST)
        bursts_rcvd <= bursts_rcvd + 1;
end

// Count the number of acknowledgements sent
always @(posedge clk) begin
    if (resetn == 0) 
        bursts_ackd <= 0;
    else if (S_AXI_BREADY & S_AXI_BVALID)
        bursts_ackd <= bursts_ackd + 1;
end

endmodule

