/****************************************************************************
**
*W  gapmpi.h            GAP source - ParGAP/MPI hooks          Gene Cooperman
**
*Y  Copyright (C) 1999-2001  Gene Cooperman
*Y    See included file, COPYING, for conditions for copying
**
*/

/****************************************************************************
**

*F * * * * * * * * * * * * * initialize package * * * * * * * * * * * * * * *
*/

StructInitInfo * InitInfoPargapmpi(void);
void             InitPargapmpi(int * argc_ptr, char *** argv_ptr);

/* For backward compatibility */
StructInitInfo * InitInfoGapmpi(void);
void             InitGapmpi(int * argc_ptr, char *** argv_ptr);


/****************************************************************************
**

*E  gapmpi.h   . . . . . . . . . . . . . . . . . . . . . . . . . . ends here
*/
