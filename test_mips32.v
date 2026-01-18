  module test_mips32;
  reg clk1, clk2;
  integer k;
  mips32 mips (clk1, clk2);
  initial
  begin
    clk1 = 0;
    clk2 = 0;
    repeat (20) // Generating two-phase clock
    begin
      #5 clk1 = 1;
      #5 clk1 = 0;
      #5 clk2 = 1;
      #5 clk2 = 0;
    end
  end
  initial
  begin
    for (k=0; k<31; k=k+1)
      mips.reg_bank[k] = k;
    mips.Mem[0] = 32'h10010005; // ADDI R1,R0,5
    mips.Mem[1] = 32'h10020005; // ADDI R2,R0,5
    mips.Mem[2] = 32'h24e73800; // OR R7,R7,R7 -- dummy instr.
    mips.Mem[3] = 32'h24e73800; // OR R7,R7,R7 -- dummy instr.
    mips.Mem[4] = 32'h00221800; // ADD R3,R1,R2
    mips.Mem[5] = 32'hfc000000; // HLT
    mips.Halted = 0;
    mips.pc = 0;
    mips.Taken_branch = 0;
    #280
     for (k=0; k<4; k=k+1)
       $display ("R%1d - %2d", k, mips.reg_bank[k]);
  end
endmodule