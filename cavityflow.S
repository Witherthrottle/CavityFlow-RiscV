    .section .data
    .align 2
    .global pressure_log
    .global u_log
    .global v_log
    .global pressure_grid
    .global u_grid
    .global v_grid
    .global pressure_final_grid
    .global u_final_grid
    .global v_final_grid
    .global nx
    .global ny
    .global nt
    .global nit
    .global c
    .global dx
    .global dy
    .global rho
    .global nu
    .global dt
    .global x
pressure_log:
    .rept 1681*400
      .float 0.0
    .endr

    # 41 x 41 grid = 1681 floats
    # Pressure is initially 0 everywhere:
pressure_grid:
    .rept 1681
      .float 0.0
    .endr

pressure_final_grid:
    .rept 1681
      .float 0.0
    .endr

    # u Grid: u = 0 in rows 0..39, and at the top (row 40) u = 1 (the lid)
    # There are 40 rows × 41 columns = 1640 points for the non‐lid
u_log:
    .rept 1681*400
      .float 0.0
    .endr
u_grid:
    .rept 1681
      .float 0.0
    .endr

u_final_grid:
    .rept 1681
      .float 0.0
    .endr

    # v Grid: v = 0 everywhere (all 1681 points)
v_log:
    .rept 1681*400
      .float 0.0
    .endr
v_grid:
    .rept 1681
      .float 0.0
    .endr

v_final_grid:
    .rept 1681
      .float 0.0
    .endr

    # For a 41×41 grid, row size in bytes = 41 * 4 = 164.
# Integer constants
nx:     .word 41
ny:     .word 41
nt:     .word 100
nit:    .word 50
x:      .word 42

# Float constants
c:      .float 1.0
dx:     .float 0.05           # 2 / (41 - 1) = 0.05
dy:     .float 0.05           # 2 / (41 - 1) = 0.05
rho:    .float 1.0
nu:     .float 0.1
dt:     .float 0.001


    .section .text
    .global main
    .extern print_grids

main:
    li   s0, 400             # nt = 100 (outer time loop)
    li a0, 0
outer_loop:
    li   s1, 50              # nit = 50 (pressure iterations)
    # Print s0
    
inner_loop:
    addi sp, sp, -16
    sw s1, 0(sp)
    sw s0, 4(sp)
    sw a0, 8(sp)
    call process_pressure_grid
    call apply_pressure_boundary_conditions
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw a0, 8(sp)
    addi sp, sp, 16
    addi s1, s1, -1
    bnez s1, inner_loop
    addi sp, sp, -16
    sw s1, 0(sp)
    sw s0, 4(sp)
    sw a0, 8(sp)
    
    call process_u_grid
    call process_v_grid

    call copy_back_u_func
    call copy_back_v_func

    call apply_u_boundary_conditions
    call apply_v_boundary_conditions
    lw a0, 8(sp)
    call store_grids
    lw s1, 0(sp)
    lw s0, 4(sp)
    
    addi sp, sp, 16
    
    addi s0, s0, -1
    addi a0, a0, 1
    bnez s0, outer_loop
    call print_grids
    
    
    

    li   a0, 0                 # return 0
    j exit

# ----------------------------------------------------------------------------
# for pressure, u, and v arrays, storing into *_final_grid.
# ----------------------------------------------------------------------------
process_pressure_grid:
    # Setup constants
    li   t1,   1            # t1 = row index i = 1
    li   t2,  40            # t2 = stop before i=40
    li   a6,  40            # a6 = stop before j=40
    li   s5, 164            # s5 = bytes per row = 41*4

    # Base addresses
    la   t3, pressure_grid
    la   t4, u_grid
    la   t5, v_grid

    la   s2, pressure_final_grid
    la   s1, u_final_grid
    la   s0, v_final_grid

row_loop:
    # a0 = i * row_bytes
    mul  a0, t1, s5

    # Pressure pointers
    sub  a1, a0, s5         # (i-1)*row_bytes
    add  a1, t3, a1         # &P[i-1][0]
    add  a2, t3, a0         # &P[i][0]
    add  a3, a0, s5
    add  a3, t3, a3         # &P[i+1][0]
    add  a4, s2, a0         # &P_final[i][0]

    # U pointers
    sub  s3, a0, s5
    add  s3, t4, s3         # &U[i-1][0]
    add  s4, t4, a0         # &U[i][0]
    add  s6, a0, s5
    add  s6, t4, s6         # &U[i+1][0]
    add  s7, s1, a0         # &U_final[i][0]

    # V pointers
    sub  s8, a0, s5
    add  s8, t5, s8         # &V[i-1][0]
    add  s9, t5, a0         # &V[i][0]
    add s10, a0, s5
    add s10, t5, s10        # &V[i+1][0]
    add s11, s0, a0         # &V_final[i][0]

    # j = 1
    li   a5, 1

col_loop:
    # remaining = a6 - j
    sub  t0, a6, a5

    # VL = min(remaining, max)
    vsetvli t6, t0, e32, m1

    # byte‑offset = j*4
    slli a7, a5, 2
    #Breakdown:
    # v1-v6 are for pressure  
    # v7-v12 for u
    # v13-v18 for v
    # ---- PRESSURE ----
    add  t0, a1, a7        # &P[i-1][j]
    vle32.v v1, (t0)                                                  
    add  t0, a2, a7        # &P[i][j]
    vle32.v v2, (t0)
    add  t0, a3, a7        # &P[i+1][j]
    vle32.v v3, (t0)
    addi t0, a2, -4        # &P[i][j-1]
    add  t0, t0, a7
    vle32.v v4, (t0)
    addi t0, a2,  4        # &P[i][j+1]
    add  t0, t0, a7
    vle32.v v5, (t0)
    #add  t0, a4, a7        # &P_final[i][j]

    # ---- U ----
    #add  t0, s3, a7        # &U[i-1][j]
    #vle32.v v7, (t0)
    #add  t0, s4, a7        # &U[i][j]
    #vle32.v v8, (t0)
    #add  t0, s6, a7        # &U[i+1][j]
    #vle32.v v9, (t0)
    addi t0, s4, -4        # &U[i][j-1]
    add  t0, t0, a7
    vle32.v v10, (t0)
    addi t0, s4,  4        # &U[i][j+1]
    add  t0, t0, a7
    vle32.v v11, (t0)
    #add  t0, s7, a7        # &U_final[i][j]

    # ---- V ----
    add  t0, s8, a7        # &V[i-1][j]
    vle32.v v13, (t0)
    #add  t0, s9, a7        # &V[i][j]
    #vle32.v v14, (t0)
    add  t0, s10, a7       # &V[i+1][j]
    vle32.v v15, (t0)

    addi t0, s9, -4        # &V[i][j-1]
    add  t0, t0, a7
    vle32.v v16, (t0)
    addi t0, s9,  4        # &V[i][j+1]
    add  t0, t0, a7
    vle32.v v17, (t0)
    #add  t0, s11, a7       # &V_final[i][j]
pressure_poission_formula:
    
    la t0, dx
    flw ft1, 0(t0)  # dx
    la t0, dy
    flw ft2, 0(t0) # dy
    fmul.s ft3, ft1, ft1 # dx^2
    fmul.s ft4, ft2, ft2 # dy^2
    la t0, rho
    flw ft5, 0(t0) # rho
    la t0, dt
    flw ft0, 0(t0) # dt
    # first part
    vfadd.vv v19, v1, v3  #  acc = p[i+1][j] + p[i-1][j]
    vfmul.vf v19, v19, ft4 # acc = acc * dx^2
    vfadd.vv v20, v4, v5  # acc2 = p[i][j+1] + p[i][j-1]
    vfmul.vf v20, v20, ft3 # acc2 = acc2 * dy^2
    vfadd.vv v20, v19,v20 # acc2 = acc1 + acc2
    fadd.s ft6, ft3, ft4
    li   t0, 2             # load integer 2
    fcvt.s.w fs1, t0       # convert integer to float: fs1 = 2.0
    fmul.s ft6, fs1, ft6   # ft6 = 2(dy^2 + dx^2) Save this for later as well
    vfmv.v.f  v19, ft6     # reuse v19
    vfdiv.vv v20, v20, v19 # v20 stores the first part

    # second part 
    fmul.s fs1, ft3, ft4 #  acc = dx^2 * dy^@
    fmul.s fs1, fs1, ft5 # acc =  acc* rho
    fdiv.s fs1,  fs1, ft6 # acc = acc/ ft6 (reused)
    vfmv.v.f v30, fs1  #  v30 = second part
    


    # last part
    
    #term1
    vfsub.vv v24, v11, v10  # v24 = uij+1 - uij-1(store for later)
    fcvt.s.w fs1, t0
    fmul.s fs1, fs1, ft1  #2 * dx
    vfmv.v.f v21, fs1     # v21  = 2*dx vectorized (keep for later too)
    vfdiv.vv v19, v24, v21 # final1

    vfsub.vv v25, v15, v13  #v25 = v i+1 - v i-1 (store for later)
    fcvt.s.w fs1, t0
    fmul.s fs1, fs1, ft2 # 2dy
    vfmv.v.f v22, fs1 # v22  = 2*dy vectorized (keep for later too)
    vfdiv.vv v23, v25, v22 # final2

    vfadd.vv v19, v19, v23 # final1 = final1+final2
    vfmv.v.f v23, ft0 # v23 = dt (reused)
    vfdiv.vv v19, v19, v23 # final1 = final1/dt


    #term2
    vfmul.vv v26, v24, v24
    vfmul.vv v27, v21, v21
    vfdiv.vv v26 , v26, v27 # v26 = answer

    # term 4
    vfmul.vv v27, v25, v25
    vfmul.vv v28, v22, v22
    vfdiv.vv v27, v27, v28 # v27 = answer

    # term3
    vfsub.vv v24, v9, v7 # u i+1 j- u i-1 j(we can now spill v24 and reuse)
    vfsub.vv v25, v17, v16 # v i j+1  - v i j-1 ( same with v25)
    vfdiv.vv v24, v24, v21 # v24 = v24/2dx
    vfdiv.vv v25, v25, v22 # v25 = v25/2dy
    vfmul.vv v24, v24,v25 # v24 = v24*v25
    fcvt.s.w fs1, t0
    vfmv.v.f v25, fs1 # reuse v25, v25 = 2
    vfmul.vv v24, v24, v25 # v24 = 2*v24

    # processing all terms
    vfsub.vv v19, v19, v26
    vfsub.vv v19, v19, v24
    vfsub.vv v19, v19, v27
    #------
    vfmul.vv v19, v19, v30
    #------
    vfsub.vv v20, v20, v19

    add  t0, a4, a7        # &P_final[i][j]
    vse32.v v20, (t0)
    
    
    # advance j
    add  a5, a5, t6
    blt  a5, a6, col_loop

    # next row
    addi t1, t1, 1
    blt  t1, t2, row_loop
    # now copy final->working pressure grid (1681 floats)
   
copy_back_p:
    la   t1, pressure_final_grid
    la   t2, pressure_grid
    li   t0, 1681
    # set vector length (VL) for 32-bit floats
loop_p:
    vsetvli t3, t0, e32, m1
    vle32.v v0, 0(t1)           # load VL floats from src
    vse32.v v0, 0(t2)           # store VL floats to dst

    slli t4, t3, 2             # bytes = VL * 4
    add  t1, t1, t4            # advance src ptr
    add  t2, t2, t4            # advance dst ptr
    sub  t0, t0, t3            # remaining -= VL
    bnez t0, loop_p             # repeat if not done

    ret


process_u_grid:
    # Setup constants
    li   t1,   1            # t1 = row index i = 1
    li   t2,  40            # t2 = stop before i=40
    li   a6,  40            # a6 = stop before j=40
    li   s5, 164            # s5 = bytes per row = 41*4

    # Base addresses
    la   t3, pressure_grid
    la   t4, u_grid
    la   t5, v_grid

    la   s2, pressure_final_grid
    la   s1, u_final_grid
    la   s0, v_final_grid

row_loop_u:
    # a0 = i * row_bytes
    mul  a0, t1, s5

    # Pressure pointers
    sub  a1, a0, s5         # (i-1)*row_bytes
    add  a1, t3, a1         # &P[i-1][0]
    add  a2, t3, a0         # &P[i][0]
    add  a3, a0, s5
    add  a3, t3, a3         # &P[i+1][0]
    add  a4, s2, a0         # &P_final[i][0]

    # U pointers
    sub  s3, a0, s5
    add  s3, t4, s3         # &U[i-1][0]
    add  s4, t4, a0         # &U[i][0]
    add  s6, a0, s5
    add  s6, t4, s6         # &U[i+1][0]
    add  s7, s1, a0         # &U_final[i][0]

    # V pointers
    sub  s8, a0, s5
    add  s8, t5, s8         # &V[i-1][0]
    add  s9, t5, a0         # &V[i][0]
    add s10, a0, s5
    add s10, t5, s10        # &V[i+1][0]
    add s11, s0, a0         # &V_final[i][0]

    # j = 1
    li   a5, 1

col_loop_u:
    # remaining = a6 - j
    sub  t0, a6, a5 

    # VL = min(remaining, max)
    vsetvli t6, t0, e32, m1

    # byte‑offset = j*4
    slli a7, a5, 2
    #Breakdown:
    # v1-v6 are for pressure  
    # v7-v12 for u
    # v13-v18 for v
    # ---- PRESSURE ----
    #add  t0, a1, a7        # &P[i-1][j]
    #vle32.v v1, (t0)                                                  
    #add  t0, a2, a7        # &P[i][j]
    #vle32.v v2, (t0)
    #add  t0, a3, a7        # &P[i+1][j]
    #vle32.v v3, (t0)
    addi t0, a2, -4        # &P[i][j-1]
    add  t0, t0, a7
    vle32.v v4, (t0)
    addi t0, a2,  4        # &P[i][j+1]
    add  t0, t0, a7
    vle32.v v5, (t0)
    #add  t0, a4, a7        # &P_final[i][j]

    # ---- U ----
    add  t0, s3, a7        # &U[i-1][j]
    vle32.v v7, 0(t0)
    add  t0, s4, a7        # &U[i][j]
    vle32.v v8, 0(t0)
    add  t0, s6, a7        # &U[i+1][j]
    vle32.v v9, (t0)
    addi t0, s4, -4        # &U[i][j-1]
    add  t0, t0, a7
    vle32.v v10, (t0)
    addi t0, s4,  4        # &U[i][j+1]
    add  t0, t0, a7
    vle32.v v11, (t0)
    add  t0, s7, a7        # &U_final[i][j]

    # ---- V ----
    #add  t0, s8, a7        # &V[i-1][j]
    #vle32.v v13, (t0)
    add  t0, s9, a7        # &V[i][j]
    vle32.v v14, (t0)
    #add  t0, s10, a7       # &V[i+1][j]
    #vle32.v v15, (t0)

    #addi t0, s9, -4        # &V[i][j-1]
    #add  t0, t0, a7
    #vle32.v v16, (t0)
    #addi t0, s9,  4        # &V[i][j+1]
    #add  t0, t0, a7
    #vle32.v v17, (t0)
    #add  t0, s11, a7       # &V_final[i][j]
velocity_equation_for_u:
    #p  v1, v2, v3, v4, v5
    #u v7, v8, v9, v10, v11
    #v v13, v14, v15, v16, v17
    #  i-1, ij, i+1, j-1, j+1
    la t0, dx
    flw ft1, 0(t0)  # dx
    la t0, dy
    flw ft2, 0(t0) # dy
    fmul.s ft3, ft1, ft1 # dx^2
    fmul.s ft4, ft2, ft2 # dy^2
    la t0, rho
    flw ft5, 0(t0) # rho
    la t0, dt
    flw ft0, 0(t0) # dt
    # first three terms:
    # part 2
    vfsub.vv v19,v8, v10 # acc = u i,j - u i,j-1
    fdiv.s fs1, ft0, ft1
    vfmv.v.f v20, fs1 # dt/dx
    vfmul.vv v19, v20, v19 # acc = dt/dx * acc
    vfmul.vv v19, v8, v19 # acc = u i,j * acc
    # part 1
    #accumulate
    vfsub.vv v19, v8, v19 # acc = u i,j -  acc
    # part 3
    vfsub.vv v20, v8, v7 # acc2 = u i,j - u i-1,j
    fdiv.s fs1, ft0, ft2 
    vfmv.v.f v21, fs1 # dt/dy
    vfmul.vv v20, v21, v20 # acc2 = dt/dy * acc2
    vfmul.vv v20, v14, v20 # acc2 = v i,j * acc2
    # accumulate
    vfsub.vv v19, v19, v20 # acc = acc - acc2

    # pressure part
    vfsub.vv v20, v5, v4 # j+1, j-1
    li t0, 2
    fcvt.s.w fs1, t0 # save for later too
    fdiv.s fs2, ft0, ft1 # dt/dx
    fdiv.s fs2, fs2, fs1 # dt/2dx
    fdiv.s fs2, fs2, ft5 # dt/rho*2dx
    vfmv.v.f v21, fs2  # inside a vector
    vfmul.vv v20, v20, v21  # whole pressure term
    # accumulate
    vfsub.vv v19, v19, v20 # accumulated in v19

    # last big bracket
    vfmv.v.f v21, fs1 # 2 vectorized
    vfmul.vv v21, v21, v8 # 2u i,j (save for later)
    vfadd.vv v20, v11, v10 #  acc2 = u i j+1 + u i, j-1
    vfsub.vv v20 , v20, v21 # acc2 = acc2 - 2u i,j
    fdiv.s fs2, ft0, ft3  #dt/dx^2
    vfmv.v.f v23, fs2 # vectorized
    vfmul.vv v20, v23, v20 # acc2 = dt/dx^2 * acc2


    vfadd.vv v22, v9, v7 #  acc3 = u i+1 j + u i-1, j
    vfsub.vv v22 , v22, v21 # acc3 = acc3 - 2u i,j
    fdiv.s fs2, ft0, ft4 # dt/dy^2
    vfmv.v.f v23, fs2 # vectorized
    vfmul.vv v22, v23, v22 # acc3 = dt/dy^2 * acc3

    # accumulate:
    vfadd.vv v20, v20, v22 # acc2 = acc2 + acc3
    # multiply by nu
    la t0, nu
    flw fs4, 0(t0)
    vfmv.v.f v23, fs4
    vfmul.vv v20, v23, v20 # acc2 = nu * acc2

    # accumulate:
    vfadd.vv v19, v19, v20 # final answer
    
    add   t0, s7, a7
    vmv.v.v v20,v19
    vse32.v v20, (t0) # u_final


    # advance j
    add  a5, a5, t6
    blt  a5, a6, col_loop_u

    # next row
    addi t1, t1, 1
    blt  t1, t2, row_loop_u
    ret
copy_back_u_func:
     # now copy final->working u grid (1681 floats)
    la   t1, u_final_grid   # source base
    la   t2, u_grid         # destination base
    li   t0, 1681           # number of elements
    
copy_back_u:
    vsetvli t3, t0, e32, m1
    vle32.v  v0, 0(t1)         # load u_final_grid[i]
    vse32.v  v0, 0(t2)         # store into u_grid[i]
    slli t4, t3, 2
    add t1, t1, t4          # advance source pointer
    add t2, t2, t4          # advance destination pointer
    sub t0, t0, t3         # decrement counter
    bnez t0, copy_back_u    # loop if not done
    ret




process_v_grid:

    li     t1, 1            # i = 1
    li     t2, 40           # end before i = 40
    li     a6, 40           # j loop: end before 40
    li     s5, 164          # row size in bytes (41 * 4)

    la     t3, pressure_grid
    la     t4, u_grid
    la     t5, v_grid

    la     s2, pressure_final_grid
    la     s1, u_final_grid
    la     s0, v_final_grid

v_row_loop:
    # a0 = i * row_bytes
    mul  a0, t1, s5

    # Pressure pointers
    sub  a1, a0, s5         # (i-1)*row_bytes
    add  a1, t3, a1         # &P[i-1][0]
    add  a2, t3, a0         # &P[i][0]
    add  a3, a0, s5
    add  a3, t3, a3         # &P[i+1][0]
    add  a4, s2, a0         # &P_final[i][0]

    # U pointers
    sub  s3, a0, s5
    add  s3, t4, s3         # &U[i-1][0]
    add  s4, t4, a0         # &U[i][0]
    add  s6, a0, s5
    add  s6, t4, s6         # &U[i+1][0]
    add  s7, s1, a0         # &U_final[i][0]

    # V pointers
    sub  s8, a0, s5
    add  s8, t5, s8         # &V[i-1][0]
    add  s9, t5, a0         # &V[i][0]
    add s10, a0, s5
    add s10, t5, s10        # &V[i+1][0]
    add s11, s0, a0         # &V_final[i][0]

    # j = 1
    li   a5, 1

v_col_loop:
    # remaining = a6 - j
    sub  t0, a6, a5 

    # VL = min(remaining, max)
    vsetvli t6, t0, e32, m1

    # byte‑offset = j*4
    slli a7, a5, 2
    #Breakdown:
    # v1-v6 are for pressure  
    # v7-v12 for u
    # v13-v18 for v
    # ---- PRESSURE ----
    add  t0, a1, a7        # &P[i-1][j]
    vle32.v v1, (t0)                                                  
    #add  t0, a2, a7        # &P[i][j]
    #vle32.v v2, (t0)
    add  t0, a3, a7        # &P[i+1][j]
    vle32.v v3, (t0)
    #addi t0, a2, -4        # &P[i][j-1]
    #add  t0, t0, a7
    #vle32.v v4, (t0)
    #addi t0, a2,  4        # &P[i][j+1]
    #add  t0, t0, a7
    #vle32.v v5, (t0)
    #add  t0, a4, a7        # &P_final[i][j]

    # ---- U ----
    #add  t0, s3, a7        # &U[i-1][j]
    #vle32.v v7, 0(t0)
    add  t0, s4, a7        # &U[i][j]
    vle32.v v8, 0(t0)
    #add  t0, s6, a7        # &U[i+1][j]
    #vle32.v v9, (t0)
    #addi t0, s4, -4        # &U[i][j-1]
    #add  t0, t0, a7
    #vle32.v v10, (t0)
    #addi t0, s4,  4        # &U[i][j+1]
    #add  t0, t0, a7
    #vle32.v v11, (t0)
    #add  t0, s7, a7        # &U_final[i][j]

    # ---- V ----
    add  t0, s8, a7        # &V[i-1][j]
    vle32.v v13, (t0)
    add  t0, s9, a7        # &V[i][j]
    vle32.v v14, (t0)
    add  t0, s10, a7       # &V[i+1][j]
    vle32.v v15, (t0)

    addi t0, s9, -4        # &V[i][j-1]
    add  t0, t0, a7
    vle32.v v16, (t0)
    addi t0, s9,  4        # &V[i][j+1]
    add  t0, t0, a7
    vle32.v v17, (t0)
    #add  t0, s11, a7       # &V_final[i][j]
velocity_v_formula:
    # velocity update for v (vectorized)
    # p: v1=p[i-1,j], v2=p[i,j], v3=p[i+1,j], v4=p[i,j-1], v5=p[i,j+1]
    # u: v7=u[i-1,j], v8=u[i,j], v9=u[i+1,j], v10=u[i,j-1], v11=u[i,j+1]
    # v: v13=v[i-1,j], v14=v[i,j], v15=v[i+1,j], v16=v[i,j-1], v17=v[i,j+1]

    la t0, dx
    flw ft1, 0(t0)  # dx
    la t0, dy
    flw ft2, 0(t0) # dy
    fmul.s ft3, ft1, ft1 # dx^2
    fmul.s ft4, ft2, ft2 # dy^2
    la t0, rho
    flw ft5, 0(t0) # rho
    la t0, dt
    flw ft0, 0(t0) # dt

    # -- convection: -u*dt/dx*(v[i,j] - v[i,j-1])
    vfsub.vv v19, v14, v16   # v19 = v[i,j] - v[i,j-1]
    fdiv.s fs1, ft0, ft1     # fs1 = dt/dx
    vfmv.v.f v20, fs1        # v20 = dt/dx
    vfmul.vv v19, v20, v19   # v19 = dt/dx * (v diff)
    vfmul.vv v19, v8, v19    # v19 = u[i,j] * that
    vfsub.vv v19, v14, v19   # v19 = v[i,j] - v19

    # -- convection: -v*dt/dy*(v[i,j] - v[i-1,j])
    vfsub.vv v20, v14, v13   # v20 = v[i,j] - v[i-1,j]
    fdiv.s fs1, ft0, ft2     # fs1 = dt/dy
    vfmv.v.f v21, fs1        # v21 = dt/dy
    vfmul.vv v20, v21, v20   # v20 = dt/dy * (v diff)
    vfmul.vv v20, v14, v20   # v20 = v[i,j] * that
    vfsub.vv v19, v19, v20   # acc = previous - this

    # -- pressure gradient: -dt/(2*rho*dy)*(p[i+1,j] - p[i-1,j])
    vfsub.vv v20, v3, v1     # v20 = p[i+1,j] - p[i-1,j]
    li    t0, 2
    fcvt.s.w fs1, t0         # fs1 = 2.0
    fdiv.s fs2, ft0, ft2     # fs2 = dt/dy
    fdiv.s fs2, fs2, fs1     # fs2 = dt/(2*dy)
    fdiv.s fs2, fs2, ft5     # fs2 = dt/(2*rho*dy)
    vfmv.v.f v21, fs2        # v21 = coeff
    vfmul.vv v20, v20, v21   # v20 = pressure term
    vfsub.vv v19, v19, v20   # acc -= pressure term

    # -- diffusion terms
    # horizontal part: dt/dx^2 * (v[i,j+1] - 2v[i,j] + v[i,j-1])
    vfadd.vv v20, v17, v16   # v20 = v[i,j+1] + v[i,j-1]
    li    t0, 2
    fcvt.s.w fs1, t0         # fs1 = 2.0
    vfsub.vv v20, v20, v14   # v20 = neighbors_sum - v[i,j]
    vfsub.vv v20, v20, v14   # v20 = neighbors_sum - v[i,j]
    fdiv.s fs2, ft0, ft3     # fs2 = dt/dx^2 (ft3 = dx^2)
    vfmv.v.f v23, fs2        # v23 = coeff_x
    vfmul.vv v20, v23, v20   # v20 = horizontal diff

    # vertical part: dt/dy^2 * (v[i+1,j] - 2v[i,j] + v[i-1,j])
    vfadd.vv v22, v15, v13   # v22 = v[i+1,j] + v[i-1,j]
    vfsub.vv v22, v22, v14   # v22 = neighbors_sum - v[i,j]
    vfsub.vv v22, v22, v14   # v22 = neighbors_sum - v[i,j]
    fdiv.s fs2, ft0, ft4     # fs2 = dt/dy^2 (ft4 = dy^2)
    vfmv.v.f v23, fs2        # v23 = coeff_y
    vfmul.vv v22, v23, v22   # v22 = vertical diff

    # sum diffusion and multiply by nu
    vfadd.vv v20, v20, v22   # v20 = sum of diffs
    la    t0, nu
    flw   fs4, 0(t0)         # fs4 = nu
    vfmv.v.f v23, fs4        # v23 = nu
    vfmul.vv v20, v23, v20   # v20 = nu * diff_sum

    # accumulate final
    vfadd.vv v19, v19, v20   # v19 = updated v[i,j]

    # store
    add   t0, s11, a7        # t0 = &V_final[i][j]
    vse32.v v19, (t0)        # V_final[i][j] = v19

    # Advance j
    add   a5, a5, t6
    blt   a5, a6, v_col_loop

    # Next row
    addi  t1, t1, 1
    blt   t1, t2, v_row_loop
    ret
copy_back_v_func:
     # now copy final->working u grid (1681 floats)
    la   t1, v_final_grid   # source base
    la   t2, v_grid         # destination base
    li   t0, 1681           # number of elements
    
copy_back_v:
    vsetvli t3, t0, e32, m1
    vle32.v  v0, 0(t1)         # load u_final_grid[i]
    vse32.v  v0, 0(t2)         # store into u_grid[i]
    slli t4, t3, 2
    add t1, t1, t4          # advance source pointer
    add t2, t2, t4          # advance destination pointer
    sub t0, t0, t3         # decrement counter
    bnez t0, copy_back_v   # loop if not done
    ret


apply_pressure_boundary_conditions:
    li   t3, 41              # N = 41
    li   t6, 40              # boundary index
    li   t5, 4               # float size

    # p[:, 40] = p[:, 39]
    li   t0, 0
p_col_right_loop:
    mul  t1, t0, t3          # row * N
    add  t1, t1, 39
    slli t1, t1, 2
    la   t2, pressure_grid
    add  t2, t2, t1
    flw  ft0, 0(t2)          # p[row,39]
    addi t2, t2, 4           # p[row,40]
    fsw  ft0, 0(t2)
    addi t0, t0, 1
    blt  t0, t3, p_col_right_loop

    # p[0, :] = p[1, :]
    la   t1, pressure_grid
    addi t2, t1, 41*4        # next row
    li   t0, 0
p_row0_loop:
    flw  ft0, 0(t2)
    fsw  ft0, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 4
    addi t0, t0, 1
    blt  t0, t3, p_row0_loop

    # p[:, 0] = p[:, 1]
    li   t0, 0
p_col0_loop:
    mul  t1, t0, t3
    slli t1, t1, 2
    la   t2, pressure_grid
    add  t2, t2, t1
    flw  ft0, 4(t2)          # p[row,1]
    fsw  ft0, 0(t2)
    addi t0, t0, 1
    blt  t0, t3, p_col0_loop

    # p[40, :] = 0
    li   t0, 0
    li   a0, 40
    mul  t1, a0, t3
    slli t1, t1, 2
    la   t2, pressure_grid
    add  t2, t2, t1
    fmv.w.x ft0, zero
p_row40_loop:
    fsw  ft0, 0(t2)
    addi t2, t2, 4
    addi t0, t0, 1
    blt  t0, t3, p_row40_loop

    ret

apply_u_boundary_conditions:
    li   t3, 41
    li   t5, 4

    # u[:, 0] = 0 and u[:, 40] = 0
    li   t0, 0
    la   t1, u_grid
u_col_loop:
    fmv.w.x ft0, zero
    fsw ft0, 0(t1)
    fsw ft0, 160(t1)     # 40*4
    addi t1, t1, 164     # 41*4
    addi t0, t0, 1
    blt  t0, t3, u_col_loop

    # u[0, :] = 0
    la   t1, u_grid
    li   t0, 0
u_row0_loop:
    fmv.w.x ft0, zero
    fsw ft0, 0(t1)
    addi t1, t1, 4
    addi t0, t0, 1
    blt  t0, t3, u_row0_loop

    # u[40, :] = 1
    li   a0, 40
    mul  t1, a0, t3
    slli t1, t1, 2
    la   t2, u_grid
    add  t2, t2, t1
    li   a0, 0x3f800000      # 1.0
    fmv.w.x ft0, a0
    li   t0, 0
u_row40_loop:
    fsw ft0, 0(t2)
    addi t2, t2, 4
    addi t0, t0, 1
    blt  t0, t3, u_row40_loop

    ret

apply_v_boundary_conditions:
    li   t3, 41
    li   t5, 4

    # v[:, 0] = 0 and v[:, 40] = 0
    li   t0, 0
    la   t1, v_grid
v_col_loop_x:
    fmv.w.x ft0, zero
    fsw ft0, 0(t1)
    fsw ft0, 160(t1)
    addi t1, t1, 164
    addi t0, t0, 1
    blt  t0, t3, v_col_loop_x

    # v[0, :] = 0
    la   t1, v_grid
    li   t0, 0
v_row0_loop:
    fmv.w.x ft0, zero
    fsw ft0, 0(t1)
    addi t1, t1, 4
    addi t0, t0, 1
    blt  t0, t3, v_row0_loop

    # v[40, :] = 0
    li   a0, 40
    mul  t1, a0, t3
    slli t1, t1, 2
    la   t2, v_grid
    add  t2, t2, t1
    li   t0, 0
v_row40_loop:
    fmv.w.x ft0, zero
    fsw  ft0, 0(t2)
    addi t2, t2, 4
    addi t0, t0, 1
    blt  t0, t3, v_row40_loop

    ret

    .text
    .globl store_grids
# a0 = frame index (0–99)
# Copies: pressure_grid  -> pressure_log[frame]
#         u_grid         -> u_log[frame]
#         v_grid         -> v_log[frame]
# Each frame = 1681 floats = 6724 bytes

store_grids:
    # ---- base pointers (sources) ----
    la      t0, pressure_grid      # src P
    la      t2, u_grid             # src U
    la      t4, v_grid             # src V

    # ---- base pointers (dest logs) ----
    la      t1, pressure_log       # dst P_log
    la      t3, u_log              # dst U_log
    la      t5, v_log              # dst V_log

    # ---- compute byte offset = frame_idx * 6724 ----
    li      t6, 6724               # 1681 * 4
    mul     t6, a0, t6
    add     t1, t1, t6             # advance P_log
    add     t3, t3, t6             # advance U_log
    add     t5, t5, t6             # advance V_log

    # ---- remaining element count ----
    li      t6, 1681               # remaining = N

here:  
    vsetvli a6, t6, e32, m1           # VL = min(remaining, hw_max)

    # vector loads
    vle32.v v0, (t0)               # P chunk
    vle32.v v1, (t2)               # U chunk
    vle32.v v2, (t4)               # V chunk

    # vector stores
    vse32.v v0, (t1)
    vse32.v v1, (t3)
    vse32.v v2, (t5)

    # pointer bumps: bytes = VL * 4
    slli    a7, a6, 2
    add     t0, t0, a7             # src P
    add     t1, t1, a7             # dst P_log
    add     t2, t2, a7             # src U
    add     t3, t3, a7             # dst U_log
    add     t4, t4, a7             # src V
    add     t5, t5, a7             # dst V_log

    # remaining -= VL
    sub     t6, t6, a6
    bnez    t6, here

    ret



exit:
j exit




