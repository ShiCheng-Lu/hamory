
`include "handle_handler.v"

`define H_ADDR(handle_id, address) ((1 << (`ADDR_WIDTH-1)) + (handle_id << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + address) 
`define H_OP(handle_id) ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + handle_id)
`define H_OP_BASE ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + {(`HNDL_WIDTH){1'b1}})


// test bench
module handle_handler_tb;
    reg [2:0] op = 0; // 0 for no-op, 1 for read, 2 for write
    reg [`ADDR_WIDTH-1:0] addr = 0;
    reg [`ADDR_WIDTH-1:0] data = 0;

    initial begin
        # 1 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP(2);      data = 'h10; op = `WRITE;
        # 4 addr = `H_ADDR(2, 5); data = 0; op = `READ;
        # 4 addr = `H_ADDR(2, 1); data = 8; op = `WRITE;
        # 4 addr = `H_OP(2);      data = 0; op = `READ;
        # 4 addr = `H_OP(2);      data = 6; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1); data = 1; op = `READ;
        # 4 addr = `H_ADDR(2, 1); data = 2; op = `READ;
        # 4 addr = `H_ADDR(2, 1); data = 3; op = `READ;
        # 4 addr = `H_OP(2);      data = 0; op = `READ;
        # 4 addr = `H_OP(2);      data = 0; op = `WRITE;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 $stop;
    end
    /* Make a regular pulsing clock. */
    reg clk = 0;
    always #2 clk = !clk;

    wire [2:0] o_op;
    wire [`ADDR_WIDTH-1:0] o_address;
    wire [`ADDR_WIDTH-1:0] o_data;

    handle_handler s(clk, op, addr, data, o_op, o_address, o_data);
    always @(negedge clk) begin
        $display("At time %t | inputs: %d, %h, %h | outputs: %d, %h, %h, ",
                $time, op, addr, data, o_op, o_address, o_data);
    end
    
endmodule
