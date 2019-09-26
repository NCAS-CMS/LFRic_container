# LFRic_container

Containerisation of the LFRic software stack.

Please see README.txt for a complete description.

# Requirements
Container build machine: Singularity 2.6+; Intel Fortran v17; sudo for Singularity
LFRic build machine: Singularity 2.6+ (compatible with build machine); Intel Fortran v17;MPICH compatible MPI.

# Workflow

## Container build
Build base container
```
sudo singularity build lfric_base.sif lfric_base.def
```

Log onto base container
```
singularity shell -B /opt:/opt lfric_base.sif
```
Note: Replace the bind point /opt:/opt with the top level directory were the Intel compile is locate

Inside container:
```
. /opt/intel/compilers_and_libraries_2017.4.196/linux/bin/ifortvars.sh  intel64
. ./build_stack
```
Note: Replace the ifortvars.sh command with your local Intel Fortran.
Note: Modules can be used. Include a bind of their local top level directory. Then, inside container:
```
module purge
module load name_of_your_intel17
```
This builds the software stack using the containerise environment and tars it into files/container_usr.tgz.
Then log out of container

Build final container:
```
sudo singularity build lfric_usr.sif lfric_usr.def
```

Then copy this to the LFRic build machine. Then
```
singularity shell -B /opt:/opt lfric_usr.sif
```
Setting the bind points to the Intel/modules(if required) directories in a similar way as above.

Inside the container
```
setup/load Intel fortran
. /contianer/setup
```
Obtain LFRic. For gungho the Makefile needs to be edited. Change the lines:
```
export EXTERNAL_DYNAMIC_LIBRARIES = yaxt yaxt_c netcdff netcdf hdf5 \
                                    $(CXX_RUNTIME_LIBRARY)
export EXTERNAL_STATIC_LIBRARIES = xios
```
to
```
export EXTERNAL_DYNAMIC_LIBRARIES = 
export EXTERNAL_STATIC_LIBRARIES = yaxt yaxt_c xios netcdff netcdf hdf5_hl hdf5  z :libstdc++.a
```
LFRic can now be built. All of the required environment variables are set up with the setup command.

The executable is compatible with any MPICH derivative and should be run natively (ie outside the container) on the target machine.