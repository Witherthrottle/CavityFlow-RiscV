import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import re

# define frames here
frames = 400
# === Step 1: Load Grid Data ===

def load_grids(filename, num_frames, grid_shape=(41, 41) ):
    with open(filename, 'r') as f:
        text = f.read()

    def extract_block(section_name):
        pattern = fr"=== {section_name} ===\n\n((?:[\d\.\-eE]+\s*)+)"
        match = re.search(pattern, text)
        if not match:
            raise ValueError(f"{section_name} section not found")
        numbers = list(map(float, match.group(1).split()))
        return np.array(numbers).reshape((num_frames, *grid_shape))

    pressure = extract_block("Pressure Grid")
    u = extract_block("U Grid")
    v = extract_block("V Grid")

    return pressure, u, v

pressure, u, v = load_grids("grids_output_C.txt", frames)  # Your own loader
frames = 400
ny, nx = pressure.shape[1], pressure.shape[2]

x = np.linspace(0, 2, nx)
y = np.linspace(0, 2, ny)
X, Y = np.meshgrid(x, y)

fig = plt.figure(figsize=(11, 7), dpi=100)
plt.tight_layout()

# === Step 3: Animation Function ===

def update(frame):
    plt.clf()
    plt.contourf(X, Y, pressure[frame], alpha=0.5, cmap='viridis')
    plt.colorbar()
    plt.contour(X, Y, pressure[frame], cmap='viridis')
    plt.streamplot(X, Y, u[frame], v[frame])
    plt.xlabel('X')
    plt.ylabel('Y')
    plt.title(f'Cavity Flow (Frame {frame})')

ani = animation.FuncAnimation(
    fig, update, frames=frames, interval=100
)

ani.save("cavity_flow.gif", writer='pillow', fps=10)

print("Animation saved!")