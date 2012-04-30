
gap> # This assumes your procgroup file includes two slave processes.
gap> PingSlave(1); #a `true' response indicates Slave 1 is alive
true
gap> # Print() on slave appears on standard output
gap> # i.e. after the master's prompt.
gap> SendMsg( "Print(3+4)" );
gap> 7
gap> # A <return> was input above to get a fresh prompt.
gap> #
gap> # To get special characters (including newline: `\n')
gap> # into a string, escape them with a `\'.
gap> SendMsg( "Print(3+4,\"\\n\")" );
gap> 7

gap> # Again, a <return> was input above after the 7 and new-line
gap> # were printed to get a fresh prompt.
gap> #
gap> # Each SendMsg() is normally balanced by a RecvMsg().
gap> SendMsg( "3+4", 2);
gap> RecvMsg( 2 );
7
gap> # The following is equivalent to the two previous commands.
gap> SendRecvMsg( "3+4", 2);
7
gap> # The two SendMsg() commands that were sent to Slave 1 earlier have
gap> # responses that are waiting in the message queue from that slave.
gap> # Check that there is a message waiting. With some MPI implementations
gap> # the message is not immediately available, but when ProbeMsg() does
gap> # return true then RecvMsg() is guaranteed to succeed.
gap> ProbeMsgNonBlocking( 1 );
false
gap> ProbeMsgNonBlocking( 1 );
true
gap> # Print() is a `no-value' functions, and so the result of a RecvMsg()
gap> # in both these cases is "<no_return_val>".
gap> RecvMsg( 1 );
"<no_return_val>"
gap> RecvMsg( 1 );
"<no_return_val>"
gap> # As with Print() the result of Exec() appears on standard
gap> # output, and the result is "<no_return_val>".
gap> SendRecvMsg( "Exec(\"pwd\")" ); # Your pwd will differ :-)
/home/gene
"<no_return_val>"
gap> # Define a variable on a slave
gap> SendRecvMsg( "a:=45; 3+4", 1 );
7
gap> # Note "a" is defined on slave 1, not slave 2.
gap> SendMsg( "a", 2 ); # Slave prints error, output on master
gap>  Variable: 'a' must have a value
gap> # <return> entered to get fresh prompt.
gap> RecvMsg( 2 ); # No value for last SendMsg() command
"<no_return_val>"
gap> RecvMsg( 1 );
45
gap> # Execute analogue of GAP's List() in parallel on slaves.
gap> squares := ParList( [1..100], x->x^2 );
[ 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256,
  289, 324, 361, 400, 441, 484, 529, 576, 625, 676, 729, 784, 841,
  900, 961, 1024, 1089, 1156, 1225, 1296, 1369, 1444, 1521, 1600,
  1681, 1764, 1849, 1936, 2025, 2116, 2209, 2304, 2401, 2500, 2601,
  2704, 2809, 2916, 3025, 3136, 3249, 3364, 3481, 3600, 3721, 3844,
  3969, 4096, 4225, 4356, 4489, 4624, 4761, 4900, 5041, 5184, 5329,
  5476, 5625, 5776, 5929, 6084, 6241, 6400, 6561, 6724, 6889, 7056,
  7225, 7396, 7569, 7744, 7921, 8100, 8281, 8464, 8649, 8836, 9025,
  9216, 9409, 9604, 9801, 10000 ]
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
gap> # Ensure problem shared data is read into master and slaves.
gap> # Try one of your GAP program files instead.
gap> ParRead( "/home/gene/myprogram.g");


gap> ParInstallTOPCGlobalFunction( "MyParList",
> function( list, fnc )
>   local result, iter;
>   result := [];
>   iter := Iterator(list);
>   MasterSlave( function() if IsDoneIterator(iter) then return NOTASK;
>                           else return NextIterator(iter); fi; end,
>                fnc,
>                function(input,output) result[input] := output;
>                                       return NO_ACTION; end,
>                Error
>              );
>   return result;
> end );
gap> MyParList( [1..25], x->x^3 );
master -> 1:  1
master -> 2:  2
2 -> master: 8
1 -> master: 1
master -> 1:  3
master -> 2:  4
2 -> master: 64
1 -> master: 27
master -> 1:  5
master -> 2:  6
2 -> master: 216
1 -> master: 125
master -> 1:  7
master -> 2:  8
2 -> master: 512
1 -> master: 343
master -> 1:  9
master -> 2:  10
2 -> master: 1000
1 -> master: 729
master -> 1:  11
master -> 2:  12
2 -> master: 1728
1 -> master: 1331
master -> 1:  13
master -> 2:  14
2 -> master: 2744
1 -> master: 2197
master -> 1:  15
master -> 2:  16
2 -> master: 4096
1 -> master: 3375
master -> 1:  17
master -> 2:  18
2 -> master: 5832
1 -> master: 4913
master -> 1:  19
master -> 2:  20
2 -> master: 8000
1 -> master: 6859
master -> 1:  21
master -> 2:  22
2 -> master: 10648
1 -> master: 9261
master -> 1:  23
master -> 2:  24
2 -> master: 13824
1 -> master: 12167
master -> 1:  25
1 -> master: 15625
[ 1, 8, 27, 64, 125, 216, 343, 512, 729, 1000, 1331, 1728, 2197, 2744, 3375,
  4096, 4913, 5832, 6859, 8000, 9261, 10648, 12167, 13824, 15625 ]
gap> ParInstallTOPCGlobalFunction( "MyParListWithAglom",
> function( list, fnc, aglomCount )
>   local result, iter;
>   result := [];
>   iter := Iterator(list);
>   MasterSlave( function() if IsDoneIterator(iter) then return NOTASK;
>                           else return NextIterator(iter); fi; end,
>                fnc,
>                function(input,output)
>                  local i;
>                  for i in [1..Length(input)] do
>                    result[input[i]] := output[i];
>                  od;
>                  return NO_ACTION;
>                end,
>                Error,  # Never called, can specify anything
>                aglomCount
>              );
>   return result;
> end );
gap> MyParListWithAglom( [1..25], x->x^3, 4 );
master -> 1: (AGGLOM_TASK): [ 1, 2, 3, 4 ]
master -> 2: (AGGLOM_TASK): [ 5, 6, 7, 8 ]
1 -> master: [ 1, 8, 27, 64 ]
2 -> master: [ 125, 216, 343, 512 ]
master -> 1: (AGGLOM_TASK): [ 9, 10, 11, 12 ]
master -> 2: (AGGLOM_TASK): [ 13, 14, 15, 16 ]
1 -> master: [ 729, 1000, 1331, 1728 ]
2 -> master: [ 2197, 2744, 3375, 4096 ]
master -> 1: (AGGLOM_TASK): [ 17, 18, 19, 20 ]
master -> 2: (AGGLOM_TASK): [ 21, 22, 23, 24 ]
1 -> master: [ 4913, 5832, 6859, 8000 ]
2 -> master: [ 9261, 10648, 12167, 13824 ]
master -> 1: (AGGLOM_TASK): [ 25 ]
1 -> master: [ 15625 ]
[ 1, 8, 27, 64, 125, 216, 343, 512, 729, 1000, 1331, 1728, 2197, 2744, 3375,
  4096, 4913, 5832, 6859, 8000, 9261, 10648, 12167, 13824, 15625 ]


gap> SendMsg("Exec(\"hostname\")", 2);


gap> MPI_Initialized();


gap> SendRecvMsg("Exec(pwd)"); SendRecvMsg("UNIX_Hostname()");
gap> SendRecvMsg("UNIX_Getpid()");

