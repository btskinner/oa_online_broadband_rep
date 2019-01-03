This repository contains the replication files for  

> Skinner, B.T. (2019). [Making the connection: Broadband access and
> online course enrollment at public open admissions
> institutions](https://link.springer.com/article/10.1007/s11162-018-9539-6). Research
> in Higher Education, 1-40.  

# Requirements

To run the core analyses, you will need the following programs on your
machine (tested on MacOS):

1. [R](https://cran.r-project.org)  
2. [CmdStan](https://mc-stan.org/users/interfaces/cmdstan)  
3. [Bash](https://www.gnu.org/software/bash/)  
4. [git](https://git-scm.com)  
5. [sqlite](https://www.sqlite.org/index.html)  

To build all data, including broadband databases, you will need
[unar](https://theunarchiver.com/command-line) to unpack the large
compressed files. The easiest way to get it is with
[homebrew](https://brew.sh): 

```bash
brew install unar
```

You can also use Homebrew to update Bash, git, and sqlite if you want,
though that shouldn't be necessary a relatively modern machine.

To replicate analysis and tables, clone or download the repository,
and choose one of the following methods:

## Makefile

If your machine has make, simply run the makefile from the terminal

```bash
make
```

This makefile will   
1. download and install all required R packages  
2. download all required data files  
3. build/clean data  
4. run analyses  
5. knit tables/figures  

### OPTIONS

At the top of the makefile, adjust the settings to best your
machine. The defaults should work for most users:

```bash
# --- settings -----------------------------------

# set to https or ssh (probably https for most)
git_type := https

# cores (used when building cmdstan)
cores := 4
```

## Piecemeal

You can you can also run the scripts one by one. You will need to:

1. Get the data files listed in `./data/README.md`  
2. Build Broadband database using scripts in `./scripts/bash`  

```bash
cd ./scripts/bash
./make_bb.sh ../../data/broadband/zip ../../data/broadband .
```

3. Download required R packages, found in `get_packages.R`  
4. Clean IPEDS using `clean_ipeds.R`  
5. Clean Broadband using `clean_bb.R`  
6. Clean data using `clean_data.R`  
7. Download and build
   [CmdStan](https://mc-stan.org/users/interfaces/cmdstan)  
8. Compile `*.stan` model scripts  
9. Run analyses using `./scripts/bash/run_stan.sh`  

```bash
# example call (assuming in ./scripts/bash directory)
./run_stan.sh ../stan/sl_normal ../../data/cleaned sl_normal full ../../output both ../r
```

10. Make figures using `make_figures.R`  
11. Knit tables and figures document using `table_figures.Rnw`

**NB** Most R scripts assume command line arguments. If you are not using
makefile or calling from the command line, you will need to replace
`args` object with a vector of the proper paths indicated in the files.
