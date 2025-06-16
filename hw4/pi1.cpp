// C++ code to implement computation of pi with MPI Send/Recv two-way communication
#include <bits/stdc++.h>
#include <stdio.h>
#include <math.h>
#include <mpi.h>
using namespace std;

bool DEBUG_ENABLED = false;

void debug_log(const string &msg){
    if(DEBUG_ENABLED){
        std::cout<<"[DEBUG] " << msg << std::endl;
    }
}

// Function to calculate PI (unchanged)
long double calcPI(long double PI, long double n, long double sign, long double iterations)
{
    // Add for (iterations)
    for (unsigned long int i = 0; i <= iterations; i++) {
        PI = PI + (sign * (4 / ((n) * (n + 1) * (n + 2))));
        // Add and sub
        // alt sequences
        sign = sign * (-1);
        // Increment by 2 according to Nilkantha’s formula
        n += 2;
    }
    // Return the value of Pi
    return PI;
}

// main
int main(int argc, char** argv)
{
    // Initialize MPI
    MPI_Init(&argc, &argv);
    
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    auto start = std::chrono::steady_clock::now(); // set timer
    
    long double PI = 3, n = 2, sign = 1;
    const long double PI25DT = 3.141592653589793238462643383; // set test value for error
    long double cPI = 0.0;
    long double total_iterations = 0;
    
    // Root process handles input and sends work to other processes
    if (rank == 0) {
        if (argc == 1) {
            printf("You must pass a single numeric value\n");
            printf("the value should be 100M or higher\n");
            MPI_Finalize();
            return -1;
        }
        total_iterations = std::stod(argv[1]); // set to passed-in numeric value
        printf("Using %d MPI processes\n", size);
        
        // Send total iterations to each worker process
        for (int i = 1; i < size; i++) {
            MPI_Send(&total_iterations, 1, MPI_LONG_DOUBLE, i, 0, MPI_COMM_WORLD);
        }
    } else {
        // Worker processes receive total iterations from root
        MPI_Recv(&total_iterations, 1, MPI_LONG_DOUBLE, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }
    
    // Calculate work distribution for each process
    long double iterations_per_process = total_iterations / size;
    long double start_iteration = rank * iterations_per_process;
    long double end_iteration;
    
    // Handle remainder for last process
    if (rank == size - 1) {
        end_iteration = total_iterations;
    } else {
        end_iteration = start_iteration + iterations_per_process;
    }
    
    long double local_iterations = end_iteration - start_iteration;
    
    // Calculate starting values for this process's portion
    // Each iteration in the original loop increments n by 2 and flips sign
    long double local_n = n + (2 * start_iteration);
    // Sign alternates: starts with +1, then -1, +1, -1, ...
    // For iteration i, sign = initial_sign * (-1)^i
    long double local_sign = (((unsigned long long)start_iteration % 2) == 0) ? sign : -sign;
    
    printf("Process %d: start_iter=%.0Lf, local_iter=%.0Lf, local_n=%.0Lf, local_sign=%.0Lf\n", 
           rank, start_iteration, local_iterations, local_n, local_sign);
    long double local_PI = 0.0; // Start from 0 for partial calculations
    
    // Each process calculates its portion
    long double partial_result = calcPI(local_PI, local_n, local_sign, local_iterations);
    
    printf("Process %d calculated partial result: %.20Lf (iterations: %.0Lf)\n", 
           rank, partial_result, local_iterations);
    
    // Two-way communication: Send results to root and receive final answer
    if (rank == 0) {
        // Root process: receive partial results from all worker processes
        cPI = PI + partial_result; // Start with initial PI (3) + root's contribution
        
        for (int i = 1; i < size; i++) {
            long double worker_result;
            MPI_Recv(&worker_result, 1, MPI_LONG_DOUBLE, i, 1, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            cPI += worker_result;
        }
        
        // Display results
        printf("PI is approx %.50Lf, Error is %.50Lf\n", cPI, fabsl(cPI - PI25DT));
        
        auto end = std::chrono::steady_clock::now(); // end timer
        auto diff = end - start; // compute time
        std::cout << std::chrono::duration<double, std::milli>(diff).count() << " Runtime ms" << std::endl;
        
        // Send final result back to all worker processes
        for (int i = 1; i < size; i++) {
            MPI_Send(&cPI, 1, MPI_LONG_DOUBLE, i, 2, MPI_COMM_WORLD);
        }
        
        printf("Root process sent final PI value to all workers\n");
        
    } else {
        // Worker processes: send partial result to root
        MPI_Send(&partial_result, 1, MPI_LONG_DOUBLE, 0, 1, MPI_COMM_WORLD);
    }
    
    MPI_Finalize();
    return 0;
}