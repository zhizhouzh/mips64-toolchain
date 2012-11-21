#!/bin/bash

PWD=$(pwd)
J=8
export CLFS=${PWD}/../clfs_be
export SYS_ROOT=${PWD}/../sys_root_be
export BUILD=${PWD}/../build_be
export SRC=${PWD}/../sources

unset CFLAGS
unset CXXFLAGS

export CLFS_HOST=$(echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/')
export CLFS_TARGET="mips64-unknown-linux-gnu"
export PATH=$PATH:${SYS_ROOT}/cross-tools/bin/

die()
{
	echo -e "\n**********\033[41m$1 \033[0m**********\n"
	exit -1
}

bar()
{
	let stage+=1
	echo -e "[$(date +%T)] \033[31m +++++++++++++++ STAGE $stage: $1 +++++++++++++++ \033[0m"
}

:<< EOFEOF
EOFEOF

if [ "x$1" = "xclean" ]; then
rm -rf ${BUILD} ${SYS_ROOT} ${CLFS}
fi

mkdir -p ${BUILD} ${SYS_ROOT} ${CLFS}


### Installation of Linux-Headers
bar 'install linux-headers..'
if [ ! -d ${BUILD}/linux-2.6.39 ]; then
[ -f ${SRC}/linux-2.6.39.tar.bz2 ] || die "Miss linux kernel "
tar -xjf ${SRC}/linux-2.6.39.tar.bz2 -C ${BUILD}
fi
cd ${BUILD}/linux-2.6.39
install -dv ${SYS_ROOT}/tools/include
make mrproper  > /dev/null || die "Install Linux Headers 1"
make ARCH=mips headers_check  > /dev/null || die "Install Linux Headers 2"
make ARCH=mips INSTALL_HDR_PATH=dest headers_install  > /dev/null || die "Install Linux Headers 3"
cp -rv dest/include/* ${SYS_ROOT}/tools/include > /dev/null

bar 'build file..'
if [ ! -d ${BUILD}/file-5.07 ]; then
tar -xzf ${SRC}/file-5.07.tar.gz -C ${BUILD} || die "tar file"
fi
cd ${BUILD}/file-5.07
./configure --prefix=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null || die "make file"
make install || die "install file"

bar 'build m4..'
if [ ! -d ${BUILD}/m4-1.4.16 ]; then 
tar -xjf ${SRC}/m4-1.4.16.tar.bz2 -C ${BUILD} || die "tar m4"
fi
cd ${BUILD}/m4-1.4.16
./configure --prefix=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null || die "make m4"
make install || die "install m4"

bar 'build ncurses..'
if [ ! -d ${BUILD}/ncurses-5.9 ]; then
tar -xzf ${SRC}/ncurses-5.9.tar.gz -C ${BUILD} || die "tar ncurses"
cd ${BUILD}/ncurses-5.9
patch -Np1 -i ${SRC}/ncurses-5.9-bash_fix-1.patch > /dev/null
fi
cd ${BUILD}/ncurses-5.9
./configure --prefix=${SYS_ROOT}/cross-tools \
    --without-debug --without-shared > /dev/null || die "configure"
make -C include  > /dev/null || die "make ncurses"
make -C progs tic  > /dev/null || die "make ncurses"
install -v -m755 progs/tic ${SYS_ROOT}/cross-tools/bin  > /dev/null || die "install ncurses"

bar 'build gmp..'
if [ ! -d ${BUILD}/gmp-5.0.2 ]; then
tar -xjf ${SRC}/gmp-5.0.2.tar.bz2 -C ${BUILD} || die "tar gmp"
fi
cd ${BUILD}/gmp-5.0.2
CPPFLAGS=-fexceptions ./configure \
    --prefix=${SYS_ROOT}/cross-tools --enable-cxx > /dev/null || die "configure"
make -j${J} > /dev/null || die "make gmp"
make install  > /dev/null || die "install gmp"

bar 'build mpfr..'
if [ ! -d ${BUILD}/mpfr-3.0.1 ]; then
tar -xjf ${SRC}/mpfr-3.0.1.tar.bz2 -C ${BUILD} || die "tar mpfr"
fi
cd ${BUILD}/mpfr-3.0.1
LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
./configure --prefix=${SYS_ROOT}/cross-tools \
    --enable-shared --with-gmp=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null  || die "make mpfr"
make install  > /dev/null || die "install mpfr"

bar 'build mpc..'
if [ ! -d ${BUILD}/mpc-0.9 ]; then
tar -xzf ${SRC}/mpc-0.9.tar.gz -C ${BUILD} || die "tar mpc"
fi
cd ${BUILD}/mpc-0.9
LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
./configure --prefix=${SYS_ROOT}/cross-tools \
    --with-gmp=${SYS_ROOT}/cross-tools \
    --with-mpfr=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null || die "make mpc"
make install  > /dev/null || die "install mpc"


bar 'build ppl..'
if [ ! -d ${BUILD}/ppl-0.11.2 ]; then
tar -xjf ${SRC}/ppl-0.11.2.tar.bz2 -C ${BUILD} || die "tar ppl"
fi
cd ${BUILD}/ppl-0.11.2
CPPFLAGS="-I${SYS_ROOT}/cross-tools/include" \
    LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
    ./configure --prefix=${SYS_ROOT}/cross-tools --enable-shared \
    --enable-interfaces="c,cxx" --disable-optimization \
    --with-libgmp-prefix=${SYS_ROOT}/cross-tools \
    --with-libgmpxx-prefix=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null || die "make ppl"
make install  > /dev/null || die "install ppl"

bar 'build cloog-ppl..'
if [ ! -d cloog-ppl-0.15.11 ]; then
tar -xzf ${SRC}/cloog-ppl-0.15.11.tar.gz -C ${BUILD}
fi
cd ${BUILD}/cloog-ppl-0.15.11
cp -v configure{,.orig}
sed -e "/LD_LIBRARY_PATH=/d" \
    configure.orig > configure
LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
    ./configure --prefix=${SYS_ROOT}/cross-tools --enable-shared --with-bits=gmp \
    --with-gmp=${SYS_ROOT}/cross-tools --with-ppl=${SYS_ROOT}/cross-tools > /dev/null || die "configure"
make -j${J} > /dev/null || die "make cloog-ppl"
make install  > /dev/null || die "install cloog-ppl"


### 
bar 'build binutils..'
if [ ! -d ${BUILD}/binutils-2.21.1 ]; then
tar -xjf ${SRC}/binutils-2.21.1a.tar.bz2 -C ${BUILD} || die "tar binutils"
fi
mkdir -p ${BUILD}/binutils-build
cd ${BUILD}/binutils-build
AR=ar AS=as ../binutils-2.21.1/configure \
  --prefix=${SYS_ROOT}/cross-tools --host=${CLFS_HOST} --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS} --with-lib-path=${SYS_ROOT}/tools/lib --disable-nls --enable-shared \
  --disable-multilib > /dev/null || die "configure" 
make configure-host > /dev/null
make -j${J} > /dev/null || die "make binutils"
make install  > /dev/null || die "install binutils"
cp -v ../binutils-2.21.1/include/libiberty.h ${SYS_ROOT}/tools/include

bar 'build gcc(static)..'
if [ ! -d ${BUILD}/gcc-4.6.0 ]; then 
tar -xjf ${SRC}/gcc-4.6.0.tar.bz2 -C ${BUILD} || die "tar gcc"
cd ${BUILD}/gcc-4.6.0
patch -Np1 -i ${SRC}/gcc-4.6.0-branch_update-1.patch > /dev/null
patch -Np1 -i ${SRC}/gcc-4.6.0-pure64_specs-1.patch > /dev/null
patch -Np1 -i ${SRC}/gcc-4.6.0-mips_fix-1.patch > /dev/null
echo -en "#undef STANDARD_INCLUDE_DIR\n#define STANDARD_INCLUDE_DIR \"${SYS_ROOT}/tools/include/\"\n\n" >> gcc/config/linux.h
echo -en "\n#undef STANDARD_STARTFILE_PREFIX_1\n#define STANDARD_STARTFILE_PREFIX_1 \"${SYS_ROOT}/tools/lib/\"\n" >> gcc/config/linux.h
echo -en '\n#undef STANDARD_STARTFILE_PREFIX_2\n#define STANDARD_STARTFILE_PREFIX_2 ""\n' >> gcc/config/linux.h
echo -en "\n#undef CROSS_INCLUDE_DIR\n#define  CROSS_INCLUDE_DIR \"${SYS_ROOT}/tools/include\"\n" >> gcc/config/linux.h
cp -v gcc/Makefile.in{,.orig}
#sed -i "s@\(^CROSS_SYSTEM_HEADER_DIR =\).*@\1 \"${SYS_ROOT}/tools/include\"@g" gcc/Makefile.in
sed -i "/\-DCROSS_INCLUDE_DIR/d" gcc/Makefile.in
touch ${SYS_ROOT}/tools/include/limits.h
rm -rf ${BUILD}/gcc-build
mkdir -vp ${BUILD}/gcc-build
fi
cd ${BUILD}/gcc-build
AR=ar LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
  ../gcc-4.6.0/configure --prefix=${SYS_ROOT}/cross-tools \
  --build=${CLFS_HOST} --host=${CLFS_HOST} --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS} --with-local-prefix=${SYS_ROOT}/tools --disable-nls \
  --disable-shared --with-mpfr=${SYS_ROOT}/cross-tools --with-gmp=${SYS_ROOT}/cross-tools \
  --with-ppl=${SYS_ROOT}/cross-tools --with-cloog=${SYS_ROOT}/cross-tools \
  --without-headers --with-newlib --disable-decimal-float \
  --disable-libgomp --disable-libmudflap --disable-libssp \
  --disable-threads --enable-languages=c --disable-multilib > /dev/null || die "configure"

make all-gcc all-target-libgcc -j${J} > /dev/null || die "make gcc"
make install-gcc install-target-libgcc  > /dev/null || die "install gcc"


bar 'build eglibc..'
rm ${BUILD}/eglibc* -rf
if [ ! -d ${BUILD}/eglibc-2.13 ]; then
tar -xjf ${SRC}/eglibc-2.13-r13356.tar.bz2 -C ${BUILD} || die "tar eglibc"
cd ${BUILD}/eglibc-2.13
tar -jxf ${SRC}/eglibc-ports-2.13-r13356.tar.bz2 || die "tar ports"
cp -v Makeconfig{,.orig}
sed -e 's/-lgcc_eh//g' Makeconfig.orig > Makeconfig
sed -i "s@\(ldd_rewrite_script=\).*@\1${BUILD}/eglibc-2.13/ports/sysdeps/unix/sysv/linux/mips/mips64/@" \
	ports/sysdeps/unix/sysv/linux/mips/mips64/configure || die "sed"
mkdir ${BUILD}/eglibc-build
fi
cd ${BUILD}/eglibc-build
cat > config.cache << EOF
libc_cv_forced_unwind=yes
libc_cv_c_cleanup=yes
libc_cv_gnu89_inline=yes
libc_cv_ssp=no
EOF
BUILD_CC="gcc" CC="${CLFS_TARGET}-gcc" \
    AR="${CLFS_TARGET}-ar" RANLIB="${CLFS_TARGET}-ranlib" \
    ../eglibc-2.13/configure --prefix=${SYS_ROOT}/tools \
    --host=${CLFS_TARGET} --build=${CLFS_HOST} \
    --disable-profile --enable-add-ons \
    --with-tls --enable-kernel=2.6.0 --with-__thread \
    --with-binutils=${SYS_ROOT}/cross-tools/bin --with-headers=${SYS_ROOT}/tools/include \
    --cache-file=config.cache > /dev/null || die "configure"
make -j${J} > /dev/null || die "make eglib"
make install   > /dev/null || die "install eglib"

bar 'build gcc..(2)'
if [ ! -d ${BUILD}/gcc-4.6.0 ]; then 
tar -xjf ${SRC}/gcc-4.6.0.tar.bz2 -C ${BUILD} || die "tar gcc"
cd ${BUILD}/gcc-4.6.0
patch -Np1 -i ${SRC}/gcc-4.6.0-branch_update-1.patch > /dev/null
patch -Np1 -i ${SRC}/gcc-4.6.0-pure64_specs-1.patch > /dev/null
patch -Np1 -i ${SRC}/gcc-4.6.0-mips_fix-1.patch > /dev/null
echo -en "#undef STANDARD_INCLUDE_DIR\n#define STANDARD_INCLUDE_DIR \"${SYS_ROOT}/tools/include/\"\n\n" >> gcc/config/linux.h
echo -en "\n#undef STANDARD_STARTFILE_PREFIX_1\n#define STANDARD_STARTFILE_PREFIX_1 \"${SYS_ROOT}/lib/\"\n" >> gcc/config/linux.h
echo -en '\n#undef STANDARD_STARTFILE_PREFIX_2\n#define STANDARD_STARTFILE_PREFIX_2 ""\n' >> gcc/config/linux.h
echo -en "\n#undef CROSS_INCLUDE_DIR\n#define  CROSS_INCLUDE_DIR \"${SYS_ROOT}/tools/include\"\n" >> gcc/config/linux.h
fi
rm -rf ${BUILD}/gcc-build/*
cd ${BUILD}/gcc-build
AR=ar LDFLAGS="-Wl,-rpath,${SYS_ROOT}/cross-tools/lib" \
  ../gcc-4.6.0/configure --prefix=${SYS_ROOT}/cross-tools \
  --build=${CLFS_HOST} --target=${CLFS_TARGET} --host=${CLFS_HOST} \
  --with-sysroot=/ --with-local-prefix=${SYS_ROOT}/tools --disable-nls \
  --enable-shared --enable-languages=c,c++ --enable-__cxa_atexit \
  --with-mpfr=${SYS_ROOT}/cross-tools --with-gmp=${SYS_ROOT}/cross-tools --enable-c99 \
  --with-ppl=${SYS_ROOT}/cross-tools --with-cloog=${SYS_ROOT}/cross-tools \
  --enable-long-long --enable-threads=posix --disable-multilib > /dev/null || die "configure"
make AS_FOR_TARGET="${CLFS_TARGET}-as" \
    LD_FOR_TARGET="${CLFS_TARGET}-ld"  -j${J} > /dev/null || die "make gcc (2)"
make install  > /dev/null || die "install gcc (2)"


echo -e "\033[35m ALL DONE \033[0m"
