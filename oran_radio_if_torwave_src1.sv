QuestaSim-64 vlog 2020.3 Compiler 2020.07 Jul 12 2020
Start time: 11:12:27 on Aug 30,2021
vlog oran_radio_if_torwave_src.sv 
`timescale 1ps/1ps
//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
module torwave_sv #(

    parameter integer  C_S_AXI_ADDR_WIDTH = 16 ,
    parameter memory_word_depth           = 1024,
    parameter C_NUM_ETH               = 1,
    parameter integer clocks_for_10ms     = 4000000,
    parameter integer clocks_for_1ms      = 400000,
    parameter  count_init_for_sim         = 96460,
    parameter  start_to_offset_cycles     = 108608,
    parameter ps_per_clock                = 6400

  ) (

  output logic [C_NUM_ETH - 1:0][63:0] m_data_tdata    ,
  output logic [C_NUM_ETH - 1:0] [7:0] m_data_tkeep    ,
  output logic [C_NUM_ETH - 1:0]       m_data_tvalid   ,
  output logic [C_NUM_ETH - 1:0]       m_data_tlast    ,
  output logic [C_NUM_ETH - 1:0]       m_data_tuser    ,
  input  logic [C_NUM_ETH - 1:0]       m_data_tready   ,
  
  input  logic [C_NUM_ETH - 1:0][63:0] s_data_tdata    ,
  input  logic [C_NUM_ETH - 1:0] [7:0] s_data_tkeep    ,
  input  logic [C_NUM_ETH - 1:0]       s_data_tvalid   ,
  input  logic [C_NUM_ETH - 1:0]       s_data_tlast    ,
  input  logic [C_NUM_ETH - 1:0]       s_data_tuser    ,
  output logic [C_NUM_ETH - 1:0]       s_data_tready   ,

  output logic [C_NUM_ETH - 1:0][63:0] s_tieoff_tdata  ={C_NUM_ETH{64'd0}},
  output logic [C_NUM_ETH - 1:0] [7:0] s_tieoff_tkeep  ={C_NUM_ETH{8'd0}},
  output logic [C_NUM_ETH - 1:0]       s_tieoff_tvalid ={C_NUM_ETH{1'd0}},
  output logic [C_NUM_ETH - 1:0]       s_tieoff_tlast  ={C_NUM_ETH{1'd0}},
  output logic [C_NUM_ETH - 1:0]       s_tieoff_tuser  ={C_NUM_ETH{1'd0}},
  input  logic [C_NUM_ETH - 1:0]       s_tieoff_tready ,

  output logic                         radio_start_one_pps       ,
  output logic                         radio_start_10ms_stretch  ,
  output logic                         radio_start_10ms          ,
  output logic                         radio_offset_10ms_stretch ,
  output logic                         radio_offset_10ms         ,
                
  input  wire                          radio_start_10ms_toggle_in,
  output logic                         radio_start_10ms_retimed  =0,
                
  output reg    [7:0]                  dip_status                =0,
  output reg                           error_flag                =0,
                
  input  wire                          s_axis_aresetn            ,
  input  wire                          s_axis_aclk               ,
  input  wire                          s_axi_aclk                ,


  input                                  s_axi_aresetn  ,
  input       [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr   ,
  input                                  s_axi_awvalid  ,
  output                                 s_axi_awready  ,
  input       [31:0]                     s_axi_wdata    ,
  input                                  s_axi_wvalid   ,
  output                                 s_axi_wready   ,
  output      [1:0]                      s_axi_bresp    ,
  output                                 s_axi_bvalid   ,
  input                                  s_axi_bready   ,
  input       [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr   ,
  input                                  s_axi_arvalid  ,
  output                                 s_axi_arready  ,
  output      [31:0]                     s_axi_rdata    ,
  output      [1:0]                      s_axi_rresp    ,
  output                                 s_axi_rvalid   ,
  input                                  s_axi_rready   

);

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
localparam radio_counter_width    = 24;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
localparam integer  BANK_DECODE_HIGH_BIT           = 15;
localparam integer  BANK_DECODE_HIGH_LOW           = 12;
localparam integer  C_S_TIMEOUT_WIDTH              = 12;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
logic [15:0]                  radio_us_count;
logic [C_NUM_ETH-1:0][31:0]   dij_ram_locations         ;
logic [C_NUM_ETH-1:0][19:0]   dij_address_write_r       ;
logic [C_NUM_ETH-1:0][19:0]   dij_address_read_r        ;
logic [C_NUM_ETH-1:0][63:0]   dij_data_rd               ;

logic [19:0]                  sel_dij_address_write_r   ;
logic [19:0]                  sel_dij_address_read_r    ;
logic [63:0]                  sel_dij_data_rd           ;

logic [19:0]                  dij_address_write         ;
logic [19:0]                  dij_address_read          ;
logic [63:0]                  dij_data_wr               ;
logic                         dij_data_msby_wr_strb     ;
logic                         dij_data_msby_rd_strb     ;
logic                         djictl_start_when_ready   ;
logic                         djictl_reset_data_injector;
logic                         djictl_loop_enable        ;  
logic                         timeout_enable            ;
logic [C_S_TIMEOUT_WIDTH-1:0] timeout_value             ;


logic [C_NUM_ETH-1:0][19:0]   djictl_start_address       ;
logic [C_NUM_ETH-1:0][19:0]   djictl_end_address         ;
logic [C_NUM_ETH-1:0]         djictl_lane_enable         ;
logic [C_NUM_ETH-1:0][23:0]   djictl_offset_clocks       ;
logic [C_NUM_ETH-1:0][23:0]   djictl_offset_clocks_pdef  = {C_NUM_ETH{start_to_offset_cycles[23:0]}};

logic [7:0]                   dij_bank_select            ;

logic                         djictl_reset_data_sink     ; // 
logic                         djictl_trigger_capture     ; // 
logic                         djictl_sample_counters     ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_payload; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_ecpri  ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_1914_3 ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_cpu    ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_prach  ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_unsol  ; // 
logic [C_NUM_ETH-1:0][3:0]    djictl_sink_counter_select ; // 
logic [C_NUM_ETH-1:0][18:0]   djictl_sink_counter_ss     ; // 

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin
  sel_dij_address_write_r <= dij_address_write_r[dij_bank_select[1:0]];
  sel_dij_address_read_r  <= dij_address_read_r [dij_bank_select[1:0]];
  sel_dij_data_rd         <= dij_data_rd        [dij_bank_select[1:0]];
end

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------

torwave_regif #(

.C_NUM_ETH           (C_NUM_ETH           ),
.C_S_AXI_ADDR_WIDTH  (C_S_AXI_ADDR_WIDTH  ),
.BANK_DECODE_HIGH_BIT(BANK_DECODE_HIGH_BIT),
.BANK_DECODE_HIGH_LOW(BANK_DECODE_HIGH_LOW),
.C_S_TIMEOUT_WIDTH   (C_S_TIMEOUT_WIDTH   )
 
) reg_if (
 
   .timeout_enable              (timeout_enable              ),
   .timeout_value               (timeout_value               ),
   .gpio_cdc_dipstatus          (8'd0                        ),
   .dij_ram_locations           (dij_ram_locations[0]        ),
   .dij_address_write           (dij_address_write           ),
   .dij_address_write_r         (sel_dij_address_write_r     ), // Many to 1
   .dij_address_read            (dij_address_read            ),
   .dij_address_read_r          (sel_dij_address_read_r      ), // Many to 1
   .dij_bank_select             (dij_bank_select             ),
   .dij_data_wr_63_0            (dij_data_wr                 ),
   .dij_data_rd_63_0            (sel_dij_data_rd             ), // Many to 1
   .dij_data_msby_wr_strb       (dij_data_msby_wr_strb       ),
   .dij_data_msby_rd_strb       (dij_data_msby_rd_strb       ),
   .djictl_start_when_ready     (djictl_start_when_ready     ),
   .djictl_enable_10_ms         (djictl_enable_10_ms         ),
   .djictl_reset_data_injector  (djictl_reset_data_injector  ),
   .djictl_loop_enable          (djictl_loop_enable          ),
   
   .djictl_start_address        (djictl_start_address        ),
   .djictl_end_address          (djictl_end_address          ),
   .djictl_lane_enable          (djictl_lane_enable          ),
   .djictl_offset_clocks        (djictl_offset_clocks        ),
   .djictl_offset_clocks_pdef   (djictl_offset_clocks_pdef   ),


   .djictl_reset_data_sink      (djictl_reset_data_sink      ), 
   .djictl_trigger_capture      (djictl_trigger_capture      ), 
   .djictl_sample_counters      (djictl_sample_counters      ), 
   .djictl_sink_counter_payload (djictl_sink_counter_payload ), 
   .djictl_sink_counter_ecpri   (djictl_sink_counter_ecpri   ), 
   .djictl_sink_counter_1914_3  (djictl_sink_counter_1914_3  ), 
   .djictl_sink_counter_cpu     (djictl_sink_counter_cpu     ), 
   .djictl_sink_counter_prach   (djictl_sink_counter_prach   ), 
   .djictl_sink_counter_unsol   (djictl_sink_counter_unsol   ), 
   .djictl_sink_counter_select  (djictl_sink_counter_select  ), 
   .djictl_sink_counter_ss      (djictl_sink_counter_ss      ), 

   
   .data_clk                    (s_axis_aclk                 ),
   .data_resetn                 (s_axis_aresetn              ),
   .timeout_enable_in           (timeout_enable              ),
   .timeout_value_in            (timeout_value               ),
   .s_axi_aclk                  (s_axi_aclk                  ),
   .s_axi_aresetn               (s_axi_aresetn               ),
   .s_axi_awaddr                (s_axi_awaddr                ),
   .s_axi_awvalid               (s_axi_awvalid               ),
   .s_axi_awready               (s_axi_awready               ),
   .s_axi_wdata                 (s_axi_wdata                 ),
   .s_axi_wvalid                (s_axi_wvalid                ),
   .s_axi_wready                (s_axi_wready                ),
   .s_axi_bresp                 (s_axi_bresp                 ),
   .s_axi_bvalid                (s_axi_bvalid                ),
   .s_axi_bready                (s_axi_bready                ),
   .s_axi_araddr                (s_axi_araddr                ),
   .s_axi_arvalid               (s_axi_arvalid               ),
   .s_axi_arready               (s_axi_arready               ),
   .s_axi_rdata                 (s_axi_rdata                 ),
   .s_axi_rresp                 (s_axi_rresp                 ),
   .s_axi_rvalid                (s_axi_rvalid                ),
   .s_axi_rready                (s_axi_rready                )

);

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
radio_start_gen23  #(

   .NO_OF_CLOCKS_FOR_10MS(clocks_for_10ms    ),
   .CLOCK_PERIOD_IN_PS   (ps_per_clock       ),
   .cnt_w                (radio_counter_width)

) ms10_i (

  .clk                       (s_axis_aclk               ),
  .resetn                    (s_axis_aresetn            ),
  
  .count_init_for_sim        (count_init_for_sim  [radio_counter_width-1:0] ),
  .offset_10ms_cycles        (djictl_offset_clocks[0]                       ),
  .enable                    (djictl_enable_10_ms       ),
  .radio_us_count            (radio_us_count            ),
  .radio_start_one_pps       (radio_start_one_pps       ),
  .radio_start_10ms_stretch  (radio_start_10ms_stretch  ),
  .radio_start_10ms          (radio_start_10ms          ),
  .radio_offset_10ms_stretch (radio_offset_10ms_stretch ),
  .radio_offset_10ms         (radio_offset_10ms         )

);

//-----------------------------------------------------------------------------
// Need to make this work for multi port
//-----------------------------------------------------------------------------
genvar    tt;
generate
  for (tt = 0; tt < C_NUM_ETH; tt = tt + 1) begin : eth_src

torwave_unit #(
    .who_am_i         (tt),
    .who_am_i_str     (48 + tt), // 48 is ASCII 0
    .memory_word_depth(memory_word_depth)
) dg (

  // Generator specific
  .m_data_tdata              (m_data_tdata  [tt]        ),
  .m_data_tkeep              (m_data_tkeep  [tt]        ),
  .m_data_tvalid             (m_data_tvalid [tt]        ),
  .m_data_tlast              (m_data_tlast  [tt]        ),
  .m_data_tuser              (m_data_tuser  [tt]        ),
  .m_data_tready             (m_data_tready [tt]        ),

  .dij_ram_locations         (dij_ram_locations[tt]     ),
  .dij_address_write_r       (dij_address_write_r[tt]   ),
  .dij_address_read_r        (dij_address_read_r[tt]    ),
  .dij_data_rd               (dij_data_rd[tt]           ),

  .dij_address_write         (dij_address_write         ),
  .dij_address_read          (dij_address_read          ),
  .dij_data_wr               (dij_data_wr               ),
  .dij_data_wr_pls           (dij_data_msby_wr_strb     ),
  .dij_data_rd_pls           (dij_data_msby_rd_strb     ),
  .dij_bank_select           (dij_bank_select           ),

  .error_flag                (),

  .djictl_start_address      (djictl_start_address[tt]  ),
  .djictl_end_address        (djictl_end_address  [tt]  ),

  // Common signals
  .djictl_start_when_ready   (djictl_start_when_ready   ),
  .djictl_reset_data_injector(djictl_reset_data_injector),
  .djictl_loop_enable        (djictl_loop_enable        ),

  .radio_us_count            (radio_us_count            ),
  .radio_start_10ms          (radio_start_10ms          ),

  .s_axis_aresetn            (s_axis_aresetn            ),
  .s_axis_aclk               (s_axis_aclk               ),
  .s_axi_aclk                (s_axi_aclk                )

);


torsink_top #(
    .memory_word_depth(memory_word_depth)
) sink (

  .s_data_tdata               (s_data_tdata [tt] ),  // input  wire [63:0]    
  .s_data_tkeep               (s_data_tkeep [tt] ),  // input  wire  [7:0]    
  .s_data_tvalid              (s_data_tvalid[tt] ),  // input  wire           
  .s_data_tlast               (s_data_tlast [tt] ),  // input  wire           
  .s_data_tuser               (s_data_tuser [tt] ),  // input  wire           
  .s_data_tready              (s_data_tready[tt] ),  // output reg            
 
  .djictl_reset_data_sink     (djictl_reset_data_sink         ),
  .djictl_trigger_capture     (djictl_trigger_capture         ),
  .djictl_sample_counters     (djictl_sample_counters         ),
  .djictl_sink_counter_payload(djictl_sink_counter_payload[tt]),
  .djictl_sink_counter_ecpri  (djictl_sink_counter_ecpri  [tt]),
  .djictl_sink_counter_1914_3 (djictl_sink_counter_1914_3 [tt]),
  .djictl_sink_counter_cpu    (djictl_sink_counter_cpu    [tt]),
  .djictl_sink_counter_prach  (djictl_sink_counter_prach  [tt]),
  .djictl_sink_counter_unsol  (djictl_sink_counter_unsol  [tt]),
  .djictl_sink_counter_select (djictl_sink_counter_select [tt]),
  .djictl_sink_counter_ss     (djictl_sink_counter_ss     [tt]),

  .s_axis_aresetn             (s_axis_aresetn                 ),  // input  wire           
  .s_axis_aclk                (s_axis_aclk                    ),  // input  wire           
  .s_axi_aclk                 (s_axi_aclk                     )   // input  wire           

);

  end
endgenerate

endmodule

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Block to generate 10ms from a  10ms toggling signal. Also generates a 1ms
// strobe for use with the v2_1 IP. v2_2 no longer uses a 1ms strobe 
//-----------------------------------------------------------------------------
module radio_start_recover  #(
   parameter setup_cnt       = 'd10000,
   parameter clocks_for_1ms  = 'd156250,
   parameter filter_w        = 16  ,
   parameter guard_cycles    = 6400,
   parameter cnt_w           = 16  
) (
  input  wire                clk                          ,
  input  wire                radio_start_10ms_stretch     ,
  output reg                 radio_start_10ms_toggle   = 0,
  output reg                 radio_start_1ms_toggle    = 0,
  output reg                 radio_start_10ms          = 0,
  output reg                 radio_start_1ms           = 0
);

localparam stretchlength = 8;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
logic [filter_w - 1:0] filter0                     = 'd0;
logic [filter_w - 1:0] filter1                     = 'd0;
logic                  radio_start_10ms_stretch_s  ;
logic                  filter0_out                 =0;
logic                  filter1_out                 =0;
logic [cnt_w - 1:0]    guard_cnt                   = 'd0;
logic                  guard_is_zero               = 'd0;
int                    i;
reg   [3:0]            radio_counter_10            = 1; //
reg   [23:0]           radio_counter               = setup_cnt; //;

//-----------------------------------------------------------------------------
// cdc incoming signal
//-----------------------------------------------------------------------------
xpm_cdc_single #( .SRC_INPUT_REG (0) ) xpm_cdc_rs10ms_i  ( 
  .src_clk  (), 
  .src_in   (radio_start_10ms_stretch),    
  .dest_clk (clk), 
  .dest_out (radio_start_10ms_stretch_s)
);

//-----------------------------------------------------------------------------
// Filter the incoming signal
// Create balanced paths for detection of 0->1 and 1->0
//-----------------------------------------------------------------------------
always @(posedge clk) begin
  filter0[0]  <= radio_start_10ms_stretch_s;
  filter0_out <= filter0[filter_w - 1];
  filter1[0]  <= ~radio_start_10ms_stretch_s;
  filter1_out <= filter1[filter_w - 1];
  for (i=1;i<filter_w;i=i+1) begin
    filter0[i] <= filter0[i-1];
    filter1[i] <= filter1[i-1];
  end
end

//-----------------------------------------------------------------------------
// Perform the detection and generate the pulse.
// Once detected, start the guard count to prevent any accidental trigger.
// The stretch is expected to toggle evernt 10ms, so 10ms high, 10ms low etc.
// This make it very measurable on the scope and should limit issues passing
// board to board.
//-----------------------------------------------------------------------------
always @(posedge clk) begin

  guard_is_zero    <= |guard_cnt;
  radio_start_10ms <= 1'd0;
  radio_start_1ms  <= 1'd0;

  if(
      (!guard_is_zero ) & // Not in guard period
      ( 
        (
          (!filter0_out   ) & // zero out, rising coming
          (&filter0       )   // Filter is full of ones
        ) |
        (
          (!filter1_out   ) & // zero out, rising coming
          (&filter1       )   // Filter is full of ones
        )
      )
    ) begin
    
    radio_start_10ms        <= 1'd1;
    radio_start_10ms_toggle <= ~radio_start_10ms_toggle;
    guard_cnt               <= guard_cycles;
    radio_counter           <= clocks_for_1ms-1;
    radio_counter_10        <= 'd9;
    radio_start_1ms         <= 1'd1;

  end else begin
    
    if(guard_cnt != 'd0)
      guard_cnt <= guard_cnt -'d1;


    if(radio_counter == 'd0) begin

      radio_counter <= clocks_for_1ms - 'd1;

      if (radio_counter_10 != 0)
        radio_counter_10 <= radio_counter_10 - 'd1;

    end else begin
      radio_counter <= radio_counter - 'd1;
    end

    if( (radio_counter == 'd0) & (radio_counter_10 != 'd0) ) begin
      radio_start_1ms  <= 1'd1;
      radio_start_1ms_toggle  <= ~radio_start_1ms_toggle;
    end

  end
end

endmodule

//-----------------------------------------------------------------------------
// Strobe generator block
//-----------------------------------------------------------------------------
module radio_start_gen23  #(
   parameter NO_OF_CLOCKS_FOR_10MS = 'd1562500,
   parameter CLOCK_PERIOD_IN_PS    = 6400,
   parameter cnt_w                 = 24
) (
  input  wire [cnt_w - 1:0]  count_init_for_sim           ,
  input  wire [cnt_w - 1:0]  offset_10ms_cycles           ,
  input  wire                enable                       ,
  input  wire                resetn                       ,
  input  wire                clk                          ,
  output reg  [15:0]         radio_us_count            = 0,
  output reg                 radio_start_10ms_stretch  = 0,
  output reg                 radio_start_10ms          = 0,
  output reg                 radio_start_one_pps       = 0,
  output reg                 radio_offset_10ms_stretch = 0,
  output reg                 radio_offset_10ms         = 0
);

localparam stretchlength = 8;
localparam int three_p = CLOCK_PERIOD_IN_PS * 3;
localparam int ome_us_in_ps  = 1000000;

//-----------------------------------------------------------------------------
// Sized to deal with a max antenna rate of 500MHz
//-----------------------------------------------------------------------------
reg   [cnt_w - 1:0]       radio_counter    = {24{1'd1}}; //; Max Val = 16,777,216
reg   [cnt_w - 1:0]       radio_counter_off= 'd0; //; Max Val = 16,777,216
reg   [3:0]               one_pps_cnt      = 'd0;
reg   [stretchlength-1:0] stretch_10ms     = 'd0;
reg   [stretchlength-1:0] stretch_10ms_off = 'd0;
reg   [stretchlength-1:0] one_pps_high     = 'd0;
reg                       enable_r         = 0;
logic [27:0]              one_us_counter     = 0; // 
logic                     one_us_rollover    = 0; // 
logic                     one_us_counter27_d = 0; // 

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
always @(posedge clk) begin
  
  enable_r <= enable;
  
  // Radio counter simple continually decrements
  if(~enable_r) begin
    radio_counter <= count_init_for_sim[cnt_w - 1:0];
  end else 
    if(radio_counter == 'd0)
       radio_counter <= NO_OF_CLOCKS_FOR_10MS-1;
    else 
       radio_counter <= radio_counter - 'd1;

end

//-----------------------------------------------------------------------------
// Generate a 1us counter
// This needs improvement. results in 15 extra us in 10 ms. Wont break our 
// testing, but need more accutrate solution whwn injecting skew.
//-----------------------------------------------------------------------------
always @(posedge clk) begin
  
  if((~resetn) | radio_start_10ms | one_us_rollover) begin
     one_us_counter <= ome_us_in_ps - three_p;
  end else begin
     one_us_counter <= one_us_counter - CLOCK_PERIOD_IN_PS;
  end

  // Rollover indicated by this going negative, i.e. wrapping round.
  one_us_counter27_d <= one_us_counter[27];
  one_us_rollover    <= one_us_counter[27] & (~one_us_counter27_d) ;

end

always @(posedge clk) begin
  
  if((~resetn) | radio_start_10ms) begin

     radio_us_count <= 0;

  end else begin

     if (one_us_rollover)
        radio_us_count <= radio_us_count + 'd1;
  end

end

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
always @(posedge clk) begin

  if (~resetn) begin
    radio_start_10ms <= 1'd0;
    stretch_10ms     <= 'd0;
  end else begin

    radio_start_10ms   <= 1'd0; // Catchall
    radio_offset_10ms  <= 1'd0;

    if (radio_counter == 'd0) begin

      radio_start_10ms_stretch <= ~radio_start_10ms_stretch;
      radio_start_10ms <= 1'd1;
      stretch_10ms     <= {stretchlength{1'b1}};
      radio_counter_off<= offset_10ms_cycles;

      if(one_pps_cnt == 0) begin
        radio_start_one_pps <= 1'd1;
        one_pps_cnt <= 10;
      end else begin
        one_pps_cnt <= one_pps_cnt - 'd1;
        radio_start_one_pps <= 1'd0;
      end

    end else begin

      if (stretch_10ms != 'd0) 
        stretch_10ms <= stretch_10ms - 'd1;

      if(radio_counter_off!=0)
        radio_counter_off <= radio_counter_off -'d1;

      if (radio_counter_off == 'd1) begin
        radio_offset_10ms <= 'd1;
        stretch_10ms_off  <= {stretchlength{1'b1}};
        radio_offset_10ms_stretch <= ~radio_offset_10ms_stretch;
      end else       
        if (stretch_10ms_off != 'd0) 
          stretch_10ms_off <= stretch_10ms_off - 'd1;

    end

  end

end

endmodule

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
module torwave_unit #(
    parameter [7:0] who_am_i_str      = 0, // Must be Byte Width
                                           // Needs 48 added to this
    parameter       who_am_i          = 0, // The raw number
    parameter       memory_word_depth = 1024 
) (

  output reg  [63:0]    m_data_tdata               = 0,
  output reg   [7:0]    m_data_tkeep               = 0,
  output reg            m_data_tvalid              = 0,
  output reg            m_data_tlast               = 0,
  output reg            m_data_tuser               = 0,
  input  wire           m_data_tready              ,
 
  output reg  [31:0]    dij_ram_locations          = memory_word_depth,
  output reg  [19:0]    dij_address_write_r        = 0,
  output reg  [19:0]    dij_address_read_r         = 0,
  output reg  [63:0]    dij_data_rd                = 0,
 
  output reg            error_flag                 = 0,
 
  input  wire [19:0]    dij_address_write          ,
  input  wire [19:0]    dij_address_read           ,
  input  wire [63:0]    dij_data_wr                ,
  input  wire  [7:0]    dij_bank_select            ,  
 
  input                 dij_data_wr_pls            ,
  input                 dij_data_rd_pls            ,                
 
  input  wire           djictl_start_when_ready    ,
  input  wire           djictl_reset_data_injector ,
  input  wire           djictl_loop_enable         ,
  input  wire [19:0]    djictl_start_address       ,
  input  wire [19:0]    djictl_end_address         ,

  input  wire [15:0]    radio_us_count             ,
  input  wire           radio_start_10ms           ,

  input  wire           s_axis_aresetn             ,
  input  wire           s_axis_aclk                ,
  input  wire           s_axi_aclk

);

parameter integer memory_word_depth_w = $clog2(memory_word_depth);
localparam mem_init_file = {"ethdata_port_", who_am_i_str,".mem"};

initial begin
  $display ("%s -- %d", mem_init_file, who_am_i_str);
end

parameter integer stuff = 20 - memory_word_depth_w;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
reg  [memory_word_depth_w-1:0]   addra=0;
reg  [memory_word_depth_w-1:0]   addrb=0;
reg  [memory_word_depth_w-1:0]   djictl_end_address_r=0;

reg           wea=0;
wire [63:0]   douta;
wire [63:0]   doutb;

reg           dij_data_wr_pls_1=0;
reg           dij_data_wr_pls_2=0;

reg  [19:0]   dij_address_write_d=0;
reg  [19:0]   dij_address_read_d=0;
reg           dij_address_write_diff=0;
reg           dij_address_read_diff=0;

reg  [15:0]   radio_us_count_r=0;

reg           axi4_is_for_me =0;

// State logic
typedef enum {IDLE, LOADADDR, WAIT, LD_TIME,LD_LENGTH,SEND_PACKET,TIMESTALL1,TIMESTALL2,TIMEHOLD,TIMESTART1,TIMESTART2} axis_rd_sm;
axis_rd_sm    rd_sm = IDLE;

logic [12:0]  packet_length_words=0;
logic  [2:0]  packet_remainder_bytes=0;
logic         stall_packet_length=0;
logic [63:0]  packet_circlr_buf[2];
logic  [7:0]  tkeep_r=0;
logic [31:0]  packet_time_us=0;

reg   [3:0]   i_am_eth_port=who_am_i;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
always @(posedge s_axi_aclk) begin
  axi4_is_for_me       <= i_am_eth_port == dij_bank_select;
end

//-----------------------------------------------------------------------------
// AXI side logic. Use to read/write the RAM on Port A
//-----------------------------------------------------------------------------
// Write logic
always @(posedge s_axi_aclk) begin
  
  dij_data_wr_pls_1  <= 1'd0;
  dij_data_wr_pls_2  <= 1'd0;
  wea                <= 1'd0;
  dij_data_rd        <= douta;
  dij_address_read_r <= { {stuff{1'd0}}, addra };

  // Create diff strobes on the R/W address registers
  // Bit crude, biut works mostly.
  dij_address_write_d    <= dij_address_write;
  dij_address_read_d     <= dij_address_read;
  dij_address_write_diff <= dij_address_write_d != dij_address_write;
  dij_address_read_diff  <= dij_address_read_d  != dij_address_read;

  // Write pulse managment
  if (dij_data_wr_pls & axi4_is_for_me) begin
    dij_data_wr_pls_1 <= dij_data_wr_pls;
  end
  if (dij_data_wr_pls_1) begin
    dij_data_wr_pls_2 <= dij_data_wr_pls_1;
    wea               <= 1'd1;
  end

  // ddra managment
  if (dij_data_wr_pls_2 | (dij_data_rd_pls & axi4_is_for_me)) begin
    addra <= addra + 'd1;
  end else begin
    if (dij_address_write_diff) begin
      addra <= dij_address_write;
    end else begin
      if (dij_address_read_diff) begin
        addra <= dij_address_read;
      end 
    end
  end
  
end

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
roe_framer_v2_2_tdpram_2clk #(

  .C_DL_SS_DATA       (memory_word_depth),  // 
  .C_MEM_INIT_FILE    (mem_init_file),  // wf0.mem
  .P_DL_SS_DATA_WIDTH (64      ),  // 
  .P_MEMORY_PRIMITIVE ("block" ),  // 
  .P_READ_LATENCY_A   (2       ),  // 
  .P_READ_LATENCY_B   (2       )   //

  ) data_store_i (

  .addra   (addra[memory_word_depth_w - 1:0]),
  .dina    (dij_data_wr),
  .wea     (wea        ),
  .douta   (douta      ),
  .addrb   (addrb[memory_word_depth_w - 1:0]),
  .doutb   (doutb      ),
  .clka    (s_axi_aclk ),
  .clkb    (s_axis_aclk),
  .rsta    (1'd0), // 
  .rstb    (1'd0), // 
  .ena     (1'd1), // Tie high to use simply
  .enb     (1'd1), // Tie high to use simply
  .regcea  (1'd1), // Tie high to use simply
  .regceb  (1'd1), // Tie high to use simply
  .sleep   (1'd0)  // Tie low to use simply

);

//-----------------------------------------------------------------------------
// Data read engine
//-----------------------------------------------------------------------------
//typedef struct pcap_hdr_s {
//        guint32 magic_number;   /* magic number */
//        guint16 version_major;  /* major version number */
//        guint16 version_minor;  /* minor version number */
//        gint32  thiszone;       /* GMT to local correction */
//        guint32 sigfigs;        /* accuracy of timestamps */
//        guint32 snaplen;        /* max length of captured packets, in octets */
//        guint32 network;        /* data link type */
//} pcap_hdr_t;
// typedef struct pcaprec_hdr_s {
//         guint32 ts_sec;         /* timestamp seconds */
//         guint32 ts_usec;        /* timestamp microseconds */
//         guint32 incl_len;       /* number of octets of packet saved in file */
//         guint32 orig_len;       /* actual length of packet */
// } pcaprec_hdr_t;
//-----------------------------------------------------------------------------
// Register signals, just to minimise timing issues
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin

  // register the count
  radio_us_count_r <= radio_us_count;

  // convert tkeep, assumption is this will be valid long before its used
  // Valid as min packet sise is 64 bytes, or 8 words.
  case(packet_remainder_bytes)
    0 : tkeep_r <= 8'hff;
    1 : tkeep_r <= 8'h01;
    2 : tkeep_r <= 8'h03;
    3 : tkeep_r <= 8'h07;
    4 : tkeep_r <= 8'h0f;
    5 : tkeep_r <= 8'h1f;
    6 : tkeep_r <= 8'h3f;
    7 : tkeep_r <= 8'h7f;
  endcase

end

//-----------------------------------------------------------------------------
// Main PCAP read logic
// TODO : Add full tready support, mitigate with packet fifo on output for now
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin

  // Register the end address locally. This is essentially static
  djictl_end_address_r <= djictl_end_address[memory_word_depth_w - 1:0];

  if (!djictl_start_when_ready) begin

    rd_sm         <= IDLE;
    m_data_tdata  <= 0;
    m_data_tkeep  <= 'hff;
    m_data_tvalid <= 0;
    m_data_tlast  <= 0;
    m_data_tuser  <= 0;

  end else begin

    // Default state for all these signals
    rd_sm         <= rd_sm;
    m_data_tdata  <= 0;
    m_data_tkeep  <= 'hff;
    m_data_tvalid <= 0;
    m_data_tlast  <= 0;
    m_data_tuser  <= 0;

    // Main Case
    case(rd_sm)

      // ----------------------------------------------------------------------
      // Wait
      IDLE : begin
        if(djictl_start_when_ready & radio_start_10ms) begin
          rd_sm <= LOADADDR;
          addrb <= djictl_start_address[memory_word_depth_w - 1:0];
        end
      end

      // ----------------------------------------------------------------------
      // Address is off to the RAM.
      LOADADDR : begin
        rd_sm <= WAIT;
        addrb <= addrb + 'd1;
      end

      // ----------------------------------------------------------------------
      // Wait for the data.
      WAIT : begin
        rd_sm <= LD_TIME;
        addrb <= addrb + 'd1;
      end

      // ----------------------------------------------------------------------
      // We have stripped the first 3 words of the PCAP header. If we add back
      // support, we need a state to let these run through. Currently there is
      // no reqyuirement for this. We may add at a later stage.
      // First line is back, this contains the record header.
      // See more @ https://wiki.wireshark.org/Development/LibpcapFileFormat
      LD_TIME : begin
        rd_sm               <= LD_LENGTH;
        addrb               <= addrb + 'd1;
        packet_time_us      <= doutb[31:0];
        stall_packet_length <= 1'd0;
      end

      // ----------------------------------------------------------------------
      // Load the packet length
      // Now we make the time to send decision
      LD_LENGTH : begin

        packet_length_words    <= doutb[15:3];
        packet_remainder_bytes <= doutb[2:0];

        if(packet_time_us[15:0] <= radio_us_count) begin

          rd_sm <= SEND_PACKET;
          addrb <= addrb + 'd1;

        end else begin
 
          rd_sm <= TIMESTALL1;
          addrb <= addrb; // Do nothing, wait for time to send

        end

      end

      // ----------------------------------------------------------------------
      // Save the RAM output
      TIMESTALL1 : begin
        rd_sm <= TIMESTALL2;
        packet_circlr_buf[0]<=doutb;
      end

      // ----------------------------------------------------------------------
      // Save the RAM outout
      TIMESTALL2 : begin
        rd_sm <= TIMEHOLD;
        packet_circlr_buf[1]<=doutb;
      end

      // ----------------------------------------------------------------------
      // Wait, continually check the time
      TIMEHOLD : begin

        if((packet_time_us[15:0] <= radio_us_count[15:0]) & m_data_tready) begin

          rd_sm         <= TIMESTART1;
          addrb         <= addrb + 'd1;
        end

      end

      // ----------------------------------------------------------------------
      // Startup. unload the data
      TIMESTART1 : begin

        rd_sm         <= SEND_PACKET;
        addrb         <= addrb + 'd1;
        m_data_tdata  <= packet_circlr_buf[0];
        m_data_tvalid <= 'd1;
        packet_length_words <= packet_length_words - 'd1;

      end

      // ----------------------------------------------------------------------
      //  unload the saved data
      TIMESTART2 : begin

        rd_sm         <= SEND_PACKET;
        addrb         <= addrb + 'd1;
        m_data_tdata  <= packet_circlr_buf[1];
        m_data_tvalid <= 'd1;
        packet_length_words <= packet_length_words - 'd1;

      end

      // ----------------------------------------------------------------------
      // Send all the packet data
      SEND_PACKET : begin

        if (djictl_end_address_r != addrb)
          addrb <= addrb + 'd1;

        m_data_tdata  <= doutb;
        m_data_tvalid <= 'd1;

        // Manage the packet length decrement
        if ((!stall_packet_length) & (|packet_remainder_bytes)) begin

          packet_length_words <= packet_length_words;
          stall_packet_length <= 1'd1;

        end else
          packet_length_words <= packet_length_words - 'd1;

        // Deal with TKEEP at the end of the frame
        if(packet_length_words == 'd1) begin

         // Are we finished, or have we more packets to process
         if (djictl_end_address_r != addrb)
            rd_sm <= LD_TIME;
          else 
            rd_sm <= IDLE;

          m_data_tlast <= 'd1;
          m_data_tkeep <= tkeep_r;

        end

      end

    endcase // dl_eth_to_ss_arb_state

  end

end

endmodule

//-----------------------------------------------------------------------------
// Dual port memory for data store
//-----------------------------------------------------------------------------
module roe_framer_v2_2_tdpram_2clk #(

  parameter integer  C_DL_SS_DATA       = 20000               , // 
  parameter          C_MEM_INIT_FILE    = "none"              , //
  parameter integer  P_DL_SS_DATA_WIDTH = 72                  , // 
  parameter          P_MEMORY_PRIMITIVE = "ultra"             , // 
  parameter integer  P_READ_LATENCY_A   = 2                   , // 
  parameter integer  P_READ_LATENCY_B   = 2                   , // 

  // These are essentially considered derived, with the option of being
  // overridden at a higer level 
  parameter integer  P_DL_SS_DATA_W     = $clog2(C_DL_SS_DATA)  // 

)  (
                                               // Write Interface 
  input   [P_DL_SS_DATA_W - 1:0]     addra   , // 
  input   [P_DL_SS_DATA_WIDTH - 1:0] dina    , // 
  input                              wea     , // 
  output  [P_DL_SS_DATA_WIDTH - 1:0] douta   , // 
                                               // Read Interface 
  input   [P_DL_SS_DATA_W - 1:0]     addrb   , // 
  output  [P_DL_SS_DATA_WIDTH - 1:0] doutb   , // 
                                               // CLK Interface 
  input                              clka    , // 
  input                              clkb    , // 
  input                              rsta    , // 
  input                              rstb    , // 
                                               // CTRL Interface 
  input                              ena     , // Tie high to use simply
  input                              enb     , // Tie high to use simply
  input                              regcea  , // Tie low to use simply
  input                              regceb  , // Tie low to use simply
  input                              sleep     // Tie low to use simply

  );

// Xilinx Parameterized Macro, version 2018.2
xpm_memory_tdpram #(

  .ADDR_WIDTH_A(P_DL_SS_DATA_W),                  // DECIMAL
  .ADDR_WIDTH_B(P_DL_SS_DATA_W),                  // DECIMAL
  .AUTO_SLEEP_TIME(0),                            // DECIMAL
  .BYTE_WRITE_WIDTH_A(P_DL_SS_DATA_WIDTH),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(P_DL_SS_DATA_WIDTH),        // DECIMAL
  .CASCADE_HEIGHT(0),                             // DECIMAL
  .CLOCKING_MODE("independent_clock"),            // String
  .ECC_MODE("no_ecc"),                            // String
  .MEMORY_INIT_FILE(C_MEM_INIT_FILE),             // String
  .MEMORY_INIT_PARAM("0"),                        // String
  .MEMORY_OPTIMIZATION("true"),                   // String
  .MEMORY_PRIMITIVE(P_MEMORY_PRIMITIVE),          // String
  .MEMORY_SIZE((C_DL_SS_DATA*P_DL_SS_DATA_WIDTH)),// DECIMAL
  .MESSAGE_CONTROL(0),                            // DECIMAL
  .READ_DATA_WIDTH_A(P_DL_SS_DATA_WIDTH),         // DECIMAL
  .READ_DATA_WIDTH_B(P_DL_SS_DATA_WIDTH),         // DECIMAL
  .READ_LATENCY_A(P_READ_LATENCY_B),              // DECIMAL
  .READ_LATENCY_B(P_READ_LATENCY_B),              // DECIMAL
  .READ_RESET_VALUE_A("0"),                       // String
  .READ_RESET_VALUE_B("0"),                       // String
  .RST_MODE_A("SYNC"),                            // String
  .RST_MODE_B("SYNC"),                            // String
  .SIM_ASSERT_CHK(0),                             // DECIMAL; 0=disable simulation messages, 1=enable
  .USE_EMBEDDED_CONSTRAINT(0),                    // DECIMAL
  .USE_MEM_INIT(1),                               // DECIMAL
  .WAKEUP_TIME("disable_sleep"),                  // String
  .WRITE_DATA_WIDTH_A(P_DL_SS_DATA_WIDTH),        // DECIMAL
  .WRITE_DATA_WIDTH_B(P_DL_SS_DATA_WIDTH),        // DECIMAL
  .WRITE_MODE_A("no_change"),                     // String
  .WRITE_MODE_B("no_change")                      // String

) xpm_memory_tdpram_inst (

      .dbiterra(        ),             // 1-bit output: Status signal to indicate double bit error occurrence
      .dbiterrb(        ),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .douta(douta),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(        ),             // 1-bit output: Status signal to indicate single bit error occurrence
      .sbiterrb(        ),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb({P_DL_SS_DATA_WIDTH{1'd0}}), // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'd0),           // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'd0),           // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).
      .injectdbiterrb(1'd0),           // 1-bit input: Controls double bit error injection on input data when
      .injectsbiterrb(1'd0),           // 1-bit input: Controls single bit error injection on input data when

      .regcea(regcea),                 // 1-bit input: Clock Enable for the last register stage on the output
      .regceb(regceb),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rsta),                     // 1-bit input: Reset signal for the final port B output register stage.
      .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea),                       // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
      .web(1'd0)                       // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
                                       // data port dina. 1 bit wide when word-wide writes are used. In
                                       // byte-wide write configurations, each bit controls the writing one
                                       // byte of dina to address addra. For example, to synchronously write
                                       // only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
                                       // 4'b0010.
);

endmodule


//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
module torsink_top #(
    parameter memory_init_file  = "none",
    parameter memory_word_depth = 1024 
) (

  input  wire [63:0]    s_data_tdata               ,
  input  wire  [7:0]    s_data_tkeep               ,
  input  wire           s_data_tvalid              ,
  input  wire           s_data_tlast               ,
  input  wire           s_data_tuser               ,
  output reg            s_data_tready              =1,

  input  logic          djictl_reset_data_sink     , // 
  input  logic          djictl_trigger_capture     , // 
  input  logic          djictl_sample_counters     , // 
  output logic [18:0]   djictl_sink_counter_payload=0, // 
  output logic [18:0]   djictl_sink_counter_ecpri  =0, // 
  output logic [18:0]   djictl_sink_counter_1914_3 =0, // 
  output logic [18:0]   djictl_sink_counter_cpu    =0, // 
  output logic [18:0]   djictl_sink_counter_prach  =0, // 
  output logic [18:0]   djictl_sink_counter_unsol  =0, // 
  input  logic [3:0]    djictl_sink_counter_select , // 
  output logic [18:0]   djictl_sink_counter_ss     =0, // 
 
  input  wire           s_axis_aresetn             ,
  input  wire           s_axis_aclk                ,
  input  wire           s_axi_aclk

);

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
logic           sink_protocol_enable       =1; 

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
logic [63:0]    r_s_data_tdata       =0; 
logic  [7:0]    r_s_data_tkeep       =0; 
logic           r_s_data_tvalid      =0; 
logic           r_s_data_tlast       =0; 
logic           r_s_data_tuser       =0; 
logic           r_s_data_tready      =0; 

logic [7:0]     or_s_data_tdata      = 0;
logic           or_or_s_data_tdata   = 0;


logic [63:0] header_transport;
logic [31:0] header_oran;
logic [31:0] header_section;
logic [19:0] counter_payload=0;

logic  [7:0] bo_trans_type;
logic [15:0] bo_trans_length;
logic [15:0] bo_trans_pcid;
logic [15:0] bo_trans_seq_id;

typedef enum {IDLE, SRCDEST, VLAN, ECPRI, ORAN_HEAD, VLAN_ECPRI, VLAN_I1914, I1914, RUN, FORARM} axis_rd_sm;
axis_rd_sm    unpack = IDLE;

//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin

  r_s_data_tdata     <= {s_data_tdata[ 7: 0],
                         s_data_tdata[15: 8],
                         s_data_tdata[23:16],
                         s_data_tdata[31:24],
                         s_data_tdata[39:32],
                         s_data_tdata[47:40],
                         s_data_tdata[55:48],
                         s_data_tdata[63:56]};
  
  r_s_data_tkeep     <= s_data_tkeep  ;
  r_s_data_tvalid    <= s_data_tvalid ;
  r_s_data_tlast     <= s_data_tlast  ;
  r_s_data_tuser     <= s_data_tuser  ;
  r_s_data_tready    <= s_data_tready ;

  or_s_data_tdata[0] <= |s_data_tdata[ 7: 0]; // 
  or_s_data_tdata[1] <= |s_data_tdata[15: 8]; // 
  or_s_data_tdata[2] <= |s_data_tdata[23:16]; // 
  or_s_data_tdata[3] <= |s_data_tdata[31:24]; // 
  or_s_data_tdata[4] <= |s_data_tdata[39:32]; // 
  or_s_data_tdata[5] <= |s_data_tdata[47:40]; // 
  or_s_data_tdata[6] <= |s_data_tdata[55:48]; // 
  or_s_data_tdata[7] <= |s_data_tdata[63:56]; // 

  or_or_s_data_tdata <= |or_s_data_tdata; // Prevent data being removed if were
                                          // only going to check protocol
end

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
assign bo_trans_type   = header_transport[55:48];
assign bo_trans_length = header_transport[47:32];
assign bo_trans_pcid   = header_transport[31:16];
assign bo_trans_seq_id = header_transport[15:0];

//-----------------------------------------------------------------------------
// Sample all the counters for stats
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk)
  if (djictl_sample_counters) begin
    djictl_sink_counter_payload <= counter_payload;
  end

//-----------------------------------------------------------------------------
// Packet filtering SM for UL Uplane packets
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin
  if (sink_protocol_enable) begin
    if (r_s_data_tvalid & r_s_data_tready) begin
      case(unpack)
        IDLE   : begin
                   unpack <= SRCDEST;
                 end
        SRCDEST: begin
                   case (r_s_data_tdata[31:16])
                   16'hAEFE  : begin
                               unpack <= ECPRI;
                               header_transport[63:48] <= r_s_data_tdata[15:0];
                               end
                   16'h8100  : unpack <= VLAN ;
                   16'hFC3D  : unpack <= I1914;
                   default   : unpack <= FORARM;
                   endcase
                 end
        VLAN   : begin
                   case (r_s_data_tdata[63:48])
                   16'hAEFE  : unpack <= VLAN_ECPRI;
                   16'hFC3D  : unpack <= VLAN_I1914;
                   default   : unpack <= FORARM;
                   endcase
                 end
        ECPRI  : begin
                   unpack <= ORAN_HEAD;
                   header_transport[47:0] <= r_s_data_tdata[63:16];
                   header_oran[31:16] <= r_s_data_tdata[15:0];
                 end
        I1914  : begin
                   unpack <= ORAN_HEAD;
                   header_transport[47:0] <= r_s_data_tdata[63:16];
                   header_oran[31:16] <= r_s_data_tdata[15:0];
                 end
        VLAN_ECPRI  : begin
                   unpack <= RUN;
                 end
        VLAN_I1914  : begin
                   unpack <= RUN;
                 end
        ORAN_HEAD: begin
                   unpack <= RUN;
                   header_oran[15:0] <= r_s_data_tdata[63:48];
                   // Got here as this was a RAW T2 packet
                   counter_payload <= counter_payload + 'd6;
                 end
        
        // For now the counter will only manage RAW Ethernet Packets. 
        // Add dissection of the incoming sections and stats gathering
        // VLAN managment

        RUN    : begin
                   if (r_s_data_tlast) begin
                     unpack <= IDLE;
                     case (r_s_data_tkeep) 
                     8'hFF   : counter_payload <= counter_payload + 'd8;
                     8'h7F   : counter_payload <= counter_payload + 'd7;
                     8'h3F   : counter_payload <= counter_payload + 'd6;
                     8'h1F   : counter_payload <= counter_payload + 'd5;
                     8'h0F   : counter_payload <= counter_payload + 'd4;
                     8'h07   : counter_payload <= counter_payload + 'd3;
                     8'h03   : counter_payload <= counter_payload + 'd2;
                     default : counter_payload <= counter_payload + 'd1;
                     endcase
                   end else begin
                     counter_payload <= counter_payload + 'd8;
                   end
                 end
        FORARM : begin
                   if (r_s_data_tlast)
                     unpack <= IDLE;
                 end
      endcase
    end
  end
end

endmodule

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
module torsink_unit #(
    parameter memory_init_file  = "none",
    parameter memory_word_depth = 1024 
) (

  input  wire [63:0]    s_data_tdata               ,
  input  wire  [7:0]    s_data_tkeep               ,
  input  wire           s_data_tvalid              ,
  input  wire           s_data_tlast               ,
  input  wire           s_data_tuser               ,
  output reg            s_data_tready              =0,
 
  output reg  [31:0]    dij_ram_locations          = memory_word_depth,
  output reg  [19:0]    dij_address_write_r        = 0,
  output reg  [19:0]    dij_address_read_r         = 0,
  output reg  [63:0]    dij_data_rd                = 0,
  
  input  wire [19:0]    dij_address_write          ,
  input  wire [19:0]    dij_address_read           ,
  input  wire [63:0]    dij_data_wr                ,
 
  input                 dij_data_wr_pls            ,
  input                 dij_data_rd_pls            ,                
 
  input  wire           djictl_start_when_ready    ,
  input  wire           djictl_reset_data_injector ,
  input  wire           djictl_loop_enable         ,
  input  wire [19:0]    djictl_start_address       ,
  input  wire [19:0]    djictl_end_address         ,

  input  wire           s_axis_aresetn             ,
  input  wire           s_axis_aclk                ,
  input  wire           s_axi_aclk

);

parameter integer memory_word_depth_w = $clog2(memory_word_depth); 

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
reg  [19:0]   addra=0;
reg  [19:0]   addrb=0;
reg           wea=0;
wire [63:0]   douta;
wire [63:0]   doutb;

reg           dij_data_wr_pls_1=0;
reg           dij_data_wr_pls_2=0;

reg  [19:0]   dij_address_write_d=0;
reg  [19:0]   dij_address_read_d=0;
reg           dij_address_write_diff=0;
reg           dij_address_read_diff=0;

reg  [15:0]   radio_us_count_r=0;

// State logic
typedef enum {IDLE, ARM, CAPTURE} axis_rd_sm;
axis_rd_sm    rd_sm = IDLE;

logic [12:0]  packet_length_words=0;
logic  [2:0]  packet_remainder_bytes=0;
logic         stall_packet_length=0;
logic [63:0]  packet_circlr_buf[2];
logic  [7:0]  tkeep_r=0;
logic [31:0]  packet_time_us=0;

//-----------------------------------------------------------------------------
// AXI side logic. Use to read/write the RAM on Port A
//-----------------------------------------------------------------------------
// Write logic
always @(posedge s_axi_aclk) begin
  
  dij_data_wr_pls_1  <= 1'd0;
  dij_data_wr_pls_2  <= 1'd0;
  wea                <= 1'd0;
  dij_data_rd        <= douta;
  dij_address_read_r <= addra;

  // Create diff strobes on the R/W address registers
  // Bit crude, biut works mostly.
  dij_address_write_d    <= dij_address_write;
  dij_address_read_d     <= dij_address_read;
  dij_address_write_diff <= dij_address_write_d != dij_address_write;
  dij_address_read_diff  <= dij_address_read_d  != dij_address_read;

  // Write pulse managment
  if (dij_data_wr_pls) begin
    dij_data_wr_pls_1 <= dij_data_wr_pls;
  end
  if (dij_data_wr_pls_1) begin
    dij_data_wr_pls_2 <= dij_data_wr_pls_1;
    wea               <= 1'd1;
  end

  // ddra managment
  if (dij_data_wr_pls_2 | dij_data_rd_pls) begin
    addra <= addra + 'd1;
  end else begin
    if (dij_address_write_diff) begin
      addra <= dij_address_write;
    end else begin
      if (dij_address_read_diff) begin
        addra <= dij_address_read;
      end 
    end
  end
  
end

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
roe_framer_v2_2_tdpram_2clk #(

  .C_DL_SS_DATA       (memory_word_depth),  // 
  .C_MEM_INIT_FILE    (memory_init_file),  // wf0.mem
  .P_DL_SS_DATA_WIDTH (64      ),  // 
  .P_MEMORY_PRIMITIVE ("block" ),  // 
  .P_READ_LATENCY_A   (2       ),  // 
  .P_READ_LATENCY_B   (2       )   //

  ) data_store_i (

  .addra   (addra      ),
  .dina    (dij_data_wr),
  .wea     (wea        ),
  .douta   (douta      ),
  .addrb   (addrb      ),
  .doutb   (doutb      ),
  .clka    (s_axi_aclk ),
  .clkb    (s_axis_aclk),
  .rsta    (1'd0), // 
  .rstb    (1'd0), // 
  .ena     (1'd1), // Tie high to use simply
  .enb     (1'd1), // Tie high to use simply
  .regcea  (1'd1), // Tie high to use simply
  .regceb  (1'd1), // Tie high to use simply
  .sleep   (1'd0)  // Tie low to use simply

);

//-----------------------------------------------------------------------------
// Main PCAP read logic
// TODO : Add full tready support, mitigate with packet fifo on output for now
//-----------------------------------------------------------------------------
always @(posedge s_axis_aclk) begin

  if (!djictl_start_when_ready) begin

    rd_sm         <= IDLE;

  end else begin

    // Default state for all these signals
    rd_sm         <= rd_sm;
    // Main Case
    case(rd_sm)

      // ----------------------------------------------------------------------
      // Wait
      IDLE : begin
        if(djictl_start_when_ready) begin
          rd_sm <= ARM;
          addrb <= djictl_start_address;
        end
      end

    endcase // dl_eth_to_ss_arb_state

  end

end

endmodule



//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
module torsink_sv #(
    parameter integer  C_S_AXI_ADDR_WIDTH = 16 ,
    parameter memory_word_depth           = 1024

  ) (

  input  logic [63:0]                     s0_data_tdata  ,
  input  logic  [7:0]                     s0_data_tkeep  ,
  input  logic                            s0_data_tvalid ,
  input  logic                            s0_data_tlast  ,
  input  logic                            s0_data_tuser  ,
  output logic                            s0_data_tready ,
                   
  input  wire                             s_axis_aresetn ,
  input  wire                             s_axis_aclk    ,
  input  wire                             s_axi_aclk     ,


   input                                  s_axi_aresetn  ,
   input       [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr   ,
   input                                  s_axi_awvalid  ,
   output                                 s_axi_awready  ,
   input       [31:0]                     s_axi_wdata    ,
   input                                  s_axi_wvalid   ,
   output                                 s_axi_wready   ,
   output      [1:0]                      s_axi_bresp    ,
   output                                 s_axi_bvalid   ,
   input                                  s_axi_bready   ,
   input       [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr   ,
   input                                  s_axi_arvalid  ,
   output                                 s_axi_arready  ,
   output      [31:0]                     s_axi_rdata    ,
   output      [1:0]                      s_axi_rresp    ,
   output                                 s_axi_rvalid   ,
   input                                  s_axi_rready

);

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
localparam integer  BANK_DECODE_HIGH_BIT           = 15;
localparam integer  BANK_DECODE_HIGH_LOW           = 12;
localparam integer  C_S_TIMEOUT_WIDTH              = 12;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
logic [15:0]                  radio_us_count;
logic [31:0]                  dij_ram_locations         ;
logic [19:0]                  dij_address_write_r       ;
logic [19:0]                  dij_address_read_r        ;
logic [63:0]                  dij_data_rd               ;
logic [19:0]                  dij_address_write         ;
logic [19:0]                  dij_address_read          ;
logic [63:0]                  dij_data_wr               ;
logic                         dij_data_msby_wr_strb     ;
logic                         dij_data_msby_rd_strb     ;
logic                         djictl_start_when_ready   ;
logic                         djictl_reset_data_injector;
logic                         djictl_loop_enable        ;        
logic [19:0]                  djictl_start_address      ;
logic [19:0]                  djictl_end_address        ;
logic                         timeout_enable            ;
logic [C_S_TIMEOUT_WIDTH-1:0] timeout_value             ;

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------

torwave_regif #(

.C_S_AXI_ADDR_WIDTH  (C_S_AXI_ADDR_WIDTH  ),
.BANK_DECODE_HIGH_BIT(BANK_DECODE_HIGH_BIT),
.BANK_DECODE_HIGH_LOW(BANK_DECODE_HIGH_LOW),
.C_S_TIMEOUT_WIDTH   (C_S_TIMEOUT_WIDTH   )
 
) reg_if (
 
   .timeout_enable_in         (timeout_enable            ),
   .timeout_value_in          (timeout_value             ),
   .timeout_enable            (timeout_enable            ),
   .timeout_value             (timeout_value             ),
   .gpio_cdc_dipstatus        (8'd0                      ),

   .dij_ram_locations         (dij_ram_locations         ),
   .dij_address_write         (dij_address_write         ),
   .dij_address_write_r       (dij_address_write_r       ),
   .dij_address_read          (dij_address_read          ),
   .dij_address_read_r        (dij_address_read_r        ),
   .dij_bank_select           (dij_bank_select           ),
   .dij_data_wr_63_0          (dij_data_wr               ),
   .dij_data_rd_63_0          (dij_data_rd               ),

   .dij_data_msby_wr_strb     (dij_data_msby_wr_strb     ),
   .dij_data_msby_rd_strb     (dij_data_msby_rd_strb     ),
   .djictl_start_when_ready   (djictl_start_when_ready   ),
   .djictl_reset_data_injector(djictl_reset_data_injector),
   .djictl_loop_enable        (djictl_loop_enable        ),
   .djictl_start_address      (djictl_start_address      ),
   .djictl_end_address        (djictl_end_address        ),
   .djictl_lane_enable        (djictl_lane_enable        ),

   .data_clk                  (s_axis_aclk               ),
   .data_resetn               (s_axis_aresetn            ),
   .s_axi_aclk                (s_axi_aclk                ),
   .s_axi_aresetn             (s_axi_aresetn             ),
   .s_axi_awaddr              (s_axi_awaddr              ),
   .s_axi_awvalid             (s_axi_awvalid             ),
   .s_axi_awready             (s_axi_awready             ),
   .s_axi_wdata               (s_axi_wdata               ),
   .s_axi_wvalid              (s_axi_wvalid              ),
   .s_axi_wready              (s_axi_wready              ),
   .s_axi_bresp               (s_axi_bresp               ),
   .s_axi_bvalid              (s_axi_bvalid              ),
   .s_axi_bready              (s_axi_bready              ),
   .s_axi_araddr              (s_axi_araddr              ),
   .s_axi_arvalid             (s_axi_arvalid             ),
   .s_axi_arready             (s_axi_arready             ),
   .s_axi_rdata               (s_axi_rdata               ),
   .s_axi_rresp               (s_axi_rresp               ),
   .s_axi_rvalid              (s_axi_rvalid              ),
   .s_axi_rready              (s_axi_rready              )

);

//-----------------------------------------------------------------------------
// 
//-----------------------------------------------------------------------------
torsink_unit #(
    .memory_init_file ("none"),
    .memory_word_depth(memory_word_depth)
) dsg_0 (

  // Generator specific
  .s_data_tdata              (s0_data_tdata             ),
  .s_data_tkeep              (s0_data_tkeep             ),
  .s_data_tvalid             (s0_data_tvalid            ),
  .s_data_tlast              (s0_data_tlast             ),
  .s_data_tuser              (s0_data_tuser             ),
  .s_data_tready             (s0_data_tready            ),

  .dij_ram_locations         (dij_ram_locations         ),
  .dij_address_write_r       (dij_address_write_r       ),
  .dij_address_read_r        (dij_address_read_r        ),
  .dij_data_rd               (dij_data_rd               ),
  .dij_address_write         (dij_address_write         ),
  .dij_address_read          (dij_address_read          ),
  .dij_data_wr               (dij_data_wr               ),
  .dij_data_wr_pls           (dij_data_msby_wr_strb     ),
  .dij_data_rd_pls           (dij_data_msby_rd_strb     ),

  .djictl_start_address      (djictl_start_address      ),
  .djictl_end_address        (djictl_end_address        ),

  // Common signals
  .djictl_start_when_ready   (djictl_start_when_ready   ),
  .djictl_reset_data_injector(djictl_reset_data_injector),
  .djictl_loop_enable        (djictl_loop_enable        ),

  .s_axis_aresetn            (s_axis_aresetn            ),
  .s_axis_aclk               (s_axis_aclk               ),
  .s_axi_aclk                (s_axi_aclk                )

);

endmodule
** Warning: oran_radio_if_torwave_src.sv(87): (vlog-13314) Defaulting port '<protected>' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.
** Warning: oran_radio_if_torwave_src.sv(87): (vlog-13314) Defaulting port '<protected>' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

Top level modules:
End time: 11:12:27 on Aug 30,2021, Elapsed time: 0:00:00
Errors: 0, Warnings: 2
