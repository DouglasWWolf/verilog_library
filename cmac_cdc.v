module cmac_cdc # (parameter FIFO_DEPTH = 256)
(
    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 user_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF user0_rx:user0_tx:user1_rx:user1_tx, ASSOCIATED_RESET user_resetn" *)
    input user_clk,
    input user_resetn,

    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 cmac0_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF cmac0_rx:cmac0_tx, ASSOCIATED_RESET cmac0_resetn" *)
    input cmac0_clk,
    input cmac0_resetn,

    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 cmac1_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF cmac1_rx:cmac1_tx, ASSOCIATED_RESET cmac1_resetn" *)
    input cmac1_clk,
    input cmac1_resetn,

    // These indicate that PCS alignment has been acheived
    input  cmac0_aligned, cmac1_aligned,

    // These are the "cmacX_aligned" bits, synchronous with user_clk
    output  user0_aligned, user1_aligned,

    // TX0 stream from the user
    input  [511:0] user0_tx_tdata,
    input  [ 63:0] user0_tx_tkeep,
    input          user0_tx_tuser,
    input          user0_tx_tlast,
    input          user0_tx_tvalid,
    output         user0_tx_tready,

    // TX0 stream to the CMAC
    output [511:0] cmac0_tx_tdata,
    output [ 63:0] cmac0_tx_tkeep,
    output         cmac0_tx_tuser,
    output         cmac0_tx_tlast,
    output         cmac0_tx_tvalid,
    input          cmac0_tx_tready,

    // RX0 stream from the CMAC
    input  [511:0] cmac0_rx_tdata,
    input  [ 63:0] cmac0_rx_tkeep,
    input          cmac0_rx_tuser,
    input          cmac0_rx_tlast,
    input          cmac0_rx_tvalid,
    output         cmac0_rx_tready,

    // RX0 stream to the user
    output [511:0] user0_rx_tdata,
    output [ 63:0] user0_rx_tkeep,
    output         user0_rx_tuser,
    output         user0_rx_tlast,
    output         user0_rx_tvalid,
    input          user0_rx_tready,

    // TX1 stream from the user
    input  [511:0] user1_tx_tdata,
    input  [ 63:0] user1_tx_tkeep,
    input          user1_tx_tuser,
    input          user1_tx_tlast,
    input          user1_tx_tvalid,
    output         user1_tx_tready,

    // TX1 stream to the CMAC
    output [511:0] cmac1_tx_tdata,
    output [ 63:0] cmac1_tx_tkeep,
    output         cmac1_tx_tuser,
    output         cmac1_tx_tlast,
    output         cmac1_tx_tvalid,
    input          cmac1_tx_tready,

    // RX1 stream from the CMAC
    input  [511:0] cmac1_rx_tdata,
    input  [ 63:0] cmac1_rx_tkeep,
    input          cmac1_rx_tuser,
    input          cmac1_rx_tlast,
    input          cmac1_rx_tvalid,
    output         cmac1_rx_tready,

    // RX1 stream to the user
    output [511:0] user1_rx_tdata,
    output [ 63:0] user1_rx_tkeep,
    output         user1_rx_tuser,
    output         user1_rx_tlast,
    output         user1_rx_tvalid,
    input          user1_rx_tready


);

//=============================================================================
// Synchronize "cmac0_aligned" to the user_clk
//=============================================================================
xpm_cdc_single #
(
      .DEST_SYNC_FF  (4), 
      .INIT_SYNC_FF  (0), 
      .SIM_ASSERT_CHK(0),
      .SRC_INPUT_REG (1) 
)
cdc_aligned_0
(
    .src_clk    (cmac0_clk    ),  
    .src_in     (cmac0_aligned),    
    .dest_clk   (user_clk     ),
    .dest_out   (user0_aligned)    
);
//=============================================================================


//=============================================================================
// Synchronize "cmac1_aligned" to the user_clk
//=============================================================================
xpm_cdc_single #
(
      .DEST_SYNC_FF  (4), 
      .INIT_SYNC_FF  (0), 
      .SIM_ASSERT_CHK(0),
      .SRC_INPUT_REG (1) 
)
cdc_aligned_1
(
    .src_clk    (cmac1_clk    ),  
    .src_in     (cmac1_aligned),    
    .dest_clk   (user_clk     ),
    .dest_out   (user1_aligned)
);
//=============================================================================



// These link the channel 0 TX CDC FIFO to the Packetization FIFO
wire [511:0] link0_tx_tdata;
wire [ 63:0] link0_tx_tkeep;
wire         link0_tx_tuser;
wire         link0_tx_tlast;
wire         link0_tx_tvalid;
wire         link0_tx_tready;


// These link the channel 1 TX CDC FIFO to the Packetization FIFO
wire [511:0] link1_tx_tdata;
wire [ 63:0] link1_tx_tkeep;
wire         link1_tx_tuser;
wire         link1_tx_tlast;
wire         link1_tx_tvalid;
wire         link1_tx_tready;



/*
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><>                           Channel 0 FIFOs                            <><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
*/

//====================================================================================
// This FIFO serves as the TX clock-domain crossing for CMAC 0
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("independent_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
tx0_cdc
(
    // Clock and reset
   .s_aclk          (user_clk   ),
   .m_aclk          (cmac0_clk  ),
   .s_aresetn       (user_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (user0_tx_tdata ),
   .s_axis_tvalid   (user0_tx_tvalid),
   .s_axis_tuser    (user0_tx_tuser ),
   .s_axis_tkeep    (user0_tx_tkeep ),
   .s_axis_tlast    (user0_tx_tlast ),
   .s_axis_tready   (user0_tx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (link0_tx_tdata ),
   .m_axis_tvalid   (link0_tx_tvalid),
   .m_axis_tuser    (link0_tx_tuser ),
   .m_axis_tkeep    (link0_tx_tkeep ),
   .m_axis_tlast    (link0_tx_tlast ),
   .m_axis_tready   (link0_tx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================



//====================================================================================
// This is the TX packetization FIFO for CMAC 0
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("true"),
    .FIFO_DEPTH         (FIFO_DEPTH),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
tx0_packetize
(
    // Clock and reset
   .s_aclk          (cmac0_clk   ),
   .m_aclk          (cmac0_clk   ),
   .s_aresetn       (cmac0_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (link0_tx_tdata ),
   .s_axis_tvalid   (link0_tx_tvalid),
   .s_axis_tuser    (link0_tx_tuser ),
   .s_axis_tkeep    (link0_tx_tkeep ),
   .s_axis_tlast    (link0_tx_tlast ),
   .s_axis_tready   (link0_tx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (cmac0_tx_tdata ),
   .m_axis_tvalid   (cmac0_tx_tvalid),
   .m_axis_tuser    (cmac0_tx_tuser ),
   .m_axis_tkeep    (cmac0_tx_tkeep ),
   .m_axis_tlast    (cmac0_tx_tlast ),
   .m_axis_tready   (cmac0_tx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================


//====================================================================================
// This FIFO serves as the RX clock-domain crossing for CMAC 0
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("independent_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
rx0_cdc
(
    // Clock and reset
   .s_aclk          (cmac0_clk  ),
   .m_aclk          (user_clk   ),
   .s_aresetn       (user_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (cmac0_rx_tdata ),
   .s_axis_tvalid   (cmac0_rx_tvalid),
   .s_axis_tuser    (cmac0_rx_tuser ),
   .s_axis_tkeep    (cmac0_rx_tkeep ),
   .s_axis_tlast    (cmac0_rx_tlast ),
   .s_axis_tready   (cmac0_rx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (user0_rx_tdata ),
   .m_axis_tvalid   (user0_rx_tvalid),
   .m_axis_tuser    (user0_rx_tuser ),
   .m_axis_tkeep    (user0_rx_tkeep ),
   .m_axis_tlast    (user0_rx_tlast ),
   .m_axis_tready   (user0_rx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================


/*
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><>                           Channel 1 FIFOs                            <><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
*/


//====================================================================================
// This FIFO serves as the TX clock-domain crossing for CMAC 1
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("independent_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
tx1_cdc
(
    // Clock and reset
   .s_aclk          (user_clk   ),
   .m_aclk          (cmac1_clk  ),
   .s_aresetn       (user_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (user1_tx_tdata ),
   .s_axis_tvalid   (user1_tx_tvalid),
   .s_axis_tuser    (user1_tx_tuser ),
   .s_axis_tkeep    (user1_tx_tkeep ),
   .s_axis_tlast    (user1_tx_tlast ),
   .s_axis_tready   (user1_tx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (link1_tx_tdata ),
   .m_axis_tvalid   (link1_tx_tvalid),
   .m_axis_tuser    (link1_tx_tuser ),
   .m_axis_tkeep    (link1_tx_tkeep ),
   .m_axis_tlast    (link1_tx_tlast ),
   .m_axis_tready   (link1_tx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================



//====================================================================================
// This is the TX packetization FIFO for CMAC 1
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("true"),
    .FIFO_DEPTH         (FIFO_DEPTH),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
tx1_packetize
(
    // Clock and reset
   .s_aclk          (cmac1_clk   ),
   .m_aclk          (cmac1_clk   ),
   .s_aresetn       (cmac1_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (link1_tx_tdata ),
   .s_axis_tvalid   (link1_tx_tvalid),
   .s_axis_tuser    (link1_tx_tuser ),
   .s_axis_tkeep    (link1_tx_tkeep ),
   .s_axis_tlast    (link1_tx_tlast ),
   .s_axis_tready   (link1_tx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (cmac1_tx_tdata ),
   .m_axis_tvalid   (cmac1_tx_tvalid),
   .m_axis_tuser    (cmac1_tx_tuser ),
   .m_axis_tkeep    (cmac1_tx_tkeep ),
   .m_axis_tlast    (cmac1_tx_tlast ),
   .m_axis_tready   (cmac1_tx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================


//====================================================================================
// This FIFO serves as the RX clock-domain crossing for CMAC 1
//====================================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("independent_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),             
    .TDATA_WIDTH        (512), 
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),   
    .USE_ADV_FEATURES   ("0000")    
)
rx1_cdc
(
    // Clock and reset
   .s_aclk          (cmac1_clk  ),
   .m_aclk          (user_clk   ),
   .s_aresetn       (user_resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (cmac1_rx_tdata ),
   .s_axis_tvalid   (cmac1_rx_tvalid),
   .s_axis_tuser    (cmac1_rx_tuser ),
   .s_axis_tkeep    (cmac1_rx_tkeep ),
   .s_axis_tlast    (cmac1_rx_tlast ),
   .s_axis_tready   (cmac1_rx_tready),


    // The output bus of the FIFO
   .m_axis_tdata    (user1_rx_tdata ),
   .m_axis_tvalid   (user1_rx_tvalid),
   .m_axis_tuser    (user1_rx_tuser ),
   .m_axis_tkeep    (user1_rx_tkeep ),
   .m_axis_tlast    (user1_rx_tlast ),
   .m_axis_tready   (user1_rx_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================


endmodule