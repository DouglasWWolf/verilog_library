`timescale 1ns / 1ps

//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 21-Jul-22  DWW  1000  Initial creation
//====================================================================================

/*

    This module measures the bandwidth of an AXI interface.

    On the AXI4-lite slave interface, there are eleven 32-bit registers:
       Offset 0x00 : Read  starting address, hi 32 bits
       Offset 0x04 : Read  starting address, lo 32 bits
       Offset 0x08 : Write starting address, hi 32 bits
       Offset 0x0C : Write starting address, lo 32 bits
       Offset 0x10 : Block size (i.e, number of bytes in an AXI burst)
       Offset 0x14 : Number of blocks to read or write
       Offset 0x18 : Result clock cycles for read,  hi 32 bits
       Offset 0x1c : Result clock cycles for read,  lo 32 bits
       Offset 0x20 : Result clock cycles for write, hi 32 bits
       Offset 0x24 : Result clock cycles for write, lo 32 bits
       Offset 0x28 : Control / Status

    The control/status register is bitmapped.
      During a write:
              Bit 0 : 0 = Do nothing, 1 = Start measuring read bandwidth
              Bit 1 : 0 = Do nothing, 1 = Start measuring write bandwidth
      During a read:
              Bit 0 : 0 = Read  measurement complete, 1 = read measurement in progress
              Bit 1 : 0 = Write measurement complete, 1 = write measurement in progress
        

*/


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//            Application-specific logic goes at the bottom of the file
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

// These are the dimensions of our AXI4-Lite slave interface
`define S_AXI_ADDR_WIDTH 6
`define S_AXI_DATA_WIDTH 32 

module measure_bw#
(
    parameter[63:0] ADDRESS_OFFSET        = 64'h0000_0000,
    parameter       MAX_OUTSTANDING_RREQ  = 8,
    parameter       MAX_OUTSTANDING_WREQ  = 8,
    parameter       AXI_DATA_WIDTH        = 512,
    parameter       AXI_ADDR_WIDTH        = 64
)
(
    input wire  AXI_ACLK, AXI_ARESETN,

    //==========================================================================
    //            This defines the AXI4-Lite slave control interface
    //==========================================================================
    // "Specify write address"              -- Master --    -- Slave --
    input  wire[`S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_AWADDR,   
    input  wire                             S_AXI_AWVALID,  
    output wire                                             S_AXI_AWREADY,
    input  wire[2 : 0]                      S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input  wire[`S_AXI_DATA_WIDTH-1 : 0]    S_AXI_WDATA,      
    input  wire                             S_AXI_WVALID,
    input  wire[(`S_AXI_DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
    output wire                                             S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output  wire[1 : 0]                                     S_AXI_BRESP,
    output  wire                                            S_AXI_BVALID,
    input   wire                            S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input  wire[`S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_ARADDR,     
    input  wire                             S_AXI_ARVALID,
    input  wire[2 : 0]                      S_AXI_ARPROT,     
    output wire                                             S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output  wire[`S_AXI_DATA_WIDTH-1 : 0]                   S_AXI_RDATA,
    output  wire                                            S_AXI_RVALID,
    output  wire[1 : 0]                                     S_AXI_RRESP,
    input   wire                            S_AXI_RREADY,
    //==========================================================================

   

    //==========================================================================
    //  This defines the AXI Master interface that connects to the interface
    //  whose bandwidth we're trying to measure
    //==========================================================================

    // "Read Request"                      -- Master --      -- Slave --
    output wire[AXI_ADDR_WIDTH-1 : 0]      M_AXI_ARADDR,     
    output wire                            M_AXI_ARVALID,
    output wire[2:0]                       M_AXI_ARPROT,     
    output wire                            M_AXI_ARLOCK,
    output wire[3:0]                       M_AXI_ARID,
    output wire[7:0]                       M_AXI_ARLEN,
    output wire[2:0]                       M_AXI_ARSIZE,
    output wire[1:0]                       M_AXI_ARBURST,
    output wire[3:0]                       M_AXI_ARCACHE,
    output wire[3:0]                       M_AXI_ARQOS,
    input  wire                                              M_AXI_ARREADY,

    // "Read data back to master"          -- Master --      -- Slave --
    input  wire[AXI_DATA_WIDTH-1 : 0]                        M_AXI_RDATA,
    input  wire                                              M_AXI_RVALID,
    input  wire[1:0]                                         M_AXI_RRESP,
    input  wire                                              M_AXI_RLAST,
    output wire                            M_AXI_RREADY,

    // "Write Request"
    output wire[AXI_ADDR_WIDTH-1:0]        M_AXI_AWADDR,
    output wire                            M_AXI_AWVALID,
    output wire[2:0]                       M_AXI_AWPROT,
    output wire[3:0]                       M_AXI_AWID,
    output wire[7:0]                       M_AXI_AWLEN,
    output wire[2:0]                       M_AXI_AWSIZE,
    output wire[1:0]                       M_AXI_AWBURST,
    output wire                            M_AXI_AWLOCK,
    output wire[3:0]                       M_AXI_AWCACHE,
    output wire[3:0]                       M_AXI_AWQOS,
    input  wire                                              M_AXI_AWREADY,

    // "Write Data"                        -- Master --      -- Slave --
    output wire[AXI_DATA_WIDTH-1 : 0]      M_AXI_WDATA,
    output wire                            M_AXI_WVALID,
    output wire[(AXI_DATA_WIDTH/8)-1:0]    M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    input  wire                                              M_AXI_WREADY,

    // "Receive Write Response"           -- Master --       -- Slave --
    input  wire[1:0]                                         M_AXI_BRESP,
    input  wire                                              M_AXI_BVALID,
    output wire                           M_AXI_BREADY
    //==========================================================================

 );


    //=========================================================================================================
    // These are parameters and variables that must be accessible to the rest of the module
    //=========================================================================================================

    // This calculation assumes AXI_DATA_WIDTH is a power of 2
    localparam BYTES_PER_BEAT  = AXI_DATA_WIDTH / 8;

    localparam REG_RADDR_H   =  0;    // Hi word of the source address
    localparam REG_RADDR_L   =  1;    // Lo word of the source address
    localparam REG_WADDR_H   =  2;    // Hi word of the destination address
    localparam REG_WADDR_L   =  3;    // Lo word of the destination address
    localparam REG_BLK_SIZE  =  4;    // Number of bytes in a burst (must be multiple of AXI_DATA_WIDTH/8)
    localparam REG_COUNT     =  5;    // Number of blocks to read
    localparam REG_RRESULT_H =  6;    // Elapsed read clock-cycles, hi word
    localparam REG_RRESULT_L =  7;    // Elapsed read clock-cycles, lo word
    localparam REG_WRESULT_H =  8;    // Elapsed write clock-cycles, hi word
    localparam REG_WRESULT_L =  9;    // Elapsed write clock-cycles, lo word
    localparam REG_CTL_STAT  = 10;    // Combined control and status register

    // Storage for the above registers.  (We don't actually store CTL_STAT or the result registers)    
    reg[31:0] register[0:5];

    // The number of beats per AXI burst
    reg[31:0] beats_per_burst;

    // "cycle_counter" will be incremented on every clock cycles
    reg[63:0] cycle_counter, elapsed_read_cycles, elapsed_write_cycles;

    // When these are pulsed high, the bandwidth tests begin
    reg start_read, start_write;       

    // When the measurement starts, these will contain the measurement parameters
    reg[31:0] xfer_count, xfer_count_less_1, xfer_block_size;
    
    // The number of blocks queued for read, and actually read,
    reg[31:0] reads_queued, blocks_read, writes_queued, blocks_written, blocks_acked;
    
    // The state of the "read data from source" state machine
    reg m_read_state;

    // The state of the "count write-acknowledgements" state machine
    reg m_wack_state;

    // This keeps track of whether our measurement engines are running
    wire is_read_engine_idle  = (start_read  == 0) & (m_read_state == 0);
    wire is_write_engine_idle = (start_write == 0) & (m_wack_state == 0);

    // Define the AXI handshakes 
    wire M_AR_HANDSHAKE = M_AXI_ARVALID & M_AXI_ARREADY;
    wire M_R_HANDSHAKE  = M_AXI_RVALID  & M_AXI_RREADY;    
    wire M_AW_HANDSHAKE = M_AXI_AWVALID & M_AXI_AWREADY;
    wire M_W_HANDSHAKE  = M_AXI_WVALID  & M_AXI_WREADY;    
    wire M_B_HANDSHAKE  = M_AXI_BVALID  & M_AXI_BREADY;
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //                           This section is standard AXI4-Lite Slave logic
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    // These are valid values for BRESP and RRESP
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    
    // These are for communicating with application-specific read and write logic
    reg  user_read_start,  user_read_idle;
    reg  user_write_start, user_write_idle;
    wire user_write_complete = (user_write_start == 0) & user_write_idle;
    wire user_read_complete  = (user_read_start  == 0) & user_read_idle;


    // Define the handshakes for all 5 slave AXI channels
    wire S_B_HANDSHAKE  = S_AXI_BVALID  & S_AXI_BREADY;
    wire S_R_HANDSHAKE  = S_AXI_RVALID  & S_AXI_RREADY;
    wire S_W_HANDSHAKE  = S_AXI_WVALID  & S_AXI_WREADY;
    wire S_AR_HANDSHAKE = S_AXI_ARVALID & S_AXI_ARREADY;
    wire S_AW_HANDSHAKE = S_AXI_AWVALID & S_AXI_AWREADY;
        
    //=========================================================================================================
    // FSM logic for handling AXI4-Lite read-from-slave transactions
    //=========================================================================================================
    // When a valid address is presented on the bus, this register holds it
    reg[`S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;

    // Wire up the AXI interface outputs
    reg                        s_axi_arready; assign S_AXI_ARREADY = s_axi_arready;
    reg                        s_axi_rvalid;  assign S_AXI_RVALID  = s_axi_rvalid;
    reg[1:0]                   s_axi_rresp;   assign S_AXI_RRESP   = s_axi_rresp;
    reg[`S_AXI_DATA_WIDTH-1:0] s_axi_rdata;   assign S_AXI_RDATA   = s_axi_rdata;
     //=========================================================================================================
    reg s_read_state;
    always @(posedge AXI_ACLK) begin
        user_read_start <= 0;
        
        if (AXI_ARESETN == 0) begin
            s_read_state  <= 0;
            s_axi_arready <= 1;
            s_axi_rvalid  <= 0;
        end else case(s_read_state)

        0:  begin
                s_axi_rvalid <= 0;                   // RVALID will go high only when we have filled in RDATA
                if (S_AXI_ARVALID) begin             // If the AXI master has given us an address to read...
                    s_axi_arready   <= 0;            //   We are no longer ready to accept an address
                    s_axi_araddr    <= S_AXI_ARADDR; //   Register the address that is being read from
                    user_read_start <= 1;            //   Start the application-specific read-logic
                    s_read_state    <= 1;            //   And go wait for that read-logic to finish
                end
            end

        1:  if (user_read_complete) begin            // If the application-specific read-logic is done...
                s_axi_rvalid <= 1;                   //   Tell the AXI master that RDATA and RRESP are valid
                if (S_R_HANDSHAKE) begin             //   Wait for the AXI master to say "OK, I saw your response"
                    s_axi_rvalid  <= 0;              //     The AXI master has registered our data
                    s_axi_arready <= 1;              //     Once that happens, we're ready to start a new transaction
                    s_read_state  <= 0;              //     And go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // FSM logic for handling AXI4-Lite write-to-slave transactions
    //=========================================================================================================

    // When a valid address is presented on the bus, this register holds it
    reg[`S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;

    // When valid write-data is presented on the bus, this register holds it
    reg[`S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    
    // Wire up the AXI interface outputs
    reg      s_axi_awready; assign S_AXI_AWREADY = s_axi_arready;
    reg      s_axi_wready;  assign S_AXI_WREADY  = s_axi_wready;
    reg      s_axi_bvalid;  assign S_AXI_BVALID  = s_axi_bvalid;
    reg[1:0] s_axi_bresp;   assign S_AXI_BRESP   = s_axi_bresp;
    //=========================================================================================================
    reg s_write_state;
    always @(posedge AXI_ACLK) begin
        user_write_start <= 0;
        if (AXI_ARESETN == 0) begin
            s_write_state <= 0;
            s_axi_awready <= 1;
            s_axi_wready  <= 1;
            s_axi_bvalid  <= 0;
        end else case(s_write_state)

        0:  begin
                s_axi_bvalid <= 0;                    // BVALID will go high only when we have filled in BRESP

                if (S_AW_HANDSHAKE) begin             // If this is the write-address handshake...
                    s_axi_awready <= 0;               //     We are no longer ready to accept a new address
                    s_axi_awaddr  <= S_AXI_AWADDR;    //     Keep track of the address we should write to
                end

                if (S_W_HANDSHAKE) begin              // If this is the write-data handshake...
                    s_axi_wready     <= 0;            //     We are no longer ready to accept new data
                    s_axi_wdata      <= S_AXI_WDATA;  //     Keep track of the data we're supposed to write
                    user_write_start <= 1;            //     Start the application-specific write logic
                    s_write_state    <= 1;            //     And go wait for that write-logic to complete
                end
            end

        1:  if (user_write_complete) begin            // If the application-specific write-logic is done...
                s_axi_bvalid <= 1;                    //   Tell the AXI master that BRESP is valid
                if (S_B_HANDSHAKE) begin              //   Wait for the AXI master to say "OK, I saw your response"
                    s_axi_awready <= 1;               //     Once that happens, we're ready for a new address
                    s_axi_wready  <= 1;               //     And we're ready for new data
                    s_write_state <= 0;               //     Go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //              Application-specific logic for handling read/writes to the slave interface 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    
    //=========================================================================================================
    // State machine that handles AXI master reads of our AXI4-Lite slave registers
    //
    // When user_read_start goes high, this state machine should handle the read-request.
    //    s_axi_araddr = The byte address of the register to read
    //
    // When read operation is complete:
    //    user_read_idle = 1
    //    s_axi_rresp     = OKAY/SLVERR response to send to the requesting master
    //    s_axi_rdata     = The read-data to send back to the requesting master
    //=========================================================================================================
    always @(posedge AXI_ACLK) begin

        if (AXI_ARESETN == 0) begin
            user_read_idle <= 1;
        end else if (user_read_start) begin
            
            // By default, we'll return a read-response of OKAY
            s_axi_rresp <= OKAY;     
            
            // Turn the read-address into a register number
            case(s_axi_araddr >> 2)
                
                // Handle reads of legitimate register addresses
                REG_RADDR_H:    s_axi_rdata <= register[REG_RADDR_H];
                REG_RADDR_L:    s_axi_rdata <= register[REG_RADDR_L];
                REG_WADDR_H:    s_axi_rdata <= register[REG_WADDR_H];
                REG_WADDR_L:    s_axi_rdata <= register[REG_WADDR_L];
                REG_BLK_SIZE:   s_axi_rdata <= register[REG_BLK_SIZE];
                REG_COUNT:      s_axi_rdata <= register[REG_COUNT];
                REG_RRESULT_H:  s_axi_rdata <= elapsed_read_cycles[63:32];
                REG_RRESULT_L:  s_axi_rdata <= elapsed_read_cycles[31: 0];
                REG_WRESULT_H:  s_axi_rdata <= elapsed_write_cycles[63:32];
                REG_WRESULT_L:  s_axi_rdata <= elapsed_write_cycles[31: 0];

                REG_CTL_STAT:   begin
                                    s_axi_rdata[0]    <= ~is_read_engine_idle;
                                    s_axi_rdata[1]    <= ~is_write_engine_idle;
                                    s_axi_rdata[31:2] <= 0;
                                end
                
                // A read of an unknown register results in a SLVERR response
                default:      begin
                                  s_axi_rdata    <= 32'h0DEC0DE0;
                                  s_axi_rresp    <= SLVERR;
                              end
            endcase
        end
    end
    //=========================================================================================================
    

    //=========================================================================================================
    // State machine that handles AXI master writes to our AXI4-Lite slave registers
    //
    // When user_write_start goes high, this state machine should handle the write-request.
    //    s_axi_awaddr = The byte address of the register to write to
    //    s_axi_wdata  = The 32-bit word to write into that register
    //
    // When write operation is complete:
    //    user_write_idle = 1
    //    s_axi_bresp     = OKAY/SLVERR response to send to the requesting master
    //
    // If the write was to the REG_CTL_STAT:
    //   If bit 0 = 1, start_read is pulsed high for one cycle
    //   If bit 1 = 1, start_write is pulsed high for one cycle
    //
    // If start_read or start_write gets pulsed, these things are true:
    //   beats_per_burst = The number of beats in an AXI burst
    //   xfer_block_size = The size of a single data-burst in bytes
    //   xfer_count      = The number of blocks to data to read
    //=========================================================================================================
    
    always @(posedge AXI_ACLK) begin

        // When start gets set to 1, ensure that it's a one-clock-cycle pulse
        start_read  <= 0;
        start_write <= 0;

        // The cycle counter increments continuously, once per clock cycle
        cycle_counter <= cycle_counter + 1;

        if (AXI_ARESETN == 0) begin
            user_write_idle <= 1;
            xfer_count      <= 0;

        end else if (user_write_start) begin
            
            // By default, we'll return a write-response of OKAY
            s_axi_bresp  <= OKAY;     
            
            // Write to the appropriate register
            case(s_axi_awaddr >> 2)
                
                // Handle writes to legitimate register addresses
                REG_RADDR_H:  register[REG_RADDR_H ] <= s_axi_wdata;
                REG_RADDR_L:  register[REG_RADDR_L ] <= s_axi_wdata; 
                REG_WADDR_H:  register[REG_WADDR_H ] <= s_axi_wdata;
                REG_WADDR_L:  register[REG_WADDR_L ] <= s_axi_wdata; 
                REG_BLK_SIZE: register[REG_BLK_SIZE] <= s_axi_wdata;
                REG_COUNT:    register[REG_COUNT   ] <= s_axi_wdata;

                // A write to the control/status register starts a bandwidth measurement
                REG_CTL_STAT:   if (is_read_engine_idle && is_write_engine_idle && register[REG_COUNT] != 0) begin
                                    cycle_counter     <= 0;
                                    xfer_count        <= register[REG_COUNT];
                                    xfer_count_less_1 <= register[REG_COUNT] - 1;
                                    xfer_block_size   <= register[REG_BLK_SIZE];
                                    beats_per_burst   <= register[REG_BLK_SIZE] >> $clog2(BYTES_PER_BEAT);
                                    start_read        <= s_axi_wdata[0];
                                    start_write       <= s_axi_wdata[1];
                                end
                     
                // A write to an unknown register results in a SLVERR response
                default:      s_axi_bresp <= SLVERR;
                              
            endcase
        end 
    end

    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //                           End of AXI slave read/write handlers
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><




    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //                    The state machines in this section measure bandwidth
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><


    
    //=========================================================================================================
    // State machine for queing up read requests
    //
    // To start: pulse "start_read" high for one cycle
    //
    // At start:
    //   beats_per_burst   = The number of beats in an AXI burst
    //   xfer_count        = The number of bursts to transfer
    //   xfer_count_less_1 = Same as above, minus 1
    //=========================================================================================================
    reg m_rreq_state;

    // Declare registers that we will use to control the AXI AR channel
    reg                     m_axi_arvalid; 
    reg[3:0]                m_axi_arid;    assign M_AXI_ARID   = m_axi_arid;
    reg[AXI_ADDR_WIDTH-1:0] m_axi_araddr;  assign M_AXI_ARADDR = m_axi_araddr;
    reg[7:0]                m_axi_arlen;   assign M_AXI_ARLEN  = m_axi_arlen;
    
    // Wire up the AXI interface outputs
    assign M_AXI_ARSIZE  = $clog2(BYTES_PER_BEAT);
    assign M_AXI_ARBURST = 1;   // Incremental burst
    assign M_AXI_ARPROT  = 0;   // Normal, secure, data-access
    assign M_AXI_ARLOCK  = 0;   // Normal signaling
    assign M_AXI_ARCACHE = 0;   // Normal, no cache, no buffer
    assign M_AXI_ARQOS   = 0;   // Lowest quality of service (unused)
    //=========================================================================================================

    // ARVALID can only be raised when there is room for the slave to accept another read request    
    assign M_AXI_ARVALID = m_axi_arvalid & ((reads_queued - blocks_read) < MAX_OUTSTANDING_RREQ);
    
    always @(posedge AXI_ACLK) begin

        // We come out of reset in state 0        
        if (AXI_ARESETN == 0) begin
            m_rreq_state  <= 0;
            m_axi_arid    <= 0;
            m_axi_arvalid <= 0;
            reads_queued  <= 0;
        end else

        case(m_rreq_state)
         
            // Here we are waiting for the signal to begin a measurement
            0:  if (start_read) begin
                    m_axi_arlen   <= beats_per_burst - 1;
                    m_axi_arid    <= 0;
                    m_axi_araddr  <= {register[REG_RADDR_H], register[REG_RADDR_L]} + ADDRESS_OFFSET;
                    m_axi_arvalid <= 1;
                    reads_queued  <= 0;
                    m_rreq_state  <= 1;
                end

            // Here, we wait for the other side to tell us it has accepted our read request
            1:  if (M_AR_HANDSHAKE) begin
                    if (reads_queued == xfer_count_less_1) begin
                        m_axi_arvalid <= 0;
                        m_rreq_state  <= 0;
                    end
                    m_axi_arid   <= m_axi_arid + 1;    
                    m_axi_araddr <= m_axi_araddr + xfer_block_size;
                    reads_queued <= reads_queued + 1;
                end

        endcase
    end
    //=========================================================================================================



    //=========================================================================================================
    // FSM logic used for receiving requested data from the slave 
    //
    // To start: start_read is pulsed high for one clock cycle
    //
    // At start:
    //   beats_per_burst   = The number of beats in an AXI burst
    //   xfer_count        = The number of bursts to transfer
    //   xfer_count_less_1 = Same as above, minus 1
    //=========================================================================================================
       
    // RREADY is active whenever we're waiting for data
    assign M_AXI_RREADY = (m_read_state == 1);

    always @(posedge AXI_ACLK) begin

        // We come out of RESET in state 0
        if (AXI_ARESETN == 0) begin
            blocks_read  <= 0;
            m_read_state <= 0;
        end
        
        else case (m_read_state)

            0:  if (start_read) begin
                    blocks_read  <= 0;    // Start counting number of data bursts received
                    m_read_state <= 1;    // Go wait for read-channel handshakes
                end
           
            1:  if (M_R_HANDSHAKE && M_AXI_RLAST) begin
                    if (blocks_read == xfer_count_less_1) begin
                        elapsed_read_cycles <= cycle_counter;
                        m_read_state        <= 0;
                    end
                    blocks_read <= blocks_read + 1;
                end
        endcase
    end
    //=========================================================================================================



    
    //=========================================================================================================
    // State machine for queing up write requests
    //
    // To start: pulse "start_write" high for one cycle
    //
    // At start:
    //   beats_per_burst   = The number of beats in an AXI burst
    //   xfer_count        = The number of bursts to transfer
    //   xfer_count_less_1 = Same as above, minus 1
    //=========================================================================================================
    reg m_wreq_state;

    // Declare registers that we will use to control the AXI AW channel
    reg                     m_axi_awvalid; 
    reg[3:0]                m_axi_awid;    assign M_AXI_AWID   = m_axi_awid;
    reg[AXI_ADDR_WIDTH-1:0] m_axi_awaddr;  assign M_AXI_AWADDR = m_axi_awaddr;
    reg[7:0]                m_axi_awlen;   assign M_AXI_AWLEN  = m_axi_awlen;
    
    // Wire up the AXI interface outputs
    assign M_AXI_AWSIZE  = $clog2(BYTES_PER_BEAT);
    assign M_AXI_AWBURST = 1;   // Incremental burst
    assign M_AXI_AWPROT  = 0;   // Normal, secure, data-access
    assign M_AXI_AWLOCK  = 0;   // Normal signaling
    assign M_AXI_AWCACHE = 0;   // Normal, no cache, no buffer
    assign M_AXI_AWQOS   = 0;   // Lowest quality of service (unused)
    //=========================================================================================================

    // AWVALID can only be raised when there is room for the slave to accept another write request    
    assign M_AXI_AWVALID = m_axi_awvalid & ((writes_queued - blocks_acked) < MAX_OUTSTANDING_WREQ);
    
    always @(posedge AXI_ACLK) begin

        // We come out of reset in state 0        
        if (AXI_ARESETN == 0) begin
            m_wreq_state  <= 0;
            m_axi_awid    <= 0;
            m_axi_awvalid <= 0;
            writes_queued <= 0;
        end else

        case(m_wreq_state)
         
            // Here we are waiting for the signal to begin a measurement
            0:  if (start_write) begin
                    m_axi_awlen   <= beats_per_burst - 1;
                    m_axi_awid    <= 0;
                    m_axi_awaddr  <= {register[REG_WADDR_H], register[REG_WADDR_L]} + ADDRESS_OFFSET;
                    m_axi_awvalid <= 1;
                    writes_queued <= 0;
                    m_wreq_state  <= 1;
                end

            // Here, we wait for the other side to tell us it has accepted our write request
            1:  if (M_AW_HANDSHAKE) begin
                    if (writes_queued == xfer_count_less_1) begin
                        m_axi_awvalid <= 0;
                        m_wreq_state  <= 0;
                    end
                    m_axi_awid    <= m_axi_awid + 1;    
                    m_axi_awaddr  <= m_axi_awaddr + xfer_block_size;
                    writes_queued <= writes_queued + 1;
                end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // State machine for writing data to the master interface
    //
    //  To start:   pulse start_write high for one cycle
    //
    //=========================================================================================================
    reg       m_write_state;
    reg[8:0]  wbeats_remaining;
    reg[31:0] wdata;
    //=========================================================================================================

    // Each data write will have a unique, identifiable value
    assign M_AXI_WDATA = {wdata, 480'h0};

    // WVALID is true any time we're actively writing data
    assign M_AXI_WVALID = (m_write_state == 1 && writes_queued > blocks_written); 
    
    // WSTRB should always have all bits on to signify that this is a full-data-width write
    assign M_AXI_WSTRB = -1;

    // WLAST is raised on the last beat of every burst
    assign M_AXI_WLAST  = (m_write_state == 1 && wbeats_remaining == 0);

    always @(posedge AXI_ACLK) begin

        // If we're in RESET mode...
        if (AXI_ARESETN == 0) begin
            m_write_state   <= 0;
            blocks_written  <= 0;
        end else

        // Otherwise, we're not in RESET and our state machine is running
        case (m_write_state)

            // Wait for the signal to start
            0:  if (start_write) begin
                    m_write_state    <= 1;
                    blocks_written   <= 0;
                    wbeats_remaining <= beats_per_burst-1;
                    wdata            <= 0;
                end


            // Every time we see a "Data was accepted" handshake, keep track of how many beats we've sent
            1:  if (M_W_HANDSHAKE) begin
                    
                    // Every write transaction gets unique data
                    wdata <= wdata + 1;
                    
                    // Don't forget, this doesn't effect the 'if' statement below on this clock cycle
                    wbeats_remaining <= wbeats_remaining - 1;

                    // After the last beat, go wait for another block to arrive in the FIFO
                    if (wbeats_remaining == 0) begin
                        m_write_state    <= (blocks_written == xfer_count_less_1) ? 0 : 1;
                        wbeats_remaining <= beats_per_burst - 1;
                        blocks_written   <= blocks_written + 1;
                    end

                end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // State machine for counting write-acknowledgements
    //
    // To start:   pulse start_write high for one cycle
    //
    // Running count of B-channel responses is in blocks_acked
    //=========================================================================================================
    assign M_AXI_BREADY = m_wack_state;

    always @(posedge AXI_ACLK) begin

        // If we're in RESET mode...
        if (AXI_ARESETN == 0) begin
            m_wack_state <= 0;
            blocks_acked <= 0;
        end else

        // Otherwise, we're not in RESET and our state machine is running
        case (m_wack_state)

            // Wait for the signal to start
            0:  if (start_write) begin
                    m_wack_state <= 1;
                    blocks_acked <= 0;
                end

            // Count the number of write-acknowledgments we receive
            1:  if (M_B_HANDSHAKE) begin
                    if (blocks_acked == xfer_count_less_1) begin
                        elapsed_write_cycles <= cycle_counter;
                        m_wack_state         <= 0;
                    end
                    blocks_acked <= blocks_acked + 1;
                end
        endcase
    end
    //=========================================================================================================

endmodule




