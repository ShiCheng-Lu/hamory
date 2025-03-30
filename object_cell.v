/*
Design: this will be infront? of virtual address translation. There will be a set amount of objects to allocate
suppose we use 2 bytes to define handles, in a 64 bit system, this leaves 48 bit's of normal "unhandled" memory
which is ~280 terabyte.

2 bytes can uniquely identify 65k objects, and a total of 256KB of cache is required to store memory mapping

cell commands:
if write & base_address == 0, write to map

if write & base_address == 1, write to valid bit

else if read/write, translate to addr


unit commands:
read from handle 0: return the next available handle address

1 00000

*/
`define ADDR_WIDTH 64
`define HNDL_WIDTH 15
`define NUM_CELLS 32

// for testing, for terminal visibility
// `define ADDR_WIDTH 16
// `define HNDL_WIDTH 3
// `define NUM_CELLS 8

`define NOP 0
`define READ 1
`define WRITE 2

`define H_ADDR(handle_id, address) ((1 << (`ADDR_WIDTH-1)) + (handle_id << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + address) 
`define H_OP(handle_id) ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + handle_id)
`define H_OP_BASE ((1 << (`ADDR_WIDTH-1)) + ({(`HNDL_WIDTH){1'b1}} << (`ADDR_WIDTH-`HNDL_WIDTH-1)) + {(`HNDL_WIDTH){1'b1}})

/*
TODO: 
add command to output a handle's address

this module translates an object handle into the real address
  address bits: 
   [W-1]     = is handle
   [W-2:W-7] = object id
   [W-8:0]   = address offset
*/
module object_cell #(
    parameter [`HNDL_WIDTH-1:0] id = 0
) (
    input i_clock,
    input [`ADDR_WIDTH-1:0] i_address,
    input [`ADDR_WIDTH-1:0] i_data,
    inout [`ADDR_WIDTH-1:0] o_data,
    output wire [`ADDR_WIDTH-`HNDL_WIDTH-1:0] o_offset,
    input write_to_map,
    input get_available_id,
    input write_invalid
);
    reg valid = 0;
    reg [`ADDR_WIDTH-`HNDL_WIDTH-1:0] mapped_address;
    wire [`HNDL_WIDTH-1:0] outputs_id;
    
    // commit any data changes on falling edge
    always @(negedge i_clock) begin
        if (outputs_id[0] & (o_data[0] == id[0])) begin
            valid = 1;
        end
        
        if (i_address[`HNDL_WIDTH-1:0] == id) begin
            if (write_invalid) valid <= 0;
            if (write_to_map) mapped_address <= i_data;
        end
    end

    // if handle matches with this cell
    // drive o_address with strong 1s and weak 0s
    // a == b can be implmented with ~|(a ^ b) equiv. nor(bits of xor(a, b))
    assign (strong1, weak0) o_offset = mapped_address & {(`ADDR_WIDTH-`HNDL_WIDTH){(i_address[`ADDR_WIDTH-2:`ADDR_WIDTH-`HNDL_WIDTH-1] == id)}};
    
    // handling getting available ids
    assign outputs_id[`HNDL_WIDTH-1] = get_available_id & !valid;
    // logic to output the id if this handle is invalid
    assign (strong0, weak1) o_data[`HNDL_WIDTH-1] = !outputs_id[`HNDL_WIDTH-1] | id[`HNDL_WIDTH-1];
    generate
        for (genvar i = 0; i < `HNDL_WIDTH - 1; i = i + 1) begin
            assign (strong0, weak1) outputs_id[i] = outputs_id[i + 1] & (o_data[i + 1] == id[i + 1]);
            assign (strong0, weak1) o_data[i] = (!outputs_id[i]) | id[i];
        end
    endgenerate
endmodule

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

    wire write_to_map;
    wire get_available_id;
    wire write_invalid;

    generate
        for (genvar i = 0; i < `NUM_CELLS; i = i + 1) begin
            object_cell #(.id(i)) c (
                i_clock, i_address, i_data, 
                o_data, offset, 
                write_to_map, get_available_id, write_invalid
            );
        end
    endgenerate

    // 
    wire handle_cmd;
    assign handle_cmd = &i_address[`ADDR_WIDTH-1:`ADDR_WIDTH-`HNDL_WIDTH-1];

    assign get_available_id = (i_op == `READ) & (handle_cmd) & (&i_address[`HNDL_WIDTH-1:0]);
    assign (strong0, weak1) o_data = {(`HNDL_WIDTH){get_available_id}};
    always @(negedge i_clock) begin
        $display("At time %t | %h ",
                $time, o_data);
    end

    assign write_to_map = (i_op == `WRITE) & (handle_cmd) & (|i_data);

    assign write_invalid = (i_op == `WRITE) & (handle_cmd) & !(|i_data);
    
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
        # 4 addr = `H_OP(2);        data = 'h10; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1);   data = 5; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 8; op = `WRITE;
        # 4 addr = `H_OP(2);        data = 2; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1);   data = 1; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 2; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 3; op = `READ;
        # 4 addr = `H_OP(2);        data = 0; op = `WRITE;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = `H_OP_BASE;    data = 0; op = `READ;
        # 4 addr = 'h802c;  data = 1; op = `NOP;
        # 0 $stop;
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
