`timescale 1ns / 1ps
//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 10-May-22  DWW  1000  Initial creation
//====================================================================================


module uart_axi_if#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer UART_BASE = 32'h4060_0000
)
(
    input wire UART_INT,

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
    assign M_AXI_WSTRB   = (1 << AXI_DATA_BYTES) - 1; // usually 4'b1111
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


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    // From here down is the logic that manages messages on the UART and instantiates AXI read/write transactions
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    localparam UART_RX   = UART_BASE + 0;
    localparam UART_TX   = UART_BASE + 4;
    localparam UART_STAT = UART_BASE + 8;
    localparam UART_CTRL = UART_BASE + 12;
    localparam UART_INT_ENABLE = (1 << 4);
    localparam INP_BUFF_SIZE   = 9;
    localparam CMD_READ        = 1;
    localparam CMD_WRITE       = 2;

    localparam S_NEW_COMMAND     = 1;
    localparam S_WAIT_NEXT_CHAR  = 2;
    localparam S_WAIT_FOR_STATUS = 3;
    localparam S_FETCH_BYTE      = 4;
    localparam S_AXI_READ        = 8;
    localparam S_AXI_WRITE       = 16;

    reg[ 4:0] inp_state;                     // Tracks the state of this FSM
    reg[ 3:0] inp_count;                     // The number of bytes stored in inp_buff;
    reg[ 3:0] inp_last_idx;                  // Number of bytes that make up the current command
    reg[ 7:0] inp_buff[0:INP_BUFF_SIZE-1];   // Buffer of bytes rcvd from the UART
    reg[31:0] read_data;                     // Data returned from an AXI read

    always @(posedge M_AXI_ACLK) begin
        amci_write <= 0;
        amci_read  <= 0;

        if (M_AXI_ARESETN == 0) begin
            inp_state <= 0;
            inp_count <= 0;
        end else case(inp_state)
        
        // Enable UART interrupts
        0:  begin
                amci_waddr <= UART_CTRL;
                amci_wdata <= UART_INT_ENABLE;
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end

        // Initialize variables in expectation of a new command arriving
        S_NEW_COMMAND:
            begin
                inp_count <= 0;
                inp_state <= S_WAIT_NEXT_CHAR;
            end

        S_WAIT_NEXT_CHAR:
            if (UART_INT) begin                     // If a UART interrupt has occured...
                amci_raddr <= UART_STAT;            //   We're going to read the status register
                amci_read  <= 1;                    //   Initiate that read transaction
                inp_state  <= S_WAIT_FOR_STATUS;    //   And go wait for the transaction to complete
            end

        S_WAIT_FOR_STATUS:
           if (amci_ridle) begin                    // Wait for the AXI read to complete
                if (amci_rdata[0]) begin            //   If the status registers says we have an RX byte...
                    amci_raddr <= UART_RX;          //     We're going to read the UART RX FIFO
                    amci_read  <= 1;                //     Initiate the AXI read transaction
                    inp_state  <= S_FETCH_BYTE;     //     And go to the next state
                end else begin                      //  Otherwise, we don't have an RX byte waiting
                    inp_state  <= S_WAIT_NEXT_CHAR; //     Go back to waiting for an interrupt      
                end
            end

        S_FETCH_BYTE: 
            if (amci_ridle) begin                        // Wait to receive a byte from the UART
                inp_buff[inp_count] <= amci_rdata;
                inp_state           <= S_WAIT_NEXT_CHAR;
                
                if (inp_count == 0) begin
                    case(amci_rdata)
                    CMD_READ: begin
                                inp_last_idx <= 4;
                                inp_count    <= 1;
                              end

                    CMD_WRITE: begin
                                inp_last_idx <= 8;
                                inp_count    <= 1;
                               end
                    endcase

                end else if (inp_count == inp_last_idx) begin
                    inp_state <= (inp_buff[0] == CMD_READ) ? S_AXI_READ : S_AXI_WRITE;
                
                end else begin
                    inp_count <= inp_count + 1;
                end
            end


        // Start the AXI read transaction specified by the user
        S_AXI_READ:
            if (amci_ridle) begin
                amci_raddr <= (inp_buff[1] << 24) | (inp_buff[2] << 16) | (inp_buff[3] << 8) | inp_buff[4];
                amci_read  <= 1;
                inp_state  <= inp_state + 1;
            end

        S_AXI_READ+1:
            if (amci_ridle) begin
                read_data  <= amci_rdata;
                amci_waddr <= UART_TX;
                amci_wdata <= amci_rresp;
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end

        S_AXI_READ+2:
            if (amci_widle) begin
                amci_waddr <= UART_TX;
                amci_wdata <= read_data[31:24];
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end
        
        S_AXI_READ+3:
            if (amci_widle) begin
                amci_waddr <= UART_TX;
                amci_wdata <= read_data[23:16];
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end
        
        S_AXI_READ+4:
            if (amci_widle) begin
                amci_waddr <= UART_TX;
                amci_wdata <= read_data[15:8];
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end
        
        S_AXI_READ+5:
            if (amci_widle) begin
                amci_waddr <= UART_TX;
                amci_wdata <= read_data[7:0];
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end

        S_AXI_READ+6:
            if (amci_widle) inp_state <= S_NEW_COMMAND;



        // Start the AXI write transaction specified by the user
        S_AXI_WRITE:
            if (amci_widle) begin
                amci_waddr <= (inp_buff[1] << 24) | (inp_buff[2] << 16) | (inp_buff[3] << 8) | inp_buff[4];
                amci_wdata <= (inp_buff[5] << 24) | (inp_buff[6] << 16) | (inp_buff[7] << 8) | inp_buff[8];
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end

        // Wait for that transaction to complete.  When it does, send the write-response to the user
        S_AXI_WRITE+1:
            if (amci_widle) begin
                amci_waddr <= UART_TX;
                amci_wdata <= amci_wresp;
                amci_write <= 1;
                inp_state  <= inp_state + 1;
            end

        // When the write-response has finished sending, go wait for a new command
        S_AXI_WRITE+2:
            if (amci_widle) inp_state <= S_NEW_COMMAND;

        endcase
    
    end




endmodule