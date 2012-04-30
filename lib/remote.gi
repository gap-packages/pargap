DeclareRepresentation( "IsRemoteReferenceRep", 
                       IsPositionalObjectRep,
                       [ ] );


RemoteReferenceDefaultType :=
  NewType( RemoteReferencesFamily, 
           IsRemoteReferenceRep and IsRemoteReference);

      
InstallGlobalFunction( RemoteReference, function( pid, localaddr,weight )
return Objectify( RemoteReferenceDefaultType,
                    [ pid, localaddr,weight ] ); 
end);


#############################################################################
##
#M  ViewObj( <RemoteObject> )
##
InstallMethod( ViewObj, "for RemoteReference",
[ IsRemoteReferenceRep and IsRemoteReference ],
function( obj )
    Print("< remote reference ", obj![2], ":", obj![3], "/", obj![1], " >");
end);
