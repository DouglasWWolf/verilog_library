//=============================================================================
//               ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 10-May-22  DWW     1  Initial creation
//
// 31-Mar-24  DWW     2  General cleanup, because I'm better at Verilog than
//                       I used to be :-)
//=============================================================================


//=============================================================================
// button - Detects the high-going or low-going edge of a pin 
//
// Input:  CLK = system clock
//         PIN = the pin to look for an edge on
//
// Output:  Q = 1 if an active-going edge is detected, otherwise 0
//
// Notes: edge detection is fully debounced.  Q only goes high if a specified 
//        pin is still active 10ms after the active-going edge was initially 
//        detected 
//=============================================================================
module button#
(
    parameter ACTIVE_STATE    = 1,
    parameter CLOCKS_PER_USEC = 100,
    parameter DEBOUNCE_MSEC   = 10
) 
(
    input CLK, input PIN, output Q
);
    
    localparam DEBOUNCE_PERIOD = CLOCKS_PER_USEC * DEBOUNCE_MSEC * 1000;
    
    // Determine how many bits wide "DEBOUNCE_PERIOD"
    localparam COUNTER_WIDTH = $clog2(DEBOUNCE_PERIOD);

    // If ACTIVE=1, an active edge is low-to-high.
    // If ACTIVE_STATE=0, an active edge is high-to-low
    localparam ACTIVE_EDGE = ACTIVE_STATE ? 2'b01 : 2'b10;
    
    // All three bits button_sync start out in the "inactive" state
    (* ASYNC_REG = "TRUE" *) reg [3:0] button_sync = ACTIVE_STATE ? 0 : -1;

    // This the current state of the button, post synchronization
    wire button_state = button_sync[2];

    // This count will clock down as a debounce timer
    reg [COUNTER_WIDTH-1 : 0] debounce_clock = 0;
    
    // This is 1 on any cycle that an active-going edge is detected
    assign Q = (debounce_clock == 1) & (button_state == ACTIVE_STATE);    

    // Synchronise "PIN" into "button_sync"
    always @(posedge CLK) begin
        button_sync <= {button_sync[2:0], PIN};
    end

    // We're going to check for edges on every clock cycle
    always @(posedge CLK) begin
        
        // If we've detected the edge we're looking for, start the debounce clock
        if (button_sync[3:2] == ACTIVE_EDGE)
            debounce_clock <= DEBOUNCE_PERIOD;
        else if (debounce_clock)
            debounce_clock <= debounce_clock - 1;
    end
    
endmodule
//=============================================================================
