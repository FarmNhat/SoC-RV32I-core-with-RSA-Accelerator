// ============================================================================
// PROCESSOR TOP LEVEL
// ============================================================================

`include "wishbone.v" 
`include "RV32I_core.v"

module Processor (
    input  clock_proc,
    input  clock_mem,
    input  rst,
    output halt
);

  wire [`REG_SIZE:0] pc_to_imem, inst_from_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [        3:0] mem_data_we;
  wire rsa_en, mem_en, ack_from_rsa;

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
    .wb_ack_o     (ack_from_rsa)
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
    .ack_from_rsa        (ack_from_rsa),
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
    output reg [`REG_SIZE:0] inst_from_imem
);

  reg [`REG_SIZE:0] imem_array[0:511];

  initial begin
    $readmemh("inst_mem.hex", imem_array);
  end

  localparam AddrMsb = $clog2(512) + 1;
  localparam AddrLsb = 2;

  always @(posedge clock_mem) begin
    inst_from_imem <= imem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
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
    input      [        3:0] store_we_to_dmem,
    output reg [`REG_SIZE:0] load_data_from_dmem
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