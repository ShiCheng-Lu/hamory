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
*/

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
    parameter [6:0] id = 0,
    parameter [7:0] map = 0
) (
    input [W-1:0] i_address,
    inout [W-1:0] io_data,
    input i_clock,
    output wire [W-1:0] o_address,
);
    reg [7:0] mapped_address = map;
    reg valid = 0;
    reg [W-1:0] candidate_output;
    // at rising edge, compare if the address matches the handle, 
    // output the translated address if matches
    always @(posedge i_clock) begin
        // a == b can be implmented with ~|(a ^ b) equiv. nor(bits of xor(a, b))
        if (i_address[W-1] & (i_address[W-2:W-8] == id)) begin
            candidate_output <= {mapped_address, i_address[W-9:0]};
        end else begin
            // if doesn't match, weakly output 0
            candidate_output <= 0;
        end
    end
    // drive o_address with strong 1s and weak 0s
    assign (strong1, weak0) o_address = candidate_output;
endmodule

// test bench
module object_cell_tb;
  reg [15:0] data = 0;
  initial begin
    # 1 data = 'h8066;
    # 4 data = 'h812c;
    # 4 data = 'h802c;
    # 200 $stop;
  end
  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  wire [15:0] result;

  object_cell #(.id(0), .map(5)) c1 (data, clk, result);
  object_cell #(.id(1), .map(7)) c2 (data, clk, result);

  initial
     $monitor("At time %t, data = %h, value = %h (%0d)",
              $time, data, result, result);
endmodule
