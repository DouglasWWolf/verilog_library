`timescale 1ns / 1ps
//====================================================================================
// This is a full AXI4 slave that supports bursting. 
//
// Unsupported features:
//     Unaligned memory access
//     Bursts of type WRAP
//     "Narrow" bursts. (i.e., AxLEN must match the data bus width)
//
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 10-May-22  DWW  1000  Initial creation
//====================================================================================


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//       Application-specific read/write logic goes at the bottom of the file
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

module axi4_full_slave#
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
    input  wire[3:0]                        S_AXI_AWID,
    input  wire[7:0]                        S_AXI_AWLEN,
    input  wire[2:0]                        S_AXI_AWSIZE,
    input  wire[1:0]                        S_AXI_AWBURST,
    input  wire                             S_AXI_AWLOCK,
    input  wire[3:0]                        S_AXI_AWCACHE,
    input  wire[3:0]                        S_AXI_AWQOS,
    input  wire[2:0]                        S_AXI_AWPROT,

    output wire                                             S_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    input  wire [AXI_DATA_WIDTH-1 : 0]      S_AXI_WDATA,      
    input  wire                             S_AXI_WVALID,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]    S_AXI_WSTRB,
    input  wire                             S_AXI_WLAST,
    output wire                                             S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output  wire [1 : 0]                                    S_AXI_BRESP,
    output  wire                                            S_AXI_BVALID,
    input   wire                            S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input  wire [AXI_ADDR_WIDTH-1 : 0]      S_AXI_ARADDR,     
    input  wire                             S_AXI_ARVALID,
    input  wire [2 : 0]                     S_AXI_ARPROT,     
    input  wire                             S_AXI_ARLOCK,
    input  wire[3:0]                        S_AXI_ARID,
    input  wire[7:0]                        S_AXI_ARLEN,
    input  wire[1:0]                        S_AXI_ARBURST,
    input  wire[3:0]                        S_AXI_ARCACHE,
    input  wire[3:0]                        S_AXI_ARQOS,
    output wire                                             S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output  wire [AXI_DATA_WIDTH-1 : 0]                     S_AXI_RDATA,
    output  wire                                            S_AXI_RVALID,
    output  wire [1 : 0]                                    S_AXI_RRESP,
    output  wire                                            S_AXI_RLAST,
    input   wire                            S_AXI_RREADY
    //==========================================================================
 );

    localparam AXI_DATA_BYTES = AXI_DATA_WIDTH / 8;

    // These are valid values for BRESP and RRESP
    localparam OKAY   = 0;
    localparam SLVERR = 2;

    // These are for communicating with application-specific read and write logic
    reg app_read,  app_read_idle;
    reg app_write, app_write_idle;
    wire app_write_complete = (app_write == 0) & app_write_idle;
    wire app_read_complete  = (app_read  == 0) & app_read_idle;

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
    reg                     axi_rlast;   assign S_AXI_RLAST   = axi_rlast;   
    reg[1:0]                axi_rresp;   assign S_AXI_RRESP   = axi_rresp;
    reg[AXI_DATA_WIDTH-1:0] axi_rdata;   assign S_AXI_RDATA   = axi_rdata;
    //=========================================================================================================
    reg                     read_state;
    reg[7:0]                rburst_count;
    reg[AXI_ADDR_WIDTH-1:0] rburst_incr;

    always @(posedge AXI_ACLK) begin
        app_read <= 0;
        
        if (AXI_ARESETN == 0) begin
            read_state  <= 0;
            axi_arready <= 1;
            axi_rvalid  <= 0;
        end else case(read_state)

        0:  if (S_AXI_ARVALID) begin                        // Wait for AXI master to start a new transaction
                axi_arready  <= 0;                          //   We are no longer ready for a new transaction
                axi_araddr   <= S_AXI_ARADDR;               //   Register the address to read from
                rburst_count <= S_AXI_ARLEN;                //   Register the number of "extra" beats to read
                rburst_incr  <= (S_AXI_ARBURST) ? AXI_DATA_BYTES : 0; // How big is the address increment on each beat?
                app_read     <= 1;                          //   Start the application-specific read-logic
                read_state   <= 1;                          //   And go wait for that read-logic to complete
            end

        1:  if (app_read_complete) begin                    // When the application-specific read-logic is complete... 
                axi_rvalid <= 1;                            //   Tell the AXI Master that valid read-data is on the bus
                axi_rlast  <= (rburst_count == 0);          //   Note whether this is the last beat of the burst
                if (R_HANDSHAKE) begin                      //   If the AXI Master has said "Read transaction complete"...
                    axi_rvalid <= 0;                        //     RDATA is no longer valid
                    axi_araddr <= axi_araddr + rburst_incr; //     FIgure out what the new address to read from is
                    if (rburst_count) begin                 //     If we still have beats remaining in this burst...
                        rburst_count <= rburst_count - 1;   //       We now have one fewer beats left in the burst
                        app_read     <= 1;                  //       And go read from the addr specified in axi_araddr
                    end else begin                          //     Otherwise, this was the last beat in the burst
                        axi_arready <= 1;                   //       We are now ready to receive another read transaction
                        read_state  <= 0;                   //       Go wait for another read transaction to start
                    end 
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

    // When valid write-data is presented on the bus, these registers hold it
    reg[AXI_DATA_WIDTH-1:0] axi_wdata;
    reg                     axi_wlast;
    
    // Wire up the AXI interface outputs
    reg      axi_awready; assign S_AXI_AWREADY = axi_arready;
    reg      axi_wready;  assign S_AXI_WREADY  = axi_wready;
    reg      axi_bvalid;  assign S_AXI_BVALID  = axi_bvalid;
    reg[1:0] axi_bresp;   assign S_AXI_BRESP   = axi_bresp;
    //=========================================================================================================
    reg                     write_state;
    reg[AXI_ADDR_WIDTH-1:0] wburst_incr;

    always @(posedge AXI_ACLK) begin
        app_write <= 0;
        if (AXI_ARESETN == 0) begin
            write_state <= 0;
            axi_awready <= 1;
            axi_wready  <= 1;
            axi_bvalid  <= 0;
        end else case(write_state)

        0:  begin
                if (AW_HANDSHAKE) begin                 // If we are being handed an address to write to...              
                    axi_awready  <= 0;                  //   We are no longer ready to accept a new address
                    axi_awaddr   <= S_AXI_AWADDR;       //   Register the address we should write to
                    wburst_incr  <= (S_AXI_AWBURST) ? AXI_DATA_BYTES : 0;  // Determine whether the address increments
                end

                if (W_HANDSHAKE) begin                  // If this is the write-data handshake...
                    axi_wready  <= 0;                   //   We are no longer ready to accept new data
                    axi_wdata   <= S_AXI_WDATA;         //   Register the data we're supposed to write
                    axi_wlast   <= S_AXI_WLAST;
                    app_write   <= 1;                   //   Start the application-specific write logic
                    write_state <= 1;                   //   And go wait for that write-logic to complete
                end
            end

        1:  if (app_write_complete) begin               // Wait for the application-specific write-logic to finish
                if (axi_wlast == 0) begin               //   If this was not the last beat of the burst...
                    axi_wready <= 1;                    //     We're ready to accept new write-data from master
                    if (W_HANDSHAKE) begin              //     If AXI master has provided new write-data...
                        axi_wready <= 0;                //       No longer willing to accept new write-data
                        axi_wdata  <= S_AXI_WDATA;      //       Register the data that the AXI master gave us
                        axi_wlast  <= S_AXI_WLAST;      //       Find out if this is the last beat of the burst
                        axi_awaddr <= axi_awaddr + wburst_incr;   // Keep track of the next address we'll write to
                        app_write  <= 1;                //       And start the application specific write-logic
                    end           
                end else begin                          //   Otherwise, this *is* the last beat of the burst
                    axi_bvalid <= 1;                    //     Tell the master that BRESP is valid
                    if (B_HANDSHAKE) begin              //     When the master acknowledges that is aw BRESP...
                        axi_bvalid  <= 0;               //       BRESP is no longer valid
                        axi_wready  <= 1;               //       We're ready to accept new data
                        axi_awready <= 1;               //       We're ready to accept a new address
                        write_state <= 0;               //       Go wait for a new transaction to start
                    end                       
                end
            end

        endcase
    end
    //=========================================================================================================



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
    //                  Application-specific read/write logic goes below this point
    //
    //                       An example of application-specific logic is below
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

    //=========================================================================================================
    // Your application specific state machine for handling AXI "read" transactions goes here
    //=========================================================================================================
    // The rules:
    //
    // --- Inputs ---
    // Your state machine starts when "app_read" is true.
    // axi_araddr holds the address to read from
    // 
    // --- Outputs ---
    // Your state machine is assumed to be idle/done whenever "app_read_idle" is high
    // axi_rdata = The data to send back to the AXI master
    // axi_rresp = The error response to send back to the AXI master, either OKAY or SLVERR (slave error)
    //
    // Don't forget that by convention, AXI4-lite addresses begin on 4-byte boundaries
    //=========================================================================================================

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~   This is an example of a state machine for handling AXI reads ~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    reg[31:0] example_data;

    always @(posedge AXI_ACLK) if (app_read) begin
        axi_rresp     <= OKAY;                  // By default, our response will be OKAY
        app_read_idle <= 1;                     // Tell the other task that we're (permanently) done
        case (axi_araddr)                       // Examine the address the user is reading
            0:  axi_rdata <= 17;                //     If they're reading address 0, respond with 17
            4:  axi_rdata <= 76;                //     If they're reading address 4, respond with 76
            8:  axi_rdata <= example_data;      //     If they're reading address 8, repond with the data
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
    // Your state machine starts when "app_write" is true
    // axi_awaddr = The address to write to
    // axi_wdata  = The data to write
    //
    // --- Outputs ---
    // Your state machine is assumed to be idle/done whenever "app_write_idle" is high
    // axi_bresp = The error response to send back to the AXI master, either OKAY or SLVERR (slave error)
    //
    // Don't forget that by convention, AXI4-lite addresses begin on 4-byte boundaries
    //=========================================================================================================

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~   This is an example of a state machine for handling AXI writes  ~~~~~~~~~~~~~~~~~~~~~
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    always @(posedge AXI_ACLK) if (app_write) begin
        app_write_idle  <= 1;              // Tell the infrastructure that we're done
        axi_bresp        <= OKAY;           // By default, our response will be OKAY
        case (axi_awaddr)                   // Examine the address the user is writing to
            8:  example_data <= axi_wdata;  //     If they're writing to address 8, store their data
            default:                        //     In all other cases, respond with a slave error
                axi_bresp    <= SLVERR;
        endcase
    end
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

endmodule
