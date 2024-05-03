//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 02-May-22  DWW     1  Initial creation
//====================================================================================

/*

     This module serves as an example of an AXI4-Lite Master

*/


module dance_master # (parameter FREQ_HZ = 100000000, SLAVE_ADDR = 32'h1000)
(

    input wire clk, resetn,

    input button,

    //====================  An AXI-Lite Master Interface  ======================

    // "Specify write address"          -- Master --    -- Slave --
    output[31:0]                        M_AXI_AWADDR,   
    output                              M_AXI_AWVALID,  
    input                                               M_AXI_AWREADY,

    // "Write Data"                     -- Master --    -- Slave --
    output[31:0]                        M_AXI_WDATA,      
    output                              M_AXI_WVALID,
    output[3:0]                         M_AXI_WSTRB,
    input                                               M_AXI_WREADY,

    // "Send Write Response"            -- Master --    -- Slave --
    input[1:0]                                          M_AXI_BRESP,
    input                                               M_AXI_BVALID,
    output                              M_AXI_BREADY,

    // "Specify read address"           -- Master --    -- Slave --
    output[31:0]                        M_AXI_ARADDR,     
    output                              M_AXI_ARVALID,
    input                                               M_AXI_ARREADY,

    // "Read data back to master"       -- Master --    -- Slave --
    input[31:0]                                         M_AXI_RDATA,
    input                                               M_AXI_RVALID,
    input[1:0]                                          M_AXI_RRESP,
    output                              M_AXI_RREADY
    //==========================================================================
);


//==========================================================================
// We use these as the AMCI interface to an AXI4-Lite Master
//==========================================================================
reg[31:0]  AMCI_WADDR;
reg[31:0]  AMCI_WDATA;
reg        AMCI_WRITE;
wire[1:0]  AMCI_WRESP;
wire       AMCI_WIDLE;
reg[31:0]  AMCI_RADDR;
reg        AMCI_READ;
wire[31:0] AMCI_RDATA;
wire[1:0]  AMCI_RRESP;
wire       AMCI_RIDLE;
//==========================================================================

// This is the state of our state machine
reg[3:0] fsm_state;

// This is a countdown timer for implementing delays
reg[31:0] delay;

//==========================================================================
// This state machine alternates sending 0xAAAA and 0x5555 to an AXI slave,
// with a 250ms delay after each transaction
//==========================================================================
always @(posedge clk) begin
    
    AMCI_READ <= 0;
    AMCI_WRITE <= 0;
    
    if (delay) delay <= delay - 1;

    if (resetn == 0) begin
        fsm_state <= 0;
        delay     <= 0;
    end else case (fsm_state)

        // Wait for the button to be pressed
        0:  if (button) fsm_state <= fsm_state + 1;
        
        // If the timer has expired, send 'AAAA' to the LED slave
        1:  if (delay == 0) begin
                AMCI_WADDR <= SLAVE_ADDR;
                AMCI_WDATA <= 16'hAAAA;
                AMCI_WRITE <= 1;
                fsm_state  <= fsm_state + 1;
            end

        // When the write transaction is complete, start a timer
        2:  if (AMCI_WIDLE) begin
                delay     <= FREQ_HZ / 4;
                fsm_state <= fsm_state + 1;
            end

        // After the timer has expired, send '5555' to the LED slave
        3:  if (delay == 0) begin
                AMCI_WADDR <= SLAVE_ADDR;
                AMCI_WDATA <= 16'h5555;
                AMCI_WRITE <= 1;
                fsm_state  <= fsm_state + 1;
            end

        // When the write transaction has completed, start a timer
        4:  if (AMCI_WIDLE) begin
                delay     <= FREQ_HZ / 5;
                fsm_state <= 1;
            end

    endcase

end
//==========================================================================


//==========================================================================
// This wires a connection to an AXI4-Lite bus master
//==========================================================================
axi4_lite_master
(
    .clk            (clk),
    .resetn         (resetn),
    .AMCI_WADDR     (AMCI_WADDR),
    .AMCI_WDATA     (AMCI_WDATA),
    .AMCI_WRITE     (AMCI_WRITE),
    .AMCI_WRESP     (AMCI_WRESP),
    .AMCI_WIDLE     (AMCI_WIDLE),

    .AMCI_RADDR     (AMCI_RADDR),
    .AMCI_READ      (AMCI_READ ),
    .AMCI_RDATA     (AMCI_RDATA),
    .AMCI_RRESP     (AMCI_RRESP),
    .AMCI_RIDLE     (AMCI_RIDLE),

    .AXI_AWADDR     (M_AXI_AWADDR),
    .AXI_AWVALID    (M_AXI_AWVALID),
    .AXI_AWREADY    (M_AXI_AWREADY),

    .AXI_WDATA      (M_AXI_WDATA),
    .AXI_WVALID     (M_AXI_WVALID),
    .AXI_WSTRB      (M_AXI_WSTRB),
    .AXI_WREADY     (M_AXI_WREADY),

    .AXI_BRESP      (M_AXI_BRESP),
    .AXI_BVALID     (M_AXI_BVALID),
    .AXI_BREADY     (M_AXI_BREADY),

    .AXI_ARADDR     (M_AXI_ARADDR),
    .AXI_ARVALID    (M_AXI_ARVALID),
    .AXI_ARREADY    (M_AXI_ARREADY),

    .AXI_RDATA      (M_AXI_RDATA),
    .AXI_RVALID     (M_AXI_RVALID),
    .AXI_RRESP      (M_AXI_RRESP),
    .AXI_RREADY     (M_AXI_RREADY)
);
//==========================================================================



endmodule