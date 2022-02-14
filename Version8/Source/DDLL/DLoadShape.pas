unit DLoadShape;

interface

function LoadShapeI(mode: Longint; arg: Longint): Longint; CDECL;
function LoadShapeF(mode: Longint; arg: Double): Double; CDECL;
function LoadShapeS(mode: Longint; arg: Pansichar): Pansichar; CDECL;
procedure LoadShapeV(mode: Longint; var arg: Variant); CDECL;

implementation

uses
    Loadshape,
    DSSGlobals,
    PointerList,
    Variants,
    ExecHelper,
    ucomplex;

var
    ActiveLSObject: TLoadshapeObj;

function LoadShapeI(mode: Longint; arg: Longint): Longint; CDECL;

var
    iElem: Integer;

begin
    Result := 0;   // Default return value
    case mode of
        0:
        begin  // LoadShapes.Count
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
                Result := LoadshapeClass[ActiveActor].ElementList.ListSize;
        end;
        1:
        begin  // LoadShapes.First
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                iElem := LoadshapeClass[ActiveActor].First;
                if iElem <> 0 then
                begin
                    ActiveLSObject := ActiveDSSObject[ActiveActor] as TLoadShapeObj;
                    Result := 1;
                end
            end;
        end;
        2:
        begin  // LoadShapes.Next
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                iElem := LoadshapeClass[ActiveActor].Next;
                if iElem <> 0 then
                begin
                    ActiveLSObject := ActiveDSSObject[ActiveActor] as TLoadShapeObj;
                    Result := iElem;
                end
            end;
        end;
        3:
        begin  // LoadShapes.Npts read
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.NumPoints;
        end;
        4:
        begin  // LoadShapes.Npts write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.NumPoints := arg;
        end;
        5:
        begin  // LoadShapes.Normalize
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.Normalize;
        end;
        6:
        begin   // LoadShapes.UseActual read
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    if ActiveLSObject.UseActual then
                        Result := 1;
        end;
        7:
        begin   // LoadShapes.UseActual write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                begin
                    if arg = 1 then
                        ActiveLSObject.UseActual := TRUE
                    else
                        ActiveLSObject.UseActual := FALSE
                end;
        end
    else
        Result := -1;
    end;
end;

//**********************Floating point type properties***************************
function LoadShapeF(mode: Longint; arg: Double): Double; CDECL;
begin
    Result := 0.0;    // Default return value
    case mode of
        0:
        begin  // LoadShapes.HrInterval read
            Result := 0.0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.Interval;
        end;
        1:
        begin  // LoadShapes.HrInterval write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.Interval := arg;
        end;
        2:
        begin  // LoadShapes.MinInterval read
            Result := 0.0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.Interval * 60.0;
        end;
        3:
        begin  // LoadShapes.MinInterval write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.Interval := arg / 60.0;
        end;
        4:
        begin  // LoadShapes.PBase read
            Result := 0.0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.baseP;
        end;
        5:
        begin  // LoadShapes.PBase write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.baseP := arg;
        end;
        6:
        begin  // LoadShapes.QBase read
            Result := 0.0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.baseQ;
        end;
        7:
        begin  // LoadShapes.QBase write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.baseQ := arg;
        end;
        8:
        begin  // LoadShapes.Sinterval read
            Result := 0.0;
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    Result := ActiveLSObject.Interval * 3600.0;
        end;
        9:
        begin  // LoadShapes.Sinterval write
            if ActiveCircuit[ActiveActor] <> NIL then
                if ActiveLSObject <> NIL then
                    ActiveLSObject.Interval := arg / 3600.0;
        end
    else
        Result := -1.0;
    end;
end;

//**********************String type properties***************************
function LoadShapeS(mode: Longint; arg: Pansichar): Pansichar; CDECL;

var
    elem: TLoadshapeObj;

begin
    Result := Pansichar(Ansistring(''));      // Default return value
    case mode of
        0:
        begin  // LoadShapes.Name read
            Result := Pansichar(Ansistring(''));
            elem := LoadshapeClass[ActiveActor].GetActiveObj;
            if elem <> NIL then
                Result := Pansichar(Ansistring(elem.Name));
        end;
        1:
        begin  // LoadShapes.Name write
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if LoadshapeClass[ActiveActor].SetActive(Widestring(arg)) then
                begin
                    ActiveLSObject := LoadshapeClass[ActiveActor].ElementList.Active;
                    ActiveDSSObject[ActiveActor] := ActiveLSObject;
                end
                else
                begin
                    DoSimpleMsg('Relay "' + Widestring(arg) + '" Not Found in Active Circuit.', 77003);
                end;
            end;
        end
    else
        Result := Pansichar(Ansistring('Error, parameter not valid'));
    end;
end;

//**********************Variant type properties***************************
procedure LoadShapeV(mode: Longint; var arg: Variant); CDECL;

var
    i,
    k,
    LoopLimit: Integer;
    elem: TLoadshapeObj;
    pList: TPointerList;
    Sample: Complex;
    UseHour: Boolean;

begin
    case mode of
        0:
        begin  // LoadShapes.AllNames
            arg := VarArrayCreate([0, 0], varOleStr);
            arg[0] := 'NONE';
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if LoadShapeClass[ActiveActor].ElementList.ListSize > 0 then
                begin
                    pList := LoadShapeClass[ActiveActor].ElementList;
                    VarArrayRedim(arg, pList.ListSize - 1);
                    k := 0;
                    elem := pList.First;
                    while elem <> NIL do
                    begin
                        arg[k] := elem.Name;
                        Inc(k);
                        elem := pList.next;
                    end;
                end;
            end;
        end;
        1:
        begin  // LoadShapes.PMult read
            arg := VarArrayCreate([0, 0], varDouble);
            arg[0] := 0.0;  // error condition: one element array=0
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                begin
                    VarArrayRedim(arg, ActiveLSObject.NumPoints - 1);
                    UseHour := ActiveLSObject.Interval = 0;
                    for k := 1 to ActiveLSObject.NumPoints do
                    begin
                        if UseHour then
                            Sample := ActiveLSObject.GetMult(ActiveLSObject.Hours^[k]) // For variable step
                        else
                            Sample := ActiveLSObject.GetMult(k * ActiveLSObject.Interval);     // This change adds compatibility with MMF
                        arg[k - 1] := Sample.re;
                    end;
                end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61001);
                end;
            end;
        end;
        2:
        begin  // LoadShapes.PMult write
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                    with ActiveLSObject do
                    begin

        // Only put in as many points as we have allocated
                        LoopLimit := VarArrayHighBound(arg, 1);
                        if (LoopLimit - VarArrayLowBound(arg, 1) + 1) > NumPoints then
                            LoopLimit := VarArrayLowBound(arg, 1) + NumPoints - 1;

                        ReallocMem(PMultipliers, Sizeof(PMultipliers^[1]) * NumPoints);
                        k := 1;
                        for i := VarArrayLowBound(arg, 1) to LoopLimit do
                        begin
                            ActiveLSObject.Pmultipliers^[k] := arg[i];
                            inc(k);
                        end;

                    end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61002);
                end;
            end;
        end;
        3:
        begin  // LoadShapes.QMult read
            arg := VarArrayCreate([0, 0], varDouble);
            arg[0] := 0.0;  // error condition: one element array=0
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                begin
                    if assigned(ActiveLSObject.QMultipliers) then
                    begin
                        VarArrayRedim(arg, ActiveLSObject.NumPoints - 1);    // This change adds compatibility with MMF
                        UseHour := ActiveLSObject.Interval = 0;
                        for k := 1 to ActiveLSObject.NumPoints do
                        begin
                            if UseHour then
                                Sample := ActiveLSObject.GetMult(ActiveLSObject.Hours^[k]) // For variable step
                            else
                                Sample := ActiveLSObject.GetMult(k * ActiveLSObject.Interval);
                            arg[k - 1] := Sample.im;
                        end;
                    end;
                end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61001);
                end;
            end;
        end;
        4:
        begin  // LoadShapes.QMult write
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                    with ActiveLSObject do
                    begin

        // Only put in as many points as we have allocated
                        LoopLimit := VarArrayHighBound(arg, 1);
                        if (LoopLimit - VarArrayLowBound(arg, 1) + 1) > NumPoints then
                            LoopLimit := VarArrayLowBound(arg, 1) + NumPoints - 1;

                        ReallocMem(QMultipliers, Sizeof(QMultipliers^[1]) * NumPoints);
                        k := 1;
                        for i := VarArrayLowBound(arg, 1) to LoopLimit do
                        begin
                            ActiveLSObject.Qmultipliers^[k] := arg[i];
                            inc(k);
                        end;

                    end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61002);
                end;
            end;
        end;
        5:
        begin   // LoadShapes.Timearray read
            arg := VarArrayCreate([0, 0], varDouble);
            arg[0] := 0.0;  // error condition: one element array=0
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                begin
                    if ActiveLSObject.hours <> NIL then
                    begin
                        VarArrayRedim(arg, ActiveLSObject.NumPoints - 1);
                        for k := 0 to ActiveLSObject.NumPoints - 1 do
                            arg[k] := ActiveLSObject.Hours^[k + 1];
                    end
                end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61001);
                end;
            end;
        end;
        6:
        begin   // LoadShapes.Timearray write
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if ActiveLSObject <> NIL then
                    with ActiveLSObject do
                    begin

        // Only put in as many points as we have allocated
                        LoopLimit := VarArrayHighBound(arg, 1);
                        if (LoopLimit - VarArrayLowBound(arg, 1) + 1) > NumPoints then
                            LoopLimit := VarArrayLowBound(arg, 1) + NumPoints - 1;

                        ReallocMem(Hours, Sizeof(Hours^[1]) * NumPoints);
                        k := 1;
                        for i := VarArrayLowBound(arg, 1) to LoopLimit do
                        begin
                            ActiveLSObject.Hours^[k] := arg[i];
                            inc(k);
                        end;

                    end
                else
                begin
                    DoSimpleMsg('No active Loadshape Object found.', 61002);
                end;
            end;
        end
    else
        arg[0] := 'Error, parameter not valid';
    end;
end;


end.
