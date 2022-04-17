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
//   (1) Add a set of interface lines as shown below
//   (2) Add a set of read-registers as shown below
//   (3) Add the case to the three "case" statements highlighted below
//   (4) Add the xpm_fifo_sync (or xpm_fifo_async) to the bottom of this module 
//   (5) Update the FIFO_COUNT localparam
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
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_00_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE FULL"    *) output       FIFO_00_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_00_WRITE WR_EN"   *) input        FIFO_00_WR_EN,
    `endif

    // A FIFO for writing data to be printed  
    `ifdef HAS_01
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_01_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE FULL"    *) output       FIFO_01_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_01_WRITE WR_EN"   *) input        FIFO_01_WR_EN,
    `endif

    `ifdef HAS_02
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_02_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE FULL"    *) output       FIFO_02_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_02_WRITE WR_EN"   *) input        FIFO_02_WR_EN,
    `endif

    `ifdef HAS_03
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_03_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE FULL"    *) output       FIFO_03_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_03_WRITE WR_EN"   *) input        FIFO_03_WR_EN,
    `endif

    `ifdef HAS_04
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_04_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE FULL"    *) output       FIFO_04_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_04_WRITE WR_EN"   *) input        FIFO_04_WR_EN,
    `endif

    `ifdef HAS_05
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE WR_DATA" *) `PBUFF_INPUT FIFO_05_IN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE FULL"    *) output       FIFO_05_FULL,
    (* X_INTERFACE_INFO = "xilinx.com:interface:fifo_write:1.0 FIFO_05_WRITE WR_EN"   *) input        FIFO_05_WR_EN,
    `endif


    //================ From here down is the AXI4-Lite interface ===============
    input wire  CLK, RESETN,
    output wire CLK_OUT, RESETN_OUT,
    output wire[15:0] LED,
    output wire BLINKY,

        
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
    `else
        localparam FIFO_COUNT =  1;
    `endif
    //==========================================================================
    

    integer i;
    reg[15:0] led = 16'h0000;   assign LED = led;

    localparam PBUFF_CHARS = `PBUFF_CHARS;
    localparam C_AXI_DATA_BYTES = (C_AXI_DATA_WIDTH/8);
    
    wire RESET = ~RESETN;
    assign CLK_OUT = CLK;
    assign RESETN_OUT = RESETN;

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
           
                    // Keep track of whether we have seen the slave raise AWREADY and/or WREADY         
                    if (avalid_and_ready) saw_waddr_ready <= 1;
                    if (wvalid_and_ready) saw_wdata_ready <= 1; 
                    
                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((saw_waddr_ready || avalid_and_ready) && (saw_wdata_ready || wvalid_and_ready)) begin
                        m_axi_awvalid <= 0;
                        m_axi_wvalid  <= 0;
                        write_state   <= 2;
                    end
                end
                
           // Wait around for the slave to assert "M_AXI_BVALID".  When it does, we'll acknowledge
           // it by raising M_AXI_BREADY for one cycle, and go back to idle state
           2:   if (bvalid_and_ready) begin
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
    //            The data read is available in amci_rdata.
    //=========================================================================================================
    reg                         read_state = 0;

    // FSM user interface inputs
    reg[C_AXI_ADDR_WIDTH-1:0]   amci_raddr;
    reg                         amci_read;

    // FSM user interface outputs
    reg[C_AXI_DATA_WIDTH-1:0]   amci_rdata;
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
            led[5:0]      <= 0;
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
            1:  if (M_AXI_RVALID && M_AXI_RREADY) begin
                    amci_rdata    <= M_AXI_RDATA;
                    m_axi_rready  <= 0;
                    m_axi_arvalid <= 0;
                    read_state    <= 0;
                end

        endcase
    end
    //=========================================================================================================


    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //                             The logic to manage the FIFOs begins here
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><    
    
    // These registers map to the matching register in the FIFO specified by "fifo_index"
    reg[$clog2(FIFO_COUNT)-1:0]   fifo_index = 0;
	reg                           fifo_rd_en;
	`PBUFF_REG                    fifo_data;

    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //      Everything in this block describes registers for reading each FIFO
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    `PBUFF_WIRE fifo_00_data;
    wire        fifo_00_rd_en = (fifo_index == 0 & fifo_rd_en);


    `PBUFF_WIRE fifo_01_data;
    wire        fifo_01_rd_en = (fifo_index == 1 & fifo_rd_en);
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                                 End of per-FIFO registers
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


    wire fifo_data_valid[0:FIFO_COUNT-1];
    wire      fifo_empty[0:FIFO_COUNT-1];
    //==================================================================================================================
    // If you add or remove a FIFO, the appropriate case must be added or removed to/from these three "case" statements
    //==================================================================================================================	
	
	always @(*) begin
	   fifo_data <= 0;
	   case (fifo_index)
	   0:  fifo_data <= fifo_00_data;
	   1:  fifo_data <= fifo_01_data;
	   endcase
	end

    //==================================================================================================================
	


    //==================================================================================================================
    // This state machine waits for someone to raise the "transmit_start" signal, then sends the byte in register  
    // "transmit_data" to the UART TX FIFO.
    //
    // Note that there are only four states in this machine, and they always proceed in order:
    //       state 0, then state 1, then state 2, then state 3, then back to state 0
    //==================================================================================================================
    reg[1:0] transmit_state = 0;
    
    // Set this to 1 to start the "Fetch the TX FIFO status" state machine
    reg      transmit_start = 0;
    
    // This is the byte that will be transmitted to the UART
    reg[7:0] transmit_data;
    
    // When this goes high, the character has been stuffed into the UART's TX FIFO
    wire transmit_done = transmit_start == 0 && transmit_state == 0;

    // UART AXI register definitions
    localparam UART_TX_FIFO_REG = 4;
    localparam UART_STATUS_REG  = 8;
    //==================================================================================================================
    always @(posedge CLK) begin
        amci_read  <= 0;
        amci_write <= 0;
        if (RESETN == 0) begin
            transmit_state <= 0;
        end else case (transmit_state)

            // Here we are idle, waiting around for someone to raise the "transmit_start" signal
            0:  if (transmit_start) begin
                    transmit_state <= 1;
                end

            // Once the AXI master is ready for a read transaction, read the UART status register
            1:  if (amci_ridle) begin
                    amci_raddr      <= UART_STATUS_REG;  
                    amci_read       <= 1;
                    transmit_state  <= 2;
                end
                
            // Wait for the UART TX FIFO status to be returned, then either start another status read (if it's full),
            // or advance to the next state    
            2:  if (amci_ridle) begin
                    led[13] <= 1;
                    if (amci_rdata[3]) begin
                        amci_read <= 1;
                    end else begin
                        transmit_state <= 3;
                    end
                end
                    
            // Finally, stuff the byte in "transmit_data" into the UART's TX FIFO
            3:  if (amci_widle) begin
                    amci_waddr     <= UART_TX_FIFO_REG;
                    amci_wdata     <= transmit_data;
                    amci_write     <= 1;
                    transmit_state <= 0;
                end
                
       endcase  
    end
    //==================================================================================================================
  
  
  /*
    //==================================================================================================================
    // This takes "char_index" as an input, and fills in "indexed_byte" with the byte at that index in the input string
    //==================================================================================================================
    reg[$clog2(PBUFF_CHARS):0]   char_index;
    reg[7:0]                     indexed_byte;
    `PBUFF_REG                   print_buffer;
    //==================================================================================================================
    integer i;
    always @(*) begin
        indexed_byte <= 0;
        for (i=0; i<PBUFF_CHARS; i=i+1) begin
            if (char_index == i) begin
                indexed_byte <= print_buffer[((PBUFF_CHARS-1) -i)*8 +: 8];            
            end
        end
    end
    //==================================================================================================================
  */
  
    reg[7:0] print_buffer[0:PBUFF_CHARS-1];
    //==================================================================================================================
    // This state machine loops through the input string, transmitting each byte in turn until they've all been
    // transmitted.
    //
    // To start:    string to be printed is right-justified in "print_buffer"
    //              raise "printer_start"
    // 
    // At end:      "printer_idle" will go high 
    //==================================================================================================================
    localparam s_IDLE               = 0;
    localparam s_LOOK_FOR_FNZ       = 1;
    localparam s_TRANSMIT_CHAR      = 2;
    localparam s_WAIT_FOR_TRANSMIT  = 3;
    localparam s_END_OF_INPUT       = 4;

    reg[$clog2(PBUFF_CHARS):0]      char_index;
    reg[2:0]                        printer_state;
    reg                             printer_start;     
    wire                            printer_idle = (printer_state == s_IDLE && ~printer_start);     
    //-----------------------------------------------------------------------------------------------------------------------
    always @(posedge CLK) begin
        transmit_start <= 0;

        for (i=0; i<PBUFF_CHARS; i=i+1) begin
             print_buffer[i] <= 0;
        end
        print_buffer[PBUFF_CHARS-1] <= "Y";
        print_buffer[PBUFF_CHARS-2] <= "X";       

        if (RESETN == 0) begin
            printer_state  <= s_IDLE;
        end else begin
            case (printer_state)
            
            // In IDLE mode, we're waiting around for the "START" signal to go high
            s_IDLE: 
                if (printer_start) begin
                    char_index    <= 0;
                    printer_state <= s_LOOK_FOR_FNZ;
                end                       
                 
            // Here, we are looking for the first non-zero byte of the string         
            s_LOOK_FOR_FNZ:
                if (char_index == PBUFF_CHARS) begin
                    printer_state <= s_IDLE;
                end else if (print_buffer[char_index] == 0)
                    char_index <= char_index + 1;
                else begin
                    printer_state <= s_TRANSMIT_CHAR;        
                end

            // Transmit a character
            s_TRANSMIT_CHAR:
                begin 
                    transmit_data   <= print_buffer[char_index];
                    transmit_start  <= 1;
                    printer_state   <= s_WAIT_FOR_TRANSMIT;
                end
            
            // Wait for the transmit to complete, and either go fetch the next character, or be done
            s_WAIT_FOR_TRANSMIT:
                if (transmit_start == 0 && transmit_done == 1) begin
                    if (char_index == PBUFF_CHARS -1) begin
                        printer_state <= s_END_OF_INPUT;
                    end else begin
                        char_index    <= char_index + 1;
                        printer_state <= s_TRANSMIT_CHAR;
                    end
                end
                
            s_END_OF_INPUT:
                    begin
                        printer_state <= s_IDLE;
                    end
   
           endcase
        end
    end
    //==================================================================================================================
 

 

    //==================================================================================================================
    // This block of code performs a round-robin scan of the FIFOs, and when it finds one that isn't empty, it reads
    // the FIFO and hands the FIFO data off to the state machine that transmits it to the UART a single byte at a time.
    //==================================================================================================================
    reg       reader_state = 0;
    
    always @(posedge CLK) begin
        fifo_rd_en    <= 0;
        printer_start <= 0;

        if (RESETN == 0) begin
            fifo_index   <= 0;
            reader_state <= 0;
            led[9] <= 0;
        end else begin
            case (reader_state)
            
            0:  if (fifo_empty[fifo_index]) begin
                    fifo_index <= (fifo_index == FIFO_COUNT-1) ? 0: fifo_index + 1;
                end else begin
                    fifo_rd_en   <= 1;
                    reader_state <= 1;
                end
                
            1:  if (fifo_data_valid[fifo_index]) begin
                    //?print_buffer  <= fifo_data;
                    printer_start <= 1;
                    reader_state  <= 0;
                    led[9] <= 1;
                end
            
            endcase
        end
    end
    //==================================================================================================================









    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                  Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(256),    // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(`PBUFF_SIZE),
      .READ_MODE("std"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1000"), // String; 1000 = "Enable the data_valid flag"
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(`PBUFF_SIZE), 
      .WR_DATA_COUNT_WIDTH(1)    // DECIMAL

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_00
    (
        .rst        (RESET             ),                      
        .full       (FIFO_00_FULL      ),              
        .din        (FIFO_00_IN        ),                 
        .wr_en      (FIFO_00_WR_EN     ),            
        .wr_clk     (CLK               ),          
        .data_valid (fifo_data_valid[0]),  
        .dout       (fifo_00_data      ),              
        .empty      (fifo_empty[0]     ),            
        .rd_en      (fifo_00_rd_en     ),            

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



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //               Everything in this block instantiates a single FIFO 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(256),    // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
      .READ_DATA_WIDTH(`PBUFF_SIZE),
      .READ_MODE("std"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1000"), // String; 1000 = "Enable the data_valid flag"
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH(`PBUFF_SIZE), 
      .WR_DATA_COUNT_WIDTH(1)    // DECIMAL

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_fifo_01
    (
        .rst        (RESET             ),                      
        .full       (FIFO_01_FULL      ),              
        .din        (FIFO_01_IN        ),                 
        .wr_en      (FIFO_01_WR_EN     ),            
        .wr_clk     (CLK               ),          
        .data_valid (fifo_data_valid[1]),  
        .dout       (fifo_01_data      ),              
        .empty      (fifo_empty[1]     ),            
        .rd_en      (fifo_01_rd_en     ),            

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


endmodule