# Copilot Instructions for PHY_project

## Project Overview
This repository implements a modular PHY (Physical Layer) design in Verilog. The top-level module is `Top-PHY.v`, which integrates several key components:
- **Serializer/Deserializer (SerDes):** `Serializer.v`, `Deserializer.v`
- **Scrambler/Descrambler:** `Scrambler.v`, `Descrambler.v`
- **Encoder/Decoder:** `Encoder.v`, `Decoder.v`
- **Gearbox:** `Gearbox_s2p.v` (serial-to-parallel), `Gearbox_p2s.v` (parallel-to-serial)

The `SerDes_project/` subdirectory contains Xilinx Vivado project files for simulation, synthesis, and implementation.

## Key Patterns & Conventions
- **Module Naming:** Each file implements a single Verilog module named after the file (e.g., `Serializer.v` defines `module Serializer`).
- **Signal Naming:** Signals use descriptive names reflecting their function (e.g., `data_in`, `clk`, `rst_n`).
- **Top-Level Integration:** `Top-PHY.v` wires together all submodules, defining the main data flow.
- **Parameterization:** Where possible, modules use Verilog parameters for data width and configuration.

## Developer Workflows
- **Build/Synthesis:**
  - Open `SerDes_project/SerDes_project.xpr` in Xilinx Vivado for synthesis, implementation, and bitstream generation.
  - All source files are located in the root of `PHY_project/`.
- **Simulation:**
  - Add testbenches in Vivado or your preferred simulator. No testbenches are present by default.
- **Debugging:**
  - Use Vivado's built-in simulation and waveform tools.
  - Check module boundaries and signal connections in `Top-PHY.v` for integration issues.

## Integration Points
- **Vivado Project:** All hardware design flows are managed via the Vivado project in `SerDes_project/`.
- **No External IP Cores:** All logic is implemented in Verilog; no encrypted or third-party IP is present.

## Examples
- To add a new module, follow the naming and parameterization conventions seen in `Serializer.v` or `Encoder.v`.
- To modify the data path, update both the relevant submodule and its connections in `Top-PHY.v`.

## Additional Notes
- No README or prior agent instructions were found; this file is the canonical source for AI agent guidance.
- Keep all new Verilog source files in the project root for Vivado compatibility.

---
For questions about build flows or module integration, review `Top-PHY.v` and the Vivado project structure.
