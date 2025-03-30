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
`define HNDL_WIDTH 8
`define NUM_CELLS 4

// for testing, for terminal visibility
// `define ADDR_WIDTH 16
// `define HNDL_WIDTH 3
// `define NUM_CELLS 8

/*
TODO: 
add command to output a handle's address
maybe write to BASE to release


this module translates an object handle into the real address
  address bits: 
   [W-1]     = is handle
   [W-2:W-7] = object id
   [W-8:0]   = address offset
*/
module object_cell #(
    parameter [`HNDL_WIDTH-1:0] id = 0
) (
    input clock,
    input [`HNDL_WIDTH-1:0] cs,
    inout triand [`ADDR_WIDTH-`HNDL_WIDTH-2:0] data,
    input write_to_map,
    input get_available_id,
    input write_invalid,
    input read_address
);
    reg valid = 0;
    reg [`ADDR_WIDTH-`HNDL_WIDTH-2:0] mapped_address = 0;
    wire [`HNDL_WIDTH-1:0] outputs_id;
    wire disabled;
    
    // commit any data changes on falling edge
    always @(negedge clock) begin
        // $display("%d | cell %d: %d, %d, %h, %h", $time, id, disabled, write_to_map, data, mapped_address);

        if (outputs_id[0] & (data[0] == id[0])) begin
            valid = 1;
        end
        
        if (!disabled) begin
            if (write_invalid) valid <= 0;
            if (write_to_map) mapped_address <= data;
        end
    end

    assign disabled = |(cs ^ id);

    // if handle matches with this cell
    // drive o_address with strong 1s and weak 0s
    // a == b can be implmented with ~|(a ^ b) equiv. nor(bits of xor(a, b))
    assign data = {(`ADDR_WIDTH){disabled | !read_address}} | mapped_address;
    
    // handling getting available ids
    assign outputs_id[`HNDL_WIDTH-1] = get_available_id & !valid;

    // logic to output the id if this handle is invalid
    assign data[`HNDL_WIDTH-1] = !outputs_id[`HNDL_WIDTH-1] | id[`HNDL_WIDTH-1];
    generate
        for (genvar i = 0; i < `HNDL_WIDTH - 1; i = i + 1) begin
            assign outputs_id[i] = outputs_id[i + 1] & (data[i + 1] == id[i + 1]);
            assign data[i] = (!outputs_id[i]) | id[i];
        end
    endgenerate
endmodule
