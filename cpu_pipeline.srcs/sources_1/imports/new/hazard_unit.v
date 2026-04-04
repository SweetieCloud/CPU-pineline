/* * File: hazard_unit.v
 */
`timescale 1ns / 1ps

module hazard_unit( 
    input ID_EX_MemRead,
    input [2:0] ID_EX_rt,
     
    input [2:0] IF_ID_rs,
    input [2:0] IF_ID_rt,
    
    input Branch_Taken, 
    
    // Outputs 
    output reg PCWrite,       
    output reg IF_ID_Write,     
    output reg IF_ID_Flush,   
    output reg ID_EX_Flush    
);

    always @(*) begin
        PCWrite = 1;
        IF_ID_Write = 1;
        IF_ID_Flush = 0;
        ID_EX_Flush = 0;
        if (ID_EX_MemRead && 
           ((ID_EX_rt == IF_ID_rs) || (ID_EX_rt == IF_ID_rt))) begin
            
            // Stall Pipeline:
            PCWrite     = 0; 
            IF_ID_Write = 0;  
            ID_EX_Flush = 1;  
        end
         
        if (Branch_Taken) begin
            IF_ID_Flush = 1;
        end
    end

endmodule
