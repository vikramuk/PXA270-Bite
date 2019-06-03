dnl Process this file with autoconf
AC_INIT(xes-utils, 0.7)
AC_PREREQ(2.5)
AC_CONFIG_SRCDIR(src/functions-xes.sh)
AC_CONFIG_AUX_DIR(config)
AM_INIT_AUTOMAKE(1.8)

dnl Check for toolchain and install components
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_RANLIB

dnl Check for standard headers:
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_CHECK_HEADERS([stdlib.h stdio.h])

dnl Check for libraries:
dnl AC_CHECK_LIB(util, logwtmp)

dnl Check for functions:
dnl AC_CHECK_FUNCS([])

AM_CONFIG_HEADER(config.h)
AC_OUTPUT(Makefile src/Makefile xes-utils.spec)
