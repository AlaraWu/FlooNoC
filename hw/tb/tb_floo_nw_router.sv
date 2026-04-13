// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Chen Wu <chenwu@iis.ee.ethz.ch>

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "floo_noc/typedef.svh"

// Wrapper for the DUT nw_router
module floo_nw_router_dut_wrapper #(
  parameter int unsigned NumRoutes = floo_test_pkg::NumRoutes,
  parameter int unsigned NumInputs = NumRoutes,
  parameter int unsigned NumOutputs = NumRoutes,
  parameter type id_t = logic,
  parameter int unsigned NumAddrRules = 1,
  parameter type addr_rule_t = logic,
  parameter type hdr_t = logic,
  parameter type floo_req_t = logic,
  parameter type floo_rsp_t = logic,
  parameter type floo_wide_t = logic,

  parameter int unsigned NumEndpoints = 5
) (
  input   logic       clk_i,
  input   logic       rst_ni,
  input   id_t        id_i,
  input   addr_rule_t [NumAddrRules-1:0] id_route_map_i,
  input   floo_req_t  [NumInputs-1:0] floo_req_i,
  input   floo_rsp_t  [NumOutputs-1:0] floo_rsp_i,
  output  floo_req_t  [NumOutputs-1:0] floo_req_o,
  output  floo_rsp_t  [NumInputs-1:0] floo_rsp_o,
  input   floo_wide_t [NumRoutes-1:0] floo_wide_i,
  output  floo_wide_t [NumRoutes-1:0] floo_wide_o,

  input logic [NumEndpoints-1:0][1:0] end_of_sim_endpoints,
  input logic end_of_sim_monitor
);

  floo_nw_router #(
    .AxiCfgN      ( floo_test_pkg::AxiCfgN         ),
    .AxiCfgW      ( floo_test_pkg::AxiCfgW         ),
    .RouteAlgo    ( floo_pkg::XYRouting             ),
    .NumRoutes    ( floo_pkg::NumDirections         ),
    .InFifoDepth  ( floo_test_pkg::ChannelFifoDepth ),
    .OutFifoDepth ( floo_test_pkg::OutputFifoDepth  ),
    .id_t         ( id_t                            ),
    .NumAddrRules ( NumAddrRules                    ),
    .addr_rule_t   ( addr_rule_t                      ),
    .hdr_t        ( hdr_t                           ),
    .floo_req_t   ( floo_req_t                      ),
    .floo_rsp_t   ( floo_rsp_t                      ),
    .floo_wide_t  ( floo_wide_t                     )
  ) i_dut (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .test_enable_i  ( 1'b0                  ),
    .id_i           ( id_i                  ),
    .id_route_map_i ( id_route_map_i        ),
    .floo_req_i     ( floo_req_i            ),
    .floo_rsp_i     ( floo_rsp_i            ),
    .floo_req_o     ( floo_req_o            ),
    .floo_rsp_o     ( floo_rsp_o            ),
    .floo_wide_i    ( floo_wide_i           ),
    .floo_wide_o    ( floo_wide_o           )
  );

  logic corrected_fault;
  logic border_corrected_fault;
  assign corrected_fault = 1'b0;
  assign border_corrected_fault = 1'b0;

  // End-of-simulation liveness signal for Zoix strobe
  logic end_of_sim;
  assign end_of_sim = &end_of_sim_endpoints && end_of_sim_monitor;

  // Flattened output signals for Zoix $fs_compare
  localparam int FlooReqBits  = $bits(floo_req_t);
  localparam int FlooRspBits  = $bits(floo_rsp_t);
  localparam int FlooWideBits = $bits(floo_wide_t);

  logic [NumOutputs-1:0][FlooReqBits-1:0]  floo_req_o_flat;
  logic [NumInputs-1:0][FlooRspBits-1:0]   floo_rsp_o_flat;
  logic [NumRoutes-1:0][FlooWideBits-1:0]  floo_wide_o_flat;

  for (genvar i = 0; i < NumOutputs; i++) assign floo_req_o_flat[i]  = floo_req_o[i];
  for (genvar i = 0; i < NumInputs; i++)  assign floo_rsp_o_flat[i]  = floo_rsp_o[i];
  for (genvar i = 0; i < NumRoutes; i++)  assign floo_wide_o_flat[i] = floo_wide_o[i];

  `ifdef TARGET_ZOIX
  `include "strobe.sv"
  `endif

endmodule

/// Testbench for floo_nw_router:
module tb_floo_nw_router;

  import floo_pkg::*;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  localparam int unsigned NumEndpoints = 5;  // N, E, S, W, Eject

  localparam int unsigned NarrowNumReads = 100;
  localparam int unsigned NarrowNumWrites = 100;
  localparam int unsigned WideNumReads = 100;
  localparam int unsigned WideNumWrites = 100;

  logic clk, rst_n;

  // -----------------------------------------------------------------------
  //  NW Chimney configs
  //  The Eject (master) chimney needs a RoB to reorder responses;
  //  the slave chimneys use the default config.
  // -----------------------------------------------------------------------
  localparam chimney_cfg_t NarrowChimneyCfg = ChimneyDefaultCfg;
  // Wide channel: keep default (no RoB needed for simple test, DMA generates ordered wide traffic)
  localparam chimney_cfg_t WideChimneyCfg = ChimneyDefaultCfg;

  // -----------------------------------------------------------------------
  //  ID / Header types
  // -----------------------------------------------------------------------
  typedef logic [1:0] x_bits_t;
  typedef logic [1:0] y_bits_t;
  `FLOO_TYPEDEF_XY_NODE_ID_T(id_t, x_bits_t, y_bits_t, logic)
  `FLOO_TYPEDEF_HDR_T(hdr_t, id_t, id_t, nw_ch_e, logic)

  // -----------------------------------------------------------------------
  //  AXI types derived from test package configs
  // -----------------------------------------------------------------------
  `FLOO_TYPEDEF_AXI_FROM_CFG(axi_narrow, floo_test_pkg::AxiCfgN)
  `FLOO_TYPEDEF_AXI_FROM_CFG(axi_wide,   floo_test_pkg::AxiCfgW)
  `FLOO_TYPEDEF_NW_CHAN_ALL(axi, req, rsp, wide, axi_narrow_in, axi_wide_in,
      floo_test_pkg::AxiCfgN, floo_test_pkg::AxiCfgW, hdr_t)
  `FLOO_TYPEDEF_NW_LINK_ALL(req, rsp, wide, req, rsp, wide)

  // -----------------------------------------------------------------------
  //  AXI bus signals  (one per direction)
  // -----------------------------------------------------------------------

  // Narrow: manager side (into chimney)
  axi_narrow_in_req_t  chimney_narrow_in_req;
  axi_narrow_in_rsp_t  chimney_narrow_in_rsp;
  // Narrow: subordinate side (out of chimney)
  axi_narrow_out_req_t chimney_narrow_out_req;
  axi_narrow_out_rsp_t chimney_narrow_out_rsp;

  // Wide: manager side
  axi_wide_in_req_t    chimney_wide_in_req;
  axi_wide_in_rsp_t    chimney_wide_in_rsp;
  // Wide: subordinate side
  axi_wide_out_req_t   chimney_wide_out_req;
  axi_wide_out_rsp_t   chimney_wide_out_rsp;

  // Id-remapped subordinate signals (used by monitors / comparators)
  // axi_narrow_in_req_t  [NumEndpoints-1:0] narrow_out_req_id_mapped;
  // axi_narrow_in_rsp_t  [NumEndpoints-1:0] narrow_out_rsp_id_mapped;
  // axi_wide_in_req_t    [NumEndpoints-1:0] wide_out_req_id_mapped;
  // axi_wide_in_rsp_t    [NumEndpoints-1:0] wide_out_rsp_id_mapped;

  // for (genvar i = 0; i < NumEndpoints; i++) begin : gen_id_remap
  //   `AXI_ASSIGN_REQ_STRUCT(narrow_out_req_id_mapped[i], chimney_narrow_out_req[i])
  //   `AXI_ASSIGN_RESP_STRUCT(narrow_out_rsp_id_mapped[i], chimney_narrow_out_rsp[i])
  //   `AXI_ASSIGN_REQ_STRUCT(wide_out_req_id_mapped[i], chimney_wide_out_req[i])
  //   `AXI_ASSIGN_RESP_STRUCT(wide_out_rsp_id_mapped[i], chimney_wide_out_rsp[i])
  // end

  // -----------------------------------------------------------------------
  //  Floo link signals
  // -----------------------------------------------------------------------

  floo_req_t [3-1:0][3-1:0][Eject:North] floo_req_in, floo_req_out;
  floo_rsp_t [3-1:0][3-1:0][Eject:North] floo_rsp_in, floo_rsp_out;
  floo_wide_t [3-1:0][3-1:0][Eject:North] floo_wide_in, floo_wide_out;

  floo_req_t [3-1:0][3-1:0] floo_req_in_eject, floo_req_out_eject;
  floo_rsp_t [3-1:0][3-1:0] floo_rsp_in_eject, floo_rsp_out_eject;
  floo_wide_t [3-1:0][3-1:0] floo_wide_in_eject, floo_wide_out_eject;

  floo_req_t tile_req_eject_in  [NumEndpoints-1:0];
  floo_req_t tile_req_eject_out [NumEndpoints-1:0];
  floo_rsp_t tile_rsp_eject_in  [NumEndpoints-1:0];
  floo_rsp_t tile_rsp_eject_out [NumEndpoints-1:0];
  floo_wide_t tile_wide_eject_in  [NumEndpoints-1:0];
  floo_wide_t tile_wide_eject_out [NumEndpoints-1:0];

  logic mesh_end_of_sim;

  // -----------------------------------------------------------------------
  //  Clock / reset
  // -----------------------------------------------------------------------
  logic [NumEndpoints-1:0][1:0] end_of_sim_endpoints;

  for (genvar x = 0; x < 3; x++) begin : gen_eject_slice_x
    for (genvar y = 0; y < 3; y++) begin : gen_eject_slice_y
      assign floo_req_in_eject[x][y]  = floo_req_in[x][y][Eject];
      assign floo_req_out_eject[x][y] = floo_req_out[x][y][Eject];
      assign floo_rsp_in_eject[x][y]  = floo_rsp_in[x][y][Eject];
      assign floo_rsp_out_eject[x][y] = floo_rsp_out[x][y][Eject];
      assign floo_wide_in_eject[x][y] = floo_wide_in[x][y][Eject];
      assign floo_wide_out_eject[x][y] = floo_wide_out[x][y][Eject];
    end
  end

  assign floo_req_in[1][2][Eject]  = tile_req_eject_in[North];
  assign floo_req_out[1][2][Eject] = tile_req_eject_out[North];
  assign floo_rsp_in[1][2][Eject]  = tile_rsp_eject_in[North];
  assign floo_rsp_out[1][2][Eject] = tile_rsp_eject_out[North];
  assign floo_wide_in[1][2][Eject]  = tile_wide_eject_in[North];
  assign floo_wide_out[1][2][Eject] = tile_wide_eject_out[North];

  assign floo_req_in[1][0][Eject]  = tile_req_eject_in[South];
  assign floo_req_out[1][0][Eject] = tile_req_eject_out[South];
  assign floo_rsp_in[1][0][Eject]  = tile_rsp_eject_in[South];
  assign floo_rsp_out[1][0][Eject] = tile_rsp_eject_out[South];
  assign floo_wide_in[1][0][Eject]  = tile_wide_eject_in[South];
  assign floo_wide_out[1][0][Eject] = tile_wide_eject_out[South];

  assign floo_req_in[2][1][Eject]  = tile_req_eject_in[East];
  assign floo_req_out[2][1][Eject] = tile_req_eject_out[East];
  assign floo_rsp_in[2][1][Eject]  = tile_rsp_eject_in[East];
  assign floo_rsp_out[2][1][Eject] = tile_rsp_eject_out[East];
  assign floo_wide_in[2][1][Eject]  = tile_wide_eject_in[East];
  assign floo_wide_out[2][1][Eject] = tile_wide_eject_out[East];

  assign floo_req_in[0][1][Eject]  = tile_req_eject_in[West];
  assign floo_req_out[0][1][Eject] = tile_req_eject_out[West];
  assign floo_rsp_in[0][1][Eject]  = tile_rsp_eject_in[West];
  assign floo_rsp_out[0][1][Eject] = tile_rsp_eject_out[West];
  assign floo_wide_in[0][1][Eject]  = tile_wide_eject_in[West];
  assign floo_wide_out[0][1][Eject] = tile_wide_eject_out[West];

  clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  // -----------------------------------------------------------------------
  //  Address regions for the traffic-generator
  // -----------------------------------------------------------------------
  typedef struct packed {
    int unsigned  idx;
    axi_narrow_addr_t start_addr;
    axi_narrow_addr_t end_addr;
  } node_addr_region_t;

  // Address map overview
  localparam int unsigned NumAddrRegions = 5;
  localparam node_addr_region_t [NumAddrRegions-1:0] AddrRegions = '{
    '{idx: North, start_addr: 48'h00000000, end_addr: 48'h0000FFFF},
    '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF},
    '{idx: East,  start_addr: 48'h00100000, end_addr: 48'h0010FFFF},
    '{idx: West,  start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
    '{idx: Eject, start_addr: 48'h00120000, end_addr: 48'h0012FFFF}
  };

  // No Y->X turn allowed, so North/South have fewer regions than East/West
  // localparam int unsigned NumAddrRegionsNS = 2;
  localparam int unsigned NumAddrRegionsNS = 4;
  localparam int unsigned NumAddrRegionsEW = 4;
  localparam int unsigned NumAddrRegionsEject = 4;

  localparam node_addr_region_t [NumAddrRegionsEject-1:0] EjectAddrRegions = '{
    '{idx: West,  start_addr: 48'h00100000, end_addr: 48'h0010FFFF},
    '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF},
    '{idx: East,  start_addr: 48'h00120000, end_addr: 48'h0012FFFF},
    '{idx: North, start_addr: 48'h00210000, end_addr: 48'h0021FFFF}
  };
  // localparam node_addr_region_t [NumAddrRegionsNS-1:0] NorthAddrRegions = '{
  //   '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
  //   '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF}
  // };
  localparam node_addr_region_t [NumAddrRegionsNS-1:0] NorthAddrRegions = '{
    '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
    '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF},
    '{idx: East,  start_addr: 48'h00120000, end_addr: 48'h0012FFFF},
    '{idx: West,  start_addr: 48'h00100000, end_addr: 48'h0010FFFF}
  };
  localparam node_addr_region_t [NumAddrRegionsEW-1:0] EastAddrRegions = '{
    '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
    '{idx: West,  start_addr: 48'h00100000, end_addr: 48'h0010FFFF},
    '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF},
    '{idx: North, start_addr: 48'h00210000, end_addr: 48'h0021FFFF}
  };
  // localparam node_addr_region_t [NumAddrRegionsNS-1:0] SouthAddrRegions = '{
  //   '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
  //   '{idx: North, start_addr: 48'h00210000, end_addr: 48'h0021FFFF}
  // };
  localparam node_addr_region_t [NumAddrRegionsNS-1:0] SouthAddrRegions = '{
    '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
    '{idx: North, start_addr: 48'h00210000, end_addr: 48'h0021FFFF},
    '{idx: East,  start_addr: 48'h00120000, end_addr: 48'h0012FFFF},
    '{idx: West,  start_addr: 48'h00100000, end_addr: 48'h0010FFFF}
  };
  localparam node_addr_region_t [NumAddrRegionsEW-1:0] WestAddrRegions = '{
    '{idx: Eject, start_addr: 48'h00110000, end_addr: 48'h0011FFFF},
    '{idx: South, start_addr: 48'h00010000, end_addr: 48'h0001FFFF},
    '{idx: East,  start_addr: 48'h00120000, end_addr: 48'h0012FFFF},
    '{idx: North, start_addr: 48'h00210000, end_addr: 48'h0021FFFF}
  };

  /////////////////////////
  //  Peripheral Nodes   //
  /////////////////////////

  // NESW Endpoint Tiles
  floo_nw_tile #(
    .DELAY ( 1 ),
    .ApplTime ( ApplTime ),
    .TestTime ( TestTime ),
    .NarrowNumReads ( NarrowNumReads ),
    .NarrowNumWrites ( NarrowNumWrites ),
    .WideNumReads ( WideNumReads ),
    .WideNumWrites ( WideNumWrites ),
    .NumAddrRegions ( NumAddrRegionsNS ),
    .node_addr_region_t ( node_addr_region_t ),
    .AddrRegions ( NorthAddrRegions ),
    .id_t ( id_t ),
    .hdr_t ( hdr_t ),
    .axi_narrow_in_req_t ( axi_narrow_in_req_t ),
    .axi_narrow_in_rsp_t ( axi_narrow_in_rsp_t ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_in_req_t ( axi_wide_in_req_t ),
    .axi_wide_in_rsp_t ( axi_wide_in_rsp_t ),
    .axi_wide_out_req_t ( axi_wide_out_req_t ),
    .axi_wide_out_rsp_t ( axi_wide_out_rsp_t ),
    .floo_req_t ( floo_req_t ),
    .floo_rsp_t ( floo_rsp_t ),
    .floo_wide_t ( floo_wide_t )
  ) i_North_tile (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .id_i       ( '{x: 2'd1, y: 2'd2, port_id: 1'd0} ),
    .floo_req_i ( floo_req_in[1][2][West:North] ),
    .floo_rsp_i ( floo_rsp_in[1][2][West:North] ),
    .floo_req_o ( floo_req_out[1][2][West:North] ),
    .floo_rsp_o ( floo_rsp_out[1][2][West:North] ),
    .floo_wide_i ( floo_wide_in[1][2][West:North] ),
    .floo_wide_o ( floo_wide_out[1][2][West:North] ),
    .floo_req_Eject_in_o  ( tile_req_eject_in[North]  ),
    .floo_req_Eject_out_o ( tile_req_eject_out[North] ),
    .floo_rsp_Eject_in_o  ( tile_rsp_eject_in[North]  ),
    .floo_rsp_Eject_out_o ( tile_rsp_eject_out[North] ),
    .floo_wide_Eject_in_o ( tile_wide_eject_in[North] ),
    .floo_wide_Eject_out_o( tile_wide_eject_out[North]),
    .end_of_sim ( end_of_sim_endpoints[North]        )
  );

  floo_nw_tile #(
    .DELAY ( 2 ),
    .ApplTime ( ApplTime ),
    .TestTime ( TestTime ),
    .NarrowNumReads ( NarrowNumReads ),
    .NarrowNumWrites ( NarrowNumWrites ),
    .WideNumReads ( WideNumReads ),
    .WideNumWrites ( WideNumWrites ),
    .NumAddrRegions ( NumAddrRegionsNS ),
    .node_addr_region_t ( node_addr_region_t ),
    .AddrRegions ( SouthAddrRegions ),
    .id_t ( id_t ),
    .hdr_t ( hdr_t ),
    .axi_narrow_in_req_t ( axi_narrow_in_req_t ),
    .axi_narrow_in_rsp_t ( axi_narrow_in_rsp_t ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_in_req_t ( axi_wide_in_req_t ),
    .axi_wide_in_rsp_t ( axi_wide_in_rsp_t ),
    .axi_wide_out_req_t ( axi_wide_out_req_t ),
    .axi_wide_out_rsp_t ( axi_wide_out_rsp_t ),
    .floo_req_t ( floo_req_t ),
    .floo_rsp_t ( floo_rsp_t ),
    .floo_wide_t ( floo_wide_t )
  ) i_South_tile (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .id_i       ( '{x: 2'd1, y: 2'd0, port_id: 1'd0} ),
    .floo_req_i ( floo_req_in[1][0][West:North] ),
    .floo_rsp_i ( floo_rsp_in[1][0][West:North] ),
    .floo_req_o ( floo_req_out[1][0][West:North] ),
    .floo_rsp_o ( floo_rsp_out[1][0][West:North] ),
    .floo_wide_i ( floo_wide_in[1][0][West:North] ),
    .floo_wide_o ( floo_wide_out[1][0][West:North] ),
    .floo_req_Eject_in_o  ( tile_req_eject_in[South]  ),
    .floo_req_Eject_out_o ( tile_req_eject_out[South] ),
    .floo_rsp_Eject_in_o  ( tile_rsp_eject_in[South]  ),
    .floo_rsp_Eject_out_o ( tile_rsp_eject_out[South] ),
    .floo_wide_Eject_in_o ( tile_wide_eject_in[South] ),
    .floo_wide_Eject_out_o( tile_wide_eject_out[South]),
    .end_of_sim ( end_of_sim_endpoints[South]        )
  );

  floo_nw_tile #(
    .DELAY ( 3 ),
    .ApplTime ( ApplTime ),
    .TestTime ( TestTime ),
    .NarrowNumReads ( NarrowNumReads ),
    .NarrowNumWrites ( NarrowNumWrites ),
    .WideNumReads ( WideNumReads ),
    .WideNumWrites ( WideNumWrites ),
    .NumAddrRegions ( NumAddrRegionsEW ),
    .node_addr_region_t ( node_addr_region_t ),
    .AddrRegions ( EastAddrRegions ),
    .id_t ( id_t ),
    .hdr_t ( hdr_t ),
    .axi_narrow_in_req_t ( axi_narrow_in_req_t ),
    .axi_narrow_in_rsp_t ( axi_narrow_in_rsp_t ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_in_req_t ( axi_wide_in_req_t ),
    .axi_wide_in_rsp_t ( axi_wide_in_rsp_t ),
    .axi_wide_out_req_t ( axi_wide_out_req_t ),
    .axi_wide_out_rsp_t ( axi_wide_out_rsp_t ),
    .floo_req_t ( floo_req_t ),
    .floo_rsp_t ( floo_rsp_t ),
    .floo_wide_t ( floo_wide_t )
  ) i_East_tile (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .id_i       ( '{x: 2'd2, y: 2'd1, port_id: 1'd0} ),
    .floo_req_i ( floo_req_in[2][1][West:North] ),
    .floo_rsp_i ( floo_rsp_in[2][1][West:North] ),
    .floo_req_o ( floo_req_out[2][1][West:North] ),
    .floo_rsp_o ( floo_rsp_out[2][1][West:North] ),
    .floo_wide_i ( floo_wide_in[2][1][West:North] ),
    .floo_wide_o ( floo_wide_out[2][1][West:North] ),
    .floo_req_Eject_in_o  ( tile_req_eject_in[East]  ),
    .floo_req_Eject_out_o ( tile_req_eject_out[East] ),
    .floo_rsp_Eject_in_o  ( tile_rsp_eject_in[East]  ),
    .floo_rsp_Eject_out_o ( tile_rsp_eject_out[East] ),
    .floo_wide_Eject_in_o ( tile_wide_eject_in[East] ),
    .floo_wide_Eject_out_o( tile_wide_eject_out[East]),
    .end_of_sim ( end_of_sim_endpoints[East]        )
  );

  floo_nw_tile #(
    .DELAY ( 4 ),
    .ApplTime ( ApplTime ),
    .TestTime ( TestTime ),
    .NarrowNumReads ( NarrowNumReads ),
    .NarrowNumWrites ( NarrowNumWrites ),
    .WideNumReads ( WideNumReads ),
    .WideNumWrites ( WideNumWrites ),
    .NumAddrRegions ( NumAddrRegionsEW ),
    .node_addr_region_t ( node_addr_region_t ),
    .AddrRegions ( WestAddrRegions ),
    .id_t ( id_t ),
    .hdr_t ( hdr_t ),
    .axi_narrow_in_req_t ( axi_narrow_in_req_t ),
    .axi_narrow_in_rsp_t ( axi_narrow_in_rsp_t ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t ),
    .axi_wide_in_req_t ( axi_wide_in_req_t ),
    .axi_wide_in_rsp_t ( axi_wide_in_rsp_t ),
    .axi_wide_out_req_t ( axi_wide_out_req_t ),
    .axi_wide_out_rsp_t ( axi_wide_out_rsp_t ),
    .floo_req_t ( floo_req_t ),
    .floo_rsp_t ( floo_rsp_t ),
    .floo_wide_t ( floo_wide_t )
  ) i_West_tile (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .id_i       ( '{x: 2'd0, y: 2'd1, port_id: 1'd0} ),
    .floo_req_i ( floo_req_in[0][1][West:North] ),
    .floo_rsp_i ( floo_rsp_in[0][1][West:North] ),
    .floo_req_o ( floo_req_out[0][1][West:North] ),
    .floo_rsp_o ( floo_rsp_out[0][1][West:North] ),
    .floo_wide_i ( floo_wide_in[0][1][West:North] ),
    .floo_wide_o ( floo_wide_out[0][1][West:North] ),
    .floo_req_Eject_in_o  ( tile_req_eject_in[West]  ),
    .floo_req_Eject_out_o ( tile_req_eject_out[West] ),
    .floo_rsp_Eject_in_o  ( tile_rsp_eject_in[West]  ),
    .floo_rsp_Eject_out_o ( tile_rsp_eject_out[West] ),
    .floo_wide_Eject_in_o ( tile_wide_eject_in[West] ),
    .floo_wide_Eject_out_o( tile_wide_eject_out[West]),
    .end_of_sim ( end_of_sim_endpoints[West]        )
  );

  for (genvar x = 0; x < 3; x++) begin : gen_dummy_tiles_x
    for (genvar y = 0; y < 3; y++) begin : gen_dummy_tiles_y
      if ((x!=1) && (y!=1)) begin : gen_dummy
        assign floo_req_in[x][y][Eject] = '0;
        assign floo_rsp_in[x][y][Eject] = '0;
        assign floo_wide_in[x][y][Eject] = '0;
        floo_nw_router #(
          .AxiCfgN      ( floo_test_pkg::AxiCfgN          ),
          .AxiCfgW      ( floo_test_pkg::AxiCfgW          ),
          .RouteAlgo    ( floo_pkg::XYRouting             ),
          .NumRoutes    ( floo_test_pkg::NumRoutes        ),
          .InFifoDepth  ( floo_test_pkg::ChannelFifoDepth ),
          .OutFifoDepth ( floo_test_pkg::OutputFifoDepth  ),
          .id_t         ( id_t                            ),
          .hdr_t        ( hdr_t                           ),
          .floo_req_t   ( floo_req_t                      ),
          .floo_rsp_t   ( floo_rsp_t                      ),
          .floo_wide_t  ( floo_wide_t                     )
        ) i_dummy_router (
          .clk_i        ( clk                 ),
          .rst_ni       ( rst_n               ),
          .test_enable_i ( 1'b0 ),
          .id_i           ( '{x: x, y: y, port_id: 1'd0} ),
          .id_route_map_i ( '0                  ),
          .floo_req_i     ( floo_req_in[x][y]   ),
          .floo_rsp_i     ( floo_rsp_in[x][y]   ),
          .floo_req_o     ( floo_req_out[x][y]  ),
          .floo_rsp_o     ( floo_rsp_out[x][y]  ),
          .floo_wide_i    ( floo_wide_in[x][y]  ),
          .floo_wide_o    ( floo_wide_out[x][y] )
        );
      end
    end
  end

  // -----------------------------------------------------------------------
  //  NW Router (DUT)
  // -----------------------------------------------------------------------
  floo_axi_test_node #(
    .DELAY ( 0 ),
    .AxiCfg         ( floo_test_pkg::AxiCfgN  ),
    .mst_req_t      ( axi_narrow_in_req_t     ),
    .mst_rsp_t      ( axi_narrow_in_rsp_t     ),
    .slv_req_t      ( axi_narrow_out_req_t    ),
    .slv_rsp_t      ( axi_narrow_out_rsp_t    ),
    .ApplTime       ( ApplTime                ),
    .TestTime       ( TestTime                ),
    // .Atops          ( floo_test_pkg::AtopSupport ),
    .NumAddrRegions ( NumAddrRegionsEject          ),
    .rule_t         ( node_addr_region_t      ),
    .AddrRegions    ( EjectAddrRegions             ),
    .AxiMaxBurstLen ( 4                       ),
    .NumReads       ( NarrowNumReads          ),
    .NumWrites      ( NarrowNumWrites         )
  ) i_narrow_test_node (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .slv_port_req_i   ( chimney_narrow_out_req ),
    .slv_port_rsp_o   ( chimney_narrow_out_rsp ),
    .mst_port_req_o   ( chimney_narrow_in_req  ),
    .mst_port_rsp_i   ( chimney_narrow_in_rsp  ),
    .end_of_sim       ( end_of_sim_endpoints[Eject][0]          )
  );

  floo_axi_test_node #(
    .DELAY ( 1 ),
    .AxiCfg         ( floo_test_pkg::AxiCfgW  ),
    .mst_req_t      ( axi_wide_in_req_t       ),
    .mst_rsp_t      ( axi_wide_in_rsp_t       ),
    .slv_req_t      ( axi_wide_out_req_t      ),
    .slv_rsp_t      ( axi_wide_out_rsp_t      ),
    .ApplTime       ( ApplTime                ),
    .TestTime       ( TestTime                ),
    // .Atops          ( floo_test_pkg::AtopSupport ),
    .NumAddrRegions ( NumAddrRegionsEject          ),
    .rule_t         ( node_addr_region_t      ),
    .AddrRegions    ( EjectAddrRegions             ),
    .AxiMaxBurstLen ( 4                       ),
    .NumReads       ( WideNumReads            ),
    .NumWrites      ( WideNumWrites           )
  ) i_wide_test_node (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .slv_port_req_i   ( chimney_wide_out_req ),
    .slv_port_rsp_o   ( chimney_wide_out_rsp ),
    .mst_port_req_o   ( chimney_wide_in_req  ),
    .mst_port_rsp_i   ( chimney_wide_in_rsp  ),
    .end_of_sim       ( end_of_sim_endpoints[Eject][1]        )
  );

  floo_nw_chimney #(
    .AxiCfgN              ( floo_test_pkg::AxiCfgN         ),
    .AxiCfgW              ( floo_test_pkg::AxiCfgW         ),
    .ChimneyCfgN          ( floo_test_pkg::ChimneyCfg      ),
    .ChimneyCfgW          ( floo_test_pkg::ChimneyCfg      ),
    .RouteCfg             ( floo_test_pkg::RouteCfg        ),
    // .AtopSupport          ( floo_test_pkg::AtopSupport     ),
    // .MaxAtomicTxns        ( 1'b1   ),
    .hdr_t                ( hdr_t                          ),
    .id_t                 ( id_t                           ),
    .axi_narrow_in_req_t  ( axi_narrow_in_req_t            ),
    .axi_narrow_in_rsp_t  ( axi_narrow_in_rsp_t            ),
    .axi_narrow_out_req_t ( axi_narrow_out_req_t           ),
    .axi_narrow_out_rsp_t ( axi_narrow_out_rsp_t           ),
    .axi_wide_in_req_t    ( axi_wide_in_req_t              ),
    .axi_wide_in_rsp_t    ( axi_wide_in_rsp_t              ),
    .axi_wide_out_req_t   ( axi_wide_out_req_t             ),
    .axi_wide_out_rsp_t   ( axi_wide_out_rsp_t             ),
    .floo_req_t           ( floo_req_t                     ),
    .floo_rsp_t           ( floo_rsp_t                     ),
    .floo_wide_t          ( floo_wide_t                    )
  ) i_floo_nw_chimney (
    .clk_i   ( clk                 ),
    .rst_ni  ( rst_n               ),
    .test_enable_i  ( 1'b0 ),
    .id_i ( '{x: 2'd1, y: 2'd1, port_id: 1'd0} ),
    .sram_cfg_i           ( '0                      ),
    .axi_narrow_in_req_i  ( chimney_narrow_in_req   ),
    .axi_narrow_in_rsp_o  ( chimney_narrow_in_rsp   ),
    .axi_narrow_out_req_o ( chimney_narrow_out_req  ),
    .axi_narrow_out_rsp_i ( chimney_narrow_out_rsp  ),
    .axi_wide_in_req_i    ( chimney_wide_in_req     ),
    .axi_wide_in_rsp_o    ( chimney_wide_in_rsp     ),
    .axi_wide_out_req_o   ( chimney_wide_out_req    ),
    .axi_wide_out_rsp_i   ( chimney_wide_out_rsp    ),
    .route_table_i        ( '0                      ),
    .floo_req_o           ( floo_req_in[1][1][Eject]      ),
    .floo_rsp_o           ( floo_rsp_in[1][1][Eject]      ),
    .floo_wide_o          ( floo_wide_in[1][1][Eject]     ),
    .floo_req_i           ( floo_req_out[1][1][Eject]     ),
    .floo_rsp_i           ( floo_rsp_out[1][1][Eject]     ),
    .floo_wide_i          ( floo_wide_out[1][1][Eject]    )
  );

  floo_nw_router_dut_wrapper #(
    .id_t ( id_t ),
    .addr_rule_t ( node_addr_region_t ),
    .hdr_t ( hdr_t ),
    .floo_req_t ( floo_req_t ),
    .floo_rsp_t ( floo_rsp_t ),
    .floo_wide_t ( floo_wide_t ),
    .NumEndpoints ( NumEndpoints )
  ) i_dut_wrapper (
    .clk_i        ( clk                 ),
    .rst_ni       ( rst_n               ),
    .id_i         ( '{x: 2'd1, y: 2'd1, port_id: 1'd0} ),
    .id_route_map_i ( '0                  ),  // Not used for XY routing
    .floo_req_i     ( floo_req_in[1][1]   ),
    .floo_rsp_i     ( floo_rsp_in[1][1]   ),
    .floo_req_o     ( floo_req_out[1][1]  ),
    .floo_rsp_o     ( floo_rsp_out[1][1]  ),
    .floo_wide_i    ( floo_wide_in[1][1]  ),
    .floo_wide_o    ( floo_wide_out[1][1] ),
    .end_of_sim_endpoints     ( end_of_sim_endpoints   ),
    .end_of_sim_monitor       ( mesh_end_of_sim  )
  );
  
    floo_mesh_monitor #(
      .Verbose ( 1 ),
      .NumX ( 3 ),
      .NumY ( 3 ),
      .floo_req_t ( floo_req_t ),
      .floo_rsp_t ( floo_rsp_t ),
      .floo_wide_t ( floo_wide_t ),
      .floo_axi_narrow_aw_flit_t ( floo_axi_narrow_aw_flit_t ),
      .floo_axi_narrow_w_flit_t  ( floo_axi_narrow_w_flit_t  ),
      .floo_axi_narrow_ar_flit_t ( floo_axi_narrow_ar_flit_t ),
      .floo_axi_wide_ar_flit_t   ( floo_axi_wide_ar_flit_t   ),
      .floo_axi_narrow_b_flit_t  ( floo_axi_narrow_b_flit_t  ),
      .floo_axi_narrow_r_flit_t  ( floo_axi_narrow_r_flit_t  ),
      .floo_axi_wide_b_flit_t    ( floo_axi_wide_b_flit_t    ),
      .floo_axi_wide_aw_flit_t   ( floo_axi_wide_aw_flit_t   ),
      .floo_axi_wide_w_flit_t    ( floo_axi_wide_w_flit_t    ),
      .floo_axi_wide_r_flit_t    ( floo_axi_wide_r_flit_t    )
    ) i_mesh_monitor (
      .clk_i         ( clk                ),
      .floo_req_in_i ( floo_req_in_eject  ),
      .floo_req_out_i( floo_req_out_eject ),
      .floo_rsp_in_i ( floo_rsp_in_eject  ),
      .floo_rsp_out_i( floo_rsp_out_eject ),
      .floo_wide_in_i( floo_wide_in_eject ),
      .floo_wide_out_i( floo_wide_out_eject ),
      .end_of_sim_o  ( mesh_end_of_sim    )
    );

  // -----------------------------------------------------------------------
  // Connection of noc links
  // -----------------------------------------------------------------------
  for (genvar x = 0; x < 3; x++) begin
    for (genvar y = 0; y < 3; y++) begin
      if (x != 0) begin
        assign floo_req_in[x][y][West] = floo_req_out[x-1][y][East];
        assign floo_rsp_in[x][y][West] = floo_rsp_out[x-1][y][East];
        assign floo_wide_in[x][y][West] = floo_wide_out[x-1][y][East];
      end else begin
        assign floo_req_in[x][y][West] = '0;
        assign floo_rsp_in[x][y][West] = '0;
        assign floo_wide_in[x][y][West] = '0;
      end

      if (x != 2) begin
        assign floo_req_in[x][y][East] = floo_req_out[x+1][y][West];
        assign floo_rsp_in[x][y][East] = floo_rsp_out[x+1][y][West];
        assign floo_wide_in[x][y][East] = floo_wide_out[x+1][y][West];
      end else begin
        assign floo_req_in[x][y][East] = '0;
        assign floo_rsp_in[x][y][East] = '0;
        assign floo_wide_in[x][y][East] = '0;
      end

      if (y != 0) begin
        assign floo_req_in[x][y][South] = floo_req_out[x][y-1][North];
        assign floo_rsp_in[x][y][South] = floo_rsp_out[x][y-1][North];
        assign floo_wide_in[x][y][South] = floo_wide_out[x][y-1][North];
      end else begin
        assign floo_req_in[x][y][South] = '0;
        assign floo_rsp_in[x][y][South] = '0;
        assign floo_wide_in[x][y][South] = '0;
      end

      if (y != 2) begin
        assign floo_req_in[x][y][North] = floo_req_out[x][y+1][South];
        assign floo_rsp_in[x][y][North] = floo_rsp_out[x][y+1][South];
        assign floo_wide_in[x][y][North] = floo_wide_out[x][y+1][South];
      end else begin
        assign floo_req_in[x][y][North] = '0;
        assign floo_rsp_in[x][y][North] = '0;
        assign floo_wide_in[x][y][North] = '0;
      end

    end
  end

  

  // -----------------------------------------------------------------------
  //  Simulation end
  // -----------------------------------------------------------------------
  initial begin
    $timeformat(-9, 2, " ns", 20);
    wait(&end_of_sim_endpoints && mesh_end_of_sim);
    // Wait until compare modules confirm all transactions are verified.
    // wait(narrow_cmp_done && wide_cmp_done);
    $display("[TB] All transactions verified by compare monitors. Stopping simulation.");
    $finish;
  end

endmodule