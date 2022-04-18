
`define PBUFF_CHARS         64
`define PFMT_WIDTH          16

`define PFRAME_WIDTH        (`PBUFF_CHARS*8  + `PFMT_WIDTH)
`define PFRAME_INPUT   input[`PFRAME_WIDTH-1:0]
`define PFRAME_OUTPUT output[`PFRAME_WIDTH-1:0]
`define PFRAME_REG       reg[`PFRAME_WIDTH-1:0]
`define PFRAME_WIRE     wire[`PFRAME_WIDTH-1:0]

`define PFMT_STR  16'h8000
`define PFMT_HEX  16'h9000
`define PFMT_BIN  16'hA000
`define PFMT_DEC  16'hB000
`define PFMT_CRLF 16'h0800


