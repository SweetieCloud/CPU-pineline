`timescale 1ns / 1ps

module branch_comp #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] i_src_a,  // To�n h?ng 1 (t? RS1 ho?c Forwarded)
    input  wire [DATA_WIDTH-1:0] i_src_b,  // To�n h?ng 2 (t? RS2 ho?c Forwarded)

    output wire                  o_br_eq,  // 1 n?u i_src_a == i_src_b (BEQ / BNE)
    output wire                  o_br_lt,  // 1 n?u i_src_a < i_src_b (C� d?u: BLT / BGE)
    output wire                  o_br_ltu  // 1 n?u i_src_a < i_src_b (Kh�ng d?u: BLTU / BGEU)
);

    // So s�nh b?ng
    assign o_br_eq  = (i_src_a == i_src_b);

    // So s�nh b� h?n c� d?u (Signed Comparison)
    assign o_br_lt  = ($signed(i_src_a) < $signed(i_src_b));

    // So s�nh b� h?n kh�ng d?u (Unsigned Comparison)
    assign o_br_ltu = (i_src_a < i_src_b);

endmodule