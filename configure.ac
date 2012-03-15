AC_INIT([pargap], 1.3)
AC_CONFIG_SRCDIR([src/gapmpi.c])

AC_LANG_C

AC_PROG_CC
AC_PROG_GREP
AC_PROG_SED

# Make sure CDPATH is portably set to a sensible value
CDPATH=${ZSH_VERSION+.}:

LASTCONFIGUREARGS=$ac_configure_args

###########################################################
# Can we find a System MPI library?

AC_ARG_WITH(mpi, 
  [AC_HELP_STRING([--with-mpi=system|MPINU2|MPINU], 
    [Specify the MPI library to use. By default, configure tries to find a 
     working MPI installation on the standard paths. Failing this, it drops 
     back to using the subset MPI implementation included with this package. 
     Two versions are included: MPINU and MPINU2, and the latter is used unless 
     specified otherwise.])],
  [case "$withval" in
    MPINU)
      MPINUDIR="mpinu"
      USE_MPINU=true
    ;;
    MPINU2)
      MPINUDIR="mpinu2" 
      USE_MPINU=true
      MPINU_V2=true
      ;;
    system)
      FORCE_SYSTEM_MPI="true"  
      ;;
    *)
      AC_MSG_ERROR([Bad value ${withval} for --with-mpi.]) 
      ;;
   esac])

if test "x$USE_MPINU" = "x"; then
  LIBMPINU=""
  # Look for a system MPI implementation

  # try to find the MPI compiler
  AC_ARG_VAR(MPICC,[MPI C compiler command])
  AC_CHECK_TOOLS([MPICC], [mpicc mpixlc_r mpixlc hcc mpxlc_r mpxlc sxmpicc mpifcc mpgcc mpcc cmpicc gcc cc $CC])
  if test "x$MPICC" = "x" && test "x$FORCE_SYSTEM_MPI" = "xtrue";then 
    echo "ERROR: Unable to find an MPI compiler on your standard path."
    echo "Please check your MPI installation and/or set the MPICC environment variable."
    AC_MSG_ERROR([Unable to find MPI compiler])
  fi
  OLD_CC="$CC"
  CC="$MPICC"

  AC_ARG_VAR(MPI_LIBS,[MPI linker flags])
  if test "x" != "x$MPI_LIBS"; then
    OLDLIBS=$LIBS
    LIBS="$LIBS $MPI_LIBS"
    AC_CHECK_FUNC(MPI_Init, , 
      [
      echo ""
      echo "  ERROR: The MPI_LIBS environment variable is set, but MPI_Init cannot be found."
      echo "  Please check your MPI installation."
      echo "  MPI_LIBS=$MPI_LIBS"
      AC_MSG_ERROR([Unable to find MPI library])
    ])
    LIBS=$OLDLIBS
  else
    # try to find the MPI library
    if test x = x"$MPI_LIBS"; then
      AC_CHECK_FUNC(MPI_Init, [MPI_LIBS=" "])
    fi
    if test x = x"$MPI_LIBS"; then
      AC_CHECK_LIB(mpi, MPI_Init, [MPI_LIBS="-lmpi"])
    fi
    if test x = x"$MPI_LIBS"; then
      AC_CHECK_LIB(mpich, MPI_Init, [MPI_LIBS="-lmpich"])
    fi
  fi

  if test "x$MPI_LIBS" = "x" && test "x$FORCE_SYSTEM_MPI" = "xtrue"; then 
    echo ""
    echo "  ERROR: Unable to find an MPI library on the standard path."
    echo "  Please check your MPI installation and/or set the MPI_LIBS environment variable."
    AC_MSG_ERROR([Unable to find MPI library])
  fi

  AC_ARG_VAR(MPI_CFLAGS, [MPI compiler flags])
  OLD_CFLAGS=$CFLAGS
  CFLAGS="$CFLAGS $MPI_CFLAGS"
  AC_MSG_CHECKING([for mpi.h])
  AC_TRY_COMPILE([#include <mpi.h>],[],
    [AC_MSG_RESULT(yes)], 
    [
    AC_MSG_RESULT(no)
    echo ""
    echo "  ERROR: Unable to find the MPI header file."
    echo "  Please check your MPI installation and/or set the MPI_CFLAGS environment variable."
    AC_MSG_ERROR([Unable to find MPI header files])
  ])
  CFLAGS=$OLD_CFLAGS


  CC="$OLD_CC"

fi

###########################################################
# Find the GAP root directory and read the sysinfo.gap file

#Allow the user to specify the location of GAP
AC_ARG_WITH(gap, 
  [AC_HELP_STRING([--with-gap=<path>], [specify root of GAP installation])],
  [GAPPATH=$withval])

#If this is set, we are allowed to run ./configure; make on GAP if necessary
AC_ARG_WITH(basic-gap-configure, 
  [AC_HELP_STRING([--with-basic-gap-configure], [run ./configure; make on GAP if neccessary])],
  [configure_gap=true])

if test -n "$GAPPATH"; then
  GAPPATH_LIST=$GAPPATH
else
  # Try the default location. This can be a longer list
  GAPPATH_LIST="../.."
fi

GAPINI="gap.ini"
SYSINFO="sysinfo.gap"
SRC_GAPC="src/gap.c"

# try the various directories
for GAPPATH in ${GAPPATH_LIST} 
do
  # Convert the path to absolute
  GAPPATH=`cd $GAPPATH > /dev/null 2>&1 && pwd`

  # check for sysinfo.in (which should be there whether GAP is built or not)
  # (and which needs to be there to reconfigure GAP)
  AC_MSG_CHECKING([for GAP root directory])
  if test -e ${GAPPATH}/${GAPINI}; then
    AC_MSG_RESULT([${GAPPATH}])
    have_gapini=yes
  else
    AC_MSG_RESULT([Not found])
    break;
  fi

  # check for sysinfo.gap (to see whether GAP has been built before)
  AC_MSG_CHECKING([for GAP sysinfo.gap])
  if test -e ${GAPPATH}/${SYSINFO}; then
    have_sysinfo=yes
    AC_MSG_RESULT([OK])
  else
    AC_MSG_RESULT([Not found])
    break;
  fi

  # check for the source files
  AC_MSG_CHECKING([for GAP source files])
  if test -e ${GAPPATH}/${SRC_GAPC}; then
    have_gapsrc=yes
    AC_MSG_RESULT([OK])
  else
    AC_MSG_RESULT([Not found])
    break;
  fi
done

if test "x$have_gapini" = "x"; then
  echo ""
  echo "  ERROR:  Unable to find the GAP_ROOT directory."
  echo ""
  echo "  We need to build a modified version of GAP, so need to know where"
  echo "  to find your GAP installation."
  echo ""
  echo "  Please use the --with-gap= configure option to specify the location"
  echo "  the GAP_ROOT directory."
  
  AC_MSG_ERROR([Unable to find GAP root directory])
fi

if test "x$have_sysinfo" = "x"; then
  if test "x$configure_gap" = "xtrue"; then
    need_gap_configure=true
  else
    echo ""
    echo "  WARNING:  Unable to find sysinfo.gap in the GAP_ROOT directory."
    echo "            Have you built GAP yet?"
    echo ""
    echo "  The ParGAP build process can build GAP for you."
    echo "  If you are happy to have GAP built with the default options"
    echo "  (i.e. ./configure; make) then rerun this configure script with"
    echo "     ./configure --with-basic-gap-configure"
    echo "  If you have particular configuration requirements, please build"
    echo "  GAP first before building ParGAP."
    echo ""
    echo "  If you have already built GAP, please check your installation."

    AC_MSG_ERROR([Unable to find GAP sysinfo.gap])
  fi;
fi

if test "x$have_gapsrc" = "x"; then
  echo ""
  echo "  ERROR:  Unable to find GAP source files in the directory GAP_ROOT/src."
  echo ""
  echo "  We need to build a modified version of GAP, and so need the GAP source"
  echo "  files. Please check your GAP installation."

  AC_MSG_ERROR([Unable to find GAP source files])
fi

# Now find the architecture (if we have a sysinfo.gap)
if test "x$have_sysinfo" = "xyes"; then
  GAPARCH="Unknown"

  AC_MSG_CHECKING([for GAP architecture])
  GAPARCH=`${GREP} GAParch= ${GAPPATH}/${SYSINFO} | ${SED} 's|^GAParch=\(.*\)|\1|'`
  AC_MSG_RESULT([${GAPARCH}])

  if test "x$GAPARCH" = "xUnknown"; then
    echo "  ERROR: Found a GAP installation at $GAPPATH"
    echo "  but could find information about GAP's architecture in the file"
    echo "  ${GAPROOT}/${SYSINFO}"
    echo "  This file should be present: please check your GAP installation."
    
    AC_MSG_ERROR([Unable to find GAParch information.])
  fi  

  # And check the compiler used
  if test "x$MPICC" != "x"; then
    AC_MSG_CHECKING([whether GAP compiler is set to $MPICC])

    val=$(expr "$GAPARCH" : ".*-$MPICC")
    if test "x$val" != "x0"; then
      gap_with_mpicc=true 
      AC_MSG_RESULT([yes])
    else
      AC_MSG_RESULT([no])
    fi;

    if test "x$gap_with_mpicc" = "x"; then
      if test "x$configure_gap" = "xtrue"; then
        need_gap_configure=true;
      else
        echo ""
        echo "  WARNING:  GAP is not set to be built with $MPICC, and it needs to be."
        echo "  in order to use your system MPI implementation."
        echo ""
        echo "  The ParGAP build process can reconfigure GAP for you."
        echo "  If you are happy to have GAP built with the default options"
        echo "  (i.e. ./configure; make) then rerun this configure script with"
        echo ""
        echo "     ./configure --with-basic-gap-configure"
        echo ""
        echo "  If you have particular configuration requirements, please build"
        echo "  GAP yourself before building ParGAP, using the configure option"
        echo ""
        echo "     cd $GAPPATH"
        echo "     ./configure CC=$MPICC <your other configure options>"
        echo ""
        echo "  And then run ./configure; make for ParGAP again."
        echo ""

        AC_MSG_ERROR([GAP needs building with $MPICC])
      fi;
    fi;
  fi;
fi



# Check that we have the required write permissions
AC_MSG_CHECKING([for write permissions in the GAP source directory])
if test -w $GAPPATH/src; then
  AC_MSG_RESULT([yes])
else
  gap_write_permissions=no
  AC_MSG_RESULT([no])
fi;

GAPBINPATH=$GAPPATH/bin/$GAPARCH
if test -d $GAPBINPATH; then
  AC_MSG_CHECKING([for write permissions in the GAP bin directory])
  if test -w $GAPBINPATH; then 
    AC_MSG_RESULT([yes])
  else
    gap_write_permissions=no
    AC_MSG_RESULT([no])
  fi;
fi;

if test "x$gap_write_permissions" = "xno"; then
  echo ""
  echo "  ERROR:  No write permissions in GAP source or bin directory."
  echo ""
  echo "  We need to build a modified version of GAP, and need to write files"
  echo "  into the GAP_ROOT directory structure."
  echo ""
  echo "  If you can't change the permissions or log in as a user with write"
  echo "  permissions then you can build a private copy. Copy everything"
  echo '  and then do a standard GAP "./configure; make" in the private copy.'
  echo "  You can skip all of the pkg directory apart from the pargap directory."
  echo "  Make pargap in that copy and then copy the pargapmpi.sh and gap"
  echo "  binary from the private GAP to the bin subdirectory of this package."
  echo "  It then remains only to modify the paths inside pargapmpi.sh."

  AC_MSG_ERROR([Insufficient permissions to build ParGAP in GAP_ROOT])
fi;

# How to do a basic gap configure (if we are allowed)
if test "x$configure_gap" = "xtrue"; then
  if test "x$MPICC" != "x"; then
    CONFIGUREGAP="cd $GAPPATH && ./configure CC=$MPICC"
  else
    CONFIGUREGAP="cd $GAPPATH && ./configure"
  fi;
else
  CONFIGUREGAP=""
fi;

# Do we need to configure gap?
if test "x$need_gap_configure" = "xtrue"; then
  echo "This file is automatically created by the ParGAP ./configure" > forceGAPconfigure
  echo "whenever the GAP ./configure needs calling." >> forceGAPconfigure 
  FORCEGAPCONFIGURE=forceGAPconfigure
fi;


###########################################################
# Finish off the MPI checks including setting up MPINU if necessary

# MPI_LIBS will now be set if we are to use a system MPI implementation.
# if not, then we want use MPINU
if test "x$MPI_LIBS" = "x"; then

  # If we tried to find a system MPI and failed, then drop back to MPINU2
  if test "x$MPINUDIR" = "x"; then 
    MPINUDIR=mpinu2
    USE_MPINU=true
  fi

  MPI_CFLAGS="-I${PWD}/${MPINUDIR} -DUSE_MPINU"
  if test "x$MPINU_V2" = "xtrue"; then
    MPI_CFLAGS="$MPI_CFLAGS -DMPINU_V2"
  fi
  OLD_CFLAGS=$CFLAGS
  CFLAGS="$CPPFLAGS $MPI_CFLAGS"

  # Sanity check that MPINU should build
  AC_MSG_CHECKING([for $MPINUDIR])
  AC_TRY_COMPILE([#include <mpi.h>],[],
    [AC_MSG_RESULT(yes)], 
    [AC_MSG_RESULT(no)
     echo "ERROR: Unable to find the files to build $MPINUDIR."
     echo "They should be in a subdirectory of this package - please check your installation."
     AC_MSG_ERROR([Unable to find MPI build files])
    ])

  # We get some nasty run-time behaviour if pick up a system mpi.h, so check
  # that we don't
  # TODO: This needs finishing, with some help from sysinfo.gap
  #AC_MSG_CHECKING([that system mpi.h won't be used])
  #OLD_CC="$CC"
  #CC="$GAPCC"
  #AC_RUN_IFELSE(
  #  [AC_LANG_PROGRAM([[#include <mpi.h>]],
  #                   [[if(MPI_CHAR==(MPI_Datatype)1) return 0; else return 1;]])]
  #  [AC_MSG_RESULT(yes)], 
  #  [AC_MSG_RESULT(no)
  #   echo "ERROR: A system mpi.h is being picked up by the compiler, not the one in MPINU."
  #   echo "Is GAP perhaps configured to use an MPI compiler? It shouldn't be."
  #   AC_MSG_ERROR([GAP will not build with MPINU correctly])])
  #CC="$OLD_CC"

  CFLAGS=$OLD_CFLAGS

  LIBMPINU="bin/${GAPARCH}/libmpi.a"
  MPI_LIBS="${PWD}/bin/${GAPARCH}/libmpi.a ${SOCKETLIBS} -lpthread"
fi



AC_SUBST(LASTCONFIGUREARGS)
AC_SUBST(GAPPATH)
AC_SUBST(GAPARCH)
AC_SUBST(CONFIGUREGAP)
AC_SUBST(FORCEGAPCONFIGURE)
AC_SUBST(SED)
AC_SUBST(MPINUDIR)
AC_SUBST(LIBMPINU)
AC_SUBST(USE_MPINU)
AC_SUBST(MPINU_V2)
AC_SUBST(MPICC)
AC_SUBST(MPI_LIBS)
AC_SUBST(MPI_CFLAGS)

AC_CONFIG_FILES([Makefile bin/procgroup:bin/procgroup.in])
AC_OUTPUT
