
gap> AnalyzePrimitivePermGroupsOfOrder := function(ord)
>      #returns a list of data records of all primitive
>      #permutation groups of order ord that are represented
>      #as permutation groups in GAP's primitive group database
>
>      local PrimitiveGroupsOfOrder, AnalyzePrimitivePermGroup;
>
>      PrimitiveGroupsOfOrder :=
>        ord -> List( [1..NrPrimitiveGroups(ord)],
>                     i -> PrimitiveGroup(ord,i) );
>
>      AnalyzePrimitivePermGroup :=
>        grp -> rec( order := Size(grp),
>                    degree := NrMovedPoints(grp),
>                    baseSize := Size(BaseOfGroup(grp)) );
>
>      return List( Filtered( PrimitiveGroupsOfOrder(ord),
>                             IsPermGroup ),
>                   AnalyzePrimitivePermGroup );
>    end;;
gap> #Define AnalyzePrimitivePermGroupsOfOrder on slaves
gap> BroadcastMsg(
>      PrintToString("AnalyzePrimitivePermGroupsOfOrder := ",
>                    AnalyzePrimitivePermGroupsOfOrder ) );
gap> ParList( [2..256], AnalyzePrimitivePermGroupsOfOrder );
[ [ rec( order := 2, degree := 2, baseSize := 1 ) ],
  [ rec( order := 3, degree := 3, baseSize := 1 ),
  <...many lines of output omitted...>


gap> ParList([1..100000],
>            i -> Length(PrimePowersInt(i))/2, 1000);


gap> ParFirstResult := function( list, fnc )
>   local i, result;
>   if Length(list) > TOPCnumSlaves then
>     Error("too few slaves");
>   fi;
>   for i in [1..Length(list)] do
>     SendMsg( PrintToString(
>                   "fnc :=", fnc, "; fnc(", list[i], ");"),
>              i );
>   od;
>   result := RecvMsg(); # default is MPI_ANY_SOURCE
>   ParReset(); # Interrupt all other slaves - only if using MPINU
>   return result;
> end;;


gap> ParEval("LoadPackage(\"factint\")");

Loading FactInt 1.5.2 (Routines for Integer Factorization )
by Stefan Kohl, kohl@mathematik.uni-stuttgart.de

true


gap> StreamingFactInt := function(i, x)
>   local alg;
>   alg :=
>    [ x -> [ "MPQS ALGORITHM",  FactorsMPQS(Factorial(x)+1) ],
>      x -> [ "CFRAC ALGORITHM", FactorsCFRAC(Factorial(x)+1) ]
>    ];
>   return alg[i](x);
> end;;


gap> # Now, define StreamingFactInt() on each of the slaves.
gap> BroadcastMsg( PrintToString( "StreamingFactInt :=",
>                                 StreamingFactInt ) );
gap> ParFirstResult([1,2], i->StreamingFactInt(i, 35) );
... resetting ...
[ "MPQS ALGORITHM", [ 137, 379, 17839, 340825649, 32731815563800396289317 ] ]


gap>  ParTrace := true;;
gap>  MyParList([2..256], AnalyzePrimitivePermGroupsOfOrder);


CheckTaskResult := function( taskInput, taskOutput )
  if taskOutput = fail then return NO_ACTION;
  elif not IsUpToDate() then return REDO_ACTION;
  else return UPDATE_ACTION;
  fi;
end;

