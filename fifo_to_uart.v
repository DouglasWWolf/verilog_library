`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_to_uart#
(
    parameter integer AXI_DATA_WIDTH  = 32,
    parameter integer AXI_ADDR_WIDTH  = 32,
    parameter integer XMIT_DEPTH      = 1024,
    parameter integer RECV_DEPTH      = 16,
    parameter integer UART_ADDR       = 32'h4060_0000,
    parameter integer CLOCKS_PER_USEC = 125
)
(
    // User writes to this FIFO to send data out the UART
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 XMIT_FIFO WR_DATA" *) input[7:0] XMIT_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 XMIT_FIFO FULL_N"  *) output     XMIT_FULL_N,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 XMIT_FIFO WR_EN"   *) input      XMIT_WREN,

    // User reads from this FIFO to receive data from the UART
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RECV_FIFO RD_DATA" *) output[7:0] RECV_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RECV_FIFO EMPTY_N" *) output      RECV_EMPTY_N,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RECV_FIFO RD_EN"   *) input       RECV_RDEN,


    // This is the interrupt from the UART 
    input UART_INT,

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
    
    // FSM user interface outputs
    wire                        amci_widle = (write_state == 0 && amci_write == 0);     
    reg[1:0]                    amci_wresp;

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


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                               End of AXI4 Lite Master state machines
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

    // These are the registers in a Xilinx AXI UART-Lite
    localparam UART_RX   = UART_ADDR +  0; 
    localparam UART_TX   = UART_ADDR +  4;
    localparam UART_STAT = UART_ADDR +  8;
    localparam UART_CTRL = UART_ADDR + 12;

    // Registers and wires that interface to the TX FIFO
    reg       xmit_fifo_read;
    wire      xmit_fifo_empty;
    wire      xmit_fifo_full;
    wire[7:0] xmit_fifo_data;

    // Registers and wires that interface to the RX FIFO
    reg       recv_fifo_write;
    reg[7:0]  recv_fifo_data;    
    wire      recv_fifo_empty;

    // Interfaces to/from the outside worlds
    wire RESET         = ~M_AXI_ARESETN;
    assign XMIT_FULL_N = ~xmit_fifo_full;
    assign RECV_EMPTY_N = ~recv_fifo_empty;
    
    //-------------------------------------------------------------------------------------------------
    // State machine that manages the TX side of the UART
    //-------------------------------------------------------------------------------------------------
    reg[1:0] tx_state;

    always @(posedge M_AXI_ACLK) begin
        
        xmit_fifo_read <= 0;
        amci_write     <= 0;

        if (M_AXI_ARESETN == 0) begin
            tx_state <= 0;
        end else case(tx_state)

        // Initialize the UART by enabling interrupts
        0:  begin
                amci_waddr <= UART_CTRL;
                amci_wdata <= (1<<4);
                amci_write <= 1;
                tx_state   <= 1;
            end

        // Here we wait for a character to arrive in the incoming TX fifo.   When one does, 
        // we will send it to the UART, acknowledge the TX fifo, and go wait for the AXI
        // transaction to complete.
        1:  if (amci_widle && !xmit_fifo_empty) begin
                amci_waddr     <= UART_TX;
                amci_wdata     <= xmit_fifo_data;
                amci_write     <= 1;
                xmit_fifo_read <= 1;
                tx_state       <= 2;
            end

        // Here we are waiting for an AXI write transaction to complete. 
        2:  if (amci_widle) begin
                if (amci_wresp == 0) begin
                    tx_state <= 1;
                end else begin
                    amci_write <= 1;
                end
            end
        endcase
    end
    //-------------------------------------------------------------------------------------------------



    //-------------------------------------------------------------------------------------------------
    // State machine that manages the RX side of the UART
    //-------------------------------------------------------------------------------------------------
    reg[1:0] rx_state;
    always @(posedge M_AXI_ACLK) begin
        
        recv_fifo_write <= 0;
        amci_read       <= 0;
   
        if (M_AXI_ARESETN == 0) begin
            rx_state <= 0;
        end else case(rx_state)

        // Here we are waiting for an interrupt from the UART.  When one happens, we will
        // start a read of the UART status register
        0:  if (UART_INT) begin
                amci_raddr <= UART_STAT;
                amci_read  <= 1;
                rx_state   <= 1;
            end

        // Wait for the read of the UART status register to complete.  When it does, if 
        // it tells us that there is an incoming character waiting for us, start a read
        // of the UART's RX register
        1:  if (amci_ridle) begin
                if (amci_rdata[0]) begin
                    amci_raddr <= UART_RX;
                    amci_read  <= 1;
                    rx_state   <= 2;
                end else
                    rx_state   <= 0;
            end

        // Here we wait for the read of the UART RX register to complete.  If it completes
        // succesfully, we will stuff the received byte into the RX FIFO so it can be fetched
        // by the user
        2:  if (amci_ridle) begin
                if (amci_rresp == 0) begin
                    recv_fifo_data  <= amci_rdata[7:0];
                    recv_fifo_write <= 1;
                end
                rx_state <= 0;
            end
        endcase
    end
    //-------------------------------------------------------------------------------------------------




    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (XMIT_DEPTH),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (8),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (8), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_xmit_fifo
    (
        .rst        (RESET          ),                      
        .full       (xmit_fifo_full ),              
        .din        (XMIT_DATA      ),                 
        .wr_en      (XMIT_WREN      ),            
        .wr_clk     (M_AXI_ACLK     ),          
        .data_valid (               ),  
        .dout       (xmit_fifo_data ),              
        .empty      (xmit_fifo_empty),            
        .rd_en      (xmit_fifo_read ),            

      //------------------------------------------------------------
      // This only exists in xpm_fifo_async, not in xpm_fifo_sync
      // .rd_clk    (CLK               ),                     
      //------------------------------------------------------------

        .sleep(),                        
        .injectdbiterr(),                
        .injectsbiterr(),                
        .overflow(),                     
        .prog_empty(),                   
        .prog_full(),                    
        .rd_data_count(),                
        .rd_rst_busy(),                  
        .sbiterr(),                      
        .underflow(),                    
        .wr_ack(),                       
        .wr_data_count(),                
        .wr_rst_busy(),                  
        .almost_empty(),                 
        .almost_full(),                  
        .dbiterr()                       
    );

    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (RECV_DEPTH),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (8),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (8), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_recv_fifo
    (
        .rst        (RESET          ),                      
        .full       (               ),              
        .din        (recv_fifo_data ),                 
        .wr_en      (recv_fifo_write),            
        .wr_clk     (M_AXI_ACLK     ),          
        .data_valid (               ),  
        .dout       (RECV_DATA      ),
        .empty      (recv_fifo_empty),
        .rd_en      (RECV_RDEN      ),

      //------------------------------------------------------------
      // This only exists in xpm_fifo_async, not in xpm_fifo_sync
      // .rd_clk    (CLK               ),                     
      //------------------------------------------------------------

        .sleep(),                        
        .injectdbiterr(),                
        .injectsbiterr(),                
        .overflow(),                     
        .prog_empty(),                   
        .prog_full(),                    
        .rd_data_count(),                
        .rd_rst_busy(),                  
        .sbiterr(),                      
        .underflow(),                    
        .wr_ack(),                       
        .wr_data_count(),                
        .wr_rst_busy(),                  
        .almost_empty(),                 
        .almost_full(),                  
        .dbiterr()                       
    );



endmodule
