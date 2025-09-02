# RISC-V Vectorized Cavity Flow Simulation

This project demonstrates a **lid-driven cavity flow simulation** implemented in **RISC-V vector assembly**.  
The computation is performed on RISC-V, and the results are visualized in Python.

---

## Requirements

To run the simulation, you will need:

- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)  
- [Spike RISC-V Simulator](https://github.com/riscv-software-src/riscv-isa-sim) (or any other simulator of your choice)  
- Python 3 with the following packages:
  - `matplotlib`
  - `numpy`
  - `imageio`

---

## Steps to Run

1. **Compile the RISC-V code**  
   Use the RISC-V GNU toolchain to compile the cavity flow assembly code along with the provided print utility:
   ```bash
   riscv64-unknown-elf-gcc -march=rv64gcv -mabi=lp64d cavityflow.S print.c -o run.elf
   ```

2. **Run the simulation on Spike (or another simulator)**  
   This will take time, as the simulation generates grid outputs frame by frame:
   ```bash
   spike --isa=RV64GCV $HOME/riscv/riscv64-unknown-elf/bin/pk run.elf
   ```

   - The results will be written to `grids_output_C.txt`.  
   - Once the file stops updating, you can safely exit the simulator.

3. **Visualize the results**  
   After the text file is complete, generate an animated GIF of the simulation:
   ```bash
   python animate.py
   ```

   This will create a GIF with a **predefined number of frames**.

4. **Change the number of frames (optional)**  
   If you want more or fewer frames in the animation:
   - Open `updateframes.py`
   - Modify the variable controlling the frame count and run it
   - rerun the steps above (compile + simulate + animate)

---

## Output

- A `.txt` file containing the simulation data  
- An animated `.gif` showing the cavity flow evolution

---

## Notes

- The simulation may take a significant amount of time depending on your system and simulator.  
- Make sure you have enough disk space, as the `.txt` output can grow large depending on the number of frames
