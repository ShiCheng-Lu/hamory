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

`define NOP 0
`define READ 1
`define WRITE 2

`define H_ADDR(handle_id, address) ((1 << 15) + (handle_id << 12) + address) 
`define H_OP(handle_id) ((1 << 15) + ('b111 << 12) + handle_id)

/*
TODO: 
add wire for write mapped_address
add wire to get emptiness (return id if invalid)
add validness check
output should probably only be an offset that gets added so theoretically the hardware only would need 1 adder


this module translates an object handle into the real address
  address bits: 
   [W-1]     = is handle
   [W-2:W-7] = object id
   [W-8:0]   = address offset
*/
module object_cell #(
    parameter W = 16,
    parameter HW = 3,
    parameter [HW-1:0] id = 0
) (
    input i_clock,
    input [W-1:0] i_address,
    input [W-1:0] i_data,
    inout [W-1:0] o_data,
    output wire [W-HW-1:0] o_offset,
    input write_to_map,
    input get_available_id,
    input write_invalid
);
    reg [W-HW-1:0] mapped_address = 99;
    reg valid = 0;
    reg [W-HW-1:0] candidate_output;
    wire [HW-1:0] outputs_id;
    // at rising edge, compare if the address matches the handle, 
    // output the translated address if matches
    always @(posedge i_clock) begin
        
        // handling writing to validness
        if (write_invalid) begin
            valid = 0;
        end

        if (write_to_map) begin
            mapped_address = i_data;
        end
        // a == b can be implmented with ~|(a ^ b) equiv. nor(bits of xor(a, b))
        if (i_address[W-1] & (i_address[W-2:W-HW-1] == id)) begin
            candidate_output = mapped_address;
        end else begin
            // if doesn't match, weakly output 0
            candidate_output = 0;
        end
    end

    always @(negedge i_clock) begin
        if (&outputs_id & o_data[0] == id[0]) begin
            valid = 1;
        end
    end

    // drive o_address with strong 1s and weak 0s
    assign (strong1, weak0) o_offset = candidate_output;
    
    // always #1 begin
    //     $display("mapped addr at %d (%d): %h, %h",
    //             $time, id, mapped_address, candidate_output);
    // end
    // handling getting available ids
    assign outputs_id[HW-1] = get_available_id & !valid;
    // logic to output the id if this handle is invalid
    assign (strong0, weak1) o_data[HW-1] = !outputs_id[HW-1] | id[HW-1];
    generate
        for (genvar i = 0; i < HW - 1; i = i + 1) begin
            assign (strong0, weak1) outputs_id[i] = outputs_id[i + 1] & (o_data[i + 1] == id[i + 1]);
            assign (strong0, weak1) o_data[i] = (!outputs_id[i]) | id[i];
        end
    endgenerate
endmodule

/*

*/
module handle_handler #(
    parameter W = 16,
    parameter HW = 3
) (
    input i_clock,
    input [2:0] i_op,
    input [W-1:0] i_address,
    input [W-1:0] i_data,
    output [2:0] o_op,
    output [W-1:0] o_address,
    output [W-1:0] o_data
);
    wire [W-HW-1:0] offset;

    wire write_to_map;
    wire get_available_id;
    wire write_invalid;

    object_cell #(.W(W), .HW(HW), .id('b101)) c1 (i_clock, i_address, i_data, o_data, offset, write_to_map, get_available_id, write_invalid);
    object_cell #(.W(W), .HW(HW), .id('b010)) c2 (i_clock, i_address, i_data, o_data, offset, write_to_map, get_available_id, write_invalid);

    // 
    wire handle_cmd;
    assign handle_cmd = &i_address[W-1:W-HW-1];

    assign get_available_id = (i_op == `READ) & (handle_cmd) & (&i_address[HW-1:0]);
    assign (strong0, weak1) o_data = {(W-1){get_available_id}} & 'b111;

    assign write_to_map = (i_op == `WRITE) & (handle_cmd) & (|i_data);

    // assign write_invalid = (i_op == `WRITE) & (handle_cmd) & !(|i_data);
    
    // outputs
    assign o_op = i_op & {(2){!handle_cmd}};
    // output address, result of translation if translating, 0 if its a handle operation
    assign o_address = (i_address[W-HW-1:0] + offset) & {(W){!handle_cmd}};
endmodule

// test bench
module object_cell_tb;
    reg [2:0] op = 0; // 0 for no-op, 1 for read, 2 for write
    reg [15:0] addr = 0;
    reg [15:0] data = 0;

    initial begin
        # 1;
        # 4 addr = `H_OP('b111);    data = 0; op = `READ;
        # 4 addr = `H_OP('b111);    data = 0; op = `READ;
        # 4 addr = `H_OP(2);        data = 'h10; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1);   data = 5; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 8; op = `WRITE;
        # 4 addr = `H_OP(2);        data = 2; op = `WRITE;
        # 4 addr = `H_ADDR(2, 1);   data = 1; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 2; op = `READ;
        # 4 addr = `H_ADDR(2, 1);   data = 3; op = `READ;
        # 4 addr = 'h802c;  data = 1; op = `NOP;
        # 0 $stop;
    end
    /* Make a regular pulsing clock. */
    reg clk = 0;
    always #2 clk = !clk;

    wire [2:0] o_op;
    wire [15:0] o_address;
    wire [15:0] o_data;

    handle_handler s(clk, op, addr, data, o_op, o_address, o_data);
    always @(negedge clk) begin
        $display("At time %t | inputs: %d, %h, %h | outputs: %d, %h, %h, ",
                $time, op, addr, data, o_op, o_address, o_data);
    end
    
endmodule
