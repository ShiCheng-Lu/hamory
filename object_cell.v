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

/*
this module stores a memory offset for a particular handle
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
    wire enabled;
    
    // commit any data changes on falling edge
    always @(negedge clock) begin
        // $display("%d | cell %d: %d, %d, %h, %h", $time, id, enabled, write_to_map, data, mapped_address);

        // at the clock edge, we are outputting our id into the data line, and the last bit is correct
        // then it must have been a get_available_id, and we are the lowest, so set self as valid to make 
        // get_available_id atomically increment, this way get_available_id always returns a unique, valid handle
        // ready to be used.
        if (outputs_id[0] & (data[0] == id[0])) begin
            valid = 1;
        end
        
        // the current cell is being addressed, if there was a handle command, perform it.
        if (enabled) begin
            if (write_invalid) valid <= 0;
            if (write_to_map) mapped_address <= data;
        end
    end

    assign enabled = !(|(cs ^ id));

    // if handle matches with this cell
    // drive o_address with strong 1s and weak 0s
    // a == b can be implmented with ~|(a ^ b) equiv. nor(bits of xor(a, b))
    assign data = {(`ADDR_WIDTH){!(enabled & read_address)}} | mapped_address;
    
    // handling getting available ids
    assign outputs_id[`HNDL_WIDTH-1] = get_available_id & !valid;

    // logic to output the id if this handle is invalid
    assign data[`HNDL_WIDTH-1] = !outputs_id[`HNDL_WIDTH-1] | id[`HNDL_WIDTH-1];
    generate
        for (genvar i = 0; i < `HNDL_WIDTH - 1; i = i + 1) begin : generate_get_handle
            assign outputs_id[i] = outputs_id[i + 1] & (data[i + 1] == id[i + 1]);
            assign data[i] = (!outputs_id[i]) | id[i];
        end
    endgenerate
endmodule
