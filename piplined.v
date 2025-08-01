`timescale 1ns / 1ps







module partial_sorter_general #(
    parameter N = 5,
    parameter M = 3,
    parameter sortdir = 0
) (
    input clk,
    input rst,
    input input_valid,
    input  signed [(2**N)*16-1:0] in_data_raw,
    output reg signed [(2**M)*16-1:0] out_data_reg,
    output reg output_valid
);

    reg signed [15:0] in_data_reg [0:(2**N)-1];
    reg input_valid_reg;
    genvar i_psg_loop;
    // Register management using genvar and always blocks
    generate
        for (i_psg_loop = 0; i_psg_loop < (2**N); i_psg_loop = i_psg_loop + 1) begin : gen_input_reg
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    in_data_reg[i_psg_loop] <= 16'sh0;
                end else if (input_valid) begin
                    in_data_reg[i_psg_loop] <= in_data_raw[(i_psg_loop*16) +: 16];
                end
            end
        end
    endgenerate

    // Handle input_valid_reg separately
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            input_valid_reg <= 1'b0;
        end else begin
            input_valid_reg <= input_valid;
        end
    end

    wire signed [(2**N)*16-1:0] in_data_assembled;
    genvar assemble_i_gen;
    generate
        for (assemble_i_gen = 0; assemble_i_gen < (2**N); assemble_i_gen = assemble_i_gen + 1) begin : assemble_input
            assign in_data_assembled[(assemble_i_gen*16) +: 16] = in_data_reg[assemble_i_gen];
        end
    endgenerate

    localparam num_in = 2**N;
    localparam out_size = 2**M; 

    localparam S1_INPUT_AND_VALID_REG_LATENCY_CALC = 1;
    localparam M_MINUS_1_CALC = (M < 1) ? 0 : (M - 1);
    localparam BITONIC_STAGES_1_TO_M_MINUS_1_LATENCY_COMP = (M_MINUS_1_CALC * (M_MINUS_1_CALC + 1)) / 2;
    localparam K_FOR_BMK_STAGE_M_CALC = (M < 1) ? 1 : (1 << M);
    localparam L_BMK_INTERNAL_STAGE_M_CALC = (M < 1 || K_FOR_BMK_STAGE_M_CALC <= 2) ? 0 : ($clog2(K_FOR_BMK_STAGE_M_CALC) - 1);
    localparam BITONIC_STAGE_M_LATENCY_COMP = L_BMK_INTERNAL_STAGE_M_CALC;
    localparam MAX_TREE_INPUT_REG_LATENCY_COMP = (N > M && M>=0) ? 1 : 0;
    localparam NUM_MAX_TREE_LEVELS_CALC = (N > M) ? (N - M) : 0;
    localparam K_FOR_MAXBM_UNIT_CALC = (M < 0) ? 1: (1 << M);
    localparam L_BMK_INTERNAL_FOR_MAXBM_CALC = (K_FOR_MAXBM_UNIT_CALC <= 2) ? 0 : ($clog2(K_FOR_MAXBM_UNIT_CALC) - 1);
    localparam L_MAXBM_INTERNAL_CALC = 1 + L_BMK_INTERNAL_FOR_MAXBM_CALC;
    localparam NUM_REPEATING_MAX_TREE_STAGES_CALC = (NUM_MAX_TREE_LEVELS_CALC >= 2) ? (NUM_MAX_TREE_LEVELS_CALC - 1) : 0;
    localparam REPEATING_MAX_TREE_LATENCY_COMP = NUM_REPEATING_MAX_TREE_STAGES_CALC * (L_MAXBM_INTERNAL_CALC + 1);
    localparam LAST_MAX_TREE_UNIT_LATENCY_COMP = (NUM_MAX_TREE_LEVELS_CALC >= 1) ? L_MAXBM_INTERNAL_CALC : 0;
    localparam FINAL_OUTPUT_REG_LATENCY_COMP = 1;
    localparam data_path_pipeline_stages = BITONIC_STAGES_1_TO_M_MINUS_1_LATENCY_COMP +
                                     BITONIC_STAGE_M_LATENCY_COMP +
                                     MAX_TREE_INPUT_REG_LATENCY_COMP +
                                     REPEATING_MAX_TREE_LATENCY_COMP +
                                     LAST_MAX_TREE_UNIT_LATENCY_COMP +
                                     FINAL_OUTPUT_REG_LATENCY_COMP;
    // total_pipeline_stages is the value used by your DUT for shift reg length
    localparam total_pipeline_stages = data_path_pipeline_stages; // Value is 15 for N=5,M=3

    localparam VALID_SHIFT_REG_ACTUAL_LEN = (total_pipeline_stages > 0) ? total_pipeline_stages : 1;
    reg [VALID_SHIFT_REG_ACTUAL_LEN-1:0] valid_shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) 
            valid_shift_reg <= {(VALID_SHIFT_REG_ACTUAL_LEN){1'b0}};
        else if (VALID_SHIFT_REG_ACTUAL_LEN > 1) 
            valid_shift_reg <= {valid_shift_reg[VALID_SHIFT_REG_ACTUAL_LEN-2:0], input_valid_reg};
        else if (VALID_SHIFT_REG_ACTUAL_LEN == 1) 
            valid_shift_reg <= input_valid_reg;
    end

    wire signed [(num_in*16)-1:0] bm_stage_outputs [0:M];
    assign bm_stage_outputs[0] = in_data_assembled;

    genvar stage_dut, block_dut;
    generate
        for (stage_dut = 1; stage_dut <= M; stage_dut = stage_dut + 1) begin : bitonic_stages
            localparam blocks_dut = 2**(N-stage_dut);
            localparam block_size_dut = 1 << stage_dut;
            localparam bit_width_dut = block_size_dut * 16;
            wire signed [bit_width_dut-1:0] block_outputs_dut [0:blocks_dut-1];
            wire signed [(num_in*16)-1:0] stage_wire_dut;

            if (stage_dut < M) begin : intermediate_stage_reg
                reg signed [bit_width_dut-1:0] wide_stage_reg [0:blocks_dut-1];
                for (block_dut = 0; block_dut < blocks_dut; block_dut = block_dut + 1) begin : stage_blocks_intermed
                    localparam block_dir_dut = (block_dut % 2 == 0) ? sortdir : ~sortdir;
                    wire signed [bit_width_dut-1:0] block_in_dut;
                    assign block_in_dut = bm_stage_outputs[stage_dut-1][(block_dut*bit_width_dut) +: bit_width_dut];
                    BMK_unit #(.K(block_size_dut),.sortdir(block_dir_dut)) bm_unit (
                        .clk(clk), .rst(rst),
                        .in_data(block_in_dut), .out_data(block_outputs_dut[block_dut])
                    );
                end
                genvar block_idx_dut;
                for (block_idx_dut=0; block_idx_dut<blocks_dut; block_idx_dut=block_idx_dut+1) begin : reg_block_assign
                    always @(posedge clk or posedge rst) begin
                        if (rst) 
                            wide_stage_reg[block_idx_dut] <= {(bit_width_dut){1'sh0}};
                        else     
                            wide_stage_reg[block_idx_dut] <= block_outputs_dut[block_idx_dut];
                    end
                end
                
                genvar combine_block_dut_intermed;
                for(combine_block_dut_intermed=0; combine_block_dut_intermed<blocks_dut; combine_block_dut_intermed=combine_block_dut_intermed+1) begin : combine_blocks_intermed
                    assign stage_wire_dut[(combine_block_dut_intermed*bit_width_dut)+:bit_width_dut] = wide_stage_reg[combine_block_dut_intermed];
                end
                assign bm_stage_outputs[stage_dut] = stage_wire_dut;
            end else begin : final_stage_wire // stage_dut == M
                for (block_dut = 0; block_dut < blocks_dut; block_dut = block_dut + 1) begin : stage_blocks_final
                    localparam block_dir_dut = (block_dut % 2 == 0) ? sortdir : ~sortdir;
                    wire signed [bit_width_dut-1:0] block_in_dut;
                    assign block_in_dut = bm_stage_outputs[stage_dut-1][(block_dut*bit_width_dut) +: bit_width_dut];
                    BMK_unit #(.K(block_size_dut),.sortdir(block_dir_dut)) bm_unit (
                        .clk(clk), .rst(rst),
                        .in_data(block_in_dut), .out_data(block_outputs_dut[block_dut])
                    );
                end
                genvar combine_block_dut_final;
                for(combine_block_dut_final=0; combine_block_dut_final<blocks_dut; combine_block_dut_final=combine_block_dut_final+1) begin : combine_blocks_final
                    assign stage_wire_dut[(combine_block_dut_final*bit_width_dut)+:bit_width_dut] = block_outputs_dut[combine_block_dut_final];
                end
                assign bm_stage_outputs[stage_dut] = stage_wire_dut;
            end
        end
    endgenerate

    // Max Tree with Refined Input Registration
    localparam NUM_MAX_TREE_LEVELS = (N > M) ? (N - M) : 0;
    localparam MAX_TREE_NUM_INITIAL_SEQS = (N >= M && M >= 0) ? (1 << (N - M)) : 1; // Number of 2**M sequences from bitonic stage M
    localparam MAX_TREE_SEQ_WIDTH = out_size * 16;

    // Wires for inputs and outputs of max tree levels
    wire signed [MAX_TREE_SEQ_WIDTH-1:0] max_tree_level_input_data [0:NUM_MAX_TREE_LEVELS_CALC][0:MAX_TREE_NUM_INITIAL_SEQS-1];
    reg signed [MAX_TREE_SEQ_WIDTH-1:0] max_tree_inputs_registered [0:MAX_TREE_NUM_INITIAL_SEQS-1];

    genvar seq_init_gen;
    generate
        if (N >= M && M >= 0) begin
            for (seq_init_gen = 0; seq_init_gen < MAX_TREE_NUM_INITIAL_SEQS; seq_init_gen = seq_init_gen + 1) begin : init_max_tree_level0_input
                assign max_tree_level_input_data[0][seq_init_gen] = bm_stage_outputs[M][(seq_init_gen*MAX_TREE_SEQ_WIDTH) +: MAX_TREE_SEQ_WIDTH];
            end
        end
    endgenerate

    // Register the inputs to the first layer of maxBMnby2 if max tree exists
    // This is MAX_TREE_INPUT_REG_LATENCY_COMP
    genvar mt_l0_reg_idx;
    generate
        if (N > M && M >= 0) begin
            for (mt_l0_reg_idx = 0; mt_l0_reg_idx < MAX_TREE_NUM_INITIAL_SEQS; mt_l0_reg_idx = mt_l0_reg_idx + 1) begin : reg_max_tree_inputs
                always @(posedge clk or posedge rst) begin
                    if (rst)
                        max_tree_inputs_registered[mt_l0_reg_idx] <= {(MAX_TREE_SEQ_WIDTH){1'sh0}};
                    else
                        max_tree_inputs_registered[mt_l0_reg_idx] <= max_tree_level_input_data[0][mt_l0_reg_idx];
                end
            end
        end
    endgenerate

    wire signed [MAX_TREE_SEQ_WIDTH-1:0] original_max_tree_wire [0:NUM_MAX_TREE_LEVELS_CALC][0:MAX_TREE_NUM_INITIAL_SEQS-1];
    reg  signed [MAX_TREE_SEQ_WIDTH-1:0] original_max_tree_reg  [0:NUM_MAX_TREE_LEVELS_CALC-1][0:(MAX_TREE_NUM_INITIAL_SEQS/2)-1]; // Indexing for outputs of levels

    genvar seq_orig_gen;
    generate
      if (M >= 0 && N >= M) begin
        for (seq_orig_gen = 0; seq_orig_gen < MAX_TREE_NUM_INITIAL_SEQS; seq_orig_gen = seq_orig_gen + 1) begin : init_max_tree_orig
            assign original_max_tree_wire[0][seq_orig_gen] = bm_stage_outputs[M][(seq_orig_gen*MAX_TREE_SEQ_WIDTH) +: MAX_TREE_SEQ_WIDTH];
        end
      end
    endgenerate

    genvar level_mt_gen, pair_mt_gen;
    generate
      if (M>=0 && N > M) begin // Max tree processing only if N > M
        for (level_mt_gen = 0; level_mt_gen < NUM_MAX_TREE_LEVELS_CALC; level_mt_gen = level_mt_gen + 1) begin : max_tree_level_refined
            localparam CURRENT_NUM_SEQS = (N-M-level_mt_gen >=0) ? (1 << (N-M-level_mt_gen)) : 0;
            localparam CURRENT_NUM_PAIRS = CURRENT_NUM_SEQS / 2;
            wire signed [MAX_TREE_SEQ_WIDTH-1:0] current_level_outputs_w [0:CURRENT_NUM_PAIRS-1];

            if (CURRENT_NUM_PAIRS > 0) begin
                for (pair_mt_gen = 0; pair_mt_gen < CURRENT_NUM_PAIRS; pair_mt_gen = pair_mt_gen + 1) begin : process_pair_refined
                    localparam pair_dir_refined = (level_mt_gen == NUM_MAX_TREE_LEVELS_CALC-1) ? sortdir :
                                                 ((pair_mt_gen % 2) == 0) ? 0 : 1;
                    wire signed [MAX_TREE_SEQ_WIDTH-1:0] in_a_refined, in_b_refined;

                    if (level_mt_gen == 0) begin // Inputs from registered bm_stage_outputs[M]
                        assign in_a_refined = max_tree_inputs_registered[pair_mt_gen*2];
                        assign in_b_refined = max_tree_inputs_registered[pair_mt_gen*2+1];
                    end else begin // Inputs from previous max tree level's output registers
                        assign in_a_refined = original_max_tree_reg[level_mt_gen-1][pair_mt_gen*2]; // original_max_tree_reg[l-1] holds output of maxBMs at proc level l-1
                        assign in_b_refined = original_max_tree_reg[level_mt_gen-1][pair_mt_gen*2+1];
                    end

                    maxBMnby2 #(.K(out_size), .sortdir(pair_dir_refined)) pair_maxBM_inst (
                        .clk(clk), .rst(rst),
                        .asc_in(in_a_refined), .desc_in(in_b_refined), .out_data(current_level_outputs_w[pair_mt_gen])
                    );
                end

                // Connect outputs to next stage's input wires OR final output wire
                genvar pair_out_connect_idx;
                for (pair_out_connect_idx=0; pair_out_connect_idx < CURRENT_NUM_PAIRS; pair_out_connect_idx=pair_out_connect_idx+1) begin : connect_outputs
                    assign original_max_tree_wire[level_mt_gen+1][pair_out_connect_idx] = current_level_outputs_w[pair_out_connect_idx];
                end

                // Register outputs if not the last max tree processing level
                if (level_mt_gen < NUM_MAX_TREE_LEVELS_CALC - 1) begin
                    genvar reg_idx_mt;
                    // Number of elements to register is CURRENT_NUM_PAIRS
                    for (reg_idx_mt=0; reg_idx_mt < CURRENT_NUM_PAIRS; reg_idx_mt=reg_idx_mt+1) begin : reg_outputs
                        always @(posedge clk or posedge rst) begin
                            if (rst) 
                                original_max_tree_reg[level_mt_gen][reg_idx_mt] <= {(MAX_TREE_SEQ_WIDTH){1'sh0}};
                            else     
                                original_max_tree_reg[level_mt_gen][reg_idx_mt] <= current_level_outputs_w[reg_idx_mt];
                        end
                    end
                end
            end
        end
      end
    endgenerate

    wire signed [(out_size*16)-1:0] final_out_data_wire;
    assign final_out_data_wire = (NUM_MAX_TREE_LEVELS_CALC > 0 && N > M && M>=0) ? original_max_tree_wire[NUM_MAX_TREE_LEVELS_CALC][0] :
                                 ( (N == M && M>=0) ? bm_stage_outputs[M] : // This will be registered by out_data_reg
                                   {(out_size*16){1'sh0}} );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_data_reg <= {(out_size*16){1'sh0}};
            output_valid <= 1'b0;
        end else begin
            out_data_reg <= final_out_data_wire; // Final registration stage

            if (total_pipeline_stages > 0) 
                output_valid <= valid_shift_reg[VALID_SHIFT_REG_ACTUAL_LEN-1];
            else
                output_valid <= input_valid_reg;
        end
    end
endmodule