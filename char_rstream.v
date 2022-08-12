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


module char_rstream#
(
    parameter integer AXI_DATA_WIDTH = 256,
    parameter integer AXI_ADDR_WIDTH = 32
)
(
    input  wire[1:0]                CMD,
    input  wire[AXI_ADDR_WIDTH-1:0] ADDR,
    output wire                     VALID,
    output wire[7:0]                DATA,

    //================ This section is the AXI Master interface =====================
    input wire  M_AXI_ACLK,
    input wire  M_AXI_ARESETN,
        
    // "Specify write address"              -- Master --    -- Slave --
    output wire[AXI_ADDR_WIDTH-1:0]         M_AXI_AWADDR,   
    output wire                             M_AXI_AWVALID,  
    input  wire                                             M_AXI_AWREADY,
    output wire[2:0]                        M_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    output wire[AXI_DATA_WIDTH-1 : 0]       M_AXI_WDATA,      
    output wire                             M_AXI_WVALID,
    output wire[(AXI_DATA_WIDTH/8)-1:0]     M_AXI_WSTRB,
    output wire                             M_AXI_WLAST,
    output wire[3:0]                        M_AXI_AWID,
    output wire[7:0]                        M_AXI_AWLEN,
    output wire[2:0]                        M_AXI_AWSIZE,
    output wire[1:0]                        M_AXI_AWBURST,
    output wire                             M_AXI_AWLOCK,
    output wire[3:0]                        M_AXI_AWCACHE,
    output wire[3:0]                        M_AXI_AWQOS,
    input  wire                                             M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input  wire[1:0]                                        M_AXI_BRESP,
    input  wire                                             M_AXI_BVALID,
    output wire                             M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output wire[AXI_ADDR_WIDTH-1 : 0]       M_AXI_ARADDR,     
    output wire                             M_AXI_ARVALID,
    output wire[2 : 0]                      M_AXI_ARPROT,     
    output wire                             M_AXI_ARLOCK,
    output wire[3:0]                        M_AXI_ARID,
    output wire[7:0]                        M_AXI_ARLEN,
    output wire[2:0]                        M_AXI_ARSIZE,
    output wire[1:0]                        M_AXI_ARBURST,
    output wire[3:0]                        M_AXI_ARCACHE,
    output wire[3:0]                        M_AXI_ARQOS,

    input  wire                                             M_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input  wire[AXI_DATA_WIDTH-1:0]                         M_AXI_RDATA,
    input  wire                                             M_AXI_RVALID,
    input  wire[1:0]                                        M_AXI_RRESP,
    output wire                             M_AXI_RREADY,
    input  wire                                             M_AXI_RLAST

    //==========================================================================

);

    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //    This section is a standard full AXI Master that lacks bursting capabilities
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


    localparam AXI_DATA_BYTES = (AXI_DATA_WIDTH/8);

    // Reads and writes are going to be for the full data width
    assign M_AXI_AWSIZE  = $clog2(AXI_DATA_BYTES);
    assign M_AXI_ARSIZE  = $clog2(AXI_DATA_BYTES);

    // Assign all of the "write transaction" signals that aren't in the AXI4-Lite spec
    assign M_AXI_AWID    = 0;   // Arbitrary ID
    assign M_AXI_AWLEN   = 0;   // Burst length of 1
    assign M_AXI_WLAST   = 1;   // Each beat is always the last beat of the burst
    assign M_AXI_AWBURST = 1;   // Each beat of the burst increments by 1 address (ignored)
    assign M_AXI_AWLOCK  = 0;   // Normal signaling
    assign M_AXI_AWCACHE = 0;   // Normal, no cache, no buffer
    assign M_AXI_AWQOS   = 0;   // Lowest quality of service, unused

    // Assign all of the "read transaction" signals that aren't in the AXI4-Lite spec
    assign M_AXI_ARLOCK  = 0;   // Normal signaling
    assign M_AXI_ARID    = 0;   // Arbitrary ID
    assign M_AXI_ARLEN   = 0;   // Burst length of 1
    assign M_AXI_ARBURST = 1;   // Increment address on each beat of the burst (unused)
    assign M_AXI_ARCACHE = 0;   // Normal, no cache, no buffer
    assign M_AXI_ARQOS   = 0;   // Lowest quality of service (unused)


    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = M_AXI_BVALID  & M_AXI_BREADY;
    wire R_HANDSHAKE  = M_AXI_RVALID  & M_AXI_RREADY;
    wire W_HANDSHAKE  = M_AXI_WVALID  & M_AXI_WREADY;
    wire AR_HANDSHAKE = M_AXI_ARVALID & M_AXI_ARREADY;
    wire AW_HANDSHAKE = M_AXI_AWVALID & M_AXI_AWREADY;

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

    // FSM user interface outputs
    wire                        amci_widle = (write_state == 0 && amci_write == 0);     
    reg[1:0]                    amci_wresp;

    // AXI registers and outputs
    reg[AXI_ADDR_WIDTH-1:0]     m_axi_awaddr;
    reg[AXI_DATA_WIDTH-1:0]     m_axi_wdata;
    reg                         m_axi_awvalid = 0;
    reg                         m_axi_wvalid = 0;
    reg                         m_axi_bready = 0;

    // Wire up the AXI interface outputs
    assign M_AXI_AWADDR  = m_axi_awaddr;
    assign M_AXI_WDATA   = m_axi_wdata;
    assign M_AXI_AWVALID = m_axi_awvalid;
    assign M_AXI_WVALID  = m_axi_wvalid;
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_WSTRB   = (1 << AXI_DATA_BYTES) - 1; 
    assign M_AXI_BREADY  = m_axi_bready;
    //=========================================================================================================
     
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
                    // Keep track of whether we have seen the slave raise AWREADY or WREADY
                    if (AW_HANDSHAKE) m_axi_awvalid <= 0;
                    if (W_HANDSHAKE ) m_axi_wvalid  <= 0;

                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((~m_axi_awvalid || AW_HANDSHAKE) && (~m_axi_wvalid || W_HANDSHAKE)) begin
                        write_state <= 2;
                    end
                end
                
           // Wait around for the slave to assert "M_AXI_BVALID".  When it does, we'll acknowledge
           // it by raising M_AXI_BREADY for one cycle, and go back to idle state
           2:   if (B_HANDSHAKE) begin
                    amci_wresp   <= M_AXI_BRESP;
                    m_axi_bready <= 0;
                    write_state  <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //===========================================================================================CLK==============
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
                    if (AR_HANDSHAKE) begin
                        m_axi_arvalid <= 0;
                    end

                    if (R_HANDSHAKE) begin
                        amci_rdata    <= M_AXI_RDATA;
                        amci_rresp    <= M_AXI_RRESP;
                        m_axi_rready  <= 0;
                        read_state    <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //                      From here on down is logic specific to this module
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    genvar x;
    localparam START         = 1;
    localparam GET_NEXT_BYTE = 2;
    localparam NO_CHAR       = 8'hFF;
    localparam INVALID_INDEX = AXI_DATA_BYTES + 1;


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

    // We're not outputting valid data during either a START command or on a GET_NEXT_BYTE 
    // command that we have insufficient data to fulfill.
    assign VALID = (valid && ~(CMD == START) && ~(CMD == GET_NEXT_BYTE && char_idx == INVALID_INDEX));
    
    // There is nothing in this algorithm that relies on the existence of the NO_CHAR 
    // character.  We output the NO_CHAR character only because it's easy to see in the
    // Vivado ILA at debug time.  This RTL code would not be affected if we remove the 
    // outputting of NO_CHAR when VALID is inactive.
    assign DATA = (VALID == 0)           ? NO_CHAR   :
                  (CMD == GET_NEXT_BYTE) ? next_char : this_char;

    always @(posedge M_AXI_ACLK) begin
        
        // When this is raised, it should strobe high for exactly one clock-cycle
        amci_read <= 0;

        if (M_AXI_ARESETN == 0) begin
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
            1:  if (amci_ridle) begin
                    amci_raddr <= ADDR;
                    amci_read  <= 1;
                    ram_addr   <= ADDR + AXI_DATA_BYTES;
                    scstate    <= 2;
                end

                
            // If the AXI read from RAM has completed...
            2:  if (amci_ridle) begin
                    
                    // Fetch the word we just read from RAM
                    ram_word <= amci_rdata;
                    
                    // Pre-fetch the next RAM word that we're going to need
                    amci_raddr <= ram_addr;
                    amci_read  <= 1;

                    // Bump the RAM address we read for next time
                    ram_addr <= ram_addr + AXI_DATA_BYTES;

                    // "DATA" is now valid
                    this_char <= amci_rdata[ 7:0];
                    next_char <= amci_rdata[15:8];
                    valid     <= 1;
                    char_idx  <= 2;

                    // And go back to idle state
                    scstate <= 0;
                end 
        endcase
    end

endmodule
