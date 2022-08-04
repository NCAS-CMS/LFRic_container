# LFRic_container

A [Singularity](https://sylabs.io/) container of the [LFRic](https://www.metoffice.gov.uk/research/approach/modelling-systems/lfric) software stack built with an included [Intel one API compiler](https://software.intel.com/content/www/us/en/develop/tools/oneapi/hpc-toolkit.html).

It is based on [Fedora](https://getfedora.org/) and includes all of the software package dependencies and tools in the standard [LFRic build environment](https://code.metoffice.gov.uk/trac/lfric/wiki/LFRicTechnical/LFRicBuildEnvironment) but compiled with Intel fortran rather than gfortran, and gcc.

A compiler is **not** required on the build and run machine where the container is deployed. All compilation of LFRic is done via the containerised compilers.

LFRic components are built using a shell within the container and the shell automatically sets up the build environment when invoked. 

The LFRic source code is not containerised, it is retrieved as usual via subversion from within the container shell so there is no need to rebuild the container for LFRic code updates.

The container is compatible with [slurm](https://slurm.schedmd.com/documentation.html), and the compiled executable can be run in batch using the local MPI libraries, if the host system has an [MPICH ABI](https://www.mpich.org/abi/) compatible MPI. An OpenMPI version is also available.

A pre-built container is available from [Sylabs Cloud](https://cloud.sylabs.io/library/simonwncas/default/lfric_env).

lfric_env.def is the Singularity definition file.

archer2_lfric.sub is an example ARCHER2 submission script, dirac_lfric.sub an example DiRAC HPC submission script and lotus_lfric.sub is an example OpenMPI submission script for jasmin/lotus.



# Requirements
## Base requirement

[Singularity](https://sylabs.io/) 3.0+ (3.7 preferred)

Access to [Met Office Science Repository Service](https://code.metoffice.gov.uk)

## Optional requirements

`sudo` access if changes to the container are required. This can be on a different system from the LFRic build and run machine.

either:

* `MPICH` compatible MPI on deployment system for use of local MPI libraries.

or

* `OpenMPI` compatible MPI on deployment system. Note: as OpenMPI lacks general ABI, there's a possibility that the container will not use able to use local OpenMPI libraries and will have to use the (possibly slower) containerised versions.

# Workflow

This assumes the `MPICH` version of the container. To use the `OpenMPI` version, replace `lfric_env` below with `lfric_openmpi_env`.

## 1 Obtain container
either:

* (Recommended) Download the latest version of the Singularity container from Sylabs Cloud Library.
```
singularity pull [--disable-cache] lfric_env.sif library://simonwncas/default/lfric_env:latest
```
  Note: `--disable-cache` is required if using Archer2.

or:

* Build container using `lfric_env.def`.
```
sudo singularity build lfric_env.sif lfric_env.def 
```
Note: `sudo` access required. 

## 2 Set up MOSRS account info
**One time only.** Edit (or create) `~/.subversion/servers` and add the following
```
[groups]
metofficesharedrepos = code*.metoffice.gov.uk

[metofficesharedrepos]
# Specify your Science Repository Service user name here
username = myusername
store-plaintext-passwords = no
```
Remember to replace `myusername` with your MOSRS username.

## 3 Start interactive shell on container
On deployment machine.
```
singularity shell lfric_env.sif
```
Now, using the shell **inside** the container:

## 4 Cache MOSRS password
```
. mosrs-setup-gpg-agent
```
and enter your password when instructed. You may be asked twice.

## 5 Download LFRic source
```
fcm co https://code.metoffice.gov.uk/svn/lfric/LFRic/trunk trunk
fcm co https://code.metoffice.gov.uk/svn/lfric/GPL-utilities/trunk rose-picker
```
Due to licensing concerns, the rose-picker part of the LFRic configuration system is held as a separate project.


## 6 Set rose-picker environment
```
export ROSE_PICKER=$PWD/rose-picker
export PYTHONPATH=$ROSE_PICKER/lib/python:$PYTHONPATH
export PATH=$ROSE_PICKER/bin:$PATH
```

## 7 Edit ifort.mk

There are issues with the MPI, the Intel compiler and Fortran08 C bindings, please see [https://code.metoffice.gov.uk/trac/lfric/ticket/2273](URL) for more information. Edit ifork.mk.
```
vi trunk/infrastructure/build/fortran/ifort.mk
```
and change the line
```
FFLAGS_WARNINGS           = -warn all -warn errors
```
to
```
FFLAGS_WARNINGS           = -warn all,noexternal -warn errors
```
Note: `nano` is also available in the container environment.

## 8 Build executable

### ARCHER2 Only
`PE_ENV` needs to be `unset` to ensure the LFRic build system doesn't use the Cray compiler:

```
unset PE_ENV
```


### gungho
```
cd trunk/gungho
make build [-j nproc]
```
### lfric_atm
```
cd trunk/lfric_atm
make build [-j nproc]
```
The executables are built using the Intel compiler and associated software stack within the container and written to the local filesystem.
## 9 Run executable
This is run insider the container on the command line and uses the MPI runtime libraries built into in the container.
### gungho
```
cd example
mpiexec -np 6 ../bin/gungho configuration.nml
```

### lfric_atm
Single column:
```
cd example
../bin/lfric_atm configuration.nml
```
Global. This requires an XIOS server:
```
cd example
mpiexec -np 6 ../bin/lfric_atm ./configuration.nml : -np 1 /container/usr/bin/xios_server.exe
```
## 10 Submit executable.

MPI libraries on the local system can be used in conjunction with slurm.

Four example slurm gungho submission scripts are provided, two for ARCHER2 and one for DiRAC and LOTUS.

* `archer2_lfric_gungho.sub` ARCHER2 gungho submission without XIOS server
* `archer2_lfric_atm.sub` ARCHER2 lfric_atm submission with XIOS server
* `dirac_lfric.sub` DiRAC gungho submission without XIOS server
* `lotus_lfric.sub` LOTUS gungho submission without XIOS serve. Uses OpenMPI.

Note: These scripts are submitted on the command line as usual and not from within the container.

In general, if the host machine has a MPICH based MPI (MPICH, Intel MPI, Cray MPT, MVAPICH2), then  [MPICH ABI](https://www.mpich.org/abi/) can be used to access the local MPI and therefore the fast interconnects when running the executable via the container. See the section below for full details. 




# Using MPICH ABI

This approach is a variation on the [Singularity MPI Bind model](https://sylabs.io/guides/3.7/user-guide/mpi.html#bind-model). The compiled model executable is run within the container with suitable options to allow access to the local MPI installation. At runtime, containerised libraries are used by the executable apart from  the local MPI libraries. OpenMPI will not work with this method.

Note: this only applies when a model is run, the executable is compiled using the method above, without any reference to local libraries.

## Identify local compatible MPI

A MPICH ABI compatible MPI is required. These have MPI libraries named `libmpifort.so.12` and `libmpi.so.12`. The location of these libraries varies from system to system. When logged directly onto the system, `which mpif90`  should show where the MPI binaries are located, and the MPI libraries will be in a directory `../lib` relative to this. On Cray systems the `cray-mpich-abi` libraries are needed, which can are in `/opt/cray/pe/mpich/8.0.16/ofi/gnu/9.1/lib-abi-mpich` or similar.

## Build bind points and LD_LIBRARY_PATH

The local MPI libraries need to be made available to the container. Bind points are required so that containerised processes can access the local directories which contain the MPI libraries. Also the `LD_LIBRARY_PATH` inside the container needs updating to reflect the path to the local libraries. This method has been tested for slurm, but should for other job control systems.

For example, assuming the system MPI libraries are in `/opt/mpich/lib`, set the bind directory with
```
export BIND_OPT="-B /opt/mpich"
```
then for Singularity versions <3.7
```
export SINGULARITYENV_LOCAL_LD_LIBRARY_PATH=/opt/mpich/lib
```
for Singularity v3.7 and over
```
export LOCAL_LD_LIBRARY_PATH="/opt/mpich/lib:\$LD_LIBRARY_PATH"
```

The entries in `BIND_OPT` are comma separated, while `[SINGULARITYENV_LOCAL_]LD_LIBRARY_PATH` are colon separated.

## Construct run command and submit

For Singularity versions <3.7, the command to run gungho within MPI is now
```
singularity exec $BIND_OPT <sif-dir>/lfric_env.sif ../bin/gungho configuration.nml
```
for Singularity v3.7 and over

```
singularity exec $BIND_OPT --env=LD_LIBRARY_PATH=$LOCAL_LD_LIBRARY_PATH <sif-dir>/lfric_env.sif ../bin/gungho configuration.nml
```

Running with mpirun/slurm is straightforward, just use the standard command for running MPI jobs eg:
```
mpirun -n <NUMBER_OF_RANKS> singularity exec $BIND_OPT lfric_env.sif ../bin/gungho configuration.nml
```
or
```
srun --cpu-bind=cores singularity exec $BIND_OPT lfric_env.sif ../bin/gungho configuration.nml
```
on ARCHER2

If running with slurm, `/var/spool/slurmd` should be appended to `BIND_OPT`, separated with a comma.

## Update for local MPI dependencies
It could be possible that the local MPI libraries have other dependencies which are in other system directories. In this case `BIND_OPT` and `[SINGULARITYENV_]LOCAL_LD_LIBRARY_PATH` have to be updated to reflect these. For example on ARCHER2 these are
```
export BIND_OPT="-B /opt/cray,/usr/lib64:/usr/lib/host,/var/spool/slurmd"
```
and
```
export SINGULARITYENV_LOCAL_LD_LIBRARY_PATH=/opt/cray/pe/mpich/8.0.16/ofi/gnu/9.1/lib-abi-mpich:/opt/cray/libfabric/1.11.0.0.233/lib64:/opt/cray/pe/pmi/6.0.7/lib
```
Discovering the missing dependencies is a process of trail and error where the executable is run via the container, and any missing libraries will cause an error and be reported. A suitable bind point and library path is then included in the above environment variables, and the process repeated.

`/usr/lib/host` Is at the end of `LD_LIBRARY_PATH` in the container, so that this bind point can be used to provide any remaining system libraries dependencies in standard locations. In the above example, there are extra dependencies in `/usr/lib64`, so `
/usr/lib64:/usr/lib/host` in `BIND_OPT` mounts this as `/usr/lib/host` inside the container, and therefore `/usr/lib64` is appended to the container's `LD_LIBRARY_PATH`.

# OpenMPI

An OpenMPI singularity definition file and example submission script are included. As OpenMPI lacks a general ABI there might be issues running with the local MPI libraries using the methodology described above. If there are issues, ensure that the OpenMPI version  used while building the container matches the version of the target machine.

The supplied submission script for `lotus` works for both the containerised and local OpenMPI libraries using version 4.1.0 of OpenMPI.



