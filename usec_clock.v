`timescale 1ns / 1ps
//====================================================================================
//      This is a microsecond-resolution clock with an AXI4-Lite slave interface
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 11-May-22  DWW  1000  Initial creation
//====================================================================================


 //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
 //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
 //     Everything between here and another marker like this is standard AXI4-Lite slave infrastrcture
 //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
 //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

module usec_clock#
(
    parameter integer AXI_DATA_WIDTH  = 32,
    parameter integer AXI_ADDR_WIDTH  = 3,
    parameter integer CLOCKS_PER_USEC = 125
)
(
    //================ From here down is the AXI4-Lite interface ===============
    input wire  AXI_ACLK,
    input wire  AXI_ARESETN,
        
    // "Specify write address"              -- Master --    -- Slave --
    input  wire [AXI_ADDR_WIDTH-1 : 0]      S_AXI_AWADDR,   
    input  wire                             S_AXI_AWVALID,  
    output wire                                             S_AXI_AWREADY,
    input  wire  [2 : 0]                    S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input  wire [AXI_DATA_WIDTH-1 : 0]      S_AXI_WDATA,      
    input  wire                             S_AXI_WVALID,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]    S_AXI_WSTRB,
    output wire                                             S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output  wire [1 : 0]                                    S_AXI_BRESP,
    output  wire                                            S_AXI_BVALID,
    input   wire                            S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input  wire [AXI_ADDR_WIDTH-1 : 0]      S_AXI_ARADDR,     
    input  wire                             S_AXI_ARVALID,
    input  wire [2 : 0]                     S_AXI_ARPROT,     
    output wire                                             S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output  wire [AXI_DATA_WIDTH-1 : 0]                     S_AXI_RDATA,
    output  wire                                            S_AXI_RVALID,
    output  wire [1 : 0]                                    S_AXI_RRESP,
    input   wire                            S_AXI_RREADY
    //==========================================================================
 );
    
    // These are valid values for BRESP and RRESP
    localparam OKAY   = 0;
    localparam SLVERR = 2;

    // These are for communicating with application-specific read and write logic
    reg user_read_start,  user_read_idle;
    reg user_write_start, user_write_idle;
    wire user_write_complete = (user_write_start == 0) & user_write_idle;
    wire user_read_complete  = (user_read_start  == 0) & user_read_idle;

    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = S_AXI_BVALID  & S_AXI_BREADY;
    wire R_HANDSHAKE  = S_AXI_RVALID  & S_AXI_RREADY;
    wire W_HANDSHAKE  = S_AXI_WVALID  & S_AXI_WREADY;
    wire AR_HANDSHAKE = S_AXI_ARVALID & S_AXI_ARREADY;
    wire AW_HANDSHAKE = S_AXI_AWVALID & S_AXI_AWREADY;
        
    //=========================================================================================================
    // FSM logic for handling AXI read transactions
    //=========================================================================================================
    // When a valid address is presented on the bus, this register holds it
    reg[AXI_ADDR_WIDTH-1:0] axi_araddr;

    // Wire up the AXI interface outputs
    reg                     axi_arready; assign S_AXI_ARREADY = axi_arready;
    reg                     axi_rvalid;  assign S_AXI_RVALID  = axi_rvalid;
    reg[1:0]                axi_rresp;   assign S_AXI_RRESP   = axi_rresp;
    reg[AXI_DATA_WIDTH-1:0] axi_rdata;   assign S_AXI_RDATA   = axi_rdata;
     //========================================================================================================
    reg read_state;
    always @(posedge AXI_ACLK) begin
        user_read_start <= 0;
        
        if (AXI_ARESETN == 0) begin
            read_state  <= 0;
            axi_arready <= 1;
            axi_rvalid  <= 0;
        end else case(read_state)

        0:  begin
                axi_rvalid <= 0;                      // RVALID will go high only when we have filled in RDATA
                if (S_AXI_ARVALID) begin              // If the AXI master has given us an address to read...
                    axi_arready     <= 0;             //   We are no longer ready to accept an address
                    axi_araddr      <= S_AXI_ARADDR;  //   Register the address that is being read from
                    user_read_start <= 1;             //   Start the application-specific read-logic
                    read_state      <= 1;             //   And go wait for that read-logic to finish
                end
            end

        1:  if (user_read_complete) begin             // If the application-specific read-logic is done...
                axi_rvalid <= 1;                      //   Tell the AXI master that RDATA and RRESP are valid
                if (R_HANDSHAKE) begin                //   Wait for the AXI master to say "OK, I saw your response"
                    axi_arready <= 1;                 //     Once that happens, we're ready to start a new transaction
                    read_state  <= 0;                 //     And go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // FSM logic for handling AXI write transactions
    //=========================================================================================================
    // When a valid address is presented on the bus, this register holds it
    reg[AXI_ADDR_WIDTH-1:0] axi_awaddr;

    // When valid write-data is presented on the bus, this register holds it
    reg[AXI_DATA_WIDTH-1:0] axi_wdata;
    
    // Wire up the AXI interface outputs
    reg      axi_awready; assign S_AXI_AWREADY = axi_arready;
    reg      axi_wready;  assign S_AXI_WREADY  = axi_wready;
    reg      axi_bvalid;  assign S_AXI_BVALID  = axi_bvalid;
    reg[1:0] axi_bresp;   assign S_AXI_BRESP   = axi_bresp;
    //=========================================================================================================
    reg write_state;
    always @(posedge AXI_ACLK) begin
        user_write_start <= 0;
        if (AXI_ARESETN == 0) begin
            write_state <= 0;
            axi_awready <= 1;
            axi_wready  <= 1;
            axi_bvalid  <= 0;
        end else case(write_state)

        0:  begin
                axi_bvalid <= 0;                      // BVALID will go high only when we have filled in BRESP

                if (AW_HANDSHAKE) begin               // If this is the write-address handshake...
                    axi_awready <= 0;                 //     We are no longer ready to accept a new address
                    axi_awaddr  <= S_AXI_AWADDR;      //     Keep track of the address we should write to
                end

                if (W_HANDSHAKE) begin                // If this is the write-data handshake...
                    axi_wready       <= 0;            //     We are no longer ready to accept new data
                    axi_wdata        <= S_AXI_WDATA;  //     Keep track of the data we're supposed to write
                    user_write_start <= 1;            //     Start the application-specific write logic
                    write_state      <= 1;            //     And go wait for that write-logic to complete
                end
            end

        1:  if (user_write_complete) begin             // If the application-specific write-logic is done...
                axi_bvalid <= 1;                       //   Tell the AXI master that BRESP is valid
                if (B_HANDSHAKE) begin                 //   Wait for the AXI master to say "OK, I saw your response"
                    axi_awready <= 1;                  //     Once that happens, we're ready for a new address
                    axi_wready  <= 1;                  //     And we're ready for new data
                    write_state <= 0;                  //     Go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //               Everything above is this point is standard AXI4-Lite slave infrastructure
    //
    //   Everything below this point are registers and state machines that make up the core of our module
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    //-------------------------------------------------------------------------
    // Define our 64-bit microsecond counter and the registers that control it
    //-------------------------------------------------------------------------
    localparam COUNTDOWN_WIDTH = $clog2(CLOCKS_PER_USEC);    
    reg[63:0]                usec_counter;
    reg[COUNTDOWN_WIDTH-1:0] countdown;
    reg                      reset_usec_counter;
    //-------------------------------------------------------------------------

    //=========================================================================================================
    // Simple state machine that increments "usec_counter" every microsecond
    //=========================================================================================================
    always @(posedge AXI_ACLK) begin
        if (AXI_ARESETN == 0 || reset_usec_counter) begin
            usec_counter <= 0;
            countdown    <= CLOCKS_PER_USEC - 1;
        end else begin
            if (countdown == 0) begin
                usec_counter <= usec_counter + 1;
                countdown    <= CLOCKS_PER_USEC - 1;
            end else begin
                countdown    <= countdown - 1;
            end
        end
    end
    //=========================================================================================================


    //=========================================================================================================
    // State machine that handles read transaction.   
    // A read of address 0 records the state of usec_counter, handing the user the upper 32 bits and 
    // storing the lower 32 bits.
    //
    // A read of address 4 hands the user the lower 32 bits that were previously stored
    //=========================================================================================================
    reg[31:0] low_order_32;
    always @(posedge AXI_ACLK) if (AR_HANDSHAKE) begin   // If an AXI master has initiated a read...
        axi_rresp      <= OKAY;                          //   By default, our response is 'OKAY'
        user_read_idle <= 1;                             //   Tell the infrastructure that we're done
        case (S_AXI_ARADDR)                              //   Examine the address being read

            0:  begin                                    //   If the master is reading address 0...
                    axi_rdata    <= usec_counter[63:32]; //      Fetch the upper 32-bits of usec_counter
                    low_order_32 <= usec_counter[31: 0]; //      And store the lower 32 bits for later
                end

            4:  axi_rdata <= low_order_32;               //   A read of addr 4 fetches the stored lower 32
            
            default: begin                               //   A read of any other address is an error
                         axi_rdata <= 32'h0DEC0DE0;
                         axi_rresp <= SLVERR;
                     end
        endcase
    end
    //=========================================================================================================
    

    //=========================================================================================================
    // State machine that handles AXI write transactions.   Any "write" transaction resets the usec counter
    //=========================================================================================================
    always @(posedge AXI_ACLK) begin
        user_write_idle    <= 1;
        axi_bresp          <= OKAY;
        reset_usec_counter <= user_write_start;
    end
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

endmodule
