# HW1: Matrix Multiplication
Read this document all the way through, nearly everything in it is important for the project.

## Version control

This is a Git repository.
ECU _highly_ recommends creating your own GitHub repo for your classes. This can be used to track your changes and/or collaborate with your teammates if an assignment is team based. Note: HW1 is not team-based, but starting a Github page is a very good practice.

Follow these steps to set up your own github project area:

1. Go to https://github.com/new
2. Name the repository anything you like, say `csci4110-hw1`.
Make sure it is set to **PRIVATE**.
3. Once this is done, run the following commands:

```
student@login04:~/hw1> git remote rename origin staff
student@login04:~/hw1> git remote add origin https://github.com/YOUR_GITHUB_USERNAME/csci4110-hw1.git
student@login04:~/hw1> git push -u origin main
```

If you prefer to use SSH to connect to GitHub,
[follow these instructions](https://help.github.com/en/github/using-git/which-remote-url-should-i-use#cloning-with-ssh-urls)

## Module configuration

We will use the Bridges2 system at PSC.

The user guide will be required reading for this class. Please review the manual before asking questions, as most of your questions will be answered in the manual.

https://www.psc.edu/resources/bridges-2/user-guide/

Our projects will require some modules to be loaded. See the module section of the users guide here: https://www.psc.edu/resources/software/module/
Also, see the hw1-notes document in this respository

## Build system

This assignment uses [CMake](https://cmake.org/) to provide a consistent build system for all students.
You should not need to modify the provided build in any way (CMakeLists.txt). See the comment above about modules, which will be required to perform the compile and to run the code.
This document describes the basic process for configuring and building the code.

First, note that this file is in the _source directory_.
You will run CMake commands from the _build directory_, which you create by running

```
student@login04:~/hw1> mkdir build
student@login04:~/hw1> cd build
```

## Build configuration

From this _build directory_, it is now possible to _configure_ the build.
The basic way to do this is:

```
student@login04:~/hw1/build> cmake -DCMAKE_BUILD_TYPE=Release ..
```
(do not forgot the two "dots" .. at the end of the command above, which specifies "[look] back one directory")

This command tells CMake to generate the build files for HW1 in _Release_ mode.
The syntax `-D[VAR]=[VAL]` allows you to set a variable.
Only `CMAKE_BUILD_TYPE` is required, though there are more variables that you might want to change:

1. `CMAKE_BUILD_TYPE` -- this is either `Debug` or `Release`.
2. `CMAKE_C_FLAGS` -- this allows you to specify additional compiler flags.
3. `MAX_SPEED` -- this should be equal to the maximum number of gigaflops-per-second (GF/s) your processor can execute.
It is set to 56 by default, which matches Perlmutter's (and Bridges-2) processors.
4. `TEAM_NO` -- when you are ready to submit your assignment, set this to be your **two-digit** team number, if no team then use 0.
5. `ALL_SIZES` -- set to `ON` to test against a large set of matrix sizes. `OFF` by default.

When you build in Debug mode, optimizations are disabled. (good for initial build and benchmarking/testing optimizations)
Yet when writing parallel code, it is often the case that problems arise only when optimizations are enabled.
You can recover debugging symbols in Release mode (for use with `gdb`) by running:

```
student@login04:~/hw1/build> cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-g3" ..
```

Similarly, you can enable optimizations in Debug mode by running:

```
student@login04:~/hw1/build> cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-O2" ..
```

## Compiling

Once your build is configured, you can actually compile by running `make` from the build directory.
If anything went wrong, or if changes were made you may need to run "make clean"

```
student@login04:~/hw1/build> make
```

This will produce several files:

```
student@login04:~/hw1/build> ls
benchmark-blas     CMakeCache.txt       job-blas     Makefile
benchmark-blocked  CMakeFiles           job-blocked
benchmark-naive    cmake_install.cmake  job-naive
```

The executables `benchmark-blas`, `benchmark-blocked`, and `benchmark-naive` are the relevant ones here.
You can freely make configuration changes to the build and re-run make however you choose.

## Testing

To run your code on the cluster, you can use the generated `job-xxxxxx` script like so:

```
student@login04:~/hw1/build> sbatch job-blocked
Submitted batch job 9637622
```

The job is now submitted to the job queue.
You can now check on the status of your submitted job using a few different commands.

```
student@login04:~/hw1/build> squeue -u student
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
           4613712 regular_m job-naiv   yuedai PD       0:00      1 (QOSMaxJobsPerUserLimit)
           4613708 regular_m job-bloc   yuedai  R       0:07      1 nid004961
           4613705 regular_m job-blas   yuedai  R       0:16      1 nid005254
student@login04:~/hw1/build> sqs
JOBID            ST USER      NAME          NODES TIME_LIMIT       TIME  SUBMIT_TIME          QOS             START_TIME           FEATURES       NODELIST(REASON
4613760          PD yuedai    job-naive     1           2:00       0:00  2023-01-11T21:38:08  debug           2023-01-11T21:38:35  cpu            (QOSMaxJobsPerU
4613758          R  yuedai    job-blocked   1           2:00       0:02  2023-01-11T21:38:04  debug           2023-01-11T21:38:33  cpu            nid004649      
4613754          R  yuedai    job-blas      1           2:00       0:07  2023-01-11T21:37:58  debug           2023-01-11T21:38:28  cpu            nid006483

```

When our job is finished, we'll find new files in our build directory (current directory) containing the output of our program.
For example, we'll find the files similar to job-blas.o4613758 and job-blas.e4613758.
The first file contains the standard output of our program, and the second file contains the standard error.

Feel free to modify `job-blocked`, but note that changes to it will be overwritten by CMake if you reconfigure your
build.
It might therefore be easier to copy it under a new name like `my-job` and modify it as you desire.
Example in Linux: $ cp job-blocked my-job"
Or you could open it in an editor and save it as a new file

### Interactive sessions

You may find it useful to launch an [interactive session](https://www.psc.edu/resources/bridges-2/user-guide/#interactive-sessions) when developing your code.
This lets you compile and run code interactively on a compute node that you've reserved.
In addition, running interactively lets you use the special interactive queue, which means you'll receive your
allocation quicker.

## Submission

Part of the grade will be making modifications to the dgemm-blocked.c code in order to make it run more efficiently. Run three benchmarks of the standard blocked benchmark before you make any modifications. In fact, it is a good idea to make a backup of the blocked code before you make any changes. Once you have the three benchmark runs, you can make modifications to improve the speed of the blocked benchmark. Refer to the slides and the book for help with making the code more efficient. Be sure you understand why the changes made it more efficient. For the grade, I will be looking for at least a 5% increase in the benchmark speed while still performing all the same benchmarks. In other words, do not have the program quit early before performing all the steps. Do not copy the code from the more efficient benchmarks included here or on the internet. In order to learn the most from the process, this should be your own work. I mentioned a few things in class such as loop unfolding, using registers, writing assembly inside of c language, compiler optimizations, etc.

Your write up should give a syopsis of the performance between the benchmarks, explain the differences in speed between the naive, blocked and blas benchmarks. Look through the code for each benchmark and explain why some of the benchmarks ran faster than others. Explain why your code modifications or compilation changes increased performance. Please write this in your own words, no direct copy/paste of websites explaining blas, for instance.
The paper should be at least a half-page to a full page in length. More than a page should not be neccessary.

Then configure the build with your group number:
Note: we do not have teams for this assignment, just use 00 for your team number.
```
student@login04:~/hw1/build> cmake -DGROUP_NO=NN ..
student@login04:~/hw1/build> make package
```

Once you're happy with your code compilation and feel it is running properly, you can get ready to submit.
First, make sure that your write up is in the same directory as this README and is named `csci4110-PirateID_hw1.pdf` where `PirateID`is your PirateID (beginning of your email address, but without the full email) Note: this is NOT your bannerID number.

If you have difficulty creating the pdf, you can create a simple text file with the same name but ending in .txt instead of .pdf
Use the command below to produce an archive containing the following files:

```
student@login04:~/hw1/build> tar tfz cs4410-pirateID_hw1.tar.gz 
Possible tar command output:
  csci4110GroupNN_hw1/csci4110GroupNN_hw1.pdf
  csci4110GroupNN_hw1/dgemm-blocked.c
  ...
```

Make sure you capture the binary files there were built. I want to make sure everyone is able to build successfully, and it will be part of the grade.

I showed the class how to "scp" the file to your own computer during the last class. If you are having trouble with this, you could obtain your code from your git site as well, if you created one. If you have a Windows system, you can use the "putty" tools in order to use scp from a Windows command line. Google "putty pscp.exe". The guy who made these tools is named chiark, double check that you are getting the utility from the right place.

The final turn in for this assignment should be submitted to Canvas. It is set to allow .tar and .zip files, with the preference being a .tar file.


Optional reading:
If you prefer to create the archive yourself, make sure that it follows this structure _exactly_.

## Windows Instructions (windows use is not recommended except as a client to connect to the HPC)

We recommend using [CLion](https://www.jetbrains.com/clion/) ([free for students](https://www.jetbrains.com/student/))
and [WSL](https://docs.microsoft.com/en-us/windows/wsl/about) (Ubuntu 18.04.3 LTS) for developing on Windows.
CLion provides [instructions](https://www.jetbrains.com/help/clion/how-to-use-wsl-development-environment-in-clion.html)
for setting up the IDE for use with WSL.
Be sure to install `libopenblas-dev` from within Ubuntu as well.

The starter code will compiler with MSVC and Visual Studio on Windows, but we do not recommend trying to write
first with MSVC and then porting to GCC (the required compiler).
MSVC does not implement many useful features in the C language and is fundamentally a C++ compiler.

## GCC Special Features

If you find that certain compiler flags offer a significant speed up to your code, you should add them to your
source file using the GCC optimize pragma.
For instance if you wanted to specifically enable loop peeling, you could add the following line to the top of your file.

```
#pragma GCC optimize ("peel-loops")
```

This works with any -f flag (eg. -fpeel-loops)
Note that this applies to all functions.
If you want to just tune the optimization of a single function use

```
__attribute__((optimize("peel-loops")))
void my_func() { ... }
```

See it in action here: https://godbolt.org/z/RvXfty.

Read more in the GCC documentation here: https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#Common-Function-Attributes 
