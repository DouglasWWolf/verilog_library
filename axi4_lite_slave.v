`timescale 1ns / 1ps
/*
-------------------------------------------------------------------------------
                     ------->  Revision History  <------
-------------------------------------------------------------------------------
  Date     Who   Ver  Changes
-------------------------------------------------------------------------------
10-May-22  DWW  1000  Initial
-------------------------------------------------------------------------------

*/

module axi4_lite_slave#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 5
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

    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = S_AXI_BVALID  & S_AXI_BREADY;
    wire R_HANDSHAKE  = S_AXI_RVALID  & S_AXI_RREADY;
    wire W_HANDSHAKE  = S_AXI_WVALID  & S_AXI_WREADY;
    wire AR_HANDSHAKE = S_AXI_ARVALID & S_AXI_ARREADY;
    wire AW_HANDSHAKE = S_AXI_AWVALID & S_AXI_AWREADY;
    
    // These two handshakes signal a valid AXI write and a valid AXI read, respectively
    wire WR_HANDSHAKE = W_HANDSHAKE & AW_HANDSHAKE;
    wire RD_HANDSHAKE = AR_HANDSHAKE;

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
     //=========================================================================================================
    reg read_state;
    always @(posedge AXI_ACLK) begin
        user_read_start <= 0;
        
        if (AXI_ARESETN == 0) begin
            read_state  <= 0;
            axi_arready <= 1;
            axi_rvalid  <= 0;
        end else case(read_state)

        0:  begin
                axi_rvalid <= 0;                        // RVALID will go high only when we have filled in RDATA
                if (S_AXI_ARVALID) begin                // If the AXI master has given us an address to read...
                    axi_arready     <= 0;               //   We are no longer ready to accept an address
                    axi_araddr      <= S_AXI_ARADDR;    //   Register the address that is being read from
                    user_read_start <= 1;               //   Start the application-specific read-logic
                    read_state      <= 1;               //   And go wait for that read-logic to finish
                end
            end

        1:  if (user_read_idle) begin                   // If the application-specific read-logic is done...
                axi_rvalid <= 1;                        //   Tell the AXI master that RDATA and RRESP are valid
                if (R_HANDSHAKE) begin                  //   Wait for the AXI master to say "OK, I saw your response"
                    axi_arready <= 1;                   //     Once that happens, we're ready to start a new transaction
                    read_state  <= 0;                   //     And go wait for a new transaction to arrive
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
                axi_bvalid <= 0;                        // BVALID will go high only when we have filled in BRESP
                if (WR_HANDSHAKE) begin                 // If the AXI master has given us an address and data to write
                    axi_awready      <= 0;              //   We are no longer ready to accept a new address
                    axi_wready       <= 0;              //   We are no longer ready to accept new data
                    axi_awaddr       <= S_AXI_AWADDR;   //   Register the address that is being written to
                    axi_wdata        <= S_AXI_WDATA;    //   Register the data that is being written
                    user_write_start <= 1;              //   Start the application-specific write-logic
                    write_state      <= 1;              //   And go wait for that write-logic to finish
                end
            end

        1:  if (user_write_idle) begin                   // If the application-specific write-logic is done...
                axi_bvalid <= 1;                         //   Tell the AXI master that BRESP is valid
                if (B_HANDSHAKE) begin                   //   Wait for the AXI master to say "OK, I saw your response"
                    axi_awready <= 1;                    //     Once that happens, we're ready for a new address
                    axi_wready  <= 1;                    //     And we're ready for new data
                    write_state <= 0;                    //     Go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //                                     An example of user logic is below
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    //=========================================================================================================
    // Your application specific state machine for handling AXI "read" transactions goes here
    //=========================================================================================================
    // The rules:
    //
    // --- Inputs ---
    // Your can have your state machine start in one of two ways:
    // Method 1: When "user_read_start" is true.
    //           In this case, axi_araddr holds the address to read from
    // Method 2: When RD_HANDSHAKE is true.
    //           In this case, S_AXI_ARADDR holds the address to read from
    //
    // --- Outputs ---
    // Your state machine is assumed to be idle/done whenever "user_read_idle" is high
    // axi_rdata = The data to send back to the AXI master
    // axi_rresp = The error response to send back to the AXI master, either OKAY or SLVERR (slave error)
    //
    // Don't forget that by convention, AXI4-lite addresses begin on 4-byte boundaries
    //=========================================================================================================

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~   This is an example of a state machine for handling AXI reads ~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // In this example, rather than build a full blown state machine, we are utilizing the "quick-and-dirty"
    // method of responding every time the AXI Master asserts a valid read address on the bus
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    // Any time the "address to read from" becomes valid...
    reg[31:0] example_data;
    always @(posedge AXI_ACLK) if (RD_HANDSHAKE) begin
        axi_rresp      <= OKAY;                 // By default, our response will be OKAY
        user_read_idle <= 1;                    // Tell the other task that we're (permanently) done
        case (S_AXI_ARADDR)                     // Examine the address the user is reading
            0:  axi_rdata <= 76;                //     If they're reading address 0, respond with 76
            4:  axi_rdata <= example_data;      //     If they're reading address 4, give them some data
            8:  axi_rdata <= 42;                //     If they're reading address 8, respond with 42
            default:                            //     In all other cases, respond with a slave error
                begin
                  axi_rdata <= 32'h0DEC0DE0;
                  axi_rresp <= SLVERR;
                end
        endcase
    end
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    //=========================================================================================================
    // Your application specific state machine for handling AXI "write transactions goes here
    //=========================================================================================================
    // The rules:
    //
    // --- Inputs ---
    // Your can have your state machine start in one of two ways:
    // Method 1: When "user_write_start" is true
    //           In this case, axi_awaddr/axi_wdata hold the address and data to write
    // Method 2: When WR_HANDSHAKE is true
    //           In this case, S_AXI_AWADDR/S_AXI_WDATA hold the address and data to write
    //
    // --- Outputs ---
    // Your state machine is assumed to be idle/done whenever "user_write_idle" is high
    // axi_bresp = The error response to send back to the AXI master, either OKAY or SLVERR (slave error)
    //
    // Don't forget that by convention, AXI4-lite addresses begin on 4-byte boundaries
    //=========================================================================================================

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~   This is an example of a state machine for handling AXI writes  ~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // In this example, rather than build a full blown state machine, we are utilizing the "quick-and-dirty"
    // method of responding every time the WR_HANDSHAKE is true
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    // Any time the "address-and-data-to-write" becomes valid...
    always @(posedge AXI_ACLK) if (WR_HANDSHAKE) begin
        axi_bresp       <= OKAY;                // By default, our response will be OKAY
        user_write_idle <= 1;                   // Tell the other task that we're (permanently) done
        case (S_AXI_AWADDR)                     // Examine the address the user is writing to
            4:  example_data <= S_AXI_WDATA;    //     If they're writing address 4, record their data
            default:                            //     In all other cases, respond with a slave error
                axi_bresp    <= SLVERR;
        endcase
    end
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

endmodule
