import re

# 🔧 set your global frames value here
FRAMES = 400

# --- animate.py ---
with open("animate.py", "r") as f:
    lines = f.readlines()

with open("animate.py", "w") as f:
    for line in lines:
        if line.strip().startswith("frames ="):
            f.write(f"frames = {FRAMES}\n")
        else:
            f.write(line)


# --- print.c ---
with open("print.c", "r") as f:
    lines = f.readlines()

with open("print.c", "w") as f:
    for line in lines:
        if re.match(r"\s*int\s+frames\s*=", line):
            f.write(f"int frames = {FRAMES};\n")
        else:
            f.write(line)


# --- cavityflow.s ---
with open("cavityflow.S", "r") as f:
    text = f.read()

# Replace .rept 1681*<num>
text = re.sub(r"\.rept\s+1681\*\d+", f".rept 1681*{FRAMES}", text)

# Replace li   s0, <num>
text = re.sub(r"li\s+s0,\s*\d+", f"li   s0, {FRAMES}", text)

with open("cavityflow.S", "w") as f:
    f.write(text)

print(f"✅ Updated all files with frames = {FRAMES}")
