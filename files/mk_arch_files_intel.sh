#!/bin/sh

SYSTEM_NAME=$1

cat << EOF > arch-$SYSTEM_NAME.env

export HDF5_INC_DIR="$NETCDF_DIR/include"
export HDF5_LIB_DIR="$NETCDF_DIR/lib"

export NETCDF_INC_DIR="$NETCDF_DIR/include"
export NETCDF_LIB_DIR="$NETCDF_DIR/lib"

EOF

cat << EOF > arch-$SYSTEM_NAME.fcm

%CCOMPILER      mpicc
%FCOMPILER      mpif90
%LINKER         mpif90

%BASE_CFLAGS    
%PROD_CFLAGS    -O3 -DBOOST_DISABLE_ASSERTS -std=c++11
%DEV_CFLAGS     -O2
%DEBUG_CFLAGS   -g

%BASE_FFLAGS    -D__NONE__
%PROD_FFLAGS    -O3
%DEV_FFLAGS     -G2
%DEBUG_FFLAGS   -g

%BASE_INC       -D__NONE__
%BASE_LD        -lstdc++ -lz

%CPP            cpp
%FPP            cpp
#%FPP            cpp -P -CC
%MAKE           make

EOF

cat << EOF > arch-$SYSTEM_NAME.path

NETCDF_INCDIR="-I $NETCDF_DIR/include"
NETCDF_LIBDIR="-L $NETCDF_DIR/lib"
NETCDF_LIB="-lnetcdf -lnetcdff"

MPI_INCDIR=""
MPI_LIBDIR=""
MPI_LIB=""

HDF5_INCDIR="-I$NETCDF_DIR/include"
HDF5_LIBDIR="-L$NETCDF_DIR/lib"
HDF5_LIB="-lhdf5_hl -lhdf5"

#OASIS_INCDIR="-I$UMDIR/include"
#OASIS_LIBDIR="-L$UMDIR/lib"
#OASIS_LIB="-lpsmile.MPI1 -lscrip -lmct -lmpeu"

EOF

