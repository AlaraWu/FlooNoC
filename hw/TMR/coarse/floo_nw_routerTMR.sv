// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Chen Wu <chenwu@iis.ee.ethz.ch>
//
// Coarse-grained TMR wrapper for floo_nw_router.
// Instantiates three independent baseline floo_nw_router replicas (A/B/C),
// each driven by its own triplicated control and dataflow inputs. Outputs of
// each replica pass straight through to the corresponding A/B/C output
// channel; border voting is performed by the enclosing testbench wrapper.

`include "axi/typedef.svh"
`include "floo_noc/typedef.svh"
`include "common_cells/registers.svh"

module floo_nw_routerTMR #(
  parameter floo_pkg::axi_cfg_t    AxiCfgN       = '0,
  parameter floo_pkg::axi_cfg_t    AxiCfgW       = '0,
  parameter floo_pkg::route_algo_e RouteAlgo     = floo_pkg::XYRouting,
  parameter int unsigned           NumRoutes     = 0,
  parameter int unsigned           NumInputs     = NumRoutes,
  parameter int unsigned           NumOutputs    = NumRoutes,
  parameter int unsigned           InFifoDepth   = 0,
  parameter int unsigned           OutFifoDepth  = 0,
  parameter bit                    XYRouteOpt    = 1'b1,
  parameter bit                    EnMultiCast   = 1'b0,
  parameter type                   id_t          = logic,
  parameter type                   hdr_t         = logic,
  parameter int unsigned           NumAddrRules  = 0,
  parameter type                   addr_rule_t   = logic,
  parameter type                   floo_req_t    = logic,
  parameter type                   floo_rsp_t    = logic,
  parameter type                   floo_wide_t   = logic
) (
  input  logic clk_iA,
  input  logic clk_iB,
  input  logic clk_iC,
  input  logic rst_niA,
  input  logic rst_niB,
  input  logic rst_niC,
  input  logic test_enable_iA,
  input  logic test_enable_iB,
  input  logic test_enable_iC,
  input  id_t  id_iA,
  input  id_t  id_iB,
  input  id_t  id_iC,
  input  addr_rule_t [NumAddrRules-1:0] id_route_map_iA,
  input  addr_rule_t [NumAddrRules-1:0] id_route_map_iB,
  input  addr_rule_t [NumAddrRules-1:0] id_route_map_iC,
  input  floo_req_t  [NumInputs-1:0]    floo_req_iA,
  input  floo_req_t  [NumInputs-1:0]    floo_req_iB,
  input  floo_req_t  [NumInputs-1:0]    floo_req_iC,
  input  floo_rsp_t  [NumOutputs-1:0]   floo_rsp_iA,
  input  floo_rsp_t  [NumOutputs-1:0]   floo_rsp_iB,
  input  floo_rsp_t  [NumOutputs-1:0]   floo_rsp_iC,
  output floo_req_t  [NumOutputs-1:0]   floo_req_oA,
  output floo_req_t  [NumOutputs-1:0]   floo_req_oB,
  output floo_req_t  [NumOutputs-1:0]   floo_req_oC,
  output floo_rsp_t  [NumInputs-1:0]    floo_rsp_oA,
  output floo_rsp_t  [NumInputs-1:0]    floo_rsp_oB,
  output floo_rsp_t  [NumInputs-1:0]    floo_rsp_oC,
  input  floo_wide_t [NumRoutes-1:0]    floo_wide_iA,
  input  floo_wide_t [NumRoutes-1:0]    floo_wide_iB,
  input  floo_wide_t [NumRoutes-1:0]    floo_wide_iC,
  output floo_wide_t [NumRoutes-1:0]    floo_wide_oA,
  output floo_wide_t [NumRoutes-1:0]    floo_wide_oB,
  output floo_wide_t [NumRoutes-1:0]    floo_wide_oC
);

  floo_nw_router #(
    .AxiCfgN      ( AxiCfgN      ),
    .AxiCfgW      ( AxiCfgW      ),
    .RouteAlgo    ( RouteAlgo    ),
    .NumRoutes    ( NumRoutes    ),
    .NumInputs    ( NumInputs    ),
    .NumOutputs   ( NumOutputs   ),
    .InFifoDepth  ( InFifoDepth  ),
    .OutFifoDepth ( OutFifoDepth ),
    .XYRouteOpt   ( XYRouteOpt   ),
    .EnMultiCast  ( EnMultiCast  ),
    .id_t         ( id_t         ),
    .hdr_t        ( hdr_t        ),
    .NumAddrRules ( NumAddrRules ),
    .addr_rule_t  ( addr_rule_t  ),
    .floo_req_t   ( floo_req_t   ),
    .floo_rsp_t   ( floo_rsp_t   ),
    .floo_wide_t  ( floo_wide_t  )
  ) i_replica_A (
    .clk_i          ( clk_iA          ),
    .rst_ni         ( rst_niA         ),
    .test_enable_i  ( test_enable_iA  ),
    .id_i           ( id_iA           ),
    .id_route_map_i ( id_route_map_iA ),
    .floo_req_i     ( floo_req_iA     ),
    .floo_rsp_i     ( floo_rsp_iA     ),
    .floo_req_o     ( floo_req_oA     ),
    .floo_rsp_o     ( floo_rsp_oA     ),
    .floo_wide_i    ( floo_wide_iA    ),
    .floo_wide_o    ( floo_wide_oA    )
  );

  floo_nw_router #(
    .AxiCfgN      ( AxiCfgN      ),
    .AxiCfgW      ( AxiCfgW      ),
    .RouteAlgo    ( RouteAlgo    ),
    .NumRoutes    ( NumRoutes    ),
    .NumInputs    ( NumInputs    ),
    .NumOutputs   ( NumOutputs   ),
    .InFifoDepth  ( InFifoDepth  ),
    .OutFifoDepth ( OutFifoDepth ),
    .XYRouteOpt   ( XYRouteOpt   ),
    .EnMultiCast  ( EnMultiCast  ),
    .id_t         ( id_t         ),
    .hdr_t        ( hdr_t        ),
    .NumAddrRules ( NumAddrRules ),
    .addr_rule_t  ( addr_rule_t  ),
    .floo_req_t   ( floo_req_t   ),
    .floo_rsp_t   ( floo_rsp_t   ),
    .floo_wide_t  ( floo_wide_t  )
  ) i_replica_B (
    .clk_i          ( clk_iB          ),
    .rst_ni         ( rst_niB         ),
    .test_enable_i  ( test_enable_iB  ),
    .id_i           ( id_iB           ),
    .id_route_map_i ( id_route_map_iB ),
    .floo_req_i     ( floo_req_iB     ),
    .floo_rsp_i     ( floo_rsp_iB     ),
    .floo_req_o     ( floo_req_oB     ),
    .floo_rsp_o     ( floo_rsp_oB     ),
    .floo_wide_i    ( floo_wide_iB    ),
    .floo_wide_o    ( floo_wide_oB    )
  );

  floo_nw_router #(
    .AxiCfgN      ( AxiCfgN      ),
    .AxiCfgW      ( AxiCfgW      ),
    .RouteAlgo    ( RouteAlgo    ),
    .NumRoutes    ( NumRoutes    ),
    .NumInputs    ( NumInputs    ),
    .NumOutputs   ( NumOutputs   ),
    .InFifoDepth  ( InFifoDepth  ),
    .OutFifoDepth ( OutFifoDepth ),
    .XYRouteOpt   ( XYRouteOpt   ),
    .EnMultiCast  ( EnMultiCast  ),
    .id_t         ( id_t         ),
    .hdr_t        ( hdr_t        ),
    .NumAddrRules ( NumAddrRules ),
    .addr_rule_t  ( addr_rule_t  ),
    .floo_req_t   ( floo_req_t   ),
    .floo_rsp_t   ( floo_rsp_t   ),
    .floo_wide_t  ( floo_wide_t  )
  ) i_replica_C (
    .clk_i          ( clk_iC          ),
    .rst_ni         ( rst_niC         ),
    .test_enable_i  ( test_enable_iC  ),
    .id_i           ( id_iC           ),
    .id_route_map_i ( id_route_map_iC ),
    .floo_req_i     ( floo_req_iC     ),
    .floo_rsp_i     ( floo_rsp_iC     ),
    .floo_req_o     ( floo_req_oC     ),
    .floo_rsp_o     ( floo_rsp_oC     ),
    .floo_wide_i    ( floo_wide_iC    ),
    .floo_wide_o    ( floo_wide_oC    )
  );

  // Coarse-grained TMR has no internal voters; mismatch detection is done at
  // the border voters instantiated in the testbench wrapper. No DUT-side
  // error signal is exposed so PORT fault-injection cannot flip dummy zeros.

endmodule

module majorityVoter #(parameter WIDTH = 1) (                                 
  input  wire  [WIDTH-1:0] inA, inB, inC,                                     
  output wire  [WIDTH-1:0] out,                                               
  output wire              tmrErr                                             
);                                                                            
  assign out    = (inA & inB) | (inA & inC) | (inB & inC);
  assign tmrErr = |(inA ^ inB) | |(inA ^ inC) | |(inB ^ inC);                 
endmodule