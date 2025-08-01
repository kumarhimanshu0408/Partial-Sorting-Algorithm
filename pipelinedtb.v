`timescale 1ns / 1ps



module tb_partial_sorter_1024_to_512_parametric_wait;

    localparam N_PARAM = 10;
    localparam M_PARAM = 9;
    localparam SORTDIR_PARAM = 1;

    localparam CLK_PERIOD_TB = 10;
    localparam NUM_TOTAL_INPUTS_TB = 1 << N_PARAM;
    localparam NUM_TOTAL_OUTPUTS_TB = 1 << M_PARAM;
    localparam INPUT_BUS_WIDTH_TB = NUM_TOTAL_INPUTS_TB * 16;
    localparam OUTPUT_BUS_WIDTH_TB = NUM_TOTAL_OUTPUTS_TB * 16;

    reg clk_tb;
    reg rst_tb;
    reg input_valid_tb;
    reg signed [INPUT_BUS_WIDTH_TB-1:0] in_data_raw_tb;
    wire signed [OUTPUT_BUS_WIDTH_TB-1:0] out_data_reg_tb;
    wire output_valid_tb;

    reg signed [15:0] all_inputs_tb[0:NUM_TOTAL_INPUTS_TB-1];
    reg signed [15:0] sorted_outputs_tb[0:NUM_TOTAL_OUTPUTS_TB-1];
    integer input_file_tb, output_file_tb, scan_status_tb, i_tb_loop;
    reg output_seen_high_tb; 
    integer cycle_count_tb_wait;    
    integer rst_time_marker_tb;     


    partial_sorter_general #(
        .N(N_PARAM),
        .M(M_PARAM),
        .sortdir(SORTDIR_PARAM)
    ) dut (
        .clk(clk_tb),
        .rst(rst_tb),
        .input_valid(input_valid_tb),
        .in_data_raw(in_data_raw_tb),
        .out_data_reg(out_data_reg_tb),
        .output_valid(output_valid_tb)
    );

    initial begin
        clk_tb = 0;
        forever #(CLK_PERIOD_TB/2) clk_tb = ~clk_tb;
    end

    
    localparam S1_INPUT_AND_VALID_REG_LATENCY_TB = 1;

    
    localparam M_MINUS_1_CALC_TB = (M_PARAM < 1) ? 0 : (M_PARAM - 1);
    localparam BITONIC_STAGES_1_TO_M_MINUS_1_LATENCY_TB = (M_MINUS_1_CALC_TB * (M_MINUS_1_CALC_TB + 1)) / 2;

    localparam K_FOR_BMK_STAGE_M_CALC_TB = (M_PARAM < 1) ? 1 : (1 << M_PARAM);
    localparam L_BMK_INTERNAL_STAGE_M_CALC_TB = (M_PARAM < 1 || K_FOR_BMK_STAGE_M_CALC_TB <= 2) ? 0 : ($clog2(K_FOR_BMK_STAGE_M_CALC_TB) - 1);
    localparam BITONIC_STAGE_M_LATENCY_TB = L_BMK_INTERNAL_STAGE_M_CALC_TB;

    localparam MAX_TREE_INPUT_REG_LATENCY_TB = (N_PARAM > M_PARAM && M_PARAM>=0) ? 1 : 0;

    localparam NUM_MAX_TREE_LEVELS_CALC_TB = (N_PARAM > M_PARAM) ? (N_PARAM - M_PARAM) : 0;
    localparam K_FOR_MAXBM_UNIT_CALC_TB = (M_PARAM < 0) ? 1: (1 << M_PARAM); 
    localparam L_BMK_INTERNAL_FOR_MAXBM_CALC_TB = (K_FOR_MAXBM_UNIT_CALC_TB <= 2) ? 0 : ($clog2(K_FOR_MAXBM_UNIT_CALC_TB) - 1);
    localparam L_MAXBM_INTERNAL_CALC_TB = 1 + L_BMK_INTERNAL_FOR_MAXBM_CALC_TB;

    localparam NUM_REPEATING_MAX_TREE_STAGES_CALC_TB = (NUM_MAX_TREE_LEVELS_CALC_TB >= 2) ? (NUM_MAX_TREE_LEVELS_CALC_TB - 1) : 0;
    localparam REPEATING_MAX_TREE_LATENCY_TB = NUM_REPEATING_MAX_TREE_STAGES_CALC_TB * (L_MAXBM_INTERNAL_CALC_TB + 1); // +1 for max_tree_reg[level+1]

    localparam LAST_MAX_TREE_UNIT_LATENCY_TB = (NUM_MAX_TREE_LEVELS_CALC_TB >= 1) ? L_MAXBM_INTERNAL_CALC_TB : 0;

    
    localparam FINAL_OUTPUT_REG_LATENCY_TB = 1;

   
    localparam DUT_INTERNAL_TOTAL_PIPELINE_STAGES_TB = BITONIC_STAGES_1_TO_M_MINUS_1_LATENCY_TB +
                                                   BITONIC_STAGE_M_LATENCY_TB +
                                                   MAX_TREE_INPUT_REG_LATENCY_TB +
                                                   REPEATING_MAX_TREE_LATENCY_TB +
                                                   LAST_MAX_TREE_UNIT_LATENCY_TB +
                                                   FINAL_OUTPUT_REG_LATENCY_TB;

    
    localparam EXPECTED_PIPELINE_CYCLES_TB = S1_INPUT_AND_VALID_REG_LATENCY_TB + DUT_INTERNAL_TOTAL_PIPELINE_STAGES_TB;

    localparam WAIT_CLOCKS_FOR_VALID_TB = EXPECTED_PIPELINE_CYCLES_TB + 5; 
   


    function real fixed_to_real_q_format_tb;
        input signed [15:0] fixed_value_tb;
        parameter integer FRACTIONAL_BITS = 6;
        begin
            fixed_to_real_q_format_tb = fixed_value_tb / (2.0**FRACTIONAL_BITS);
        end
    endfunction

    initial begin
     
        output_seen_high_tb = 0;
        cycle_count_tb_wait = 0; 

        $display("TB: Testbench for Pipelined Sorter Started (N=%0d, M=%0d, SortDir=%0d).",
                 N_PARAM, M_PARAM, SORTDIR_PARAM);
        $display("TB: DUT's 'total_pipeline_stages' (valid_shift_reg delay) expected by TB: %0d cycles.", DUT_INTERNAL_TOTAL_PIPELINE_STAGES_TB);
        $display("TB: Testbench's 'EXPECTED_PIPELINE_CYCLES_TB' (overall port-to-port latency): %0d cycles.", EXPECTED_PIPELINE_CYCLES_TB);


        rst_tb = 1;
        input_valid_tb = 0;
        in_data_raw_tb = {(INPUT_BUS_WIDTH_TB){1'b0}};

       
        input_file_tb = $fopen("C:/Users/vaibh/Desktop/122201016/sort2nto2m/sort2nto2m.srcs/sim_1/new/fixed_point_values.txt", "r");
        if (input_file_tb == 0) begin 
            $display("TB: WARNING - Could not open 'fixed_point_values.txt'. Generating default data."); 
            for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_INPUTS_TB; i_tb_loop = i_tb_loop + 1) 
                all_inputs_tb[i_tb_loop] = $signed(NUM_TOTAL_INPUTS_TB - 1 - i_tb_loop);
        end
        else begin 
            $display("TB: Reading %0d inputs from 'fixed_point_values.txt' (format: 16'hXXXX per line)...", NUM_TOTAL_INPUTS_TB); 
            for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_INPUTS_TB; i_tb_loop = i_tb_loop + 1) begin 
                scan_status_tb = $fscanf(input_file_tb, "16'h%h\n", all_inputs_tb[i_tb_loop]); 
                if (scan_status_tb != 1) begin
                    $display("TB: WARNING - EOF or read error at input index %d. Using 0 for remaining.", i_tb_loop); 
                    all_inputs_tb[i_tb_loop] = 16'h0000;
                end
            end 
            $fclose(input_file_tb); 
            $display("TB: Finished reading input file."); 
        end

        $display("TB: First 5 and last 5 input values being used (of %0d total):", NUM_TOTAL_INPUTS_TB); 
        for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_INPUTS_TB; i_tb_loop = i_tb_loop + 1) 
            if (i_tb_loop < 5 || i_tb_loop >= NUM_TOTAL_INPUTS_TB - 5) 
                $display("TB: Input[%4d] = %8d (0x%h)", i_tb_loop, all_inputs_tb[i_tb_loop], all_inputs_tb[i_tb_loop]);

        for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_INPUTS_TB; i_tb_loop = i_tb_loop + 1) 
            in_data_raw_tb[(i_tb_loop*16) +: 16] = all_inputs_tb[i_tb_loop];


        #(CLK_PERIOD_TB * 2);
        rst_tb = 0;
        rst_time_marker_tb = $time;
        $display("TB: Reset de-asserted at %0t ns.", rst_time_marker_tb);
        @(posedge clk_tb);

        $display("TB: Applying input_valid_tb pulse at time %0t ns.", $time);
        input_valid_tb = 1;
        @(posedge clk_tb);
        input_valid_tb = 0;
        $display("TB: input_valid_tb pulse ended. dut.input_valid_reg expected high. Time %0t ns.", $time);

        $display("TB: Waiting for output to become valid (expecting overall latency of %0d clocks / %0d ns)...",
                 EXPECTED_PIPELINE_CYCLES_TB, EXPECTED_PIPELINE_CYCLES_TB * CLK_PERIOD_TB);

        for (cycle_count_tb_wait = 0; cycle_count_tb_wait < WAIT_CLOCKS_FOR_VALID_TB; cycle_count_tb_wait = cycle_count_tb_wait + 1) begin
            @(posedge clk_tb);
            if (output_valid_tb) begin
                output_seen_high_tb = 1;
                $display("TB: output_valid_tb asserted at time %0t ns (TB cycle count %0d after rst deassertion + 1 + input pulse).",
                         $time, cycle_count_tb_wait + 1); 
                
                cycle_count_tb_wait = WAIT_CLOCKS_FOR_VALID_TB; 
            end
        end

        if (output_seen_high_tb) begin
            @(negedge clk_tb); 
            $display("TB: SUCCESS - output_valid_tb was observed HIGH.");
            
          
            for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_OUTPUTS_TB; i_tb_loop = i_tb_loop + 1) begin 
                sorted_outputs_tb[i_tb_loop] = out_data_reg_tb[(i_tb_loop*16) +: 16]; 
            end
            
            output_file_tb = $fopen("C:/Users/vaibh/Desktop/122201016/sort2nto2m/sort2nto2m.srcs/sim_1/new/sorted_output.txt", "w");
            if (output_file_tb == 0) begin 
                $display("TB: ERROR - Could not open 'sorted_output_1024_to_512.txt'."); 
            end
            else begin
                $fdisplay(output_file_tb, "Sorted Output (Top %0d elements):", NUM_TOTAL_OUTPUTS_TB);
                for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_OUTPUTS_TB; i_tb_loop = i_tb_loop + 1) begin
                    $fdisplay(output_file_tb, "Output[%3d] = %8d (Real: %f)", i_tb_loop, sorted_outputs_tb[i_tb_loop], fixed_to_real_q_format_tb(sorted_outputs_tb[i_tb_loop]));
                end
                $fclose(output_file_tb); 
                $display("TB: Output data written to 'sorted_output_1024_to_512.txt'.");
            end
            
            $display("TB: First 5 and last 5 sorted outputs:");
            for (i_tb_loop = 0; i_tb_loop < NUM_TOTAL_OUTPUTS_TB; i_tb_loop = i_tb_loop + 1) begin
                if (i_tb_loop < 5 || i_tb_loop >= NUM_TOTAL_OUTPUTS_TB - 5) begin
                    $display("TB: OutputValue[%3d] = %8d (Real: %f)", i_tb_loop, sorted_outputs_tb[i_tb_loop], fixed_to_real_q_format_tb(sorted_outputs_tb[i_tb_loop]));
                end
            end
        end else begin
            $error("TB: FAILURE - output_valid_tb did NOT assert after waiting %0d clocks. Expected overall latency was %0d. Time: %0t ns.",
                   WAIT_CLOCKS_FOR_VALID_TB, EXPECTED_PIPELINE_CYCLES_TB, $time);
        end

        #(CLK_PERIOD_TB * 10);
        $display("TB: Testbench finished at time %0t ns.", $time);
        $finish;
    end

    initial begin
       
        $monitor("Time:%0t ns|RST=%b|VldIn=%b|DUT.VldReg=%b|VldOut=%b|DUT.InReg[0]=%d|Out[0]=%d|ExpOverallLat=%d|DUT.total_pipeline_stages=%d",
                 $time, rst_tb, input_valid_tb, dut.input_valid_reg, output_valid_tb,
                 (NUM_TOTAL_INPUTS_TB>0 ? $signed(dut.in_data_reg[0]) : 16'shxxxx),
                 (NUM_TOTAL_OUTPUTS_TB>0 ? $signed(out_data_reg_tb[15:0]) : 16'shxxxx),
                 EXPECTED_PIPELINE_CYCLES_TB, dut.total_pipeline_stages);
    end
endmodule