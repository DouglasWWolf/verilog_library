module freq_counter # (parameter CLOCK_FREQ = 200000000)
(
    input clk, resetn,
    input inp_clock,

    output reg[31:0] frequency,
    output reg       valid
);


//=============================================================================
// This block divides inp_clock by 1024 and outputs the result in div_signal
//=============================================================================
reg [8:0] div_counter;
reg       div_signal;
//-----------------------------------------------------------------------------
always @(posedge inp_clock) begin
    if (div_counter == 0)
        div_signal <= ~div_signal;
    div_counter <= div_counter + 1;
end
//=============================================================================


//=============================================================================
// This synchronizes "div_signal" with clk, resulting in "div_signal_sync"
//=============================================================================
wire div_signal_sync;

xpm_cdc_single #
(
    .DEST_SYNC_FF(4),   
    .INIT_SYNC_FF(0),   
    .SIM_ASSERT_CHK(0), 
    .SRC_INPUT_REG(1)   
)
xpm_cdc_single_inst
(
    .src_in     (div_signal), 
    .src_clk    (inp_clock),  
    .dest_out   (div_signal_sync),
    .dest_clk   (clk) 
);
//=============================================================================


//=============================================================================
// This block detects high-going edges of "div_signal_sync"
//=============================================================================
reg [2:0] history = 0;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    history <= {history[1:0], div_signal_sync};
end
wire signal_edge = (history[2:1] == 2'b01);
//=============================================================================



//=============================================================================
// Counts the number of signal edges in 1 second
//=============================================================================
reg[31:0] edge_counter, countdown;
always @(posedge clk) begin
    
    valid <= 0;

    // We continuously count down to zero
    if (countdown) countdown <= countdown - 1;

    if (resetn == 0) begin
        edge_counter <= 0;
        countdown    <= CLOCK_FREQ;
    end 

    else if (signal_edge) begin
        if (edge_counter == 0)
            countdown <= CLOCK_FREQ;
        edge_counter <= edge_counter + 1;
    end
   
    else if (countdown == 0) begin
        frequency    <= (edge_counter << 10);
        valid        <= 1;
        edge_counter <= 0;
        countdown    <= CLOCK_FREQ;
    end
end
//=============================================================================


endmodule
