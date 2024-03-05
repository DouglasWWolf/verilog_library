module cdc_async_rst # (parameter ACTIVE_HIGH = 1)
(
    input async, clk,
    output sync
);

xpm_cdc_async_rst #
(
    .DEST_SYNC_FF(4), 
    .INIT_SYNC_FF(0), 
    .RST_ACTIVE_HIGH(ACTIVE_HIGH)
)
xpm_cdc_async_rst_inst
(
    .src_arst (async),
    .dest_clk (clk  ),  
    .dest_arst(sync ) 
);

endmodule