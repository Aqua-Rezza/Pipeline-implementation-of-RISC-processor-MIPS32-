`timescale 1ns / 1ps
module mips32(clk1,clk2);

input clk1,clk2;
// made intermediate registers
reg [31:0] pc,If_Id_Ir,If_Id_Npc;
reg [31:0] Id_Ex_Ir,Id_Ex_Npc,Id_Ex_A,Id_Ex_B,Id_Ex_Imm;
reg [31:0] Ex_Mem_Ir,Ex_Mem_ALU_out,Ex_Mem_B;
reg Ex_Mem_cond;   
reg [31:0] Mem_Wb_Ldr,Mem_Wb_ALU_out,Mem_Wb_Ir;
reg [2:0] Id_Ex_type,Ex_Mem_type,Mem_Wb_type;
// register bank and memory
reg [31:0] reg_bank [0:31];
reg [31:0] Mem [0:1023];
parameter Add=6'b000000, Sub=6'b000001, Mul=6'b000010, AddI=6'b000100, SubI=6'b000101, And=6'b001000,
          Or=6'b001001, Xor=6'b001010, Lw=6'b001011, Sw=6'b001100, Slt=6'b001101, BEQZ=6'b001110, BNEQZ=6'b001111,
          HLT=6'b111111;
parameter RR_t=3'b000, RM_t=3'b001, Load=3'b010, Store=3'b011, Branch=3'b100, Halt=3'b111;

reg Halted, Taken_branch;

//Instruction Fetching stage
always @(posedge clk1) begin
if(Halted==0)begin
    if((Ex_Mem_Ir[31:26]==BEQZ)&&(Ex_Mem_cond==1) || (Ex_Mem_Ir[31:26]==BNEQZ)&&(Ex_Mem_cond==0))begin
        If_Id_Ir<= #2 Mem[Ex_Mem_ALU_out];
        If_Id_Npc<= #2 Ex_Mem_ALU_out+1;
        pc<= #2 Ex_Mem_ALU_out +1;
        Taken_branch<= #2 1'b1;
    end
    else begin
        If_Id_Ir<= #2 Mem[pc];
        If_Id_Npc<= #2 pc+1;
        pc<= #2 pc+1; 
    end
end
end

//Instruction Decode stage
always @(posedge clk2) begin
    if(Halted==0)begin
    Id_Ex_Ir<= #2 If_Id_Ir;
    Id_Ex_Npc<= #2 Id_Ex_Npc;
    Id_Ex_Imm<= #2 {{16{If_Id_Ir[15]}},{If_Id_Ir[15:0]}};
        if(If_Id_Ir[25:21]==5'b00000)
            Id_Ex_A<=  0;
        else
            Id_Ex_A<= #2 reg_bank[If_Id_Ir[25:21]];
        if(If_Id_Ir[20:16]==5'b00000)
            Id_Ex_B<=  0;
        else
            Id_Ex_B<= #2 reg_bank[If_Id_Ir[20:16]];
    
    case(If_Id_Ir[31:26])
    Add,Sub,Mul,And,Or,Xor,Slt:
        Id_Ex_type<= #2 RR_t;
    AddI,SubI:
        Id_Ex_type<= #2 RM_t;
    Lw:
        Id_Ex_type<= #2 Load;
    Sw:
        Id_Ex_type<= #2 Store;
    BEQZ,BNEQZ:
        Id_Ex_type<= #2 Branch;
    HLT:
        Id_Ex_type<= #2 Halt;
    default:
        Id_Ex_type<= #2 Halt;    
    endcase          
    end
end

//Execution
always @(posedge clk1) begin
    if(Halted==0)begin
    Ex_Mem_Ir<= #2 Id_Ex_Ir;
    Ex_Mem_type<= #2 Id_Ex_type;
    Taken_branch<= #2 1'b0;
    case(Id_Ex_type)
    RR_t:
        case(Id_Ex_Ir[31:26])
        Add: Ex_Mem_ALU_out<= #2 Id_Ex_A + Id_Ex_B;
        Sub: Ex_Mem_ALU_out<= #2 Id_Ex_A - Id_Ex_B;
        Mul: Ex_Mem_ALU_out<= #2 Id_Ex_A * Id_Ex_B;
        And: Ex_Mem_ALU_out<= #2 Id_Ex_A && Id_Ex_B;
        Or: Ex_Mem_ALU_out<= #2 Id_Ex_A || Id_Ex_B;
        Xor: Ex_Mem_ALU_out<= #2 Id_Ex_A ^ Id_Ex_B;
        default: Ex_Mem_ALU_out<= #2 32'hxxxxxxxx;
        endcase
    RM_t:
        case(Id_Ex_Ir[31:26])
        AddI: Ex_Mem_ALU_out<= #2 Id_Ex_A + Id_Ex_Imm;
        SubI: Ex_Mem_ALU_out<= #2 Id_Ex_A - Id_Ex_Imm;
        default: Ex_Mem_ALU_out<= #2 32'hxxxxxxxx;
        endcase       
    Load: Ex_Mem_ALU_out<= #2 Id_Ex_A + Id_Ex_Imm;
        
    Store: Ex_Mem_B<= #2 Id_Ex_B;
        
    Branch: begin
        Ex_Mem_ALU_out<= #2 Id_Ex_A + Id_Ex_Imm;
        Ex_Mem_cond<= #2 (Id_Ex_A==0)?1:0;
   end  
   endcase
   end
end

//Data memory
always @(posedge clk2) begin
    if(Halted==0)begin
    Mem_Wb_Ir<= #2 Ex_Mem_Ir;
    Mem_Wb_type<= Ex_Mem_type;
    case(Ex_Mem_type)
    RR_t,RM_t:
        Mem_Wb_ALU_out<= #2 Ex_Mem_ALU_out;
    Load:
        Mem_Wb_Ldr<= #2 Mem[Ex_Mem_ALU_out];
    Store:
        if(Taken_branch==0)
            Mem[Ex_Mem_ALU_out]<= #2 Ex_Mem_B;    
    endcase 
    end
end

//Write back
always @(posedge clk1)begin
    if(Taken_branch==0)begin
    case(Mem_Wb_type)
    RR_t: reg_bank[Mem_Wb_Ir[15:11]]<= #2 Mem_Wb_ALU_out;
    RM_t: reg_bank[Mem_Wb_Ir[20:16]]<= #2 Mem_Wb_ALU_out;
    Load: reg_bank[Mem_Wb_Ir[20:16]]<= #2 Mem_Wb_Ldr;
    Halt: Halted<= #2 1'b1;
    endcase
    end
end
endmodule