// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Tim Fischer <fischeti@iis.ee.ethz.ch>

module floo_synth_nw_routerTMR
  import floo_pkg::*;
  import floo_synth_params_pkg::*;
  import floo_synth_nw_pkg::*;
#(
  parameter int unsigned NumPorts = int'(floo_pkg::NumDirections)
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,

  input  id_t id_i,
  input  logic id_route_map_i,

  input  floo_req_t [NumPorts-1:0] floo_req_iA,
  input  floo_req_t [NumPorts-1:0] floo_req_iB,
  input  floo_req_t [NumPorts-1:0] floo_req_iC,
  input  floo_rsp_t [NumPorts-1:0] floo_rsp_iA,
  input  floo_rsp_t [NumPorts-1:0] floo_rsp_iB,
  input  floo_rsp_t [NumPorts-1:0] floo_rsp_iC,
  output floo_req_t [NumPorts-1:0] floo_req_oA,
  output floo_req_t [NumPorts-1:0] floo_req_oB,
  output floo_req_t [NumPorts-1:0] floo_req_oC,
  output floo_rsp_t [NumPorts-1:0] floo_rsp_oA,
  output floo_rsp_t [NumPorts-1:0] floo_rsp_oB,
  output floo_rsp_t [NumPorts-1:0] floo_rsp_oC,
  input  floo_wide_t [NumPorts-1:0] floo_wide_iA,
  input  floo_wide_t [NumPorts-1:0] floo_wide_iB,
  input  floo_wide_t [NumPorts-1:0] floo_wide_iC,
  output floo_wide_t [NumPorts-1:0] floo_wide_oA,
  output floo_wide_t [NumPorts-1:0] floo_wide_oB,
  output floo_wide_t [NumPorts-1:0] floo_wide_oC
);

  floo_nw_routerTMR #(
    .AxiCfgN      ( AxiCfgN             ),
    .AxiCfgW      ( AxiCfgW             ),
    .RouteAlgo    ( RouteCfg.RouteAlgo  ),
    .NumRoutes    ( NumPorts            ),
    .NumAddrRules ( 1                   ),
    .InFifoDepth  ( InFifoDepth         ),
    .OutFifoDepth ( OutFifoDepth        ),
    .XYRouteOpt   ( 1'b0                ),
    .id_t         ( id_t                ),
    .hdr_t        ( hdr_t               ),
    .floo_req_t   ( floo_req_t          ),
    .floo_rsp_t   ( floo_rsp_t          ),
    .floo_wide_t  ( floo_wide_t         )
  ) i_floo_nw_router (
    .clk_iA          ( clk_i           ),
    .clk_iB          ( clk_i           ),
    .clk_iC          ( clk_i           ),
    .rst_niA         ( rst_ni          ),
    .rst_niB         ( rst_ni          ),
    .rst_niC         ( rst_ni          ),
    .test_enable_iA  ( test_enable_i   ),
    .test_enable_iB  ( test_enable_i   ),
    .test_enable_iC  ( test_enable_i   ),
    .id_iA           ( id_i            ),
    .id_iB           ( id_i            ),
    .id_iC           ( id_i            ),
    .id_route_map_iA ( id_route_map_i  ),
    .id_route_map_iB ( id_route_map_i  ),
    .id_route_map_iC ( id_route_map_i  ),
    .floo_req_iA     ( floo_req_iA      ),
    .floo_req_iB     ( floo_req_iB      ),
    .floo_req_iC     ( floo_req_iC      ),
    .floo_rsp_iA     ( floo_rsp_iA      ),
    .floo_rsp_iB     ( floo_rsp_iB      ),
    .floo_rsp_iC     ( floo_rsp_iC      ),
    .floo_req_oA     ( floo_req_oA      ),
    .floo_req_oB     ( floo_req_oB      ),
    .floo_req_oC     ( floo_req_oC      ),
    .floo_rsp_oA     ( floo_rsp_oA      ),
    .floo_rsp_oB     ( floo_rsp_oB      ),
    .floo_rsp_oC     ( floo_rsp_oC      ),
    .floo_wide_iA    ( floo_wide_iA     ),
    .floo_wide_iB    ( floo_wide_iB     ),
    .floo_wide_iC    ( floo_wide_iC     ),
    .floo_wide_oA    ( floo_wide_oA     ),
    .floo_wide_oB    ( floo_wide_oB     ),
    .floo_wide_oC    ( floo_wide_oC     ),
    .tmrErrorA (),
    .tmrErrorB (),
    .tmrErrorC ()
  );

endmodule