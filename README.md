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
3. Terminal or Bash shell  
4. git

To build all data, including broadband databases, you will need
[unar](https://theunarchiver.com/command-line) to unpack the large
compressed files. The easiest way to get it is with
[homebrew](https://brew.sh): 

```bash
brew install unar
```

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

## Piecemeal

You can you can also run the scripts one by one

