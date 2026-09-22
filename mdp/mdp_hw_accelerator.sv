// Fixed-point: Q0.32 unsigned operands, 64-bit accumulator.

module mac_compare_lane #(
    parameter WIDTH     = 32,   
    parameter ACC_WIDTH = 64    
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 row_start,   
    input  wire                 edge_valid,  
    input  wire [WIDTH-1:0]     value_in,    
    input  wire [WIDTH-1:0]     weight_in,   
    input  wire                 mode,        
    output reg  [WIDTH-1:0]     result,      
    output reg                  row_done     
);

    // ---- Stage 1: pipelined multiply ----

    reg                m_valid_s1;
    reg                m_mode_s1;
    reg [2*WIDTH-1:0]  product_s1;
    reg                row_start_d1;
    reg                row_start_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid_s1   <= 1'b0;
            row_start_d1 <= 1'b0;
            row_start_d2 <= 1'b0;
        end else begin
            m_valid_s1   <= edge_valid;
            m_mode_s1    <= mode;
            product_s1   <= value_in * weight_in;      
            row_start_d1 <= row_start;
            row_start_d2 <= row_start_d1;
        end
    end

    // ---- Stage 2: accumulate (SUM) or compare-select (MAX) ----

    reg [ACC_WIDTH-1:0] acc;
    wire [WIDTH-1:0] term = product_s1[2*WIDTH-1 -: WIDTH];   

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= {ACC_WIDTH{1'b0}};
        end else if (row_start_d1) begin
            acc <= {ACC_WIDTH{1'b0}};                          
        end else if (m_valid_s1) begin
            if (m_mode_s1)
                acc <= (term > acc[WIDTH-1:0])
                       ? {{(ACC_WIDTH-WIDTH){1'b0}}, term} : acc;  
            else
                acc <= acc + term;                              
        end
    end

    always @(posedge clk) begin
        result   <= acc[ACC_WIDTH-1 -: WIDTH];   
        row_done <= row_start_d2;                
    end

endmodule