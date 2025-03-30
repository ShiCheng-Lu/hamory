`include "object_cell.v"

`define NOP 0
`define READ 1
`define WRITE 2

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
    wire [`HNDL_WIDTH-1:0] chip_select;
    triand [`ADDR_WIDTH-`HNDL_WIDTH-2:0] chip_data;

    wire write_to_map;
    wire get_available_id;
    wire write_invalid;
    wire read_address;

    // create the cell array
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

    assign write_to_map = (i_op == `WRITE) & (handle_cmd) & (|i_data);

    assign get_available_id = (i_op == `READ) & (handle_cmd) & (&i_address[`HNDL_WIDTH-1:0]);

    assign write_invalid = (i_op == `WRITE) & (handle_cmd) & !(|i_data);
    
    // also read the address if its not a handle command
    assign read_address = (i_op == `READ) & (handle_cmd) & !(&i_address[`HNDL_WIDTH-1:0]) | (!handle_cmd);
    assign (strong0, weak1) o_data = {(`HNDL_WIDTH){get_available_id | read_address}};

    // chip select address is either end of the address for handle commands or at highest bits
    assign chip_select = handle_cmd ? i_address[`HNDL_WIDTH-1:0] : i_address[`ADDR_WIDTH-2:`ADDR_WIDTH-`HNDL_WIDTH-1];

    assign chip_data = {(`ADDR_WIDTH){!(write_to_map | write_invalid)}} | i_data;
    assign chip_data[`ADDR_WIDTH-`HNDL_WIDTH-2:`HNDL_WIDTH] = {(`ADDR_WIDTH-`HNDL_WIDTH){!(get_available_id)}};
    
    // always @(negedge i_clock) begin
    //     $display("Hander %t | %h %h, %d %d %d %d",
    //             $time, chip_select, chip_data, write_to_map, get_available_id, write_invalid, read_address);
    // end

    // outputs
    assign o_op = i_op & {(2){!handle_cmd}};
    // output address, result of translation if translating, 0 if its a handle operation
    assign o_address = (i_address[`ADDR_WIDTH-`HNDL_WIDTH-1:0] + chip_data) & {(`ADDR_WIDTH){!handle_cmd}};

    // maybe should also outputs i_data as o_data if it's a translation
    assign o_data = ((get_available_id | read_address) & handle_cmd) ? chip_data : 0;
endmodule


