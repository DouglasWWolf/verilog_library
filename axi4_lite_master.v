`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
//////////////////////////////////////////////////////////////////////////////////


module axi4_lite_master#
(
    parameter integer C_AXI_DATA_WIDTH = 32,
    parameter integer C_AXI_ADDR_WIDTH = 32
)
(
    
    //====================== The user interface for writing ====================
    
    input  wire [C_AXI_ADDR_WIDTH-1:0] AMCI_WADDR,
    input  wire [C_AXI_DATA_WIDTH-1:0] AMCI_WDATA,
    input  wire                        AMCI_WRITE,
    output wire                        AMCI_WIDLE,
    //==========================================================================
    
    //====================== The user interface for reading ====================
    input  wire [C_AXI_ADDR_WIDTH-1:0] AMCI_RADDR,
    output wire [C_AXI_DATA_WIDTH-1:0] AMCI_RDATA,
    input  wire                        AMCI_READ,
    output wire                        AMCI_RIDLE,
    //==========================================================================



    //================ From here down is the AXI4-Lite interface ===============
    input wire  M_AXI_ACLK,
    input wire  M_AXI_ARESETN,
        
    // "Specify write address"              -- Master --    -- Slave --
    output wire [C_AXI_ADDR_WIDTH-1 : 0]    M_AXI_AWADDR,   
    output wire                             M_AXI_AWVALID,  
    input  wire                                             M_AXI_AWREADY,
    output wire  [2 : 0]                    M_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    output wire [C_AXI_DATA_WIDTH-1 : 0]    M_AXI_WDATA,      
    output wire                             M_AXI_WVALID,
    output wire [(C_AXI_DATA_WIDTH/8)-1:0]  M_AXI_WSTRB,
    input  wire                                             M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input  wire [1 : 0]                                     M_AXI_BRESP,
    input  wire                                             M_AXI_BVALID,
    output wire                             M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output wire [C_AXI_ADDR_WIDTH-1 : 0]    M_AXI_ARADDR,     
    output wire                             M_AXI_ARVALID,
    output wire [2 : 0]                     M_AXI_ARPROT,     
    input  wire                                             M_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input  wire [C_AXI_DATA_WIDTH-1 : 0]                    M_AXI_RDATA,
    input  wire                                             M_AXI_RVALID,
    input  wire [1 : 0]                                     M_AXI_RRESP,
    output wire                             M_AXI_RREADY
    //==========================================================================

);

    localparam C_AXI_DATA_BYTES = (C_AXI_DATA_WIDTH/8);


    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   amci_waddr = Address to write to
    //              amci_wdata = Data to write at that address
    //              amci_write = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "amci_widle" goes high
    //=========================================================================================================
    reg[1:0]                    write_state = 0;

    // FSM user interface inputs
    reg[C_AXI_ADDR_WIDTH-1:0]   amci_waddr;
    reg[C_AXI_DATA_WIDTH-1:0]   amci_wdata;
    reg                         amci_write;

    // FSM user interface outputs
    wire                        amci_widle = (write_state == 0 && amci_write == 0);     

    // AXI registers and outputs
    reg[C_AXI_ADDR_WIDTH-1:0]   m_axi_awaddr;
    reg[C_AXI_DATA_WIDTH-1:0]   m_axi_wdata;
    reg                         m_axi_awvalid = 0;
    reg                         m_axi_wvalid = 0;
    reg                         m_axi_bready = 0;

    // Wire up the AXI interface outputs
    assign M_AXI_AWADDR  = m_axi_awaddr;
    assign M_AXI_WDATA   = m_axi_wdata;
    assign M_AXI_AWVALID = m_axi_awvalid;
    assign M_AXI_WVALID  = m_axi_wvalid;
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_WSTRB   = (1 << C_AXI_DATA_BYTES) - 1; // usually 4'b1111
    assign M_AXI_BREADY  = m_axi_bready;
    //=========================================================================================================
    always @(posedge M_AXI_ACLK) begin
        
        // Ensure that any writes to this signal are for a single clock-pulse
        m_axi_bready <= 0;
        
        if (M_AXI_ARESETN == 0) begin
            write_state   <= 0;
            m_axi_awvalid <= 0;
            m_axi_wvalid  <= 0;
        end else case (write_state)
            
            // Here we're idle, waiting for someone to raise the AMCI_WRITE flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate the address and data values are valid
            0:  if (amci_write) begin
                    m_axi_awaddr  <= amci_waddr;
                    m_axi_wdata   <= amci_wdata;
                    m_axi_awvalid <= 1;
                    m_axi_wvalid  <= 1;
                    write_state   <= 1;
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting M_AXI_AWREADY
           // and M_AXI_WREADY.  Once that happens, we'll de-assert the "valid" lines.      
           1:   if (m_axi_awvalid && M_AXI_AWREADY && m_axi_wvalid && M_AXI_WREADY) begin
                    m_axi_wvalid  <= 0;
                    m_axi_awvalid <= 0;
                    write_state   <= 2;                
                end
                
           // Wait around for the slave to assert "M_AXI_BVALID".  When it does, we'll acknowledge
           // it by raising M_AXI_BREADY for one cycle, and go back to idle state
           2:   if (M_AXI_BVALID) begin
                    m_axi_bready <= 1;
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
    //            The data read is available in amci_rdata.
    //=========================================================================================================
    reg[1:0]                    read_state = 0;

    // FSM user interface inputs
    reg[C_AXI_ADDR_WIDTH-1:0]   amci_raddr;
    reg                         amci_read;

    // FSM user interface outputs
    reg[C_AXI_DATA_WIDTH-1:0]   amci_rdata;
    wire                        amci_ridle = (read_state == 0 && amci_read == 0);     

    // AXI registers and outputs
    reg[C_AXI_ADDR_WIDTH-1:0]   m_axi_araddr;
    reg[C_AXI_DATA_WIDTH-1:0]   m_axi_rdata;
    reg                         m_axi_arvalid = 0;
    reg                         m_axi_rready;

    // Wire up the AXI interface outputs
    assign M_AXI_ARADDR  = m_axi_araddr;
    assign M_AXI_ARVALID = m_axi_arvalid;
    assign M_AXI_ARPROT  = 3'b001;
    assign M_AXI_RREADY  = m_axi_rready;
    //=========================================================================================================
    always @(posedge M_AXI_ACLK) begin
    
        // Ensure that any writes to this signal are for a single clock-pulse
        m_axi_rready <= 0;
    
        if (M_AXI_ARESETN == 0) begin
            read_state    <= 0;
            m_axi_arvalid <= 0;
        end else case (read_state)

        // Here we are waiting around for someone to raise "amci_read", which signals us to begin
        // a AXI read at the address specified in "amci_raddr"
        0:  if (amci_read) begin
                m_axi_araddr  <= amci_raddr;
                m_axi_arvalid <= 1;
                read_state    <= 1;
            end

        // Here we're waiting for the AXI slave to acknowledge that he saw us present the
        // address we wish to read from                
        1:  if (m_axi_arvalid && M_AXI_ARREADY) begin
                m_axi_arvalid <= 0;
                read_state    <= 2;
            end
            
        // Wait around for the slave to raise M_AXI_RVALID, which tells us that M_AXI_RDATA
        // contains the data we requested
        2:  if (M_AXI_RVALID) begin
                amci_rdata   <= M_AXI_RDATA;
                m_axi_rready <= 1;
                read_state   <= 0;
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