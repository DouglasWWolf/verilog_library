`timescale 1ns / 1ps

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

    localparam OKAY   = 0;
    localparam SLVERR = 2;

    // These are for communicating the the user-supplied "read" logic
    reg user_read_start, user_read_idle;

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
                if (S_AXI_RREADY) begin                 //   Wait for the AXI master to say "OK, I saw your response"
                    axi_arready <= 1;                   //     Once that happens, we're ready to start a new transaction
                    read_state  <= 0;                   //     And go wait for a new transaction to arrive
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
    // Method 1: On high-going edges of "user_read_start".
    //           In this case, axi_araddr holds the address to read from
    // Method 2: On high-going edges of S_AXI_ARVALID
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
    always @(posedge S_AXI_ARVALID) begin
        axi_rresp      <= OKAY;                 // By default, our response will be OKAY
        user_read_idle <= 1;                    // Tell the other task that we're (permanently) done
        case (S_AXI_ARADDR)                     // Examine the address the user is reading
            0:  axi_rdata <= 17;                //     If they're reading address 0, respond with 17
            4:  axi_rdata <= 76;                //     If they're reading address 4, respond with 76
            8:  axi_rdata <= 42;                //     If they're reading address 8, respond with 42
            default:                            //     In all other cases, respond with a slave error
                begin
                  axi_rdata <= 32'h0DEC0DE0;
                  axi_rresp <= SLVERR;
                end
        endcase
    end
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




endmodule
