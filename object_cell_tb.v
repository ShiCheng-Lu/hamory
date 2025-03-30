`include "object_cell.v"

`define CLEAR write_to_map = 0; get_available_id = 0; write_invalid = 0; read_address = 0; data = 0; 


// test bench
module object_cell_tb;
    /* Make a regular pulsing clock. */
    reg clk = 0;
    always #2 clk = !clk;

    reg [`HNDL_WIDTH-1:0] chip_select;
    wire [`ADDR_WIDTH-`HNDL_WIDTH-2:0] chip_data;
    reg [`ADDR_WIDTH-1:0] data;
    reg write_to_map = 0;
    reg get_available_id = 0;
    reg write_invalid = 0;
    reg read_address = 0;

    generate
        for (genvar i = 0; i < 8; i = i + 1) begin
            object_cell #(.id(i)) c (
                clk, chip_select, chip_data,
                write_to_map, get_available_id, write_invalid, read_address
            );
        end
    endgenerate
    
    generate
        for (genvar i = 0; i < `ADDR_WIDTH-`HNDL_WIDTH-1; i = i + 1) begin
            pullup pu_inst (chip_data[i]);
        end
    endgenerate

    assign chip_data = {(`ADDR_WIDTH){!(write_to_map | write_invalid)}} | data;
    assign chip_data[`ADDR_WIDTH-`HNDL_WIDTH-2:`HNDL_WIDTH] = {(`ADDR_WIDTH-`HNDL_WIDTH){!(get_available_id)}};

    initial begin
        # 1 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; write_invalid = 1; chip_select = 3; data = 0;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; get_available_id = 1;
        # 4 `CLEAR; write_to_map = 1; chip_select = 1; data = 'h10;
        # 4 `CLEAR; read_address = 1; chip_select = 1;
        # 4 `CLEAR; read_address = 1; chip_select = 3;
        # 4 `CLEAR; write_to_map = 1; chip_select = 4; data = 'habcd;
        # 4 `CLEAR; read_address = 1; chip_select = 4;
        # 4 $stop;
    end

    always @(negedge clk) begin
        $display("At time %t | %h, %h, %d, %d, %d, %d",
                $time, chip_select, chip_data, write_to_map, get_available_id, write_invalid, read_address);
    end
    
endmodule
