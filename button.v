`timescale 1ns / 1ps
`define SYSCLOCK_FREQ 125000000

//======================================================================================================================
//                                        ------->  Revision History  <------
//======================================================================================================================
//
//   Date     Who   Ver  Changes
//======================================================================================================================
// 10-May-22  DWW  1000  Initial creation
//======================================================================================================================


//======================================================================================================================
// button - Detects the high-going or low-going edge of a pin 
//
// Input:  CLK = system clock
//         PIN = the pin to look for an edge on
//
// Output:  Q = 1 if an active-going edge is detected, otherwise 0
//
// Notes: edge detection is fully debounced.  Q only goes high if a specified pin is still active
//        10ms after the active-going edge was initially detected 
//======================================================================================================================
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

    // If ACTIVE=1, an active edge is low-to-high.  If ACTIVE_STATE=0, an active edge is high-to-low
    localparam ACTIVE_EDGE = ACTIVE_STATE ? 2'b01 : 2'b10;
    
    // All three bits of button_sync start out in the "inactive" state
    (* ASYNC_REG = "TRUE" *) reg [2:0] button_sync = ACTIVE_STATE ? 3'b000 : 3'b111;
    
    // This count will clock down as a debounce timer
    reg [COUNTER_WIDTH-1 : 0] debounce_clock = 0;
    
    // This will be 1 on any clock cycle that a fully debounced active-going edge is detected
    reg edge_detected = 0;    
    
    // We're going to check for edges on every clock cycle
    always @(posedge CLK) begin

        // Bit 2 is the oldest reliable state
        // Bit 1 is the newest reliable state
        // Bit 0 should be considered metastable        
        button_sync[2] <= button_sync[1];
        button_sync[1] <= button_sync[0];
        button_sync[0] <= PIN;
              
        // If the debounce clock is about to expire, find out of the user-specfied pin is still active
        edge_detected <= (debounce_clock == 1) && (button_sync[1] == ACTIVE_STATE);

        // If the debounce clock is still counting down, decrement it
        if (debounce_clock) debounce_clock <= debounce_clock - 1;
        
        // If the pin is high and was previously low, start the debounce clock
        if (button_sync[2:1] == ACTIVE_EDGE) debounce_clock <= DEBOUNCE_PERIOD;
    end
    
    // The output wire always reflects the state of the 'edge_detected' register
    assign Q = edge_detected;
    
endmodule
//======================================================================================================================
