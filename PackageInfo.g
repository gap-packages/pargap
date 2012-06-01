#############################################################################
##  
##  PackageInfo.g for the package `ParGAP'  by Gene Cooperman 
##  

##  For the LoadPackage mechanism in GAP >= 4.4 only the entries
##  .PackageName, .Version, .PackageDoc, .Dependencies, .AvailabilityTest
##  .Autoload   are needed. The other entries are relevant if the
##  package shall be distributed for other GAP users, in particular if it
##  shall be redistributed via the GAP Website.

##  With a new release of the package at least the entries .Version, .Date 
##  and .ArchiveURL must be updated.

SetPackageInfo( rec(
PackageName := "ParGAP",
Subtitle := "Parallel GAP",
Version := "1.3.5",
Date := "01/06/2012",

PackageWWWHome := "http://www.gap-system.org/HostedGapPackages/pargap/",

ArchiveURL := Concatenation( ~.PackageWWWHome, "pargap-", ~.Version ),
ArchiveFormats := ".tar.gz",

Persons := [
  rec( 
    LastName      := "Cooperman",
    FirstNames    := "Gene",
    IsAuthor      := true,
    IsMaintainer  := true,
    Email         := "gene@ccs.neu.edu",
    WWWHome       := "http://www.ccs.neu.edu/home/gene/",
    Place         := "Boston",
    PostalAddress :=  "College of Computer Science, 202-WVH\nNortheastern University\nBoston, MA 02115\nUSA\n",
    Institution   := "Northeastern University"
  ),
  rec( 
    LastName      := "Smith",
    FirstNames    := "Paul",
    IsAuthor      := false,
    IsMaintainer  := true,
    Email         := "paul.smith@st-andrews.ac.uk",
    WWWHome       := "http://www.cs.st-andrews.ac.uk/~pas",
    PostalAddress := Concatenation( [
                         "Paul Smith\n",
                         "School of Computer Science\n",
                         "University of St Andrews\n",
                         "St Andrews\n",
                         "UK" ] ),
    Place         := "St Andrews",
    Institution   := "University of St Andrews"
  )
],
Status := "accepted",
CommunicatedBy := "Steve Linton (St Andrews)",
AcceptDate := "07/1999",

README_URL := Concatenation( ~.PackageWWWHome, "README" ),
PackageInfoURL := Concatenation( ~.PackageWWWHome, "PackageInfo.g" ),

AbstractHTML := 
"The ParGAP (Parallel GAP) package implements Master-Slave parallelism  on \
multiple machines and in doing so provides  a  way  of  writing  parallel \
programs using the  GAP  language.  Former  names  of  the  package  were \
ParGAP/MPI and GAP/MPI; the word MPI refers to Message Passing Interface, \
a well-known standard  for  parallelism.  ParGAP  is  based  on  the  MPI \
standard, and includes a subset  implementation  of  MPI,  to  provide  a \
portable layer  with  a  high  level  interface  to  BSD  sockets.  Since \
knowledge of MPI is not required for use of this software, we  now  refer \
to the package as simply ParGAP. ParGAP also implements the more advanced \
TOP-C model for cooperative parallelism.",

PackageDoc := rec(
  BookName  := "ParGAP",
  ArchiveURLSubset := ["doc", "htm"],
  HTMLStart := "htm/chapters.htm",
  PDFFile   := "doc/manual.pdf",
  SixFile   := "doc/manual.six",
  LongTitle := "Parallel GAP",
  Autoload  := true
),
Dependencies := rec(
  GAP := ">=4.5",
  NeededOtherPackages := [],
  SuggestedOtherPackages := [],
  ExternalConditions := []
                      
),
AvailabilityTest := function()
  if IsBoundGlobal("MPI_Initialized") then
    return ARCH_IS_UNIX() and not IsBoundGlobal("SendMsg");
  else
    LogPackageLoadingMessage(PACKAGE_WARNING, Concatenation(
      "ParGAP cannot be loaded as a package. Instead of starting GAP in\n",
      "the usual way, call the script generated during installation of ParGAP.\n",
      "Type `?Running ParGAP' for more details."));
    return false;
  fi;
end,

BannerString := "",

Autoload := true,
#TestFile := "tst/testall.g",
Keywords := ["Parallel",  "Top-C"]
));


