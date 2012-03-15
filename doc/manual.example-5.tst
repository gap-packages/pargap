
#Shared Data: none
#TaskInput:   counter
#TaskOutput:  counter^2 (square of counter)
#Task:        compute counter^2 from counter
ParEval( "result := []" );
ParEval( "counter := 0; \
          SubmitTaskInput := function() \
            counter := counter + 1; \
            if counter <= 10 then return counter; else return NOTASK; fi; \
          end;");
ParEval( "DoTask := x->x^2" );
ParEval( "CheckTaskResultVers1 := function( input, output ) \
            result[input] := [input, output]; \
            return NO_ACTION; \
          end;" );
ParEval( "MasterSlave( SubmitTaskInput, DoTask, CheckTaskResultVers1 )" );
Print(result);


ParBroadcast(PrintToString("result = ", result));


#Shared Data: result [ result is shared among all processes ]
#TaskInput:   counter
#TaskOutput:  counter^2 (square of counter)
#Task:        compute counter^2 from counter
#UpdateSharedData:  record [counter, counter^2] at index, counter, of result
MSSquare := function( range ) # expects as input a range, like [1..10]
  local counter, result,
      SubmitTaskInput, DoTask, CheckTaskResultVers2, UpdateSharedData;
  counter := range[1]; # Reset counter for use in SubmitTaskInput()
  result := [];
  SubmitTaskInput := function()
    counter := counter + 1;
    if counter <= range[Length(range)] then return counter;
    else return NOTASK;
    fi;
  end;
  DoTask := x->x^2;
  CheckTaskResultVers2 := function( input, output )
    return UPDATE_ACTION;
  end;
  UpdateSharedData := function( input, output )
    result[input] := [input, output];
  end;
  MasterSlave( SubmitTaskInput, DoTask, CheckTaskResultVers2, UpdateSharedData );
  return result;
end;

#ParSquare() is the main calling function;  It must define MSSquare on
#  all slaves before calling it in parallel.
ParSquare := function( range ) # expects as input a range, like [1..10]
  ParEval( PrintToString( "MSSquare := ", MSSquare ) );
  return ParEval( PrintToString( "MSSquare( ", range, ")" ) );
end;


ParInstallTOPCGlobalFunction( "ParSquare", function( range )
  local result;
  result := [];
  MasterSlave( TaskInputIterator( range ),
               x->x^2,
               function( input, output ) return UPDATE_ACTION; end,
               function( input, output ) result[input] := [input, output]; end
             );
  return result;
end );


SeqMultMat := function(m1, m2)               # sequential code
  local i, j, k, n, m2t, sum, result;
  n := Length(m1);
  result := [];
  m2t := TransposedMat(m2);
  for i in [1..n] do
    result[i] := [];
    for j in [1..n] do
      sum := 0;
      for k in [1..n] do
        sum := sum + m1[i][k]*m2t[j][k];
      od;
      result[i][j] := sum;
    od;
  od;
  return result;
end;


#Shared Data: m1, m2t, result (three matrices)
#TaskInput:   i (row index of result matrix)
#TaskOutput:  result[i] (row of result matrix)
#Task:        Compute result[i] from i, m1, and m2
#UpdateSharedData:  Given result[i] and i, modify result on all processes.

ParInstallTOPCGlobalFunction( "ParMultMat", function(m1, m2)
  local i, n, m2t, result, DoTask, CheckTaskResult, UpdateSharedData;
  n := Length(m1);
  result := [];
  m2t := TransposedMat(m2);

  DoTask := function(i) # i is task input
    local j, k, sum;
    result[i] := [];
    for j in [1..n] do
      sum := 0;
      for k in [1..n] do
        sum := sum + m1[i][k]*m2t[j][k];
      od;
      result[i][j] := sum;
    od;
    return result[i]; # return task output, row_i
  end;
  # CheckTaskResult executes only on the master
  CheckTaskResult := function(i, row_i) # task output is row_i
    return UPDATE_ACTION; # Pass on output and input to UpdateSharedData
  end;
  # UpdateSharedData executes on the master and on all slaves
  UpdateSharedData := function(i, row_i) # task output is row_i
    result[i] := row_i;
  end;
  # We're done defining the task.  Let's do it now.
  MasterSlave( TaskInputIterator([1..n]), DoTask, CheckTaskResult,
               UpdateSharedData );
  # result is defined on all processes;  return local copy of result
  return result;
end );


SemiEchelonMat := function( mat )

    local zero,      # zero of the field of <mat>
          nrows,     # number of rows in <mat>
          ncols,     # number of columns in <mat>
          vectors,   # list of basis vectors
          heads,     # list of pivot positions in 'vectors'
          i,         # loop over rows
          j,         # loop over columns
          x,         # a current element
          nzheads,   # list of non-zero heads
          row;       # the row of current interest

    mat:= List( mat, ShallowCopy );
    nrows:= Length( mat );
    ncols:= Length( mat[1] );

    zero:= Zero( mat[1][1] );

    heads:= ListWithIdenticalEntries( ncols, 0 );
    nzheads := [];
    vectors := [];

    for i in [ 1 .. nrows ] do
        row := mat[i];
        # Reduce the row with the known basis vectors.
        for j in [ 1 .. Length(nzheads) ] do
            x := row[nzheads[j]];
            if x <> zero then
                AddRowVector( row, vectors[ j ], - x );
            fi;
        od;
        j := PositionNot( row, zero );
        if j <= ncols then
            # We found a new basis vector.
            MultRowVector(row, Inverse(row[j]));
            Add( vectors, row );
            Add( nzheads, j);
            heads[j]:= Length( vectors );
        fi;
    od;

    return rec( heads   := heads,
                vectors := vectors );
    end;


#Shared Data: vectors (basis vectors), heads, nzheads, mat (matrix)
#TaskInput:   i (row index of matrix)
#TaskOutput:  List of (1) j and (2) row i of matrix, mat, reduced by vectors
#               j is the first non-zero element of row i
#Task:        Compute reduced row i from mat, vectors, heads
#UpdateSharedData:  Given i, j, reduced row i, add new basis vector
#               to vectors and update heads[j] to point to it

ParInstallTOPCGlobalFunction( "ParSemiEchelonMat", function( mat )
    local zero,      # zero of the field of <mat>
          nrows,     # number of rows in <mat>
          ncols,     # number of columns in <mat>
          vectors,   # list of basis vectors
          heads,     # list of pivot positions in 'vectors'
          i,         # loop over rows
          nzheads,   # list of non-zero heads
          DoTask, UpdateSharedData;

    mat:= List( mat, ShallowCopy );
    nrows:= Length( mat );
    ncols:= Length( mat[1] );

    zero:= Zero( mat[1][1] );

    heads:= ListWithIdenticalEntries( ncols, 0 );
    nzheads := [];
    vectors := [];

    DoTask := function( i ) # taskInput = i
      local j,         # loop over columns
            x,         # a current element
            row;       # the row of current interest
      row := mat[i];
      # Reduce the row with the known basis vectors.
      for j in [ 1 .. Length(nzheads) ] do
          x := row[nzheads[j]];
          if x <> zero then
              AddRowVector( row, vectors[ j ], - x );
          fi;
      od;
      j := PositionNot( row, zero );
      if j <= ncols then return [j, row]; # return taskOutput
      else return fail; fi;
    end;
    UpdateSharedData := function( i, taskOutput )
      local j, row;
      j := taskOutput[1];
      row := taskOutput[2];
      # We found a new basis vector.
      MultRowVector(row, Inverse(row[j]));
      Add( vectors, row );
      Add( nzheads, j);
      heads[j]:= Length( vectors );
    end;

    MasterSlave( TaskInputIterator( [1..nrows] ), DoTask, DefaultCheckTaskResult,
                  UpdateSharedData );

    return rec( heads   := heads,
                vectors := vectors );
end );


ParEval("globalTaskOutput := [[-1]]");


  DoTask := function( i )
      local j,         # loop over columns
            x,         # a current element
            row;       # the row of current interest
    if i = globalTaskOutput[1] then
      # then this is a REDO_ACTION
      row := globalTaskOutput[2]; # recover last row value
    else row := mat[i];
    fi;
    # Reduce the row with the known basis vectors.
    for j in [ 1 .. Length(nzheads) ] do
      x := row[nzheads[j]];
      if x <> zero then
        AddRowVector( row, vectors[ j ], - x );
      fi;
    od;
    j := PositionNot( row, zero );
    # save row in case of new REDO_ACTION
    globalTaskOutupt[1] := i;
    globalTaskOutput[2] := row;
    if j <= ncols then return [j, row]; # return taskOutput
    else return fail; fi;
  end;


MasterSlave( TaskInputIterator( [1..n] ), DoTask, DefaultCheckTaskResult,
             UpdateSharedData, 5 );


ParEval("globalTaskOutput := [[-1]]");
ParEval("globalTaskOutputs := []");

#Shared Data: vectors (basis vectors), heads, mat (matrix)
#TaskInput:   i (row index of matrix)
#TaskOutput:  List of (1) j and (2) row i of matrix, mat, reduced by vectors
#               j is the first non-zero element of row i
#Task:        Compute reduced row i from mat, vectors, heads
#UpdateSharedData:  Given i, j, reduced row i, add new basis vector
#               to vectors and update heads[j] to point to it

ParInstallTOPCGlobalFunction( "ParSemiEchelonMat", function( mat )
  local zero,      # zero of the field of <mat>
        nrows,     # number of rows in <mat>
        ncols,     # number of columns in <mat>
        vectors,   # list of basis vectors
        heads,     # list of pivot positions in 'vectors'
        i,         # loop over rows
        nzheads,   # list of non-zero heads
        DoTask, UpdateSharedDataWithAgglom;

  mat:= List( mat, ShallowCopy );
  nrows:= Length( mat );
  ncols:= Length( mat[1] );

  zero:= Zero( mat[1][1] );

  heads:= ListWithIdenticalEntries( ncols, 0 );
  nzheads := [];
  vectors := [];

  DoTask := function( i )
      local j,         # loop over columns
            x,         # a current element
            row;       # the row of current interest
    if IsBound(globalTaskOutputs[TaskAgglomIndex])
        and i = globalTaskOutputs[TaskAgglomIndex][1] then
      # then this is a REDO_ACTION
      row := globalTaskOutputs[TaskAgglomIndex][2][2]; # recover last row value
    else row := mat[i];
    fi;
    # Reduce the row with the known basis vectors.
    for j in [ 1 .. Length(nzheads) ] do
      x := row[nzheads[j]];
      if x <> zero then
        AddRowVector( row, vectors[ j ], - x );
      fi;
    od;
    j := PositionNot( row, zero );

    # save [input, output] in case of new REDO_ACTION
    globalTaskOutputs[TaskAgglomIndex] := [ i, [j, row] ];

    if j <= ncols then return [j, row]; # return taskOutput
    else return fail; fi;
  end;

  # This version of UpdateSharedData() expects a list of taskOutput's
  UpdateSharedDataWithAgglom := function( listI, taskOutputs )
    local j, row, idx, tmp;
    for idx in [1..Length( taskOutputs )] do
      j := taskOutputs[idx][1];
      row := taskOutputs[idx][2];

      if idx > 1 then
        globalTaskOutputs[1] := [-1, [j, row] ];
        tmp := DoTask( -1 ); # Trick DoTask() into a REDO_ACTION
        if tmp <> fail then
          j := tmp[1];
          row := tmp[2];
        fi;
      fi;

      # We found a new basis vector.
      MultRowVector(row, Inverse(row[j]));
      Add( vectors, row );
      Add( nzheads, j);
      heads[j]:= Length( vectors );
    od;
  end;

  MasterSlave( TaskInputIterator( [1..nrows] ), DoTask, DefaultCheckTaskResult,
                UpdateSharedDataWithAgglom, 5 ); #taskAgglom set to 5 tasks

  return rec( heads   := heads,
              vectors := vectors );
end );


#Shared Data: m1, m2t, result (three matrices)
#TaskInput:   [i,j] (indices of entry in result matrix)
#TaskOutput:  result[i][j] (value of entry in result matrix)
#Task:        Compute inner produce of row i of m1 by colum j of m1
              ( Note that column j of m1 is also row j of m2t, the transpose )
#UpdateSharedData:  Given result[i][j] and [i,j], modify result everywhere

ParInstallTOPCGlobalFunction( "ParRawMultMat", function(m1, m2)
  local i, j, k, n, m2t, sum, result, DoTask, CheckTaskResult, UpdateSharedData;
  n := Length(m1);
  m2t := TransposedMat(m2);
  result := ListWithIdenticalEntries( Length(m2t), [] );

  DoTask := function( input )
    local i,j,k,sum;
    i:=input[1]; j:=input[2];
    sum := 0;
    for k in [1..n] do
      sum := sum + m1[i][k]*m2t[j][k];
    od;
    return sum;
  end;

  CheckTaskResult := function( input, output )
    return UPDATE_ACTION;
  end;

  UpdateSharedData := function( input, output )
    local i, j;
    i := input[1]; j := input[2];
    result[i][j] := output;
    # result[i,j] := sum;
  end;

  BeginRawMasterSlave( DoTask, CheckTaskResult, UpdateSharedData );
  for i in [1..n] do
    result[i] := [];
    for j in [1..n] do
      RawSubmitTaskInput( [i,j] );
      # sum := 0;
      # for k in [1..n] do
      #   sum := sum + m1[i][k]*m2t[j][k];
      # od;
      # result[i][j] := sum;
    od;
  od;
  EndRawMasterSlave();

  return result;
end );

