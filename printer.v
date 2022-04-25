`timescale 1ns / 1ps
`include "printer.vh"

`define HAS_00
`define HAS_01
//`define HAS_02
//`define HAS_03
//`define HAS_04
//`define HAS_05

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//   If the XPM module is not found during synthesis, type "auto_detect_xpm" in the TCL Console
//
//           See Xilinx UG974 for details of xpm_fifo_sync and xpm_fifo_async
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
// To add a FIFO:
//   (1) Add a "`define HAS_XX" above
//   (2) Add the block of ports to the port list
//   (3) Update the `ifdef/`elseif block that determines how many FIFOs there are
//   (4) Add the xpm_fifo_sync (or xpm_fifo_async) to the bottom of this module 
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
// To declare an interface to a printer FIFO in your own Verilog code, do this:
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
/*
    (* X_INTERFACE_MODE = "master" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 PRINTER WR_DATA" *) `PFRAME_OUTPUT FIFO_OUT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 PRINTER FULL"    *) input          FIFO_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 PRINTER WR_EN"   *) output         FIFO_WR_EN
*/
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


module printer#  
(
    parameter integer C_AXI_DATA_WIDTH = 32,
    parameter integer C_AXI_ADDR_WIDTH = 32 
)
(
 
    // A FIFO for writing data to be printed  
    `ifdef HAS_00
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_00_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE FULL"    *) output        FIFO_00_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE WR_EN"   *) input         FIFO_00_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_01
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_01_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE FULL"    *) output        FIFO_01_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE WR_EN"   *) input         FIFO_01_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_02
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_02_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE FULL"    *) output        FIFO_02_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE WR_EN"   *) input         FIFO_02_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_03
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_03_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE FULL"    *) output        FIFO_03_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE WR_EN"   *) input         FIFO_03_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_04
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_04_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE FULL"    *) output        FIFO_04_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE WR_EN"   *) input         FIFO_04_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_05
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE WR_DATA" *) `PFRAME_INPUT FIFO_05_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE FULL"    *) output        FIFO_05_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE WR_EN"   *) input         FIFO_05_WR_EN,
    `endif
 
    input  CLK, RESETN,
    output CLK_OUT, RESETN_OUT,
    
    //================ From here down is the AXI4-Lite interface ===============
        
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

    //==========================================================================
    // Determine how many FIFOs we have
    //==========================================================================
    `ifdef HAS_05
        localparam FIFO_COUNT =  6;
    `elsif HAS_04
        localparam FIFO_COUNT =  5;
    `elsif HAS_03
        localparam FIFO_COUNT =  4;
    `elsif HAS_02
        localparam FIFO_COUNT =  3;
    `elsif HAS_01
        localparam FIFO_COUNT =  2;
    `elsif HAS_00
        localparam FIFO_COUNT =  1;
    `endif
    //==========================================================================
    


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                             Beginning of AXI4 Lite Master state machines
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    localparam C_AXI_DATA_BYTES = (C_AXI_DATA_WIDTH/8);
    
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
    reg[C_AXI_ADDR_WIDTH-1:0]   amci_waddr;
    reg[C_AXI_DATA_WIDTH-1:0]   amci_wdata;
    reg                         amci_write;
    reg[2:0]                    amci_wresp;

    // FSM user interface outputs
    wire                        amci_widle = (write_state == 0 && amci_write == 0);     

    // AXI registers and outputs
    reg[C_AXI_ADDR_WIDTH-1:0]   m_axi_awaddr;
    reg[C_AXI_DATA_WIDTH-1:0]   m_axi_wdata;
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
    assign M_AXI_WSTRB   = (1 << C_AXI_DATA_BYTES) - 1; // usually 4'b1111
    assign M_AXI_BREADY  = m_axi_bready;
    //=========================================================================================================
     
     // Define states that say "An xVALID signal and its corresponding xREADY signal are both asserted"
     wire avalid_and_ready = M_AXI_AWVALID & M_AXI_AWREADY;
     wire wvalid_and_ready = M_AXI_WVALID  & M_AXI_WREADY;
     wire bvalid_and_ready = M_AXI_BVALID  & M_AXI_BREADY;

    always @(posedge CLK) begin


        // If we're in RESET mode...
        if (RESETN == 0) begin
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
    reg[C_AXI_ADDR_WIDTH-1:0]   amci_raddr;
    reg                         amci_read;

    // FSM user interface outputs
    reg[C_AXI_DATA_WIDTH-1:0]   amci_rdata;
    reg[1:0]                    amci_rresp;
    wire                        amci_ridle = (read_state == 0 && amci_read == 0);     

    // AXI registers and outputs
    reg[C_AXI_ADDR_WIDTH-1:0]   m_axi_araddr;
    reg                         m_axi_arvalid = 0;
    reg                         m_axi_rready;

    // Wire up the AXI interface outputs
    assign M_AXI_ARADDR  = m_axi_araddr;
    assign M_AXI_ARVALID = m_axi_arvalid;
    assign M_AXI_ARPROT  = 3'b001;
    assign M_AXI_RREADY  = m_axi_rready;
    //=========================================================================================================
    always @(posedge CLK) begin
         
        if (RESETN == 0) begin
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
                    if (M_AXI_ARVALID && M_AXI_ARREADY)
                        m_axi_arvalid <= 0;
            
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
 
 
 
    integer i;genvar x;
    
    localparam PBUFF_CHARS  = `PBUFF_CHARS;
    localparam PFRAME_WIDTH = `PFRAME_WIDTH;
    localparam PFMT_WIDTH   = `PFMT_WIDTH;
    localparam TOP_PBUFF_BIT = 8*PBUFF_CHARS-1;

    localparam RADIX_ASC = 0;
    localparam RADIX_HEX = 1;
    localparam RADIX_BIN = 2;
    localparam RADIX_DEC = 3;

    wire RESET = ~RESETN;
    assign CLK_OUT = CLK;
    assign RESETN_OUT = RESETN;

    //-----------------------------------------------------------
    // Registers for binary to ASCII conversion
    //-----------------------------------------------------------
    reg[63:0]             to_ascii_input;
    reg[7:0]              to_ascii_digits_out;
    reg                   to_ascii_nosep;
    reg                   to_ascii_start [1:3];
    wire                  to_ascii_idle  [1:3];
    wire[TOP_PBUFF_BIT:0] to_ascii_result[1:3];
    //-----------------------------------------------------------

    //-----------------------------------------------------------
    // Modules for converting binary to ASCII
    //-----------------------------------------------------------
    to_ascii_hex#(.OUTPUT_WIDTH(PBUFF_CHARS)) to_ascii_hex_inst
    (
        .CLK        (CLK),
        .RESETN     (RESETN),
        .VALUE      (to_ascii_input),
        .DIGITS_OUT (to_ascii_digits_out),
        .NOSEP      (to_ascii_nosep),
        .START      (to_ascii_start [RADIX_HEX]),
        .RESULT     (to_ascii_result[RADIX_HEX]),
        .IDLE       (to_ascii_idle  [RADIX_HEX])
    );
    
    
    to_ascii_bin#(.OUTPUT_WIDTH(PBUFF_CHARS)) to_ascii_bin_inst
    (
        .CLK        (CLK),
        .RESETN     (RESETN),
        .VALUE      (to_ascii_input),
        .DIGITS_OUT (to_ascii_digits_out),
        .NOSEP      (to_ascii_nosep),
        .START      (to_ascii_start [RADIX_BIN]),
        .RESULT     (to_ascii_result[RADIX_BIN]),
        .IDLE       (to_ascii_idle  [RADIX_BIN])
    );


    to_ascii_dec#(.OUTPUT_WIDTH(PBUFF_CHARS)) to_ascii_dec_inst
    (
        .CLK        (CLK),
        .RESETN     (RESETN),
        .VALUE      (to_ascii_input),
        .FIELD_WIDTH(to_ascii_digits_out),
        .NOSEP      (to_ascii_nosep),
        .START      (to_ascii_start [RADIX_DEC]),
        .RESULT     (to_ascii_result[RADIX_DEC]),
        .IDLE       (to_ascii_idle  [RADIX_DEC])
    );
    //-----------------------------------------------------------


    //==================================================================================================================
    // This state machine waits for someone to raise the "transmit_start" signal, then sends the byte in register  
    // "transmit_data" to the UART TX FIFO.
    //==================================================================================================================
    //public:
    reg[7:0] transmit_data;
    reg      transmit_start;
    wire     transmit_idle; 
    //-----------------------------------------------------------------------------------------------------------------------
    // private:
    reg      transmit_state;
    assign   transmit_idle = transmit_start == 0 && transmit_state == 0;
    
    localparam UART_TX_FIFO_REG = 4;
    //==================================================================================================================
    always @(posedge CLK) begin
        amci_read  <= 0;
        amci_write <= 0;
        if (RESETN == 0) begin
            transmit_state <= 0;
        end else case (transmit_state)

            // Here we are idle, waiting around for someone to raise the "transmit_start" signal.  If they
            // do, send their character to the UART FIFO
            0:  if (transmit_start) begin
                    amci_waddr     <= UART_TX_FIFO_REG;
                    amci_wdata     <= transmit_data;
                    amci_write     <= 1;
                    transmit_state <= 1;
                end

            // If the write response was "SLVERR" (slave error), it means the FIFO was full
            // when we tried to write to it.  If there was a SLVERR, we need to resend the 
            // character to the FIFO.  If there was no SLVERR, we're done.
            1:  if (amci_widle) begin
                    if (amci_wresp[1])
                        amci_write <= 1;
                    else
                        transmit_state <= 0; 
                end
                
       endcase  
    end
    //==================================================================================================================
  
   
   
    
    //==================================================================================================================
    // printer: This state machine loops through the input string, transmitting each byte in turn until they've all been
    //          transmitted.
    //
    // To start:    string to be printed is right-justified in "printer_inp[]"
    //              raise "printer_start"
    // 
    // At end:      "printer_idle" will go high 
    //==================================================================================================================
    // public:
    reg[TOP_PBUFF_BIT:0] printer_inp;
    reg                  printer_crlf;        
    reg                  printer_start;     
    wire                 printer_idle;
    //-----------------------------------------------------------------------------------------------------------------------
    // private:
    reg[$clog2(PBUFF_CHARS):0]      char_index;
    reg[2:0]                        printer_state;
    assign printer_idle = (printer_state == 0 && printer_start == 0);     
    wire[7:0] printer_inp_chr[0:PBUFF_CHARS-1];
    for (x=0; x<PBUFF_CHARS; x=x+1) assign printer_inp_chr[x] = printer_inp[8*(PBUFF_CHARS-1-x) +: 8];
    //-----------------------------------------------------------------------------------------------------------------------
    
   
    always @(posedge CLK) begin
        transmit_start <= 0;

        if (RESETN == 0) begin
            printer_state  <= 0;
        end else case (printer_state)
            
            // In IDLE mode, we're waiting around for the "START" signal to go high
            0:  if (printer_start) begin
                    char_index    <= 0;
                    printer_state <= 1;
                end                       

            // Transmit the characters
            1:  if (transmit_idle) begin 
                    if (char_index == PBUFF_CHARS) 
                        printer_state   <= 2;
                    else if (printer_inp_chr[char_index]) begin
                        transmit_data   <= printer_inp_chr[char_index];
                        transmit_start  <= 1;
                    end
                    char_index <= char_index + 1;
                end
    
            // If we need to print a CRLF, wait for the transmitter to go idle then transmit a carriage-return
            2:  if (printer_crlf == 0)
                    printer_state  <= 0;
                else begin
                    transmit_data  <= "\r";
                    transmit_start <= 1;
                    printer_state  <= 3;
                end

            // Wait for the transmitter to go idle, then transmit a linefeed
            3:  if (transmit_idle) begin
                    transmit_data  <= "\n";
                    transmit_start <= 1;
                    printer_state  <= 4;
                end
            
            // Wait for the prior character to finish
            4:  if (transmit_idle) printer_state <= 0;

        endcase
    end
    //==================================================================================================================
 


    //==================================================================================================================
    // translate: translates the bits in "translate_inp" into a sequence of ASCII characters in "printer_inp", then
    //            tells the printer to print them.
    //
    //  At start:   translate_inp = The bits to be translated to ASCII and printed.
    //              translate_fmt = The format specifier to convert the bits to ASCII
    //
    //  Bits [14:12] in translate_fmt are a type-specifier.   If the type-specifier is 0, the entire input field 
    //               is assumed to contain ASCII characters.  If the type-specifier is anything else, the entire input
    //               field except for the last 8 bytes (i.e., 64 bits) is assumed to contain ASCII characters
    //==================================================================================================================
    // public:
    reg[TOP_PBUFF_BIT:0] translate_inp;
    reg[PFMT_WIDTH-1 :0] translate_fmt;
    reg                  translate_start;
    wire                 translate_idle;
    //------------------------------------------------------------------------------------------------------------------
    // private:
    reg[1:0]             translate_state;
    reg[2:0]             radix;
    reg                  need_crlf, nosep;
    assign               translate_idle = (translate_state == 0 && translate_start == 0);
    //------------------------------------------------------------------------------------------------------------------
    localparam  CRLF_BIT = 15;
    localparam  NOSEP_BIT = 11;

    always @(posedge CLK) begin
        printer_start             <= 0;
        to_ascii_start[RADIX_HEX] <= 0;
        to_ascii_start[RADIX_BIN] <= 0;
        to_ascii_start[RADIX_DEC] <= 0;
        
        if (RESETN == 0) begin
            translate_state = 0; 
        end else case(translate_state)

            // Wait for someone to raise "start", and when they do, clear the print buffer
            0:  if (translate_start) begin
                    radix           <= translate_fmt[14:12];
                    need_crlf       <= translate_fmt[CRLF_BIT];
                    nosep           <= translate_fmt[NOSEP_BIT];
                    translate_state <= 1;
                end 

            // Dependent on whether this message contains a binary value, copy either the
            // entire "translate_bits" into the print buffer, or copy everything except the
            // 8 byte (i.e., 64-bit) numeric value into the print buffer.   The message ends
            // up right-justified in the print buffer.
            1:  if (printer_idle) begin
                    if (radix == RADIX_ASC) begin
                        printer_inp     <= translate_inp;
                        printer_crlf    <= need_crlf;
                        printer_start   <= 1;
                        translate_state <= 0;
                    end else begin

                        // Start sending the text portion of the message to the UART
                        printer_inp           <= {64'b0, translate_inp[64 +: 8*PBUFF_CHARS - 64]};
                        printer_crlf          <= 0;
                        printer_start         <= 1;
                        
                        // Start translating the binary portion of the message into ASCII
                        to_ascii_input        <= translate_inp[63:0];
                        to_ascii_digits_out   <= translate_fmt[7:0];
                        to_ascii_nosep        <= nosep;
                        to_ascii_start[radix] <= 1;

                        // Go wait for the print-job and the binary-to-ASCII translation to complete
                        translate_state <= 2;
                    end
                end

            // Wait for the translation from binary to ASCII to be ready, and for the printer to be idle.  Once 
            // that's true, print the number that we just translated from binary to ASCII.
            2:  if (to_ascii_idle[radix] && printer_idle) begin
                    printer_inp     <= to_ascii_result[radix];
                    printer_crlf    <= need_crlf;
                    printer_start   <= 1;
                    translate_state <= 0;
                end

        endcase
    end
    //==================================================================================================================

 

 

    //==================================================================================================================
    // This block of code performs a round-robin scan of the FIFOs, and when it finds one that isn't empty, it reads
    // the FIFO and hands the FIFO data off to the state machine that transmits it to the UART a single byte at a time.
    //==================================================================================================================
    // private:
    reg[2:0]                    reader_state;
    reg[$clog2(FIFO_COUNT)-1:0] fifo_index;
    reg                         fifo_rd_en[0:FIFO_COUNT-1];
    wire                        fifo_valid[0:FIFO_COUNT-1];
    wire                        fifo_empty[0:FIFO_COUNT-1];
    `PFRAME_WIRE                fifo_data [0:FIFO_COUNT-1];
    //------------------------------------------------------------------------------------------------------------------
    always @(posedge CLK) begin
        
        // By default, these are low at the start of every clock cycle
        translate_start <= 0;
        for (i=0; i<FIFO_COUNT; i=i+1) fifo_rd_en[i] <= 0;

        if (RESETN == 0) begin
            fifo_index   <= 0;
            reader_state <= 3'b001;
        end else begin 
            case (reader_state)
            
            // Wait for the downstream translator to be ready for us
            3'b001: if (translate_idle) begin
                        reader_state <= 3'b010;
                    end
            // Do a round-robin scan, looking for one of the FIFOs to have data in it.  When
            // we find one, issue a "read" command 
            3'b010: if (fifo_empty[fifo_index]) begin
                        fifo_index <= (fifo_index == FIFO_COUNT-1) ? 0: fifo_index + 1;
                    end else begin
                        fifo_rd_en[fifo_index] <= 1;
                        reader_state           <= 3'b100;
                    end
                
            // Wait for the data-lines on the FIFO to become valid, and when they do, hand
            // the contents to the translation engine
            3'b100: if (fifo_valid[fifo_index]) begin
                        translate_fmt   <= fifo_data[fifo_index][ 0 +: 16];
                        translate_inp   <= fifo_data[fifo_index][32 +: PBUFF_CHARS*8];
                        translate_start <= 1;
                        reader_state    <= 3'b001;
                    end
            
            endcase 
        end
    end
    //==================================================================================================================






    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_00
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_00
    (
        .rst        (RESET        ),                      
        .full       (FIFO_00_FULL ),              
        .din        (FIFO_00_IN   ),                 
        .wr_en      (FIFO_00_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[0]),  
        .dout       (fifo_data [0]),              
        .empty      (fifo_empty[0]),            
        .rd_en      (fifo_rd_en[0]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif




    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_01
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_01
    (
        .rst        (RESET        ),                      
        .full       (FIFO_01_FULL ),              
        .din        (FIFO_01_IN   ),                 
        .wr_en      (FIFO_01_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[1]),  
        .dout       (fifo_data [1]),              
        .empty      (fifo_empty[1]),            
        .rd_en      (fifo_rd_en[1]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_02
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_02
    (
        .rst        (RESET        ),                      
        .full       (FIFO_02_FULL ),              
        .din        (FIFO_02_IN   ),                 
        .wr_en      (FIFO_02_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[2]),  
        .dout       (fifo_data [2]),              
        .empty      (fifo_empty[2]),            
        .rd_en      (fifo_rd_en[2]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_03
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_03
    (
        .rst        (RESET        ),                      
        .full       (FIFO_03_FULL ),              
        .din        (FIFO_03_IN   ),                 
        .wr_en      (FIFO_03_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[3]),  
        .dout       (fifo_data [3]),              
        .empty      (fifo_empty[3]),            
        .rd_en      (fifo_rd_en[3]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_04
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_04
    (
        .rst        (RESET        ),                      
        .full       (FIFO_04_FULL ),              
        .din        (FIFO_04_IN   ),                 
        .wr_en      (FIFO_04_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[4]),  
        .dout       (fifo_data [4]),              
        .empty      (fifo_empty[4]),            
        .rd_en      (fifo_rd_en[4]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `ifdef HAS_05
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (256),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (PFRAME_WIDTH),
      .READ_MODE            ("std"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (PFRAME_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_05
    (
        .rst        (RESET        ),                      
        .full       (FIFO_05_FULL ),              
        .din        (FIFO_05_IN   ),                 
        .wr_en      (FIFO_05_WR_EN),            
        .wr_clk     (CLK          ),          
        .data_valid (fifo_valid[5]),  
        .dout       (fifo_data [5]),              
        .empty      (fifo_empty[5]),            
        .rd_en      (fifo_rd_en[5]),            

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
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                       End of FIFO description/instantiation
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `endif

 


endmodule