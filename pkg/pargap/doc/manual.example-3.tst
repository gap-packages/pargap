
gap> ParInstallTOPCGlobalFunction( "MyParListWithAgglom",
> function( list, fnc )
>   local result, i;
>   result := []; i := 0;
>   MasterSlave( function() if i >= Length(list) then return NOTASK;
>                           else i := i+1; return i; fi; end,
>                fnc,
>                function(input,output) result[input] := output;
>                                       return NO_ACTION; end,
>                Error
>              );
>   return result;
> end );

