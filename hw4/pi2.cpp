#include <bits/stdc++.h>
#include <stdio.h>
#include <math.h>
#include <mpi.h>
using namespace std;

// Function to calculate PI
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
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    bool debug = false;

    // Parse CLI arguments
    long double iterations = -1;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--debug") == 0) {
            debug = true;
        } else {
            iterations = std::stold(argv[i]);
        }
    }

    MPI_Win win;
    long double result = 0.0;
    long double *win_buf = nullptr;

    if (rank == 0) {
        MPI_Win_allocate(sizeof(long double), sizeof(long double), MPI_INFO_NULL, MPI_COMM_WORLD, &win_buf, &win);
        *win_buf = 0.0;
    } else {
        MPI_Win_allocate(0, sizeof(long double), MPI_INFO_NULL, MPI_COMM_WORLD, &win_buf, &win);
    }

    auto start = std::chrono::steady_clock::now();

    long double PI = 3, n = 2, sign = 1;
    const long double PI25DT = 3.141592653589793238462643383;

    if (iterations <= 0) {
        if (rank == 0) {
            printf("Usage: %s <iterations> [--debug]\n", argv[0]);
            printf("The value should be 100M or higher\n");
        }
        MPI_Win_free(&win);
        MPI_Finalize();
        return -1;
    }

    // Divide work evenly
    long double chunk = iterations / size;
    long double local_start_n = n + rank * chunk * 2;
    long double local_sign = (rank % 2 == 0) ? sign : -sign;

    if (debug) {
        printf("[Rank %d] chunk: %.0Lf, start_n: %.0Lf, sign: %.0Lf\n", rank, chunk, local_start_n, local_sign);
    }

    long double local_PI = calcPI(0.0, local_start_n, local_sign, chunk - 1);

    if (debug) {
        printf("[Rank %d] local_PI: %.15Lf\n", rank, local_PI);
    }

    // One-sided communication: accumulate local_PI into rank 0
    MPI_Win_fence(0, win);
    MPI_Accumulate(&local_PI, 1, MPI_LONG_DOUBLE, 0, 0, 1, MPI_LONG_DOUBLE, MPI_SUM, win);
    if (debug) {
        printf("[Rank %d] Accumulated local_PI to rank 0\n", rank);
    }
    MPI_Win_fence(0, win);

    if (rank == 0) {
        long double cPI = *win_buf + PI;
        printf("PI is approx %.50Lf, Error is %.50Lf\n", cPI, fabsl(cPI - PI25DT));
        auto end = std::chrono::steady_clock::now();
        auto diff = end - start;
        std::cout << std::chrono::duration<double, std::milli>(diff).count() << " Runtime ms" << std::endl;
    }

    MPI_Win_free(&win);
    MPI_Finalize();
    return 0;
}
