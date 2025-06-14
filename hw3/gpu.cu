#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include <cuda.h>
#include "common.h"

#define NUM_THREADS 256

extern double size;

// Spatial binning parameters
#define MAX_PARTICLES_PER_BIN 64
__device__ int d_bins_size;
__device__ int d_bins_count;

//
//  benchmarking program
//

__device__ void apply_force_gpu(particle_t &particle, particle_t &neighbor)
{
    double dx = neighbor.x - particle.x;
    double dy = neighbor.y - particle.y;
    double r2 = dx * dx + dy * dy;
    if( r2 > cutoff*cutoff )
        return;
    //r2 = fmax( r2, min_r*min_r );
    r2 = (r2 > min_r*min_r) ? r2 : min_r*min_r;
    double r = sqrt( r2 );

    //
    //  very simple short-range repulsive force
    //
    double coef = ( 1 - cutoff / r ) / r2 / mass;
    particle.ax += coef * dx;
    particle.ay += coef * dy;
}

// Kernel to assign particles to spatial bins
__global__ void bin_particles_gpu(particle_t * particles, int n, int * bins, int * bin_counts, double size)
{
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if(tid >= n) return;
    
    particle_t * p = &particles[tid];
    
    // Calculate bin size based on cutoff radius
    int bins_per_side = (int)ceil(size / cutoff);
    int bin_x = (int)(p->x / cutoff);
    int bin_y = (int)(p->y / cutoff);
    bin_x = min(max(bin_x, 0), bins_per_side - 1);
    bin_y = min(max(bin_y, 0), bins_per_side - 1);
    
    int bin_id = bin_y * bins_per_side + bin_x;
    int pos = atomicAdd(&bin_counts[bin_id], 1);
    
    if(pos < MAX_PARTICLES_PER_BIN) {
        bins[bin_id * MAX_PARTICLES_PER_BIN + pos] = tid;
    }
}

__global__ void compute_forces_gpu(particle_t * particles, int n, int * bins, int * bin_counts, double size)
{
    // Get thread (particle) ID
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if(tid >= n) return;
    
    particles[tid].ax = particles[tid].ay = 0;
    
    particle_t * p = &particles[tid];
    
    // Calculate which bin this particle is in
    int bins_per_side = (int)ceil(size / cutoff);
    int bin_x = (int)(p->x / cutoff);
    int bin_y = (int)(p->y / cutoff);
    
    bin_x = min(max(bin_x, 0), bins_per_side - 1);
    bin_y = min(max(bin_y, 0), bins_per_side - 1);
    
    for(int dy = -1; dy <= 1; dy++) {
        for(int dx = -1; dx <= 1; dx++) {
            int check_x = bin_x + dx;
            int check_y = bin_y + dy;
            if(check_x < 0 || check_x >= bins_per_side || 
               check_y < 0 || check_y >= bins_per_side) continue;
            
            int check_bin = check_y * bins_per_side + check_x;
            int count = bin_counts[check_bin];
            
            // Iterate through particles in this bin but don't apply 
            // the force to itsself 
            for(int i = 0; i < min(count, MAX_PARTICLES_PER_BIN); i++) {
                int neighbor_id = bins[check_bin * MAX_PARTICLES_PER_BIN + i];
                if(neighbor_id != tid) { 
                    apply_force_gpu(particles[tid], particles[neighbor_id]);
                }
            }
        }
    }
}

__global__ void move_gpu (particle_t * particles, int n, double size)
{

    // Get thread (particle) ID
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if(tid >= n) return;
    
    particle_t * p = &particles[tid];
    //
    //  slightly simplified Velocity Verlet integration
    //  conserves energy better than explicit Euler method
    //
    p->vx += p->ax * dt;
    p->vy += p->ay * dt;
    p->x  += p->vx * dt;
    p->y  += p->vy * dt;
    
    //
    //  bounce from walls
    //
    while( p->x < 0 || p->x > size )
    {
        p->x  = p->x < 0 ? -(p->x) : 2*size-p->x;
        p->vx = -(p->vx);
    }
    while( p->y < 0 || p->y > size )
    {
        p->y  = p->y < 0 ? -(p->y) : 2*size-p->y;
        p->vy = -(p->vy);
    }

}



int main( int argc, char **argv )
{
    // This takes a few seconds to initialize the runtime
    cudaThreadSynchronize();
    
    if( find_option( argc, argv, "-h" ) >= 0 )
    {
        printf( "Options:\n" );
        printf( "-h to see this help\n" );
        printf( "-n <int> to set the number of particles\n" );
        printf( "-o <filename> to specify the output file name\n" );
        return 0;
    }
    
    int n = read_int( argc, argv, "-n", 1000 );

    char *savename = read_string( argc, argv, "-o", NULL );

    FILE *fsave = savename ? fopen( savename, "w" ) : NULL;
    particle_t *particles = (particle_t*) malloc( n * sizeof(particle_t) );
    
    // GPU particle data structure
    particle_t * d_particles;
    cudaMalloc((void **) &d_particles, n * sizeof(particle_t));
    
    set_size( n );

    init_particles( n, particles );
    
    // Calculate bin grid size
    int bins_per_side = (int)ceil(size / cutoff);
    int total_bins = bins_per_side * bins_per_side;
    
    // Allocate memory for spatial binning
    int * d_bins;
    int * d_bin_counts;
    cudaMalloc((void **) &d_bins, total_bins * MAX_PARTICLES_PER_BIN * sizeof(int));
    cudaMalloc((void **) &d_bin_counts, total_bins * sizeof(int));
    
    cudaThreadSynchronize();
    double copy_time = read_timer( );
    
    // Copy the particles to the GPU
    cudaMemcpy(d_particles, particles, n * sizeof(particle_t), cudaMemcpyHostToDevice);

    cudaThreadSynchronize();
    copy_time = read_timer( ) - copy_time;
    
    //
    //  simulate a number of time steps
    //
    cudaThreadSynchronize();
    double simulation_time = read_timer( );

    for( int step = 0; step < NSTEPS; step++ )
    {
  
        cudaMemset(d_bin_counts, 0, total_bins * sizeof(int));
        int blks = (n + NUM_THREADS - 1) / NUM_THREADS;
        bin_particles_gpu <<< blks, NUM_THREADS >>> (d_particles, n, d_bins, d_bin_counts, size);
        compute_forces_gpu <<< blks, NUM_THREADS >>> (d_particles, n, d_bins, d_bin_counts, size);
        
        //
        //  move particles
        //
        move_gpu <<< blks, NUM_THREADS >>> (d_particles, n, size);
        
        //
        //  save if necessary
        //
        if( fsave && (step%SAVEFREQ) == 0 ) {
            // Copy the particles back to the CPU
            cudaMemcpy(particles, d_particles, n * sizeof(particle_t), cudaMemcpyDeviceToHost);
            save( fsave, n, particles);
        }
    }
    cudaThreadSynchronize();
    simulation_time = read_timer( ) - simulation_time;
    
    printf( "CPU-GPU copy time = %g seconds\n", copy_time);
    printf( "n = %d, simulation time = %g seconds\n", n, simulation_time );
    
    free( particles );
    cudaFree(d_particles);
    cudaFree(d_bins);
    cudaFree(d_bin_counts);
    if( fsave )
        fclose( fsave );
    
    return 0;
}
