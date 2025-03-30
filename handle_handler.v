

`define NOP 0
`define READ 1
`define WRITE 2

`define H_ADDR(handle_id, address) ((1 << (`ADDR_WIDTH-1)) + (handle_id << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + address) 
`define H_OP(handle_id) ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + handle_id)
`define H_OP_BASE ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + {(`HNDL_WIDTH){1'b1}})


/*

*/
module handle_handler (
    input i_clock,
    input [2:0] i_op,
    input [`ADDR_WIDTH-1:0] i_address,
    input [`ADDR_WIDTH-1:0] i_data,
    output [2:0] o_op,
    output [`ADDR_WIDTH-1:0] o_address,
    output [`ADDR_WIDTH-1:0] o_data
);
    wire [`ADDR_WIDTH-`HNDL_WIDTH-1:0] offset;

    wire [`HNDL_WIDTH-1:0] chip_select;
    wire [`ADDR_WIDTH-1:0] chip_data;

    wire write_to_map;
    wire get_available_id;
    wire write_invalid;
    wire read_address;

    generate
        for (genvar i = 0; i < `NUM_CELLS; i = i + 1) begin
            object_cell #(.id(i)) c (
                i_clock, chip_select, chip_data,
                write_to_map, get_available_id, write_invalid, read_address
            );
        end
    endgenerate

    // 
    wire handle_cmd;
    assign handle_cmd = &i_address[`ADDR_WIDTH-1:`ADDR_WIDTH-`HNDL_WIDTH-1];

    assign get_available_id = (i_op == `READ) & (handle_cmd) & (&i_address[`HNDL_WIDTH-1:0]);

    assign write_to_map = (i_op == `WRITE) & (handle_cmd) & (|i_data);

    assign write_invalid = (i_op == `WRITE) & (handle_cmd) & !(|i_data);
    
    assign read_address = (i_op == `READ) & (handle_cmd) & !(&i_address[`HNDL_WIDTH-1:0]);
    assign (strong0, weak1) o_data = {(`HNDL_WIDTH){get_available_id | read_address}};

    assign chip_select = handle_cmd ? i_address[`HNDL_WIDTH-1:0] : i_address[`ADDR_WIDTH-2:`ADDR_WIDTH-`HNDL_WIDTH-1];

    // outputs
    assign o_op = i_op & {(2){!handle_cmd}};
    // output address, result of translation if translating, 0 if its a handle operation
    assign o_address = (i_address[`ADDR_WIDTH-`HNDL_WIDTH-1:0] + offset) & {(`ADDR_WIDTH){!handle_cmd}};
endmodule


// test bench
module object_cell_tb;
    reg [2:0] op = 0; // 0 for no-op, 1 for read, 2 for write
    reg [`ADDR_WIDTH-1:0] addr = 0;
    reg [`ADDR_WIDTH-1:0] data = 0;

    initial begin
        # 1 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP(2);      data = 'h10; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1); data = 5; op = `READ;
        # 4 addr = `H_ADDR(2, 1); data = 8; op = `WRITE;
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

