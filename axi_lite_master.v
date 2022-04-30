`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
//////////////////////////////////////////////////////////////////////////////////


module axi4_lite_master#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 32
)
(
    //============================ The AMCI interface ==========================
    input  wire[97:0] AMCI_MOSI,    // AMCI Master Out, Slave In
    output wire[33:0] AMCI_MISO,    // AMCI Master In, Slave Out
    //==========================================================================
    

    //================ From here down is the AXI4-Lite interface ===============
    input wire  M_AXI_ACLK,
    input wire  M_AXI_ARESETN,
        
    // "Specify write address"              -- Master --    -- Slave --
    output wire [AXI_ADDR_WIDTH-1 : 0]      M_AXI_AWADDR,   
    output wire                             M_AXI_AWVALID,  
    input  wire                                             M_AXI_AWREADY,
    output wire  [2 : 0]                    M_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    output wire [AXI_DATA_WIDTH-1 : 0]      M_AXI_WDATA,      
    output wire                             M_AXI_WVALID,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    M_AXI_WSTRB,
    input  wire                                             M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input  wire [1 : 0]                                     M_AXI_BRESP,
    input  wire                                             M_AXI_BVALID,
    output wire                             M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output wire [AXI_ADDR_WIDTH-1 : 0]      M_AXI_ARADDR,     
    output wire                             M_AXI_ARVALID,
    output wire [2 : 0]                     M_AXI_ARPROT,     
    input  wire                                             M_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input  wire [AXI_DATA_WIDTH-1 : 0]                      M_AXI_RDATA,
    input  wire                                             M_AXI_RVALID,
    input  wire [1 : 0]                                     M_AXI_RRESP,
    output wire                             M_AXI_RREADY
    //==========================================================================

);

    localparam AXI_DATA_BYTES = (AXI_DATA_WIDTH/8);

    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   amci_waddr = Address to write to
    //              amci_wdata = Data to write at that address
    //              amci_write = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "amci_widle" goes high
    //              amci_wresp = AXI_BRESP "write response" signal from slave
    //=========================================================================================================
    reg[1:0]                    write_state = 0;

    // FSM user interface inputs
    reg[AXI_ADDR_WIDTH-1:0]     amci_waddr;
    reg[AXI_DATA_WIDTH-1:0]     amci_wdata;
    reg                         amci_write;
    reg[2:0]                    amci_wresp;

    // FSM user interface outputs
    wire                        amci_widle = (write_state == 0 && amci_write == 0);     

    // AXI registers and outputs
    reg[AXI_ADDR_WIDTH-1:0]     m_axi_awaddr;
    reg[AXI_DATA_WIDTH-1:0]     m_axi_wdata;
    reg                         m_axi_awvalid = 0;
    reg                         m_axi_wvalid = 0;
    reg                         m_axi_bready = 0;
    reg                         saw_waddr_ready = 0;
    reg                         saw_wdata_ready = 0;

    // Wire up the AXI interface outputs
    assign M_AXI_AWADDR  = m_axi_awaddr;
    assign M_AXI_WDATA   = m_axi_wdata;
    assign M_AXI_AWVALID = m_axi_awvalid;
    assign M_AXI_WVALID  = m_axi_wvalid;
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_WSTRB   = (1 << AXI_DATA_BYTES) - 1; // usually 4'b1111
    assign M_AXI_BREADY  = m_axi_bready;
    //=========================================================================================================
     
     // Define states that say "An xVALID signal and its corresponding xREADY signal are both asserted"
     wire avalid_and_ready = M_AXI_AWVALID & M_AXI_AWREADY;
     wire wvalid_and_ready = M_AXI_WVALID  & M_AXI_WREADY;
     wire bvalid_and_ready = M_AXI_BVALID  & M_AXI_BREADY;

    always @(posedge M_AXI_ACLK) begin

        // If we're in RESET mode...
        if (M_AXI_ARESETN == 0) begin
            write_state   <= 0;
            m_axi_awvalid <= 0;
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (write_state)
            
            // Here we're idle, waiting for someone to raise the 'amci_write' flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate that the address and data values are valid
            0:  if (amci_write) begin
                    saw_waddr_ready <= 0;           // The slave has not yet asserted AWREADY
                    saw_wdata_ready <= 0;           // The slave has not yet asserted WREADY
                    m_axi_awaddr    <= amci_waddr;  // Place our address onto the bus
                    m_axi_wdata     <= amci_wdata;  // Place our data onto the bus
                    m_axi_awvalid   <= 1;           // Indicate that the address is valid
                    m_axi_wvalid    <= 1;           // Indicate that the data is valid
                    m_axi_bready    <= 1;           // Indicate that we're ready for the slave to respond
                    write_state     <= 1;           // On the next clock cycle, we'll be in the next state
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting M_AXI_AWREADY
           // and M_AXI_WREADY.  Once that happens, we'll de-assert the "valid" lines.  Keep in mind that we
           // don't know what order AWREADY and WREADY will come in, and they could both come at the same
           // time.      
           1:   begin   
                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((saw_waddr_ready || avalid_and_ready) && (saw_wdata_ready || wvalid_and_ready)) begin
                        m_axi_awvalid <= 0;
                        m_axi_wvalid  <= 0;
                        write_state   <= 2;
                    end

                    // Keep track of whether we have seen the slave raise AWREADY
                    if (avalid_and_ready) begin
                        saw_waddr_ready <= 1;
                        m_axi_awvalid   <= 0;
                    end

                    // Keep track of whether we have seen the slave raise WREADY
                    if (wvalid_and_ready) begin
                        saw_wdata_ready <= 1; 
                        m_axi_wvalid    <= 0;
                    end
                end
                
           // Wait around for the slave to assert "M_AXI_BVALID".  When it does, we'll acknowledge
           // it by raising M_AXI_BREADY for one cycle, and go back to idle state
           2:   if (bvalid_and_ready) begin
                    amci_wresp   <= M_AXI_BRESP;
                    m_axi_bready <= 0;
                    write_state  <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //=========================================================================================================
    // FSM logic used for reading from a slave device.
    //
    //  To start:   amci_raddr = Address to read from
    //              amci_read  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "amci_ridle" goes high.
    //            amci_rdata = The data that was read
    //            amci_rresp = The AXI "read response" that is used to indicate success or failure
    //=========================================================================================================
    reg                         read_state = 0;

    // FSM user interface inputs
    reg[AXI_ADDR_WIDTH-1:0]     amci_raddr;
    reg                         amci_read;

    // FSM user interface outputs
    reg[AXI_DATA_WIDTH-1:0]     amci_rdata;
    reg[1:0]                    amci_rresp;
    wire                        amci_ridle = (read_state == 0 && amci_read == 0);     

    // AXI registers and outputs
    reg[AXI_ADDR_WIDTH-1:0]     m_axi_araddr;
    reg                         m_axi_arvalid = 0;
    reg                         m_axi_rready;

    // Wire up the AXI interface outputs
    assign M_AXI_ARADDR  = m_axi_araddr;
    assign M_AXI_ARVALID = m_axi_arvalid;
    assign M_AXI_ARPROT  = 3'b001;
    assign M_AXI_RREADY  = m_axi_rready;
    //=========================================================================================================
    always @(posedge M_AXI_ACLK) begin
         
        if (M_AXI_ARESETN == 0) begin
            read_state    <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready  <= 0;
        end else case (read_state)

            // Here we are waiting around for someone to raise "amci_read", which signals us to begin
            // a AXI read at the address specified in "amci_raddr"
            0:  if (amci_read) begin
                    m_axi_araddr  <= amci_raddr;
                    m_axi_arvalid <= 1;
                    m_axi_rready  <= 1;
                    read_state    <= 1;
                end else begin
                    m_axi_arvalid <= 0;
                    m_axi_rready  <= 0;
                    read_state    <= 0;
                end
            
            // Wait around for the slave to raise M_AXI_RVALID, which tells us that M_AXI_RDATA
            // contains the data we requested
            1:  begin
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                        m_axi_arvalid <= 0;
                    end

                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        amci_rdata    <= M_AXI_RDATA;
                        amci_rresp    <= M_AXI_RRESP;
                        m_axi_rready  <= 0;
                        m_axi_arvalid <= 0;
                        read_state    <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //  Below, we're goiing to wire the "amci_xxx" half of the interface to the input and output ports of
    //  this module.   If you want to adapt this module to use custom drive logic (instead of using it as a
    //  stand-alone AXI bus-master module), remove the wiring below, remove the AMCI ports from this module's
    //  port list, and add your own custom logic below to drive the "amci" registers.
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    


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

    wire[AXI_ADDR_WIDTH-1:0] AMCI_WADDR = AMCI_MOSI[AMCI_WADDR_OFFSET +: AXI_ADDR_WIDTH];
    wire[AXI_DATA_WIDTH-1:0] AMCI_WDATA = AMCI_MOSI[AMCI_WDATA_OFFSET +: AXI_DATA_WIDTH];
    wire[AXI_ADDR_WIDTH-1:0] AMCI_RADDR = AMCI_MOSI[AMCI_RADDR_OFFSET +: AXI_ADDR_WIDTH];
    wire AMCI_WRITE                     = AMCI_MOSI[AMCI_WRITE_OFFSET +: 1];
    wire AMCI_READ                      = AMCI_MOSI[AMCI_READ_OFFSET  +: 1];

    wire[AXI_DATA_WIDTH-1:0] AMCI_RDATA = AMCI_MISO[AMCI_RDATA_OFFSET +: AXI_DATA_WIDTH];
    wire                     AMCI_WIDLE = AMCI_MISO[AMCI_WIDLE_OFFSET +: 1];
    wire                     AMCI_RIDLE = AMCI_MISO[AMCI_RIDLE_OFFSET +: 1];
    //=========================================================================================================


    //=========================================================================================================
    // Wire the "write-to-slave" FSM inputs and outputs to the module ports
    //=========================================================================================================
    always @(*) begin
        amci_waddr <= AMCI_WADDR;
        amci_wdata <= AMCI_WDATA;
        amci_write <= AMCI_WRITE;
    end
    assign AMCI_WIDLE = amci_widle;    
    //=========================================================================================================

    //=========================================================================================================
    // Wire the "read-from-slave" FSM inputs and outputs to the module ports
    //=========================================================================================================
    always @(*) begin
        amci_raddr <= AMCI_RADDR;
        amci_read  <= AMCI_READ;
    end 
    assign AMCI_RIDLE = amci_ridle;
    assign AMCI_RDATA = amci_rdata;
    //=========================================================================================================

endmodule