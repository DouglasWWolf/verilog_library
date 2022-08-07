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
    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    >>>> IF YOU GET A BUILD-TIME ERROR THAT SAYS 'xpm_fifo_sync not found', <<<<
    >>>> run the TCL command "auto_detect_xpm" and try your build again.    <<<<
    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<



    This module is a DMA engine that moves data (in units of 4Kb blocks) from
    an AXI source address to an AXI destination address

    On the AXI4-lite slave interface, there are six 32-bit registers:
       Offset 0x00 : Source address high 32-bits
       Offset 0x04 : Source address low  32-bits
       Offset 0x08 : Destination address high 32-bits
       Offset 0x0C : Destination address low  32-bit
       Offset 0x10 : # of 4096 byte blocks to transfer
       Offset 0x14 : Write any value = start DMA
                     Read = get DMA completion status

    In your design:
        Connect M00_AXI to the data source (or its interconnect)
        Connect M01_AXI to the data destination (or its interconnect)

    Overall architecture of the DMA engine:

    4Kb blocks of data are copied from the source into the FIFO.   Once a block of
    data is in the FIFO, a seperate process reads it from the FIFO and sends it to
    the destination.   For the sake of effiency, the "read from source" and "write
    to destination" processes happen in parallel.

*/


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//            Application-specific logic goes at the bottom of the file
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

// Uncomment this in order to generate various ports for debugging with the ILA
//`define DEBUG

module dma_engine#
(
    parameter[63:0] SRC_ADDR_OFFSET  = 64'h0000_0000,
    parameter[63:0] DST_ADDR_OFFSET  = 64'h0000_0000,
    parameter       AXI_DATA_WIDTH   = 512,
    parameter       AXI_ADDR_WIDTH   = 64,
    parameter       S_AXI_ADDR_WIDTH = 5,
    parameter       S_AXI_DATA_WIDTH = 32 

)
(
    input wire  AXI_ACLK, AXI_ARESETN,

    `ifdef DEBUG
        output wire      DBG_DMA_START,
        output wire[3:0] DBG_DMA_STATE,
        output wire[1:0] DBG_BLOCKS_IN_FIFO,
        output wire      DBG_FIFO_EMPTY,
        output wire      DBG_FIFO_READ,
        output wire      DBG_FIFO_WRITE,
        output wire[3:0] DBG_M00_READ_STATE,
        output wire[3:0] DBG_M01_WRITE_STATE,
        output wire[7:0] DBG_BLOCKS_READ,
        output wire[7:0] DBG_BLOCKS_WRITTEN,
        output wire[7:0] DBG_BLOCK_COUNT,
    `endif

    //==========================================================================
    //            This defines the AXI4-Lite slave control interface
    //==========================================================================
    // "Specify write address"              -- Master --    -- Slave --
    input  wire [S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_AWADDR,   
    input  wire                             S_AXI_AWVALID,  
    output wire                                             S_AXI_AWREADY,
    input  wire  [2 : 0]                    S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input  wire [S_AXI_DATA_WIDTH-1 : 0]    S_AXI_WDATA,      
    input  wire                             S_AXI_WVALID,
    input  wire [(S_AXI_DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
    output wire                                             S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output  wire [1 : 0]                                    S_AXI_BRESP,
    output  wire                                            S_AXI_BVALID,
    input   wire                            S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input  wire [S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_ARADDR,     
    input  wire                             S_AXI_ARVALID,
    input  wire [2 : 0]                     S_AXI_ARPROT,     
    output wire                                             S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output  wire [S_AXI_DATA_WIDTH-1 : 0]                   S_AXI_RDATA,
    output  wire                                            S_AXI_RVALID,
    output  wire [1 : 0]                                    S_AXI_RRESP,
    input   wire                            S_AXI_RREADY,
    //==========================================================================



   

    //==========================================================================
    //  This defines the AXI Master interface that connects to the data source
    //==========================================================================

    // "Specify read address"              -- Master --      -- Slave --
    output wire[AXI_ADDR_WIDTH-1 : 0]      M00_AXI_ARADDR,     
    output wire                            M00_AXI_ARVALID,
    output wire[2:0]                       M00_AXI_ARPROT,     
    output wire                            M00_AXI_ARLOCK,
    output wire[3:0]                       M00_AXI_ARID,
    output wire[7:0]                       M00_AXI_ARLEN,
    output wire[2:0]                       M00_AXI_ARSIZE,
    output wire[1:0]                       M00_AXI_ARBURST,
    output wire[3:0]                       M00_AXI_ARCACHE,
    output wire[3:0]                       M00_AXI_ARQOS,
    input  wire                                              M00_AXI_ARREADY,

    // "Read data back to master"          -- Master --      -- Slave --
    input  wire [AXI_DATA_WIDTH-1 : 0]                       M00_AXI_RDATA,
    input  wire                                              M00_AXI_RVALID,
    input  wire [1:0]                                        M00_AXI_RRESP,
    input  wire                                              M00_AXI_RLAST,
    output wire                            M00_AXI_RREADY,
    //==========================================================================
    
     
    
    //==========================================================================
    //  Defines the AXI Master interface that connects to the data destination
    //==========================================================================
    // "Specify write address"             -- Master --      -- Slave --
    output wire[AXI_ADDR_WIDTH-1:0]        M01_AXI_AWADDR,   
    output wire                            M01_AXI_AWVALID,  
    output wire[2:0]                       M01_AXI_AWPROT,
    output wire[3:0]                       M01_AXI_AWID,
    output wire[7:0]                       M01_AXI_AWLEN,
    output wire[2:0]                       M01_AXI_AWSIZE,
    output wire[1:0]                       M01_AXI_AWBURST,
    output wire                            M01_AXI_AWLOCK,
    output wire[3:0]                       M01_AXI_AWCACHE,
    output wire[3:0]                       M01_AXI_AWQOS,
    input  wire                                              M01_AXI_AWREADY,
    

    // "Write Data"                        -- Master --      -- Slave --
    output wire[AXI_DATA_WIDTH-1 : 0]      M01_AXI_WDATA,      
    output wire                            M01_AXI_WVALID,
    output wire[(AXI_DATA_WIDTH/8)-1:0]    M01_AXI_WSTRB,
    output wire                            M01_AXI_WLAST,
    input  wire                                              M01_AXI_WREADY,


    // "Receive Write Response"           -- Master --       -- Slave --
    input  wire[1:0]                                         M01_AXI_BRESP,
    input  wire                                              M01_AXI_BVALID,
    output wire                           M01_AXI_BREADY
    //==========================================================================



 );




    //=========================================================================================================
    // These are parameters and variables that must be accessible to the rest of the module
    //=========================================================================================================

    // This is the number of bytes in a burst.  Since AXI bursts aren't allowed to cross
    // 4096-byte boundaries, 4096 is the maximum number of bytes in a single burst
    localparam BLOCK_SIZE = 4096;   
    
    // This is how many blocks of data can fit in the FIFO
    localparam FIFO_SIZE_IN_BLOCKS = 2;

    // These calculations assume AXI_DATA_WIDTH is a power of 2
    localparam BYTES_PER_BEAT  = AXI_DATA_WIDTH / 8;
    localparam BEATS_PER_BURST = BLOCK_SIZE / BYTES_PER_BEAT;
    localparam INCR_BURST      = 1;

    localparam REG_SRC_H    = 0;    // Hi word of the DMA source address
    localparam REG_SRC_L    = 1;    // Lo word of the DMA source address
    localparam REG_DST_H    = 2;    // Hi word of the DMA destination address
    localparam REG_DST_L    = 3;    // Lo word of the DMA destination address
    localparam REG_COUNT    = 4;    // Number of 4K blocks to DMA transfer
    localparam REG_CTL_STAT = 5;    // Combined control and status register

    // Storage for the above registers.  (We don't actually store CTL_STAT)    
    reg [31:0] register[0:4];

    // When this is pulsed high, the DMA state-machine springs into action.
    reg        dma_start;       

    // When DMA starts, these will contain the DMA parameters
    reg[31:0] dma_count;
    reg[63:0] dma_source, dma_dest;

    // The state of the DMA state machine
    reg[1:0]   dma_state;   

    // The number of blocks read from source and written to destination during a DMA
    reg[31:0]  blocks_read, blocks_written;
    
    // This is the number of blocks currently stored in the FIFO
    wire BLOCKS_IN_FIFO = (blocks_read - blocks_written);
    
    // This is needed by the FIFO 
    wire RESET = ~AXI_ARESETN;
    
    // The FIFO uses this to tell us when the read lines of the FIFO are valid
    wire fifo_empty;

    // This keeps track of whether the DMA engine is idle
    wire is_dma_engine_idle = (dma_start == 0 && dma_state == 0 && (blocks_read == blocks_written));

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
    reg[S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;

    // Wire up the AXI interface outputs
    reg                       s_axi_arready; assign S_AXI_ARREADY = s_axi_arready;
    reg                       s_axi_rvalid;  assign S_AXI_RVALID  = s_axi_rvalid;
    reg[1:0]                  s_axi_rresp;   assign S_AXI_RRESP   = s_axi_rresp;
    reg[S_AXI_DATA_WIDTH-1:0] s_axi_rdata;   assign S_AXI_RDATA   = s_axi_rdata;
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
                s_axi_rvalid <= 0;                      // RVALID will go high only when we have filled in RDATA
                if (S_AXI_ARVALID) begin                // If the AXI master has given us an address to read...
                    s_axi_arready   <= 0;               //   We are no longer ready to accept an address
                    s_axi_araddr    <= S_AXI_ARADDR;    //   Register the address that is being read from
                    user_read_start <= 1;               //   Start the application-specific read-logic
                    s_read_state    <= 1;               //   And go wait for that read-logic to finish
                end
            end

        1:  if (user_read_complete) begin               // If the application-specific read-logic is done...
                s_axi_rvalid <= 1;                      //   Tell the AXI master that RDATA and RRESP are valid
                if (S_R_HANDSHAKE) begin                //   Wait for the AXI master to say "OK, I saw your response"
                    s_axi_rvalid  <= 0;                 //     The AXI master has registered our data
                    s_axi_arready <= 1;                 //     Once that happens, we're ready to start a new transaction
                    s_read_state  <= 0;                 //     And go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // FSM logic for handling AXI4-Lite write-to-slave transactions
    //=========================================================================================================

    // When a valid address is presented on the bus, this register holds it
    reg[S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;

    // When valid write-data is presented on the bus, this register holds it
    reg[S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    
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
            s_axi_rresp    <= OKAY;     
            
            // Turn the read-address into a register number
            case(s_axi_araddr >> 2)
                
                // Handle reads of legitimate register addresses
                REG_SRC_H:    s_axi_rdata <= register[REG_SRC_H];
                REG_SRC_L:    s_axi_rdata <= register[REG_SRC_L];
                REG_DST_H:    s_axi_rdata <= register[REG_DST_H];
                REG_DST_L:    s_axi_rdata <= register[REG_DST_L];
                REG_COUNT:    s_axi_rdata <= register[REG_COUNT];
                REG_CTL_STAT: s_axi_rdata <= (~is_dma_engine_idle) & 1;
                
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
    // If the write was to the REG_CTL_STAT register and the DMA engine is idle, "dma_start" will be pulsed 
    // high and:
    //
    //  dma_source = The source address of the DMA transfer
    //  dma_dest   = The destination address of the DMA transfer
    //  dma_count  = The number of 4Kb blocks to transfer from source to destination
    //=========================================================================================================
    
    always @(posedge AXI_ACLK) begin

        // When dma_start gets set to 1, ensure that it's a one-clock-cycle pulse
        dma_start <= 0;

        if (AXI_ARESETN == 0) begin
            user_write_idle <= 1;
        end else if (user_write_start) begin
            
            // By default, we'll return a write-response of OKAY
            s_axi_bresp    <= OKAY;     
            
            // Write to the appropriate register
            case(s_axi_awaddr >> 2)
                
                // Handle writes to legitimate register addresses
                REG_SRC_H:      register[REG_SRC_H] <= s_axi_wdata;
                REG_SRC_L:      register[REG_SRC_L] <= s_axi_wdata; 
                REG_DST_H:      register[REG_DST_H] <= s_axi_wdata;
                REG_DST_L:      register[REG_DST_L] <= s_axi_wdata;
                REG_COUNT:      register[REG_COUNT] <= s_axi_wdata;

                // Any write to the control/status register starts a DMA transfer
                REG_CTL_STAT:   if (is_dma_engine_idle && register[REG_COUNT] != 0) begin
                                    dma_count  <= register[REG_COUNT];
                                    dma_source <= {register[REG_SRC_H], register[REG_SRC_L]} + SRC_ADDR_OFFSET;
                                    dma_dest   <= {register[REG_DST_H], register[REG_DST_L]} + DST_ADDR_OFFSET;
                                    dma_start  <= 1;
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
    //                    The state machines in this section are the DMA engine
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><


   
    //=========================================================================================================
    // FSM logic used for reading a single burst of 4Kb from the data source
    //
    //  To start:   amci00_raddr = Address to read from
    //              amci00_read  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "amci00_ridle" goes high.
    //=========================================================================================================

    // Define the handshakes for AXI channels we need
    wire M00_R_HANDSHAKE  = M00_AXI_RVALID  & M00_AXI_RREADY;
    wire M00_AR_HANDSHAKE = M00_AXI_ARVALID & M00_AXI_ARREADY;
    
    // The state of this state machine
    reg                     m00_read_state;

    // FSM user interface inputs
    reg[AXI_ADDR_WIDTH-1:0] amci00_raddr;
    reg                     amci00_read;

    // FSM user interface outputs
    wire                    amci00_ridle = (m00_read_state == 0 && amci00_read == 0);     

    // AXI registers and outputs
    reg[AXI_ADDR_WIDTH-1:0] m00_axi_araddr;  assign M00_AXI_ARADDR  = m00_axi_araddr;
    reg                     m00_axi_arvalid; assign M00_AXI_ARVALID = m00_axi_arvalid;
    reg                     m00_axi_rready;  assign M00_AXI_RREADY  = m00_axi_rready;
    
    // Wire up the AXI interface outputs
    assign M00_AXI_ARBURST = INCR_BURST;
    assign M00_AXI_ARSIZE  = $clog2(BYTES_PER_BEAT);
    assign M00_AXI_ARLEN   = BEATS_PER_BURST - 1;
    assign M00_AXI_ARPROT  = 1;
    assign M00_AXI_ARLOCK  = 0;   // Normal signaling
    assign M00_AXI_ARID    = 1;   // Arbitrary ID
    assign M00_AXI_ARCACHE = 0;   // Normal, no cache, no buffer
    assign M00_AXI_ARQOS   = 0;   // Lowest quality of service (unused)
    //=========================================================================================================
    
    
    always @(posedge AXI_ACLK) begin

        if (AXI_ARESETN == 0) begin
            m00_read_state  <= 0;
            m00_axi_arvalid <= 0;
            m00_axi_rready  <= 0;
        end else case (m00_read_state)

            // Here we are waiting around for someone to raise "amci00_read", which signals us to begin
            // a AXI read at the address specified in "amci00_raddr"
            0:  if (amci00_read) begin
                    m00_axi_araddr  <= amci00_raddr;
                    m00_axi_arvalid <= 1;
                    m00_axi_rready  <= 1;
                    m00_read_state  <= 1;
                end else begin
                    m00_axi_arvalid <= 0;
                    m00_axi_rready  <= 0;
                    m00_read_state  <= 0;
                end
            
            // Every time a M00_R_HANDSHAKE occurs, M00_AXI_RDATA is written to the FIFO.
            // Here, we are waiting for the last beat of the burst to occur
            1:  begin

                    // If we see the "Address to read" handshake, acknowledge we saw it
                    if (M00_AR_HANDSHAKE) m00_axi_arvalid <= 0;

                    // Every time we see the R(ead)-channel handshake, the data in M00_AXI_RDATA
                    // will be written to the FIFO.   When we see the last beat of the burst, we
                    // will go back to waiting for someone to tell us to read another burst
                    if (M00_R_HANDSHAKE && M00_AXI_RLAST) begin
                        m00_axi_rready <= 0;
                        m00_read_state <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // FSM logic used for reading from the FIFO and writing data to the DMA destination
    //
    //  To start:   pulse dma_start high for one cycle
    //
    //  At start:   dma_dest   = AXI destination address for data
    //              dma_count = The number of 4Kb blocks of data to write to the destination            
    //              
    //=========================================================================================================
    reg[1:0] m01_write_state; 
    reg[7:0] beats_remaining;

    // Wire up the registered AXI outputs
    reg[AXI_ADDR_WIDTH-1:0] m01_axi_awaddr;  assign M01_AXI_AWADDR  = m01_axi_awaddr;
    reg                     m01_axi_awvalid; assign M01_AXI_AWVALID = m01_axi_awvalid;
    reg                     m01_axi_bready;  assign M01_AXI_BREADY  = m01_axi_bready;
    reg                     m01_axi_wlast;   assign M01_AXI_WLAST   = m01_axi_wlast;

    // Wire up the hard-coded AXI outputs
    assign M01_AXI_AWPROT  = 0;
    assign M01_AXI_AWCACHE = 0;
    assign M01_AXI_AWSIZE  = $clog2(BYTES_PER_BEAT);
    assign M01_AXI_AWLEN   = BEATS_PER_BURST - 1;
    assign M01_AXI_AWBURST = INCR_BURST;
    assign M01_AXI_WSTRB   = (1 << BYTES_PER_BEAT) -1;

    // Define the handshakes for AXI channels we need 
    wire M01_AW_HANDSHAKE = M01_AXI_AWVALID & M01_AXI_AWREADY;
    wire M01_W_HANDSHAKE  = M01_AXI_WVALID  & M01_AXI_WREADY;
    wire M01_B_HANDSHAKE  = M01_AXI_BVALID  & M01_AXI_BREADY;
    //=========================================================================================================

    assign M01_AXI_WVALID = (m01_write_state == 2 && fifo_empty == 0);

    always @(posedge AXI_ACLK) begin
        
        // This signal should be low on any clock cycle that it isn't explicitly driven high
        m01_axi_wlast  <= 0;
        

        // If we're in RESET mode...
        if (AXI_ARESETN == 0) begin
            m01_write_state <= 0;
            m01_axi_awvalid <= 0;
            m01_axi_bready  <= 0; 
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (m01_write_state)
            
            // Wait for the signal to start, then record the AXI address where
            // we should start writing data
            0:  begin
                    blocks_written <= 0;
                    if (dma_start) begin
                        m01_axi_awaddr   <= dma_dest;
                        m01_write_state  <= 1;
                    end
                end

            // If there is a block waiting for us in the FIFO... 
            1:  if (BLOCKS_IN_FIFO) begin
                    m01_axi_awvalid <= 1;                // Tell the slave that the address on the bus is valid
                    beats_remaining <= BEATS_PER_BURST;  // This is how many beats we have yet to write to the bus
                    if (M01_AW_HANDSHAKE) begin          // If we see the AW channel acknowledgement...
                        m01_axi_awvalid <= 0;            //   Stop broadcasting on the AW channel
                        m01_write_state <= 2;            //   And go start writing data beats to the AXI bus
                    end
                end else begin
                    if (is_dma_engine_idle) m01_write_state <= 0;
                end
            
            
            // Every time we see a "Data was accepted" handshake, keep track of how many beats we've sent
            2:  if (M01_W_HANDSHAKE) begin

                    // If this is the 2nd to last beat, on the next cycle, (which is the last beat) raise AXI_WLAST
                    // and AXI_BREADY in order to tell the other side that it's the last beat of the burst
                    if (beats_remaining == 2) begin
                        m01_axi_wlast   <= 1;
                        m01_axi_bready  <= 1;
                    end

                    // On the last beat, go wait for the handshake
                    if (beats_remaining == 1) m01_write_state <= 3;

                    // In any case, there is now one fewer beats to transmit
                    beats_remaining <= beats_remaining - 1;

                end


            // Wait for the other side to acknowledge our B channel
            3:  if (M01_B_HANDSHAKE) begin
                    blocks_written  <= blocks_written + 1;
                    m01_axi_bready  <= 0;
                    m01_axi_awaddr  <= m01_axi_awaddr + BLOCK_SIZE;
                    m01_write_state <= 1;
                end

        endcase
    end
    //=========================================================================================================



    //=========================================================================================================
    // This state machine implements the "read" side of the DMA engine, reading blocks of data from the
    // source and placing them into the FIFO.
    //
    // To start: pulse "dma_start" high for one cycle
    // 
    // At start: dma_source = The AXI address of the source of the DMA transfer  
    //           dma_count  = The number of 4Kb blocks of RAM to read from the source
    //=========================================================================================================
     always @(posedge AXI_ACLK) begin

        // Ensure that when this register is pulsed, the pulse lasts for only a single clock-cycle
        amci00_read <= 0;

        // During reset, "dma_state" goes back to "wait for dma_start"
        if (AXI_ARESETN == 0) begin
            dma_state   <= 0;

        end else case(dma_state)
         
            // Here we are waiting for the signal to begin a DMA transfer.  When that
            // signal arrives, start the read of the first block of data.
            0:  begin
                    blocks_read <= 0;
                    if (dma_start) begin
                        amci00_raddr     <= dma_source;
                        amci00_read      <= 1;
                        dma_state        <= 1;
                    end
                end

            // Here we wait for the AXI read of the block of data to complete.  
            1:  if (amci00_ridle) begin
                    
                    // If there are no more blocks to read, go wait for block-writes to finish
                    if (blocks_read+1 == dma_count) 
                        dma_state <= 3;

                    // If there are still data blocks remaining to be read in...
                    else begin
                        amci00_raddr <= amci00_raddr + BLOCK_SIZE;    // Point to the next source address
                        if (BLOCKS_IN_FIFO == FIFO_SIZE_IN_BLOCKS-2)  // If there is room in the FIFO...
                            amci00_read <= 1;                         //   Start reading the next block of data
                        else                                          // Otherwise...
                            dma_state   <= 2;                         //   Go wait for there to be room in the FIFO
                    end

                    // In any case, we have just finished reading one more block
                    blocks_read <= blocks_read + 1;
                end

            // Here we're waiting for there to be sufficient free room in the FIFO
            // for us to store another block of data.  Once there is room to store 
            // that data, start the read.
            2:  if (BLOCKS_IN_FIFO < FIFO_SIZE_IN_BLOCKS) begin
                    amci00_read <= 1;
                    dma_state   <= 1;
                end

            // Here we are waiting for the "write-data-to-destination" half of the DMA
            // engine to finish writing data.  Once that is complete, this DMA transfer
            // is done
            3:  if (blocks_written == blocks_read) dma_state <= 0;
                   

        endcase
    end
    //=========================================================================================================



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //    This is the FIFO that serves as a buffer between the read-from-source DMA state-machine and the
    //    write-to-destination DMA state-machine
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    xpm_fifo_sync#
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),      
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (BEATS_PER_BURST * FIFO_SIZE_IN_BLOCKS),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (1),    
      .PROG_FULL_THRESH     (1),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (AXI_DATA_WIDTH),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1010"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (AXI_DATA_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_dma_fifo
    (
        .rst        (RESET          ),                      
        .wr_clk     (AXI_ACLK       ),          
        .empty      (fifo_empty     ),            
        .din        (M00_AXI_RDATA  ),                 
        .wr_en      (M00_R_HANDSHAKE),            
        .dout       (M01_AXI_WDATA  ),              
        .rd_en      (M01_W_HANDSHAKE),            

      //------------------------------------------------------------
      // This only exists in xpm_fifo_async, not in xpm_fifo_sync
      // .rd_clk    (CLK               ),                     
      //------------------------------------------------------------

        .full(),              
        .data_valid(), 
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


    //=========================================================================================================
    // Various outputs that are handy for debugging
    //=========================================================================================================
    `ifdef DEBUG
        assign DBG_DMA_START       = dma_start;
        assign DBG_DMA_STATE       = dma_state;
        assign DBG_BLOCKS_IN_FIFO  = BLOCKS_IN_FIFO;
        assign DBG_FIFO_EMPTY      = fifo_empty;
        assign DBG_FIFO_READ       = M01_W_HANDSHAKE;
        assign DBG_FIFO_WRITE      = M00_R_HANDSHAKE;
        assign DBG_M00_READ_STATE  = m00_read_state;
        assign DBG_M01_WRITE_STATE = m01_write_state;
        assign DBG_BLOCKS_READ     = blocks_read;
        assign DBG_BLOCKS_WRITTEN  = blocks_written;
        assign DBG_BLOCK_COUNT     = register[REG_COUNT];
    `endif


endmodule




