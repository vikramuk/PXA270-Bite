dnl Process this file with autoconf
AC_INIT(xes-utils-boards, 0.13)
AC_PREREQ(2.5)
AC_CONFIG_SRCDIR(src/global.conf.in)
AC_CONFIG_AUX_DIR(config)
AM_INIT_AUTOMAKE(1.8)

dnl Check for install components
AC_PROG_INSTALL

AC_CHECK_PROG([have_rpmbuild], [rpmbuild], [yes], [no])
AC_CHECK_PROG([have_ebuild], [ebuild], [yes], [no])

AC_ARG_ENABLE([el],
  [AC_HELP_STRING([--enable-el], [support Enterprise Linux (default is no)])],
  [enable_el=$enableval],
  [enable_el=$have_rpmbuild])
AM_CONDITIONAL([ENABLE_EL], [test $enable_el = yes])

AC_ARG_ENABLE([gentoo],
  [AC_HELP_STRING([--enable-gentoo], [support Gentoo Linux (default is no)])],
  [enable_gentoo=$enableval],
  [enable_gentoo=$have_ebuild])
AM_CONDITIONAL([ENABLE_GENTOO], [test $enable_gentoo = yes])

AS_IF([test "$enable_el" = yes && test "$have_rpmbuild" = no],
  [AC_MSG_FAILURE([Enterprise Linux requires rpmbuild])])

AS_IF([test "$enable_gentoo" = yes && test "$have_ebuild" = no],
  [AC_MSG_FAILURE([Gentoo Linux requires ebuild])])

AC_CONFIG_FILES([
  Makefile
  src/Makefile
  src/global.conf
  xes-utils-boards.spec
  xes-utils-boards.ebuild
])
AC_OUTPUT
