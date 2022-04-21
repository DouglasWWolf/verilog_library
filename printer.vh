
`define PBUFF_CHARS         64
`define PFMT_WIDTH          32

`define PFRAME_WIDTH        (`PBUFF_CHARS*8  + `PFMT_WIDTH)
`define PFRAME_INPUT   input[`PFRAME_WIDTH-1:0]
`define PFRAME_OUTPUT output[`PFRAME_WIDTH-1:0]
`define PFRAME_REG       reg[`PFRAME_WIDTH-1:0]
`define PFRAME_WIRE     wire[`PFRAME_WIDTH-1:0]


`define PFMT_STR   32'h0000
`define PFMT_HEX   32'h1000
`define PFMT_BIN   32'h2000
`define PFMT_DEC   32'h3000
`define PFMT_CRLF  32'h8000
`define PFMT_NOSEP 32'h0800

