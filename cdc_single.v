module cdc_single
(
    input async, clk,
    output sync
);

xpm_cdc_single #
(
    .DEST_SYNC_FF  (4),   
    .INIT_SYNC_FF  (0),   
    .SIM_ASSERT_CHK(0), 
    .SRC_INPUT_REG (0)   
)
xpm_cdc_single_inst
(
    .src_clk (     ),  
    .src_in  (async),
    .dest_clk(clk  ), 
    .dest_out(sync ) 
);

endmodule