#include <stdio.h>

extern float pressure_log[];
extern float u_log[];
extern float v_log[];
int frames = 400;

void print_grids() {
    FILE *file = fopen("grids_output_C.txt", "a");  // "a" = append mode
    if (!file) {
        perror("Failed to open file for appending grids");
        return;
    }


    // Print Pressure Grid
    fprintf(file, "=== Pressure Grid ===\n");
    for (int i = 0; i < 41 * 41*frames; ++i) {
        if (i % 41 == 0) fprintf(file, "\n");
        fprintf(file, "%.6f ", pressure_log[i]);
    }
    fprintf(file, "\n\n");

    // Print U Grid
    fprintf(file, "=== U Grid ===\n");
    for (int i = 0; i < 41 * 41*frames; ++i) {
        if (i % 41 == 0) fprintf(file, "\n");
        fprintf(file, "%.6f ", u_log[i]);
    }
    fprintf(file, "\n\n");

    // Print V Grid
    fprintf(file, "=== V Grid ===\n");
    for (int i = 0; i < 41 * 41*frames; ++i) {
        if (i % 41 == 0) fprintf(file, "\n");
        fprintf(file, "%.6f ", v_log[i]);
    }
    fprintf(file, "\n\n");

    fclose(file);
}
