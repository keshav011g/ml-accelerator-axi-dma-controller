# 🚀 High-Performance ML Hardware Accelerator (ARM Compatible)

> **A dedicated hardware IP core designed to offload heavy Matrix-Multiply-Accumulate (MAC) operations from ARM processors for efficient Edge AI inference.**

## 📖 Overview

This repository contains the complete **Register Transfer Level (RTL)** implementation of a custom Digital AI Accelerator. It is architected to bridge the gap between low-power embedded CPUs (like the ARM Cortex-M series) and the high compute demands of modern Deep Learning models.

By offloading the computationally expensive matrix math to this dedicated hardware, systems can achieve **100x-1000x efficiency gains** compared to software-based execution.

## ✨ Key Features

* **16x16 Systolic Array Core:** Massively parallel execution engine capable of performing **256 MAC operations per clock cycle**.
* **Weight-Stationary Dataflow:** Optimized architecture that minimizes energy-expensive memory accesses by reusing weights within the Processing Elements (PEs).
* **Hardware Tiling Engine:** Automatically breaks down large matrices (e.g., 100x100) to fit onto the 16x16 physical core without software intervention.
* **Automatic Zero Padding:** Hardware logic handles "ragged edges" (matrix sizes not divisible by 16) transparently.
* **DMA-Enabled:** Integrated Direct Memory Access (DMA) controller to fetch weights and inputs autonomously, preventing CPU starvation.
* **ARM-Ready Interface:** Standard AXI-Lite register map for seamless integration with AMBA-based SoCs.

## 📁 Repository Structure

The project has been professionally organized to separate core IP code, verification testbenches, and simulation artifacts:

* `src/` — Contains all core hardware Verilog modules (Processing Elements, DMA Controllers, AXI interfaces, etc.).
* `testbenches/` — Contains various testbenches to validate different edge cases and stress-test the hardware.
* `sim_output/` — Used to store compiled simulation binaries and large `.vcd` waveform files.
* `images/` — Contains block diagrams, architecture schematics, and GTKWave screenshots.

## 🚀 Current Project Status & Recent Milestones

The accelerator has achieved a fully verified, cycle-accurate state. Recent debugging and validation efforts successfully addressed core synchronization issues:

- **Perfect MAC Verification:** The core 16x16 systolic array now successfully executes full precision MACs with exactly 0 errors.
- **DMA Streaming Fixed:** Resolved AXI read-channel synchronization bugs and streaming logic inside `dma_controller.v`, ensuring that input features and weights are safely cached in localized SRAM without word duplication or stall violations.
- **Stress Testing (`tb_test_random.v`):** Passed verification using massive pseudo-random matrix values to thoroughly stress the full bit-width of the INT8 multipliers and INT24 accumulators.
- **Dynamic Tile Zero-Padding (`tb_test_8x8_tile.v`):** Simulated smaller arbitrary matrix sizes (e.g. 8x8 inside the 16x16 grid) using zero-padding logic. Boundary conditions safely returned 0, proving the architecture dynamically adapts without causing internal data corruption.

## 🏗️ System Architecture

The system is designed as a modular co-processor.

### 1. The Host Ecosystem
* **CPU (ARM Cortex):** Acts as the orchestrator. It parses the neural network layers, sets up the memory pointers, and issues the "Start" command.
* **External RAM (DDR):** Holds the heavy model weights and input buffers (images/audio).

### 2. The Accelerator IP
* **Control Unit (AXI-Lite):** A memory-mapped slave interface. The CPU communicates with the chip by writing to specific memory addresses.
* **DMA Controller (AXI-Master):** A bus master that bursts large blocks of data from external RAM into the chip's internal SRAM buffers.
* **Internal SRAM Buffers:**
  * **Weight Buffer (32KB):** Caches model parameters.
  * **Input Buffer (16KB):** Caches incoming feature maps.
  * **Accumulator Buffer (16KB):** Stores partial sums before final write-back.
* **Systolic Core:** The 16x16 grid of Processing Elements that performs the actual INT8 math.

## ⚙️ Technical Specifications

| Feature | Specification |
| :--- | :--- |
| **Precision** | INT8 (8-bit Integer) Inputs / INT24 Accumulation |
| **Core Size** | 16x16 Grid (256 Processing Elements) |
| **Throughput** | 256 Operations / Cycle |
| **Memory Interface** | AXI4-Master (128-bit Data Width) |
| **Control Interface** | AXI4-Lite (32-bit Data Width) |
| **On-Chip Memory** | ~64 KB (Configurable SRAM Macros) |
| **Target Frequency** | 200 MHz+ (on 28nm ASIC) / 100 MHz (on Artix-7 FPGA) |

## 🛠️ How to Simulate & Test

You can simulate the hardware design using [Icarus Verilog](http://iverilog.icarus.com/). The testbenches simulate a full SoC environment with a virtual external RAM and self-checking loops.

### Standard Full Simulation
```bash
# Compile
iverilog -g2012 -o sim_output/ultimate_test src/*.v testbenches/tb_ml_accelerator_top.v

# Execute
vvp sim_output/ultimate_test
```
You should see a detailed read-out mapping expected values vs. hardware values, finishing with `>>> ALL 256 MAC RESULTS MATCH PERFECTLY! TEST PASSED! <<<`.

### Alternative Testbenches
* **Randomized Values (Stress Test):**
  ```bash
  iverilog -g2012 -o sim_output/tb_random src/*.v testbenches/tb_test_random.v
  vvp sim_output/tb_random
  ```
* **8x8 Tile Size (Zero Padding Test):**
  ```bash
  iverilog -g2012 -o sim_output/tb_8x8 src/*.v testbenches/tb_test_8x8_tile.v
  vvp sim_output/tb_8x8
  ```

### Waveform Viewing
To view the generated waveforms in [GTKWave](https://gtkwave.sourceforge.net/):
```bash
gtkwave sim_output/waveform_soc.vcd
```
