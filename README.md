# ⚙️ Partial Sorting Using Bitonic Merge Networks in Verilog

This project implements a **parallel partial sorter** based on **Bitonic Merge Networks**, designed using **Verilog HDL**. The architecture extracts the **top 2^m elements** from **2^n unsorted inputs** efficiently using recursive, pipelined compare-and-swap structures. The design is scalable, modular, and optimized for real-time signal processing applications.

---

## 💡 What It Does

Designed a **parameterizable, high-performance hardware sorter** to extract the **top 2^m elements from 2^n inputs** using the **Bitonic Merge approach**.

- Supports configurations like **1024→512**, **512→256**, **256→128**, etc.
- Developed a **modular**, **recursive**, and **deeply pipelined** architecture
- Incorporated optimized **Compare-and-Swap units**, `BMunit`, and `maxnby2`
- Achieved **high throughput** and **low critical path delay**
- Verified through simulation using structured testbenches
- Scalable for larger data sizes and future FPGA synthesis

---

## 🧠 Architecture Overview

### 🧩 Core Modules

| Module                  | Description                                                                 |
|-------------------------|-----------------------------------------------------------------------------|
| `partial_sorter_general.v` | 🔝 Top module connecting all units                                       |
| `BMK_unit.v`            | Bitonic Merge unit that recursively combines and sorts inputs              |
| `max_k.v`               | Selects the top _k_ values from a sorted 2k-element stream                  |
| `compare_and_swap_asc.v`| Ascending compare-and-swap unit                                            |
| `compare_swap_dsc.v`    | Descending compare-and-swap unit                                           |
| `piplined.v`            | Top-level pipelined testbench for end-to-end validation                    |

### 🏗️ Partial Sorting Structure

For example, to extract the top 512 from 1024:

```

BM2 → BM4 → BM8 → BM16 → BM32 → BM64 → BM128 → BM256 → BM512
↓        ↓          ↓        ↓         ↓        ↓
MAX512

```

Each `BM` layer performs a partial sort of increasing size. The `MAX512` module then selects the final top-512 outputs.

---

## 📊 Performance Summary

| Feature              | Value                                |
|----------------------|----------------------------------------|
| Max Input Size       | 1024 elements                          |
| Output Size          | Top 512 elements (parameterizable)     |
| Latency              | Log₂(N) cycles (based on BM depth)     |
| Pipelining           | Fully pipelined for max throughput     |
| Throughput           | 1 output block per cycle (after fill)  |
| Critical Path        | Reduced via modular comparator design  |

### 🧪 Bit Growth & Timing

- All data is assumed to be 16-bit inputs.
- Bit growth is minimal due to early comparison-based reductions.
- Suitable for **FPGA implementation**, e.g., on Xilinx Artix-7.

---

## 🔬 Simulation & Validation

- **Testbench:** `piplined.v` generates inputs and compares outputs
- **Verification:** Outputs verified using Python/NumPy reference
- **Waveform Tools:** GTKWave, Vivado Simulator


## 🎯 Applications

- 📦 **Compressive Sensing** (OMP, AMP)
- 📡 **Signal Processing** (Sparse signal detection)
- 📷 **Image Processing** (Top-k filtering, attention)
- 🌐 **Network Systems** (Priority queue sorting)
- 🧠 **Neural Networks** (Top-k activation pruning)

---

## 📁 Repository Layout

```

.
├── partial\_sorter\_general.v   # Top-level sorter module
├── BMK\_unit.v                 # Bitonic Merge Kernel module
├── max\_k.v                    # Top-k selector
├── compare\_and\_swap\_asc.v     # Compare-and-swap (ascending)
├── compare\_swap\_dsc.v         # Compare-and-swap (descending)
├── piplined.v                 # Simulation testbench
├── Final\_presentation.pdf    # Final design and architecture overview
├── mid\_term\_presentation.pdf # Mid-term motivation and research context
└── README.md                  # This file

```

---

## 📊 Comparison: Full vs Partial Sort

| Metric              | Full Sort         | Partial Sort (Top-k)   |
|---------------------|-------------------|-------------------------|
| Output              | All sorted        | Top-k only              |
| Comparator Overhead | High              | Significantly reduced   |
| Area Utilization    | Large             | Efficient               |
| Throughput          | Moderate          | High (1 block/cycle)    |
| Pipelining          | Limited           | Fully pipelined         |

---

## 🧭 Presentation Takeaways

### 📘 Mid-Term

- Introduced **OMP and AMP** algorithms
- Emphasized need for **top-k extraction**
- Analyzed **sorting networks** vs **Bitonic Merge**

### 📗 Final

- Explained modular hierarchy (`BMK`, `MAX-K`, `CAE`)
- Demonstrated **recursive scaling**
- Highlighted pipelining stages and test results
- Showed future expansion to higher data widths

---

## 🧰 Tools Used

- 🖥️ Verilog HDL (Vivado / ModelSim)
- 🧪 Vivado Simulator
- 📊 Martlab (for output verification)
- 📽️ PowerPoint for design presentations

---


