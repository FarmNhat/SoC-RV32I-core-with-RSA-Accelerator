`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31
`define OPCODE_SIZE 6


`include "cla.v" 
`include "wishbone.v" 

module RegFile (
    input          [        4:0] rd,
    input          [`REG_SIZE:0] rd_data,
    input          [        4:0] rs1,
    output reg     [`REG_SIZE:0] rs1_data,
    input          [        4:0] rs2,
    output reg     [`REG_SIZE:0] rs2_data,
    input                        clk,
    input                        we,
    input                        rst
);
  localparam NumRegs = 32;
  reg [`REG_SIZE:0] regs[0:NumRegs-1];

  integer i;
  
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 32; i = i + 1) begin
        regs[i] <= 32'd0;
      end
    end else begin
      if (we && (rd != 5'd0)) begin
        regs[rd] <= rd_data;
      end
    end
  end

  always @(*) begin
    rs1_data = regs[rs1];
    rs2_data = regs[rs2];
  end
endmodule

// ============================================================================
// 4. DATAPATH SINGLE CYCLE
// ============================================================================
module DatapathSingleCycle (
    input                        clk,
    input                        rst,
    output reg                   halt,
    output        [`REG_SIZE:0]  pc_to_imem,
    input         [`REG_SIZE:0]  inst_from_imem,
    output reg    [`REG_SIZE:0]  addr_to_dmem,
    input         [`REG_SIZE:0]  load_data_from_dmem,
    output reg    [`REG_SIZE:0]  store_data_to_dmem,
    output reg    [        3:0]  store_we_to_dmem,

    output reg rsa_en,
    output reg mem_en
);

  // components of the instruction
  wire [          6:0] inst_funct7;
  wire [          4:0] inst_rs2;
  wire [          4:0] inst_rs1;
  wire [          2:0] inst_funct3;
  wire [          4:0] inst_rd;
  wire [`OPCODE_SIZE:0] inst_opcode;

  assign {inst_funct7, inst_rs2, inst_rs1, inst_funct3, inst_rd, inst_opcode} = inst_from_imem;

  // --- Immediate Generation ---
  wire [11:0] imm_i = inst_from_imem[31:20];
  wire [ 4:0] imm_shamt = inst_from_imem[24:20];
  wire [11:0] imm_s = {inst_funct7, inst_rd};
  wire [12:0] imm_b;
  assign {imm_b[12], imm_b[10:1], imm_b[11], imm_b[0]} = {inst_funct7, inst_rd, 1'b0};
  wire [20:0] imm_j;
  assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {inst_from_imem[31:12], 1'b0};

  wire [`REG_SIZE:0] imm_i_sext = {{20{imm_i[11]}}, imm_i[11:0]};
  wire [`REG_SIZE:0] imm_s_sext = {{20{imm_s[11]}}, imm_s[11:0]};
  wire [`REG_SIZE:0] imm_b_sext = {{19{imm_b[12]}}, imm_b[12:0]};
  wire [`REG_SIZE:0] imm_j_sext = {{11{imm_j[20]}}, imm_j[20:0]};

  // --- Opcodes ---
  localparam [`OPCODE_SIZE:0] OpLoad    = 7'b00_000_11;
  localparam [`OPCODE_SIZE:0] OpStore   = 7'b01_000_11;
  localparam [`OPCODE_SIZE:0] OpBranch  = 7'b11_000_11;
  localparam [`OPCODE_SIZE:0] OpJalr    = 7'b11_001_11;
  localparam [`OPCODE_SIZE:0] OpMiscMem = 7'b00_011_11;
  localparam [`OPCODE_SIZE:0] OpJal     = 7'b11_011_11;
  localparam [`OPCODE_SIZE:0] OpRegImm  = 7'b00_100_11;
  localparam [`OPCODE_SIZE:0] OpRegReg  = 7'b01_100_11;
  localparam [`OPCODE_SIZE:0] OpEnviron = 7'b11_100_11;
  localparam [`OPCODE_SIZE:0] OpAuipc   = 7'b00_101_11;
  localparam [`OPCODE_SIZE:0] OpLui     = 7'b01_101_11;

  // --- PC Logic ---
  reg [`REG_SIZE:0] pcNext, pcCurrent;
  always @(posedge clk) begin
    if (rst) begin
      pcCurrent <= 32'd0;
    end else begin
      pcCurrent <= pcNext;
    end
  end
  assign pc_to_imem = pcCurrent;

  // --- RegFile & Internal Signals ---
  reg regfile_we;
  reg [`REG_SIZE:0] wb_data;
  reg take_branch;
  reg illegal_inst;

  wire [`REG_SIZE:0] rs1_data;
  wire [`REG_SIZE:0] rs2_data;

  RegFile rf (
    .clk      (clk),
    .rst      (rst),
    .we       (regfile_we),
    .rd       (inst_rd),
    .rd_data  (wb_data),
    .rs1      (inst_rs1),
    .rs2      (inst_rs2),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data)
  );

  // --- CLA Integration (ADD/SUB) ---
  wire [31:0] cla_result;
  cla alu_adder (
        .a   (rs1_data),
        .b   (~rs2_data), // Mặc định wiring cho phép trừ hoặc so sánh, logic case sẽ quyết định dùng hay không
        .cin (1'b1),
        .sum (cla_result)
  );

  // ==========================================================================
  // LOGIC T�?CH HỢP MODULE DIVIDER
  // ==========================================================================
  
  // 1. Xác định loại phép chia (Có dấu hay Không dấu)
  // Trong R-type M-extension: 
  // DIV (100) / REM (110) -> Signed
  // DIVU (101) / REMU (111) -> Unsigned
  // Bit 0 của funct3 quyết định dấu (0: Signed, 1: Unsigned)
  wire is_div_instruction = (inst_opcode == OpRegReg) && (inst_funct7 == 7'b0000001);
  wire div_is_signed      = is_div_instruction && (~inst_funct3[0]); 

  // 2. Chuẩn bị dữ liệu đầu vào (Lấy trị tuyệt đối nếu là phép chia có dấu)
  wire op1_is_neg = div_is_signed && rs1_data[31];
  wire op2_is_neg = div_is_signed && rs2_data[31];

  wire [31:0] div_in_a = (op1_is_neg) ? -rs1_data : rs1_data;
  wire [31:0] div_in_b = (op2_is_neg) ? -rs2_data : rs2_data;

  wire [31:0] div_out_q_raw;
  wire [31:0] div_out_r_raw;

  // 3. G�?i Module DIV
  div divider_inst (
      .a(div_in_a),
      .b(div_in_b),
      .q(div_out_q_raw),
      .r(div_out_r_raw)
  );

  // 4. Xử lý kết quả đầu ra (�?ổi dấu lại nếu cần)
  // Quy tắc RISC-V:
  // Quotient:  Dấu = Sign(A) XOR Sign(B)
  // Remainder: Dấu = Sign(A)
  wire [31:0] div_final_q = ((op1_is_neg ^ op2_is_neg)) ? -div_out_q_raw : div_out_q_raw;
  wire [31:0] div_final_r = (op1_is_neg)                ? -div_out_r_raw : div_out_r_raw;

  // ==========================================================================

  // --- Main Control / Datapath Logic ---
  always @(*) begin
    illegal_inst       = 1'b0;
    regfile_we         = 1'b0;
    wb_data            = 32'd0;
    addr_to_dmem       = 32'd0;
    store_data_to_dmem = 32'd0;
    store_we_to_dmem   = 4'b0000;
    halt               = 1'b0;
    take_branch        = 1'b0;
    pcNext             = pcCurrent + 4;

    case (inst_opcode)
      OpLui: begin
        regfile_we = 1'b1;
        wb_data    = {inst_from_imem[31:12], 12'd0};
      end
      
      OpAuipc: begin
         regfile_we = 1'b1;
         wb_data    = pcCurrent + {inst_from_imem[31:12], 12'd0};
      end

      OpJal: begin
        regfile_we = 1'b1;
        pcNext     = pcCurrent + imm_j_sext;
        wb_data    = pcCurrent + 4;
      end

      OpJalr: begin
        regfile_we = 1'b1;
        pcNext     = (rs1_data + imm_i_sext) & ~32'd1;
        wb_data    = pcCurrent + 4;
      end

      OpBranch: begin
        case (inst_funct3)
          3'b000: take_branch = (rs1_data == rs2_data); // BEQ
          3'b001: take_branch = (rs1_data != rs2_data); // BNE
          3'b100: take_branch = ($signed(rs1_data) < $signed(rs2_data)); // BLT
          3'b101: take_branch = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
          3'b110: take_branch = (rs1_data < rs2_data); // BLTU
          3'b111: take_branch = (rs1_data >= rs2_data); // BGEU
          default: illegal_inst = 1'b1;
        endcase

        if(take_branch) begin
          pcNext = pcCurrent + imm_b_sext;
        end
      end

      OpLoad: begin
        regfile_we   = 1'b1;
        addr_to_dmem = rs1_data + imm_i_sext;
        
        if(addr_to_dmem[19:16] != 4'h4) rsa_en = 1'b1;
        else rsa_en = 1'b0;

        case (inst_funct3)
          3'b000: wb_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]}; // LB
          3'b001: wb_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]}; // LH
          3'b010: begin 
            wb_data = load_data_from_dmem; // LW
            
          end
          3'b100: wb_data = {24'b0, load_data_from_dmem[7:0]}; // LBU
          3'b101: wb_data = {16'b0, load_data_from_dmem[15:0]}; // LHU
          default: illegal_inst = 1'b1;
        endcase
      end
      
      OpStore: begin
        addr_to_dmem = rs1_data + imm_s_sext;

        if(addr_to_dmem[19:16] != 4'h4) rsa_en = 1'b1;
        else rsa_en = 1'b0;

        case (inst_funct3)
          3'b000: begin // SB
            store_data_to_dmem = {4{rs2_data[7:0]}};
            store_we_to_dmem   = 4'b0001;
          end
          3'b001: begin // SH
            store_data_to_dmem = {2{rs2_data[15:0]}};
            store_we_to_dmem   = 4'b0011;
          end
          3'b010: begin // SW
            store_data_to_dmem = rs2_data;
            store_we_to_dmem   = 4'b1111;
          end
          default: illegal_inst = 1'b1;
        endcase
      end

      OpRegImm: begin
        regfile_we = 1'b1;
        case (inst_funct3)
          3'b000: wb_data = rs1_data + imm_i_sext; // ADDI
          3'b010: wb_data = ($signed(rs1_data) < $signed(imm_i_sext)) ? 32'd1 : 32'd0; // SLTI
          3'b011: wb_data = (rs1_data < imm_i_sext) ? 32'd1 : 32'd0; // SLTIU
          3'b100: wb_data = rs1_data ^ imm_i_sext; // XORI
          3'b110: wb_data = rs1_data | imm_i_sext; // ORI
          3'b111: wb_data = rs1_data & imm_i_sext; // ANDI
          3'b001: begin // SLLI
            if(inst_funct7 == 7'd0) wb_data = rs1_data << imm_shamt;
          end
          3'b101: begin 
            if(inst_funct7 == 7'd0)        wb_data = rs1_data >> imm_shamt; // SRLI
            else if(inst_funct7[5] == 1'b1) wb_data = $signed(rs1_data) >>> imm_shamt; // SRAI
          end
          default: illegal_inst = 1'b1;
        endcase
      end
      
      OpRegReg: begin
        regfile_we = 1'b1;
        case (inst_funct3)
          3'b000: begin 
            if(inst_funct7 == 7'd0)        wb_data = rs1_data + rs2_data; // ADD
            else if(inst_funct7 == 7'b0100000) wb_data = rs1_data - rs2_data; // SUB
            //else if(inst_funct7 == 7'd1)   wb_data = rs1_data * rs2_data; // MUL
          end
          3'b001: begin 
            //if(inst_funct7 == 7'd1) wb_data = (rs1_data * rs2_data) >> 32; // MULH
            else                    wb_data = rs1_data << rs2_data[4:0];   // SLL
          end
          3'b010: begin 
            i//f (inst_funct7 == 7'd1) wb_data = ($signed(rs1_data) * $signed(rs2_data)) >> 32; // MULHSU
            else                     wb_data = ($signed(rs1_data) < $signed(rs2_data)) ? 32'd1 : 32'd0; // SLT
          end
          3'b011: begin 
            //if(inst_funct7 == 7'd1) wb_data = ($signed(rs1_data) * rs2_data) >> 32; // MULHU
            else                    wb_data = (rs1_data < rs2_data) ? 32'd1 : 32'd0; // SLTU
          end
          
          // --- UPDATED DIV/REM LOGIC ---
          3'b100: begin 
            //if(inst_funct7 == 7'd1) wb_data = div_final_q; // DIV
            else                    wb_data = rs1_data ^ rs2_data; // XOR
          end
          3'b101: begin 
            if(inst_funct7 == 7'd0)        wb_data = rs1_data >> rs2_data[4:0]; // SRL
            else if(inst_funct7 == 7'b0100000) wb_data = $signed(rs1_data) >>> rs2_data[4:0]; // SRA
            //else if(inst_funct7 == 7'd1)   wb_data = div_final_q; // DIVU
          end
          3'b110: begin 
            //if(inst_funct7 == 7'd1) wb_data = div_final_r; // REM
            else                    wb_data = rs1_data | rs2_data; // OR
          end
          3'b111: begin 
            //if(inst_funct7 == 7'd1) wb_data = div_final_r; // REMU
            else                    wb_data = rs1_data & rs2_data; // AND
          end
          // -----------------------------
          
          default: illegal_inst = 1'b1;
        endcase
      end

      OpEnviron: begin
        if (inst_opcode == 7'h73) begin
           halt = 1'b1;
        end
      end

      OpMiscMem: begin
        // FENCE - No Op in single cycle
      end

      default: begin
        illegal_inst = 1'b1;
      end
    endcase
  end

endmodule

// ============================================================================
// 5. PROCESSOR TOP LEVEL
// ============================================================================
module Processor (
    input  clock_proc,
    input  clock_mem,
    input  rst,
    output halt
);

  wire [`REG_SIZE:0] pc_to_imem, inst_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [        3:0] mem_data_we;
  wire rsa_en, mem_en;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
    .mem_en              (mem_en),
    .rst                 (rst),
    .clock_mem           (clock_mem),
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  wb_rsa #(
      .WIDTH(32), .E_BITS(32)
  ) rsa_bus (
    .clk          (clock_mem),
    .rst          (rst),
    .wb_adr_i     (mem_data_addr),
    .wb_dat_i     (mem_data_to_write),
    .wb_dat_o     (mem_data_loaded_value),
    .wb_we_i      (|mem_data_we),
    .rsa_en       (rsa_en),
    .wb_ack_o     ()
  );

  InstMemory imem (
    .rst            (rst),
    .clock_mem      (clock_mem),
    .pc_to_imem     (pc_to_imem),
    .inst_from_imem (inst_from_imem)
  );

  DatapathSingleCycle datapath (
    .clk                 (clock_proc),
    .rst                 (rst),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we),
    .load_data_from_dmem (mem_data_loaded_value),
    .halt                (halt),
    .rsa_en              (rsa_en),
    .mem_en              (mem_en)
  );



endmodule

// ============================================================================
// 6. INSTRUCTION  MEMORY
// ============================================================================

module InstMemory (
    input                    rst,
    input                    clock_mem,
    input      [`REG_SIZE:0] pc_to_imem,
    output reg [`REG_SIZE:0] inst_from_imem,
);

  reg [`REG_SIZE:0] imem_array[0:511];

  initial begin
    $readmemh("inst_mem.hex", imem_array);
  end

  localparam AddrMsb = $clog2(512) + 1;
  localparam AddrLsb = 2;

  always @(posedge clock_mem) begin
    inst_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
  end

endmodule

// ============================================================================
// 7. MEMORY
// ============================================================================
module MemorySingleCycle #(
    parameter NUM_WORDS = 512
) (
    input                    mem_en,
    input                    rst,
    input                    clock_mem,
    input      [`REG_SIZE:0] addr_to_dmem,
    input      [`REG_SIZE:0] store_data_to_dmem,
    input      [        3:0] store_we_to_dmem
    output reg [`REG_SIZE:0] load_data_from_dmem,
);

  reg [`REG_SIZE:0] mem_array[0:NUM_WORDS-1];

  // initial begin
  //   $readmemh("mem_initial_contents.hex", mem_array);
  // end

  localparam AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam AddrLsb = 2;


  always @(negedge clock_mem) begin
    if (store_we_to_dmem[0]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0]   <= store_data_to_dmem[7:0];
    if (store_we_to_dmem[1]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8]  <= store_data_to_dmem[15:8];
    if (store_we_to_dmem[2]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
    if (store_we_to_dmem[3]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
    
    load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    
  end
endmodule