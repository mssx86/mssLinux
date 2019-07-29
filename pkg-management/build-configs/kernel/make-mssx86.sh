#!/bin/env bash
### make-mssx86.sh ###
### help dialog func

msshelp(){
 printf "\nusage:\t ./make-mssx86 (kernel tarball) (compiler) (gnu deblob) (ck patchset)\n\n"
 printf "kernel tarball\t: location of kernel source tarball.\n"
 printf "compiler\t: gcc or clang.\n"
 printf "gnu deblob\t: yes or no.\n"
 printf "ck patchset\t: yes or no.\n\n"
}

case $1 in
 -h|--help) msshelp; exit 0;;
esac

### check if variables are set
if	[ -z $1 ]; then printf "\n ! no kernel source tarball selected, exiting.\n";		msshelp; exit 1
elif	[ -z $2 ]; then printf "\n ! (gcc/clang) no compiler selected, exiting.\n";		msshelp; exit 1
elif	[ -z $3 ]; then printf "\n ! (yes/no) deblobbing option not specified, exiting.\n";	msshelp; exit 1
elif	[ -z $4 ]; then printf "\n ! (yes/no) ck patchset option not specified, exiting.\n";	msshelp; exit 1
fi

### define kernel and patch directories
kerdir="$PWD/"$(echo $1 | sed 's/\.tar\.xz//;s/\.tar\.bz2//;s/\.tgz//')""
patchdir="/mss/repo/pkg-management/build-configs/kernel/patches"

###a> unpack kernel and cd to source
printf " * unpacking kernel source.\n"
tar xf $1 &&
printf " + done.\n\n"
cd "${kerdir}"	&&

###b> copy config from /boot/config
printf " * copying kernel config.\n"	&&
cp /boot/config "${kerdir}"/.config	&&
printf " + done.\n\n"			&&

###c> set the compiler
case $2 in
 clang)
  clang --version 2> /dev/null || printf " ! clang not found, exiting.\n" && exit 1
  memepiler="clang"							&&
  printf " * building with clang\n\n * applying clang patches.\n"	&&
  patch -p1 < "${patchdir}"/clang-linux-x86.patch 2>&1 > /dev/null	&&
  printf " + done.\n\n"
 ;;
 gcc)
  memepiler="gcc"
  printf " * building with gcc.\n\n"
 ;;
 *)
  printf " ! compiler option not recognized, exiting.\n"; exit 1
 ;;
esac &&

###d> apply gnu deblob if needed
if [ "${3}" = "yes" ]
 then 
  printf " * applying gnu deblob patches.\n"				&&
  patch -p1 < "${patchdir}"/5.2-deblob-gnu.patch 2>&1 > /dev/null	&&
  printf " + done.\n\n"							&&
  printf " * removing gnu extraversion entry.\n"			&&
  sed 's/EXTRAVERSION = -gnu/EXTRAVERSION =/' -i Makefile		&&
  printf " + done.\n\n"							&&
  printf " * applying freedo logo.\n"					&&
  install -m644 -t "${kerdir}"/drivers/video/logo \
  "${patchdir}"/freedo-logo/logo_linux_{clut224.ppm,vga16.ppm,mono.pbm} &&
  printf " + done.\n\n"
 else
  printf " * not applying gnu deblob patch.\n\n"
fi &&

###e> apply ck patchset if needed
if [ "${4}" = "yes" ]
 then
  printf " * applying ck patchset.\n"					&&
  patch -p1 < "${patchdir}"/ck-patches-5.2.patch 2>&1 > /dev/null	&&
  printf " * removing ck extraversion entry.\n"				&&
  sed 's/CKVERSION = -ck1/CKVERSION =/' -i Makefile			&&
  printf " + done.\n\n"
 else
  printf " * not applying the ck patchset patch.\n\n"
fi &&

###f> run menuconfig if wanted
printf " * run menuconfig for manual config? (y/n): " &&
read answer

if [ "$answer" != "${answer#[Yy]}" ]
then
 printf " * running menuconfig.\n"		&&
 if [ "${memepiler}" = "clang" ]
  then make CC=clang HOSTCC=clang menuconfig
  else make menuconfig
 fi						&&
 printf " + done.\n"
else
 printf " * not running menuconfig.\n"
fi &&

###g> run make if wanted
printf " * run make automatically? (y/n): "	&&
read answermake

if [ "$answermake" != "${answer#[Yy]}" ]
then
 printf " * running make.\n"			&&
 if [ "${memepiler}" = "clang" ]
  then make CC=clang HOSTCC=clang -j$(($(nproc)+1))
  else make -j$(($(nproc)+1))
 fi
fi &&

###h> run kinst from mssutils if wanted
printf " * all is well and done.\n * run kinst to install the kernel? (y/n): "
read answerkinst

if [ "$answerkinst" != "${answer#[Yy]}" ]
 then /mss/bin/kinst
 else printf " * not installing the built kernel."
fi
