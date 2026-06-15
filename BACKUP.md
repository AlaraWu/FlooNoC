# Backup Log — FlooNoC TMR Fork

## Upstream base

Built on top of upstream **pulp-platform/FlooNoC**:

- Fork point: `3f91f3d` — `floogen: Publish on PyPI (#160)`, 2026-01-28


## What this fork adds

Adds **Triple Modular Redundancy (TMR) hardening** for the NoC router in three
granularities, plus matching testbenches and a VC Z01X fault-injection (FI) flow.
Original RTL is almost untouched.

### 1. TMR RTL — `hw/TMR/`

Three TMR modes of the nw_router, by triplication granularity:

| Mode | Dir | What it is |
|------|-----|------------|
| **full (FTMR)**  | `hw/TMR/full/`   | Full triplication — combinational logic and registers are all ×3, with internal voters along the datapath plus border voting on the outputs. Triplicated I/O. |
| **coarse (CTMR)**| `hw/TMR/coarse/` | Coarse-grain — the whole router is instantiated as three independent replicas with no internal voter; mismatch is only resolved at the border. Triplicated I/O. |
| **state (STMR)** | `hw/TMR/state/`  | State-only — only the registers are ×3 and voted internally; combinational logic stays single-copy. Single-copy I/O like baseline, exporting one combined `tmrError`. |

### Changes to the baseline router

The TMR modules are additive; the only edits to existing RTL are two small ones:

- **`hw/floo_router.sv`** — the multicast past-handshake register (`past_handshakes_q`) and
  its `~past_handshakes_q` term are now gated behind `EnMultiCast`, so a non-multicast
  config no longer instantiates that state element (removes an otherwise unvoted/latent FF).
- **`hw/floo_nw_router.sv`** — default `NumAddrRules` changed `0 → 1` to avoid a zero-width
  address-rule array.

### 2. Synthesis wrapper

- `hw/synth/floo_synth_nw_routerTMR.sv` — shared wrapper for all three modes.

### 3. Testbenches / verification

- `hw/tb/tb_floo_nw_router_fi.sv` (1042 lines) — unified TB and the single nw_router
  testbench top. Selects DUT realisation by macro: baseline RTL (no macro),
  RTL TMR (`TARGET_{FTMR,CTMR,STMR}`), and synth netlist (`+TARGET_NETLIST`); the
  Zoix strobe is included only under `TARGET_ZOIX`. Covers the 11-variant FI matrix
  and the plain functional/scoreboard sim in one file.
- `hw/tb/tb_floo_robTMR.sv` — ROB TMR TB. (Initial test module for router but outdated as `tb_floo_nw_router_fi` was developed)
- Test infra: `hw/test/floo_mesh_monitor.sv`, `floo_nw_tile.sv`, `floo_axi_test_node.sv` (+scoreboard).

### 4. Build-system wiring

- **`Bender.yml`**: new targets `ftmr` / `ctmr` / `stmr` (pull `hw/TMR/{full,coarse,state}/*.sv`);
  registers the FI TB and new monitors; synth wrapper gated by `all(floo_synth, any(ftmr,ctmr,stmr))`;
  new local dependency `redundancy_cells` (path `../redundancy_cells`).
- **`Makefile`**: `TMR=full/coarse/stmr` auto-adds the matching `-t` flag; `TB_DUT` ending in
  `TMR` defaults to full; pins `QUESTA_SEPP=questa-2025.1`, `VCS_SEPP=vcs-2025.06`.
- **`.gitignore`**: ignores `floonoc_zoix` (FI workspace).
- **`Bender.lock`**: updated for the `redundancy_cells` dependency.
