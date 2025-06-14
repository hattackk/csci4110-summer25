#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include "common.h"

#define MAX_PARTICLES_PER_BIN 64

int bin_index(int x, int y, int bins_per_row) {
    return x + y * bins_per_row;
}

int main(int argc, char **argv)
{
    if (find_option(argc, argv, "-h") >= 0)
    {
        printf("Options:\n");
        printf("-h to see this help\n");
        printf("-n <int> to set the number of particles\n");
        printf("-o <filename> to specify the output file name\n");
        return 0;
    }

    int n = read_int(argc, argv, "-n", 1000);
    char *savename = read_string(argc, argv, "-o", NULL);

    FILE *fsave = savename ? fopen(savename, "w") : NULL;
    particle_t *particles = (particle_t *)malloc(n * sizeof(particle_t));
    set_size(n);
    init_particles(n, particles);

    int bins_per_row = (int)ceil(size / cutoff);
    int bin_count = bins_per_row * bins_per_row;

    particle_t **bins = (particle_t **)malloc(bin_count * sizeof(particle_t *));
    int *bin_sizes = (int *)calloc(bin_count, sizeof(int));
    for (int i = 0; i < bin_count; i++)
        bins[i] = (particle_t *)malloc(MAX_PARTICLES_PER_BIN * sizeof(particle_t));

    double simulation_time = read_timer();

    for (int step = 0; step < NSTEPS; step++)
    {
        // Clear bins
        for (int i = 0; i < bin_count; i++)
            bin_sizes[i] = 0;

        // Re-bin particles
        for (int i = 0; i < n; i++)
        {
            int x = (int)(particles[i].x / cutoff);
            int y = (int)(particles[i].y / cutoff);
            int idx = bin_index(x, y, bins_per_row);
            bins[idx][bin_sizes[idx]++] = particles[i];
        }

        // Compute forces
        for (int i = 0; i < n; i++)
        {
            particle_t *p = &particles[i];
            p->ax = p->ay = 0;

            int x = (int)(p->x / cutoff);
            int y = (int)(p->y / cutoff);

            for (int dx = -1; dx <= 1; dx++)
            {
                for (int dy = -1; dy <= 1; dy++)
                {
                    int nx = x + dx;
                    int ny = y + dy;
                    if (nx >= 0 && ny >= 0 && nx < bins_per_row && ny < bins_per_row)
                    {
                        int nidx = bin_index(nx, ny, bins_per_row);
                        for (int j = 0; j < bin_sizes[nidx]; j++)
                            apply_force(*p, bins[nidx][j]);
                    }
                }
            }
        }

        // Move particles
        for (int i = 0; i < n; i++)
            move(particles[i]);

        // Save
        if (fsave && (step % SAVEFREQ) == 0)
            save(fsave, n, particles);
    }

    simulation_time = read_timer() - simulation_time;
    printf("n = %d, simulation time = %g seconds\n", n, simulation_time);

    free(particles);
    for (int i = 0; i < bin_count; i++)
        free(bins[i]);
    free(bins);
    free(bin_sizes);
    if (fsave)
        fclose(fsave);

    return 0;
}
