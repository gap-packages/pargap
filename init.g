#############################################################################
##
#W  init.g                     ParGAP Package                  Gene Cooperman
#W                                                                Greg Gamble
##
#H  @(#)$Id$
##
#Y  Copyright (C) 1999-2001  Gene Cooperman
#Y    See included file, COPYING, for conditions for copying
##


#E init.g . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ends here

# Print the banner if I am the master
if MPI_Comm_rank() = 0 and 
  not ( GAPInfo.CommandLineOptions.q or
        GAPInfo.CommandLineOptions.b ) then
  if GAPInfo.TermEncoding = "UTF-8" then
    btop := "┌────────┐\c"; vert := "│"; bbot := "└────────┘\c";
  else
    btop := "**********"; vert := "*"; bbot := btop;
  fi;
  Print( "\n" );
  Print( " ",btop,"   Parallel GAP, Version ", 
         InstalledPackageVersion("pargap"), "\n",
         " ",vert," ParGAP ",vert,"   by Gene Cooperman <gene@ccs.neu.edu>\n");
  if MPI_USE_MPINU then
    if MPI_USE_MPINU_V2 then
      Print( " ",bbot,"   Using MPI library: MPINU2\n" );
    else
      Print( " ",bbot,"   Using MPI library: MPINU\n" );
    fi;
  else
    Print( " ",bbot,"   Using MPI library: system MPI library\n" );
  fi;
  Print(" Type `?ParGAP' for information about using ParGAP.\n\n");
fi;


#E init.g . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ends here

