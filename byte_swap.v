//
// byte_swap.v - Reverses the order of bytes in a field
//

module byte_swap #
(
    parameter DW = 32    
)
(
    input  [DW-1:0] I,
    output [DW-1:0] O
);  

// Compute how many bytes are in the input/output
localparam BC = DW / 8;

genvar i;
for (i=0; i<BC; i=i+1) begin
    assign O[i*8 +:8] = I[(BC-1-i)*8 +:8];
end 


endmodule