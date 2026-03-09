// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "floo_noc/typedef.svh"

module tb_floo_robTMR;

  import floo_pkg::*;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  localparam int unsigned NumReads = 1000;
  localparam int unsigned NumWrites = 1000;

  localparam int unsigned NumSlaves = 4;

  logic clk, rst_n;

  // Function to generate a chimney config with a RoB
  function automatic chimney_cfg_t gen_rob_chimney_cfg();
    chimney_cfg_t cfg = ChimneyDefaultCfg;
    cfg.BRoBType = SimpleRoB;
    cfg.BRoBSize = 64;
    cfg.RRoBType = NoRoB;
    cfg.RRoBSize = 64;
    return cfg;
  endfunction

  // Default chimney config with RoB for testing
  localparam chimney_cfg_t RoBChimneyCfg = gen_rob_chimney_cfg();
  typedef logic [$clog2(RoBChimneyCfg.BRoBSize)-1:0] rob_idx_t;

  typedef logic [1:0] x_bits_t;
  typedef logic [1:0] y_bits_t;
  `FLOO_TYPEDEF_XY_NODE_ID_T(id_t, x_bits_t, y_bits_t, logic)
  `FLOO_TYPEDEF_HDR_T(hdr_t, id_t, id_t, axi_ch_e, rob_idx_t)
  `FLOO_TYPEDEF_AXI_FROM_CFG(axi, floo_test_pkg::AxiCfg)
  `FLOO_TYPEDEF_AXI_CHAN_ALL(axi, req, rsp, axi_in, floo_test_pkg::AxiCfg, hdr_t)
  `FLOO_TYPEDEF_AXI_LINK_ALL(req, rsp, req, rsp)

  axi_in_req_t  node_mst_req;
  axi_in_rsp_t node_mst_rsp;

  axi_out_req_t  [NumDirections-1:0] node_slv_req;
  axi_out_rsp_t [NumDirections-1:0] node_slv_rsp;
  axi_in_req_t  [NumDirections-1:0] node_slv_req_id_mapped;
  axi_in_rsp_t [NumDirections-1:0] node_slv_rsp_id_mapped;

  for (genvar i = 0; i < NumDirections; i++) begin : gen_dir
    `AXI_ASSIGN_REQ_STRUCT(node_slv_req_id_mapped[i], node_slv_req[i])
    `AXI_ASSIGN_RESP_STRUCT(node_slv_rsp_id_mapped[i], node_slv_rsp[i])
  end

  floo_req_t [NumDirections-1:0] chimney_req_out, chimney_req_in;
  floo_rsp_t [NumDirections-1:0] chimney_rsp_out, chimney_rsp_in;
  floo_req_chan_t [NumDirections-1:0] chimney_req_out_chan, chimney_req_in_chan;
  floo_req_chan_t [NumDirections-1:0] chimney_req_out_chanA, chimney_req_out_chanB, chimney_req_out_chanC, chimney_req_in_chanA, chimney_req_in_chanB, chimney_req_in_chanC;
  floo_rsp_chan_t [NumDirections-1:0] chimney_rsp_out_chan, chimney_rsp_in_chan;
  floo_rsp_chan_t [NumDirections-1:0] chimney_rsp_out_chanA, chimney_rsp_out_chanB, chimney_rsp_out_chanC, chimney_rsp_in_chanA, chimney_rsp_in_chanB, chimney_rsp_in_chanC;

  logic [NumDirections-1:0]      chimney_req_out_valid, chimney_req_out_ready;
  logic [NumDirections-1:0]      chimney_req_out_validA, chimney_req_out_validB, chimney_req_out_validC, chimney_req_out_readyA, chimney_req_out_readyB, chimney_req_out_readyC;
  logic [NumDirections-1:0]      chimney_rsp_out_valid, chimney_rsp_out_ready;
  logic [NumDirections-1:0]      chimney_rsp_out_validA, chimney_rsp_out_validB, chimney_rsp_out_validC, chimney_rsp_out_readyA, chimney_rsp_out_readyB, chimney_rsp_out_readyC;
  logic [NumDirections-1:0]      chimney_req_in_valid, chimney_req_in_ready;
  logic [NumDirections-1:0]      chimney_req_in_validA, chimney_req_in_validB, chimney_req_in_validC, chimney_req_in_readyA, chimney_req_in_readyB, chimney_req_in_readyC;
  logic [NumDirections-1:0]      chimney_rsp_in_valid, chimney_rsp_in_ready;
  logic [NumDirections-1:0]      chimney_rsp_in_validA, chimney_rsp_in_validB, chimney_rsp_in_validC, chimney_rsp_in_readyA, chimney_rsp_in_readyB, chimney_rsp_in_readyC;

  for (genvar i = 0; i < floo_pkg::NumDirections; i++) begin : gen_directions
    assign chimney_req_out_chan[i] = chimney_req_out[i].req;
    assign chimney_rsp_out_chan[i] = chimney_rsp_out[i].rsp;
    assign chimney_req_in[i].req = chimney_req_in_chan[i];
    assign chimney_rsp_in[i].rsp = chimney_rsp_in_chan[i];
    assign chimney_req_out_valid[i] = chimney_req_out[i].valid;
    assign chimney_req_out_ready[i] = chimney_req_out[i].ready;
    assign chimney_rsp_out_valid[i] = chimney_rsp_out[i].valid;
    assign chimney_rsp_out_ready[i] = chimney_rsp_out[i].ready;
    assign chimney_req_in[i].valid = chimney_req_in_valid[i];
    assign chimney_req_in[i].ready = chimney_req_in_ready[i];
    assign chimney_rsp_in[i].valid = chimney_rsp_in_valid[i];
    assign chimney_rsp_in[i].ready = chimney_rsp_in_ready[i];
  end

  // fanout
  assign chimney_req_out_chanA = chimney_req_out_chan;
  assign chimney_req_out_chanB = chimney_req_out_chan;
  assign chimney_req_out_chanC = chimney_req_out_chan;
  assign chimney_req_out_validA = chimney_req_out_valid;
  assign chimney_req_out_validB = chimney_req_out_valid;
  assign chimney_req_out_validC = chimney_req_out_valid;
  assign chimney_req_out_readyA = chimney_req_out_ready;
  assign chimney_req_out_readyB = chimney_req_out_ready;
  assign chimney_req_out_readyC = chimney_req_out_ready;
  assign chimney_rsp_out_chanA = chimney_rsp_out_chan;
  assign chimney_rsp_out_chanB = chimney_rsp_out_chan;
  assign chimney_rsp_out_chanC = chimney_rsp_out_chan;
  assign chimney_rsp_out_validA = chimney_rsp_out_valid;
  assign chimney_rsp_out_validB = chimney_rsp_out_valid;
  assign chimney_rsp_out_validC = chimney_rsp_out_valid;
  assign chimney_rsp_out_readyA = chimney_rsp_out_ready;
  assign chimney_rsp_out_readyB = chimney_rsp_out_ready;
  assign chimney_rsp_out_readyC = chimney_rsp_out_ready;
  // vote
  assign chimney_req_in_chan = (chimney_req_in_chanA & chimney_req_in_chanB) | (chimney_req_in_chanB & chimney_req_in_chanC) | (chimney_req_in_chanA & chimney_req_in_chanC);
  assign chimney_req_in_valid = (chimney_req_in_validA & chimney_req_in_validB) | (chimney_req_in_validB & chimney_req_in_validC) | (chimney_req_in_validA & chimney_req_in_validC);
  assign chimney_req_in_ready = (chimney_req_in_readyA & chimney_req_in_readyB) | (chimney_req_in_readyB & chimney_req_in_readyC) | (chimney_req_in_readyA & chimney_req_in_readyC);
  assign chimney_rsp_in_chan = (chimney_rsp_in_chanA & chimney_rsp_in_chanB) | (chimney_rsp_in_chanB & chimney_rsp_in_chanC) | (chimney_rsp_in_chanA & chimney_rsp_in_chanC);
  assign chimney_rsp_in_valid = (chimney_rsp_in_validA & chimney_rsp_in_validB) | (chimney_rsp_in_validB & chimney_rsp_in_validC) | (chimney_rsp_in_validA & chimney_rsp_in_validC);
  assign chimney_rsp_in_ready = (chimney_rsp_in_readyA & chimney_rsp_in_readyB) | (chimney_rsp_in_readyB & chimney_rsp_in_readyC) | (chimney_rsp_in_readyA & chimney_rsp_in_readyC);

  logic [1:0] end_of_sim;

  clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  ////////////////////
  //  Local Master  //
  ////////////////////

  id_t [floo_pkg::NumDirections-1:0] xy_id;
  assign xy_id[floo_pkg::Eject] = '{x: 2'd1, y: 2'd1, port_id: 1'd0};

  typedef struct packed {
    int unsigned  idx;
    axi_addr_t start_addr;
    axi_addr_t end_addr;
  } node_addr_region_t;

  localparam int unsigned NumAddrRegions = 4;
  localparam node_addr_region_t [NumAddrRegions-1:0] AddrRegions = '{
    '{idx: North, start_addr: 32'h00210000, end_addr: 32'h0021FFFF},  // North
    '{idx: East, start_addr: 32'h00120000, end_addr: 32'h0012FFFF},   // East
    '{idx: South, start_addr: 32'h00010000, end_addr: 32'h0001FFFF},  // South
    '{idx: West, start_addr: 32'h00100000, end_addr: 32'h0010FFFF}    // West
  };

  floo_axi_test_node #(
    .AxiCfg         ( floo_test_pkg::AxiCfg ),
    .mst_req_t      ( axi_in_req_t          ),
    .mst_rsp_t      ( axi_in_rsp_t          ),
    .slv_req_t      ( axi_out_req_t         ),
    .slv_rsp_t      ( axi_out_rsp_t         ),
    .ApplTime       ( ApplTime              ),
    .TestTime       ( TestTime              ),
    .AxiMaxBurstLen ( 4                     ),
    .NumAddrRegions ( NumAddrRegions        ),
    .rule_t         ( node_addr_region_t    ),
    .AddrRegions    ( AddrRegions           ),
    .NumReads       ( NumReads              ),
    .NumWrites      ( NumWrites             )
  ) i_test_node_0 (
    .clk_i          ( clk                           ),
    .rst_ni         ( rst_n                         ),
    .mst_port_req_o ( node_mst_req                  ),
    .mst_port_rsp_i ( node_mst_rsp                  ),
    .slv_port_req_i ( node_slv_req[floo_pkg::Eject] ),
    .slv_port_rsp_o ( node_slv_rsp[floo_pkg::Eject] ),
    .end_of_sim     ( end_of_sim[0]                 )
  );

  axi_dumper #(
    .BusName    ( "MasterAxi"   ),
    .LogAW      ( 1'b0          ),
    .LogAR      ( 1'b0          ),
    .LogW       ( 1'b0          ),
    .LogB       ( 1'b0          ),
    .LogR       ( 1'b0          ),
    .axi_req_t  ( axi_in_req_t  ),
    .axi_resp_t ( axi_in_rsp_t  )
  ) i_axi_dumper (
    .clk_i      ( clk           ),
    .rst_ni     ( rst_n         ),
    .axi_req_i  ( node_mst_req  ),
    .axi_resp_i ( node_mst_rsp  )
  );

  floo_axi_chimney #(
    .AxiCfg             ( floo_test_pkg::AxiCfg         ),
    .ChimneyCfg         ( RoBChimneyCfg                 ), // Needs RoB
    .RouteCfg           ( floo_test_pkg::RouteCfg       ),
    .AtopSupport        ( floo_test_pkg::AtopSupport    ),
    .MaxAtomicTxns      ( floo_test_pkg::MaxAtomicTxns  ),
    .axi_in_req_t       ( axi_in_req_t                  ),
    .axi_in_rsp_t       ( axi_in_rsp_t                  ),
    .axi_out_req_t      ( axi_out_req_t                 ),
    .axi_out_rsp_t      ( axi_out_rsp_t                 ),
    .rob_idx_t          ( rob_idx_t                     ),
    .id_t               ( id_t                          ),
    .hdr_t              ( hdr_t                         ),
    .floo_req_t         ( floo_req_t                    ),
    .floo_rsp_t         ( floo_rsp_t                    )
  ) i_floo_axi_chimney (
    .clk_i          ( clk                               ),
    .rst_ni         ( rst_n                             ),
    .sram_cfg_i     ( '0                                ),
    .test_enable_i  ( 1'b0                              ),
    .axi_in_req_i   ( node_mst_req                      ),
    .axi_in_rsp_o   ( node_mst_rsp                      ),
    .axi_out_req_o  ( node_slv_req[floo_pkg::Eject]     ),
    .axi_out_rsp_i  ( node_slv_rsp[floo_pkg::Eject]     ),
    .id_i           ( xy_id[floo_pkg::Eject]            ),
    .route_table_i  ( '0                                ),
    .floo_req_o     ( chimney_req_out[floo_pkg::Eject]  ),
    .floo_rsp_o     ( chimney_rsp_out[floo_pkg::Eject]  ),
    .floo_req_i     ( chimney_req_in[floo_pkg::Eject]   ),
    .floo_rsp_i     ( chimney_rsp_in[floo_pkg::Eject]   )
  );

  floo_routerTMR #(
    .NumRoutes        ( floo_pkg::NumDirections ),
    .NumVirtChannels  ( 1                       ),
    .flit_t           ( floo_req_generic_flit_t ),
    .InFifoDepth      ( 2                       ),
    .RouteAlgo        ( floo_pkg::XYRouting     ),
    .id_t             ( id_t                    )
  ) i_floo_req_router (
    .clk_iA          ( clk                     ),
    .clk_iB          ( clk                     ),
    .clk_iC          ( clk                     ),
    .rst_niA         ( rst_n                   ),
    .rst_niB         ( rst_n                   ),
    .rst_niC         ( rst_n                   ),
    .test_enable_iA  ( 1'b0                    ),
    .test_enable_iB  ( 1'b0                    ),
    .test_enable_iC  ( 1'b0                    ),
    .xy_id_iA        ( xy_id[floo_pkg::Eject]  ),
    .xy_id_iB        ( xy_id[floo_pkg::Eject]  ),
    .xy_id_iC        ( xy_id[floo_pkg::Eject]  ),
    .id_route_map_iA ( '0                      ),
    .id_route_map_iB ( '0                      ),
    .id_route_map_iC ( '0                      ),
    .valid_iA        ( chimney_req_out_validA   ),
    .valid_iB        ( chimney_req_out_validB   ),
    .valid_iC        ( chimney_req_out_validC   ),
    .ready_oA        ( chimney_req_in_readyA    ),
    .ready_oB        ( chimney_req_in_readyB    ),
    .ready_oC        ( chimney_req_in_readyC    ),
    .data_iA         ( chimney_req_out_chanA    ),
    .data_iB         ( chimney_req_out_chanB    ),
    .data_iC         ( chimney_req_out_chanC    ),
    .valid_oA        ( chimney_req_in_validA    ),
    .valid_oB        ( chimney_req_in_validB    ),
    .valid_oC        ( chimney_req_in_validC    ),
    .ready_iA        ( chimney_req_out_readyA   ),
    .ready_iB        ( chimney_req_out_readyB   ),
    .ready_iC        ( chimney_req_out_readyC   ),
    .data_oA         ( chimney_req_in_chanA     ),
    .data_oB         ( chimney_req_in_chanB     ),
    .data_oC         ( chimney_req_in_chanC     ),
    .tmrErrorA       (),
    .tmrErrorB       (),
    .tmrErrorC       ()
  );

  floo_routerTMR #(
    .NumRoutes        ( floo_pkg::NumDirections ),
    .NumVirtChannels  ( 1                       ),
    .flit_t           ( floo_rsp_generic_flit_t ),
    .InFifoDepth      ( 2                       ),
    .RouteAlgo        ( floo_pkg::XYRouting     ),
    .id_t             ( id_t                    )
  ) i_floo_rsp_router (
    .clk_iA          ( clk                     ),
    .clk_iB          ( clk                     ),
    .clk_iC          ( clk                     ),
    .rst_niA         ( rst_n                   ),
    .rst_niB         ( rst_n                   ),
    .rst_niC         ( rst_n                   ),
    .test_enable_iA  ( 1'b0                    ),
    .test_enable_iB  ( 1'b0                    ),
    .test_enable_iC  ( 1'b0                    ),
    .xy_id_iA        ( xy_id[floo_pkg::Eject]  ),
    .xy_id_iB        ( xy_id[floo_pkg::Eject]  ),
    .xy_id_iC        ( xy_id[floo_pkg::Eject]  ),
    .id_route_map_iA ( '0                      ),
    .id_route_map_iB ( '0                      ),
    .id_route_map_iC ( '0                      ),
    .valid_iA        ( chimney_rsp_out_validA   ),
    .valid_iB        ( chimney_rsp_out_validB   ),
    .valid_iC        ( chimney_rsp_out_validC   ),
    .ready_oA        ( chimney_rsp_in_readyA    ),
    .ready_oB        ( chimney_rsp_in_readyB    ),
    .ready_oC        ( chimney_rsp_in_readyC    ),
    .data_iA         ( chimney_rsp_out_chanA    ),
    .data_iB         ( chimney_rsp_out_chanB    ),
    .data_iC         ( chimney_rsp_out_chanC    ),
    .valid_oA        ( chimney_rsp_in_validA    ),
    .valid_oB        ( chimney_rsp_in_validB    ),
    .valid_oC        ( chimney_rsp_in_validC    ),
    .ready_iA        ( chimney_rsp_out_readyA   ),
    .ready_iB        ( chimney_rsp_out_readyB   ),
    .ready_iC        ( chimney_rsp_out_readyC   ),
    .data_oA         ( chimney_rsp_in_chanA     ),
    .data_oB         ( chimney_rsp_in_chanB     ),
    .data_oC         ( chimney_rsp_in_chanC     ),
    .tmrErrorA       (),
    .tmrErrorB       (),
    .tmrErrorC       ()
  );

  localparam floo_test_pkg::slave_type_e SlaveType[floo_pkg::NumDirections-1] = '{
    floo_test_pkg::FastSlave,
    floo_test_pkg::FastSlave,
    floo_test_pkg::SlowSlave,
    floo_test_pkg::MixedSlave
  };

  for (genvar i = North; i <= West; i++) begin : gen_slaves

    if (i == North) begin : gen_north
      assign xy_id[i] = '{x: 2'd1, y: 2'd2, port_id: 1'd0};
    end else if (i == South) begin : gen_south
      assign xy_id[i] = '{x: 2'd1, y: 2'd0, port_id: 1'd0};
    end else if (i == East) begin : gen_east
      assign xy_id[i] = '{x: 2'd2, y: 2'd1, port_id: 1'd0};
    end else if (i == West) begin : gen_west
      assign xy_id[i] = '{x: 2'd0, y: 2'd1, port_id: 1'd0};
    end

    floo_axi_chimney #(
      .AxiCfg         ( floo_test_pkg::AxiCfg         ),
      .ChimneyCfg     ( floo_test_pkg::ChimneyCfg     ), // Does not need RoB
      .RouteCfg       ( floo_test_pkg::RouteCfg       ),
      .AtopSupport    ( floo_test_pkg::AtopSupport    ),
      .MaxAtomicTxns  ( floo_test_pkg::MaxAtomicTxns  ),
      .axi_in_req_t   ( axi_in_req_t                  ),
      .axi_in_rsp_t   ( axi_in_rsp_t                  ),
      .axi_out_req_t  ( axi_out_req_t                 ),
      .axi_out_rsp_t  ( axi_out_rsp_t                 ),
      .rob_idx_t      ( rob_idx_t                     ),
      .id_t           ( id_t                          ),
      .hdr_t          ( hdr_t                         ),
      .floo_req_t     ( floo_req_t                    ),
      .floo_rsp_t     ( floo_rsp_t                    )
    ) i_floo_axi_chimney (
      .clk_i          ( clk                   ),
      .rst_ni         ( rst_n                 ),
      .sram_cfg_i     ( '0                    ),
      .test_enable_i  ( 1'b0                  ),
      .axi_in_req_i   ( '0                    ),
      .axi_in_rsp_o   (                       ),
      .axi_out_req_o  ( node_slv_req[i]       ),
      .axi_out_rsp_i  ( node_slv_rsp[i]       ),
      .id_i           ( xy_id[i]              ),
      .route_table_i  ( '0                    ),
      .floo_req_o     ( chimney_req_out[i]    ),
      .floo_rsp_o     ( chimney_rsp_out[i]    ),
      .floo_req_i     ( chimney_req_in[i]     ),
      .floo_rsp_i     ( chimney_rsp_in[i]     )
    );

    axi_dumper #(
      .BusName    ( $sformatf("Slave%0d", i)),
      .LogAW      ( 1'b0          ),
      .LogAR      ( 1'b0          ),
      .LogW       ( 1'b0          ),
      .LogB       ( 1'b0          ),
      .LogR       ( 1'b0          ),
      .axi_req_t  ( axi_in_req_t  ),
      .axi_resp_t ( axi_in_rsp_t  )
    ) i_axi_dumper (
      .clk_i      ( clk             ),
      .rst_ni     ( rst_n           ),
      .axi_req_i  ( node_slv_req[i] ),
      .axi_resp_i ( node_slv_rsp[i] )
    );

    floo_axi_rand_slave #(
      .AxiCfg       ( floo_test_pkg::AxiCfg ),
      .axi_req_t    ( axi_out_req_t         ),
      .axi_rsp_t    ( axi_out_rsp_t         ),
      .ApplTime     ( ApplTime              ),
      .TestTime     ( TestTime              ),
      .SlaveType    ( SlaveType[i]          ),
      .DstStartAddr ( 32'h0000_0000         ), // TODO: make this configurable
      .DstEndAddr   ( 32'h0000_8000         )
    ) i_test_node_1 (
      .clk_i              ( clk             ),
      .rst_ni             ( rst_n           ),
      .slv_port_req_i     ( node_slv_req[i] ),
      .slv_port_rsp_o     ( node_slv_rsp[i] ),
      .mon_mst_port_req_o (                 ),
      .mon_mst_port_rsp_o (                 )
    );

  end

  axi_reorder_compare #(
    .NumSlaves      ( NumSlaves                       ),
    .AxiIdWidth     ( floo_test_pkg::AxiCfg.InIdWidth ),
    .NumAddrRegions ( NumAddrRegions                  ),
    .addr_t         ( axi_addr_t                      ),
    .rule_t         ( node_addr_region_t              ),
    .AddrRegions    ( AddrRegions                     ),
    .aw_chan_t      ( axi_in_aw_chan_t                ),
    .w_chan_t       ( axi_in_w_chan_t                 ),
    .b_chan_t       ( axi_in_b_chan_t                 ),
    .ar_chan_t      ( axi_in_ar_chan_t                ),
    .r_chan_t       ( axi_in_r_chan_t                 ),
    .req_t          ( axi_in_req_t                    ),
    .rsp_t          ( axi_in_rsp_t                    ),
    .Verbose        ( 1'b0                            )
  ) i_axi_reorder_compare (
    .clk_i          ( clk                                 ),
    .rst_ni         ( rst_n                               ),
    .mon_mst_req_i  ( node_mst_req                        ),
    .mon_mst_rsp_i  ( node_mst_rsp                        ),
    .mon_slv_req_i  ( node_slv_req_id_mapped[West:North]  ),
    .mon_slv_rsp_i  ( node_slv_rsp_id_mapped[West:North]  ),
    .end_of_sim_o   ( end_of_sim[1]                       )
  );

  initial begin
    wait(&end_of_sim);
    $stop;
  end


endmodule
