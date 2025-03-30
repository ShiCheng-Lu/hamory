
module object_cell #(
    parameter [3:0] id = 0
) (
    inout triand [3:0] data
);
    assign data[3] = id[3];
    assign data[2] = id[2];
    assign data[1] = id[1];
    assign data[0] = id[0];
endmodule;

// test bench
module object_cell_tb;
    wire [3:0] data;

    initial begin
        # 4 $stop;
    end

    object_cell #(.id('b0101)) s(data);
    object_cell #(.id('b1101)) s2(data);

    generate
    for(genvar i = 0; i < 4; i = i + 1) begin
        pullup pu_inst (data[i]);
    end
    endgenerate

    initial begin
        $monitor("At time %t | data: %b",
                $time, data);
    end
    
endmodule
