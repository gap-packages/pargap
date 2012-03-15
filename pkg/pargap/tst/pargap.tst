gap> START_TEST( "pargap/tst/pargap.tst" );
gap> # To run the tests use
gap> # ReadTest(Filename(DirectoriesPackageLibrary("pargap", "tst"), "pargap.tst"));

gap> # This assumes your procgroup file includes two slave processes.
gap> PingSlave(1); #a `true' response indicates Slave 1 is alive
true
gap> # Send a message to the slave and get the response
gap> SendMsg( "3+5", 1);
gap> RecvMsg( 1 );
8
gap> # The following is equivalent to the two previous commands.
gap> SendRecvMsg( "3+4", 1);
7
gap> # Recv message returns the first waiting message, not the 
gap> # response to the most recent SendMsg
gap> # In this case, messages are sent to the default slave.
gap> # Send a message to the default slave.
gap> SendMsg( "2+4");
gap> SendMsg( "2+3");
gap> RecvMsg();
6
gap> RecvMsg();
5
gap> # We can check to see whether we are the master
gap> # This returns two on the master and false on the slave
gap> IsMaster(); 
true
gap> SendRecvMsg("IsMaster();"); 
false
gap> # Variables set on the slave only exist there
gap> SendRecvMsg( "atmp:=45");
45
gap> atmp*2;
Error, Variable: 'atmp' must have a value
gap> SendRecvMsg( "atmp*2");
90
gap> # Execute analogue of GAP's List() in parallel on slaves.
gap> squares := ParList( [1..100], x->x^2 );
[ 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 289, 
  324, 361, 400, 441, 484, 529, 576, 625, 676, 729, 784, 841, 900, 961, 1024, 
  1089, 1156, 1225, 1296, 1369, 1444, 1521, 1600, 1681, 1764, 1849, 1936, 
  2025, 2116, 2209, 2304, 2401, 2500, 2601, 2704, 2809, 2916, 3025, 3136, 
  3249, 3364, 3481, 3600, 3721, 3844, 3969, 4096, 4225, 4356, 4489, 4624, 
  4761, 4900, 5041, 5184, 5329, 5476, 5625, 5776, 5929, 6084, 6241, 6400, 
  6561, 6724, 6889, 7056, 7225, 7396, 7569, 7744, 7921, 8100, 8281, 8464, 
  8649, 8836, 9025, 9216, 9409, 9604, 9801, 10000 ]
gap> #
gap> # Send a large, local (non-remote) data structure to a slave
gap> Concatenation("x := ", PrintToString([1..10]*2));            
"x := [ 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 ]\n\000"
gap> SendMsg( Concatenation("x := ", PrintToString([1..10]*2)) ); 
gap> RecvMsg();                                                  
[ 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 ]

gap> # Send a local (non-remote) function to a slave
gap> myfnc := function() return 42; end;;
gap> # Use PrintToString() to define myfnc on all slave processes
gap> BroadcastMsg( PrintToString( "myfnc := ", myfnc ) );
gap> SendRecvMsg( "myfnc()", 1 );
42
gap> # Read a TOP-C example from the examples directories
gap> # This installs ParMultMat which multiplies two matrices
gap> # in parallel
gap> ReadPackage("pargap", "examples/parmultmat.g");
true
gap> # Turn off ParTrace to remove messages
gap> ParTracetmp := ParTrace;;
gap> ParTrace := false;
false
gap> A := RandomMat(100,100,Integers);;
gap> ParMultMat(A,A) = A*A;
true
gap> # Restore ParTrace 
gap> ParTrace := ParTracetmp;;

gap> STOP_TEST( "pargap/tst/pargap.tst", 800000000 );
