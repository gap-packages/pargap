PingSlave(1); 
SendMsg( "3+5", 1);
RecvMsg( 1 );
SendRecvMsg( "6*7", 2);
SendMsg( "2+4");
SendMsg( "2+3");
RecvMsg();
RecvMsg();
IsMaster(); 
SendRecvMsg("IsMaster();"); 
SendRecvMsg( "atmp:=45");
atmp*2; # this should give an error
SendRecvMsg( "atmp*2"); # and this should work
squares := ParList( [1..100], x->x^2 );
Concatenation("x := ", PrintToString([1..10]*2));            
SendMsg( Concatenation("x := ", PrintToString([1..10]*2)) ); 
RecvMsg();              

############################################################################
#
#  QuillenSeriesByIdGroup( [ ord, nr] )
#  
# Let G:=SmallGroup( ord, nr ) be a p-group of order p^n. It was proved in 
# [D.Quillen, The spectrum of an equivariant cohomology ring II, Ann. of 
# Math., (2) 94 (1984), 573-602] that the number of conjugacy classes of 
# maximal elementary abelian subgroups of given rank is determined by the 
# group algebra KG. 
# The function calculates this numbers for each possible rank and returns 
# a list of the length n, where i-th element corresponds to the number of
# conjugacy classes of maximal elementary abelian subgroups of the rank i.
#
QuillenSeriesByIdGroup := function( id )
local G, qs, latt, msl, ccs, ccs_repr, i, x, n;
G := SmallGroup( id );
latt := LatticeSubgroups(G);
msl := MinimalSupergroupsLattice(latt);
ccs := ConjugacyClassesSubgroups(latt);
ccs_repr := List(ccs, Representative);
qs := [];
for i in [ 1 .. LogInt( Size(G), PrimePGroup(G) ) ] do
  qs[i]:=0;
od;
for i in [ 1 .. Length(ccs_repr) ] do 
  if IsElementaryAbelian( ccs_repr[i] ) then
    if ForAll( msl[i], 
               x -> IsElementaryAbelian( ccs[x[1]][x[2]] ) = false ) then
      n := LogInt( Size(ccs_repr[i]), PrimePGroup(G) );
      qs[n] := qs[n] + 1;
    fi;
  fi;
od;
return [ id, qs ];
end;

BroadcastMsg( PrintToString( "QuillenSeriesByIdGroup := ", QuillenSeriesByIdGroup ) );
SendRecvMsg( "QuillenSeriesByIdGroup([16,8])", 1 );

ParInstallTOPCGlobalFunction( "ParListQuillenSeriesByIdGroup",
function( size )
local result;

   result := [];
   MasterSlave( TaskInputIterator( [ 1 .. NrSmallGroups( size ) ] ),
		
                n -> QuillenSeriesByIdGroup( [size, n] ),
                
		function( input, output )
                  # optionally check condition
                  # if Number( output[2], x -> x<>0) > 1 then
                    result[input]:=output;
                    # AddSet( result, output) ;
                  # fi;
                  return NO_ACTION; 
		end,
                
		Error
              );
   return result;
end );

ParListQuillenSeriesByIdGroup(16);
ParListQuillenSeriesByIdGroup(64);