unit DISource;

interface

function IsourceI(mode: Longint; arg: Longint): Longint; CDECL;
function IsourceF(mode: Longint; arg: Double): Double; CDECL;
function IsourceS(mode: Longint; arg: Pansichar): Pansichar; CDECL;
procedure IsourceV(mode: Longint; out arg: Variant); CDECL;

implementation

uses
    ComServ,
    Variants,
    PointerList,
    Isource,
    DSSGlobals,
    CktElement;

function IsourceI(mode: Longint; arg: Longint): Longint; CDECL;

var
    pElem: TIsourceObj;
    elem: TIsourceObj;

begin
    Result := 0; // Default return value
    case mode of
        0:
        begin  // Isources.Count
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
                Result := IsourceClass[ActiveActor].ElementList.ListSize;
        end;
        1:
        begin  // Isources.First
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                pElem := IsourceClass[ActiveActor].ElementList.First;
                if pElem <> NIL then
                    repeat
                        if pElem.Enabled then
                        begin
                            ActiveCircuit[ActiveActor].ActiveCktElement := pElem;
                            Result := 1;
                        end
                        else
                            pElem := IsourceClass[ActiveActor].ElementList.Next;
                    until (Result = 1) or (pElem = NIL);
            end;
        end;
        2:
        begin  // Isources.Next
            Result := 0;
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                pElem := IsourceClass[ActiveActor].ElementList.Next;
                if pElem <> NIL then
                    repeat
                        if pElem.Enabled then
                        begin
                            ActiveCircuit[ActiveActor].ActiveCktElement := pElem;
                            Result := IsourceClass[ActiveActor].ElementList.ActiveIndex;
                        end
                        else
                            pElem := IsourceClass[ActiveActor].ElementList.Next;
                    until (Result > 0) or (pElem = NIL);
            end;
        end
    else
        Result := -1;
    end;
end;

//***************************Floating point type properties*******************************
function IsourceF(mode: Longint; arg: Double): Double; CDECL;

var
    pElem: TIsourceObj;
    elem: TIsourceObj;

begin
    Result := 0.0; // Default return value
    case mode of
        0:
        begin  // Isources.Amps read
            Result := 0.0;
            elem := IsourceClass[ActiveActor].ElementList.Active;
            if elem <> NIL then
                Result := elem.Amps;
        end;
        1:
        begin  // Isources.Amps write
            elem := IsourceClass[ActiveActor].GetActiveObj;
            if elem <> NIL then
                elem.Amps := arg;
        end;
        2:
        begin  // Isources.AngleDeg read
            Result := 0.0;
            elem := IsourceClass[ActiveActor].ElementList.Active;
            if elem <> NIL then
                Result := elem.Angle;
        end;
        3:
        begin  // Isources.AngleDeg write
            elem := IsourceClass[ActiveActor].GetActiveObj;
            if elem <> NIL then
                elem.Angle := arg;
        end;
        4:
        begin  // Isources.Frequency read
            Result := 0.0;
            elem := IsourceClass[ActiveActor].ElementList.Active;
            if elem <> NIL then
                Result := elem.SrcFrequency;
        end;
        5:
        begin  // Isources.Frequency write
            elem := IsourceClass[ActiveActor].GetActiveObj;
            if elem <> NIL then
                elem.SrcFrequency := arg;
        end
    else
        Result := -1.0;
    end;
end;

//***************************String type properties*******************************
function IsourceS(mode: Longint; arg: Pansichar): Pansichar; CDECL;

var
    elem: TDSSCktElement;

begin
    Result := Pansichar(Ansistring('')); // Default return value
    case mode of
        0:
        begin  // Isources.Name read
            Result := Pansichar(Ansistring(''));
            elem := ActiveCircuit[ActiveActor].ActiveCktElement;
            if elem <> NIL then
                Result := Pansichar(Ansistring(elem.Name));
        end;
        1:
        begin  // Isoruces.Name write
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if IsourceClass[ActiveActor].SetActive(Widestring(arg)) then
                begin
                    ActiveCircuit[ActiveActor].ActiveCktElement := IsourceClass[ActiveActor].ElementList.Active;
                end
                else
                begin
                    DoSimpleMsg('Isource "' + Widestring(arg) + '" Not Found in Active Circuit.', 77003);
                end;
            end;
        end
    else
        Result := Pansichar(Ansistring('Error, parameter not valid'));
    end;
end;

//***************************Variant type properties*******************************
procedure IsourceV(mode: Longint; out arg: Variant); CDECL;

var
    elem: TIsourceObj;
    pList: TPointerList;
    k: Integer;

begin
    case mode of
        0:
        begin  // Isources.AllNames
            arg := VarArrayCreate([0, 0], varOleStr);
            arg[0] := 'NONE';
            if ActiveCircuit[ActiveActor] <> NIL then
            begin
                if IsourceClass[ActiveActor].ElementList.ListSize > 0 then
                begin
                    pList := IsourceClass[ActiveActor].ElementList;
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
        end
    else
        arg[0] := 'Error, parameter not valid';
    end;
end;

end.
