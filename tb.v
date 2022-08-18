`timescale 1ns/100ps





module tokenizer#
(
    parameter M_AXI_DATA_WIDTH = 256,
    parameter M_AXI_ADDR_WIDTH =  32,
    parameter TOKEN_WIDTH      = 256
    
)
(
    input wire                        AXI_ACLK, AXI_ARESETN,
    input wire [M_AXI_ADDR_WIDTH-1:0] STR_ADDR,
    input wire                        START
);


    //========================================================================================
    // char_rstream : Fetches a stream of 8-bit bytes (i.e. characters)
    //
    // Inputs:  cmd = 
    //
    // Outputs: istream_data  = the byte that was fetched
    //          istream_valid = 1 when 'data' is valid
    //========================================================================================
    reg [1:0]                  istream_cmd;
    reg [M_AXI_ADDR_WIDTH-1:0] istream_addr;
    wire[7:0]                  istream_data;
    wire                       istream_valid;

    char_rstream#(.AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)) istream
    (
        .CMD  (istream_cmd),
        .ADDR (istream_addr),
        .VALID(istream_valid),
        .DATA (istream_data),
        .M_AXI_ACLK(AXI_ACLK),
        .M_AXI_ARESETN(AXI_ARESETN)
    );
    //========================================================================================

    // Determine how many bytes wide a token is
    localparam TOKEN_BYTES = TOKEN_WIDTH / 8;

    // Commands we send to the character read-stream core
    localparam ISTREAM_START         = 1;
    localparam ISTREAM_GET_NEXT_BYTE = 2;
    
    // States of the tokenizer state machine
    localparam tsm_IDLE                 = 0;
    localparam tsm_START_NEW_TOKEN      = 1;
    localparam tsm_PARSE_TOKEN          = 2;
    localparam tsm_REACHED_END_OF_TOKEN = 3;
    localparam tsm_SKIP_TRAILING_SPACES = 4;
    localparam tsm_SKIP_TRAILING_COMMA  = 5;
    localparam tsm_TOKENIZING_COMPLETE  = 6;

    // The state of the tokenizer state-machine
    reg[7:0] tsm_state;

    // This will always be 0, ASCII ', or ASCII "
    reg[7:0] in_quotes;

    // This is the token currently being parsed
    reg[TOKEN_WIDTH-1:0] token;


    task show(input reg[256-1:0] token);
        integer ii;
        begin
            for (ii=0; ii<32; ii=ii+1) begin
                if (token[8*(32 - 1 - ii) +:8] >= 32)
                    $write("%s", token[8*(32 - 1 - ii) +:8]);
                else
                    $write(".");
            end
            $display("");
        end
    endtask


    always @(posedge AXI_ACLK) begin

        // Commands to the input stream only pulse high for one clock cycle
        istream_cmd <= 0;

        if (AXI_ARESETN == 0) begin
            tsm_state <= tsm_IDLE;
        end else case(tsm_state)

        // When we're told to start, tell the character read-stream to start
        tsm_IDLE:
            if (START) begin
                istream_addr <= STR_ADDR;
                istream_cmd  <= ISTREAM_START;
                tsm_state    <= tsm_START_NEW_TOKEN;
            end

        // Here we are skipping over any leading spaces before our token
        tsm_START_NEW_TOKEN:

            // If we have a valid character from the input stream...
            if (istream_valid) begin
                
                // If that character is a space, skip over it
                if (istream_data == " ") istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                
                // If that character is nul, we've hit the end of the input stream
                else if (istream_data == 0) tsm_state <= tsm_TOKENIZING_COMPLETE;
                
                // Otherwise, we're at the first character of a new token
                else begin

                    // For the moment, assume the first character isn't ' or "
                    in_quotes <= 0;
                    
                    // If the first character of the token is ' or "...
                    if (istream_data == 34 || istream_data == 39) begin
                        
                        // Store the type of quotation mark 
                        in_quotes <= istream_data;

                        // And throw away the quotation mark
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                    
                    // Initialize the result field we're parsing our token into
                    token <= 0;

                    // And go parse the token into the "token" register
                    tsm_state <= tsm_PARSE_TOKEN;
                end
            end

        // Here we're going to loop through incoming characters, appending them to our token
        tsm_PARSE_TOKEN:

            // If we have a valid character from the input stream...
            if (istream_valid) begin
                
                // If we're inside of a quoted string...
                if (in_quotes) begin

                    // If we've just hit the closing quote, skip over it, otherwise, append
                    // this character to our token
                    if (istream_data == in_quotes) begin
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                        tsm_state   <= tsm_REACHED_END_OF_TOKEN;
                    end else begin
                        token       <= (token << 8) | istream_data;
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                end
                
                // Otherwise, we're not in a quoted string. 
                else begin
                    
                    // If we just hit a space, comma, or nul, this is the end of this token
                    if (istream_data == " " || istream_data == "," || istream_data == 0)
                        tsm_state   <= tsm_REACHED_END_OF_TOKEN;
                    
                    // Otherwise, append this character to the token, and fetch a new character
                    else begin   
                        token       <= (token << 8) | istream_data;
                        istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                    end
                end
            end

        tsm_REACHED_END_OF_TOKEN:
            begin
                show(token);
                tsm_state <= tsm_SKIP_TRAILING_SPACES;
            end



        tsm_SKIP_TRAILING_SPACES:
            if (istream_valid) begin
                if (istream_data == " ")
                    istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                else
                    tsm_state   <= tsm_SKIP_TRAILING_COMMA;
            end


        tsm_SKIP_TRAILING_COMMA:
            if (istream_valid) begin
                if (istream_data == ",") istream_cmd <= ISTREAM_GET_NEXT_BYTE;
                tsm_state <= tsm_START_NEW_TOKEN;
            end


        tsm_TOKENIZING_COMPLETE:
            begin
                $display("Complete!");
                $finish;
            end

        endcase

    end

endmodule




module top#(parameter AXI_ADDR_WIDTH = 32, parameter AXI_DATA_WIDTH = 256)();

    reg clk, resetn, start;

    tokenizer#
    (
        .M_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .M_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) inst_tokenizer
    (
        .AXI_ACLK(clk),
        .AXI_ARESETN(resetn),
        .STR_ADDR(32'hC000_0000),
        .START(start)
    );


//strtoul#(.STR_WIDTH(RW)) inst_strtoul
//(
    //.clk(clk),
    //.resetn(resetn),
    //.START(start),
    //.INPSTR(str),
    //.STATUS(status),
    //.RESULT(result)
//);



    initial begin
        clk = 0;
        #5;
        forever clk = #1 ~clk;
    end

    initial begin
        resetn = 0;
        start  = 0;
        #50
        resetn = 1;
        #5
        start = 1;
        #2
        start = 0;
    end


endmodule