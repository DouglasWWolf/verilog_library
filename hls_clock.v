`timescale 1ns / 1ps
//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 12-May-22  DWW  1000  Initial creation
//====================================================================================

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
// If you get an error about "xpm_sync_fifo_not_found" during synthesis, open the Tcl
// Console and run the command "auto_detect_xpm"
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

module hls_clock#
(
    parameter integer CMD_DEPTH       = 16,  /* Must be at least 16 */
    parameter integer RSP_DEPTH       = 16,  /* Must be at least 16 */
    parameter integer CLOCKS_PER_USEC = 125,
    parameter integer CMD_WIDTH       = 1,
    parameter integer RSP_WIDTH       = 64
)  
(
    input CLK, RESETN,

    // User writes to this FIFO to send a command
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 CMD_FIFO WR_DATA" *) input[CMD_WIDTH-1:0] CMD_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 CMD_FIFO FULL_N"  *) output               CMD_FULL_N,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_write:1.0 CMD_FIFO WR_EN"   *) input                CMD_WREN,

    // User reads from this FIFO to receive a response
    (* X_INTERFACE_MODE = "slave" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RSP_FIFO RD_DATA" *) output[RSP_WIDTH-1:0] RSP_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RSP_FIFO EMPTY_N" *) output                RSP_EMPTY_N,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_fifo_read:1.0 RSP_FIFO RD_EN"   *) input                 RSP_RDEN
);

    // Registers and wires that interface to the CMD FIFO
    reg                 cmd_fifo_read;              
    wire                cmd_fifo_empty;             
    wire                cmd_fifo_full;
    wire[CMD_WIDTH-1:0] cmd_fifo_data;

    // Registers and wires that interface to the RX FIFO
    reg                 rsp_fifo_write;              
    wire                rsp_fifo_empty;
    reg[RSP_WIDTH-1:0]  rsp_fifo_data;    
  
    // Interfaces to/from the outside worlds
    wire RESET         = ~RESETN;
    assign CMD_FULL_N  = ~cmd_fifo_full;
    assign RSP_EMPTY_N = ~rsp_fifo_empty; 

    //-------------------------------------------------------------------------
    // Define our 64-bit microsecond counter and the registers that control it
    //-------------------------------------------------------------------------
    localparam COUNTDOWN_WIDTH = $clog2(CLOCKS_PER_USEC);    
    reg[63:0]                usec_counter;
    reg[COUNTDOWN_WIDTH-1:0] countdown;
    reg                      reset_usec_counter;
    //-------------------------------------------------------------------------


    //-------------------------------------------------------------------------------------------------
    // State machine that manages the command and response FIFOs
    //-------------------------------------------------------------------------------------------------
    reg[1:0] latency;
    always @(posedge CLK) begin
        
        cmd_fifo_read      <= 0;
        rsp_fifo_write     <= 0;
        reset_usec_counter <= 0;

        // We only trust 'cmd_fifo_empty' some number of cycles after issuing
        // a 'cmd_fifo_read'        
        if (latency) latency <= latency - 1;

        if (RESETN == 0) begin
            latency <= 0;
        end else if (latency == 0 && !cmd_fifo_empty) begin

            if (cmd_fifo_data == 0) begin
                reset_usec_counter <= 1;
                rsp_fifo_data      <= 0;
            end else begin 
                rsp_fifo_data      <= usec_counter;
            end

            rsp_fifo_write <= 1;    // Write the response data to the response FIFO
            cmd_fifo_read  <= 1;    // Acknowledge that we're done with this cmd data
            latency        <= 2;    // It will be a couple of cycles before we trust 'cmd_fifo_empty'
        end
    end
    //-------------------------------------------------------------------------------------------------



    //=========================================================================================================
    // Simple state machine that increments "usec_counter" every microsecond
    //=========================================================================================================
    always @(posedge CLK) begin
        if (RESETN == 0 || reset_usec_counter) begin
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





    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (0),     
      .FIFO_WRITE_DEPTH     (CMD_DEPTH),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (CMD_WIDTH),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (CMD_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_cmd_fifo
    (
        .rst        (RESET         ),                      
        .full       (cmd_fifo_full ),              
        .din        (CMD_DATA      ),                 
        .wr_en      (CMD_WREN      ),            
        .wr_clk     (CLK           ),          
        .data_valid (              ),     
        .dout       (cmd_fifo_data ),              
        .empty      (cmd_fifo_empty),            
        .rd_en      (cmd_fifo_read ),            

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
      .FIFO_READ_LATENCY    (0),     
      .FIFO_WRITE_DEPTH     (RSP_DEPTH),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (RSP_WIDTH),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("1000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (RSP_WIDTH), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    ) 
    xpm_rsp_fifo 
    (
        .rst        (RESET         ),                      
        .full       (              ),              
        .din        (rsp_fifo_data ),                 
        .wr_en      (rsp_fifo_write),            
        .wr_clk     (CLK           ),          
        .data_valid (              ),  
        .dout       (RSP_DATA      ),
        .empty      (rsp_fifo_empty),
        .rd_en      (RSP_RDEN      ),

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
