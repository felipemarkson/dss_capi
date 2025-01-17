unit GICTransformer;

// ----------------------------------------------------------
// Copyright (c) 2011-2015, Electric Power Research Institute, Inc.
// All rights reserved.
// ----------------------------------------------------------

// Special resistance-only model of transformers for geomagnetically-induced current (GIC) studies

interface

uses
    Classes,
    Command,
    DSSClass,
    PDClass,
    Circuit,
    PDElement,
    UcMatrix,
    ArrayDef,
    XYCurve;

type
{$SCOPEDENUMS ON}
    TGICTransformerPropLegacy = (
        INVALID = 0,
        BusH=1,
        BusNH=2,
        BusX=3,
        BusNX=4,
        phases=5,
        Typ=6,
        R1=7,
        R2=8,
        KVLL1=9,
        KVLL2=10,
        MVA=11,
        VarCurve=12,
        pctR1=13,
        pctR2=14,
        K=15
    );
    TGICTransformerProp = (
        INVALID = 0,
        BusH=1,
        BusNH=2,
        BusX=3,
        BusNX=4,
        Phases=5,
        Typ=6,
        R1=7,
        R2=8,
        kVLL1=9,
        kVLL2=10,
        MVA=11,
        VarCurve=12,
        pctR1=13,
        pctR2=14,
        K=15
    );
{$SCOPEDENUMS OFF}

    TGICTransformer = class(TPDClass)
    PROTECTED
        procedure DefineProperties; override;
    PUBLIC
        constructor Create(dssContext: TDSSContext);
        destructor Destroy; OVERRIDE;

        Function NewObject(const ObjName: String; Activate: Boolean = True): Pointer; OVERRIDE;
    end;

    TGICTransformerObj = class(TPDElement)
    PRIVATE
        G1, G2: Double;         // single G per phase (line rating)

        SpecType: Integer;
        FMVARating: Double;
        FVarCurveObj: TXYCurveObj;
        FpctR1,
        FpctR2: Double;
        FZbase1,
        FZbase2: Double;
        // FkVSpecified: Boolean;
        FpctRSpecified: Boolean;
        KSpecified: Boolean;
        FKFactor: Double;
        FkV1,
        FkV2: Double;

    PUBLIC
        constructor Create(ParClass: TDSSClass; const FaultName: String);
        destructor Destroy; OVERRIDE;
        procedure PropertySideEffects(Idx: Integer; previousIntVal: Integer; setterFlags: TDSSPropertySetterFlags); override;
        procedure MakeLike(OtherPtr: Pointer); override;

        procedure RecalcElementData; OVERRIDE;
        procedure CalcYPrim; OVERRIDE;

        procedure MakePosSequence(); OVERRIDE;  // Make a positive Sequence Model

        procedure WriteVarOutputRecord(F: TStream); // Add a record to the ouput file based on present GIC
    end;

implementation

uses
    DSSClassDefs,
    DSSGlobals,
    Sysutils,
    UComplex, DSSUcomplex,
    MathUtil,
    Utilities,
    DSSHelper,
    DSSObjectHelper,
    TypInfo;

type
    TObj = TGICTransformerObj;
    TProp = TGICTransformerProp;
    TPropLegacy = TGICTransformerPropLegacy;
const
    NumPropsThisClass = Ord(High(TProp));

    SPEC_GSU = 1;
    SPEC_AUTO = 2;
    SPEC_YY = 3;
var
    PropInfo: Pointer = NIL;
    PropInfoLegacy: Pointer = NIL;    
    TypeEnum: TDSSEnum;

constructor TGICTransformer.Create(dssContext: TDSSContext);
begin
    if PropInfo = NIL then
    begin
        PropInfo := TypeInfo(TProp);
        PropInfoLegacy := TypeInfo(TPropLegacy);
        TypeEnum := TDSSEnum.Create('GICTransformer: Type', True, 1, 1, ['GSU', 'Auto', 'YY'], [SPEC_GSU, SPEC_AUTO, SPEC_YY]);
    end;

    inherited Create(dssContext, GIC_TRANSFORMER, 'GICTransformer');
end;

destructor TGICTransformer.Destroy;
begin
    inherited Destroy;
end;

procedure SetBusX(obj: TObj; busDef: String);
begin
    // Make sure we have enough terminals defined
    // Set Bus2 = Bus1.0.0.0
    if obj.Nterms <> 4 then   // have to have 4 terminals to set this property
    begin
        obj.Nterms := 4;
        obj.NConds := obj.Fnphases; // force reallocation of terminals and conductors
    end;
    obj.SetBus(3, busDef);
end;

procedure TGICTransformer.DefineProperties;
var 
    obj: TObj = NIL; // NIL (0) on purpose
begin
    Numproperties := NumPropsThisClass;
    CountPropertiesAndAllocate();
    PopulatePropertyNames(0, NumPropsThisClass, PropInfo, PropInfoLegacy);

    SpecSetNames := ArrayOfString.Create(
        'R1, R2',
        'pctR1, pctR2'
    );
    SpecSets := TSpecSets.Create(
        TSpecSet.Create(ord(TProp.R1), ord(TProp.R2)),
        TSpecSet.Create(ord(TProp.pctR1), ord(TProp.pctR2))
    );

    // enum properties
    // PropertyType[ord(TProp.conn)] := TPropertyType.MappedStringEnumProperty;
    // PropertyOffset[ord(TProp.conn)] := ptruint(@obj.Connection);
    // PropertyOffset2[ord(TProp.conn)] := PtrInt(DSS.ConnectionEnum);

    PropertyType[ord(TProp.typ)] := TPropertyType.MappedStringEnumProperty;
    PropertyOffset[ord(TProp.typ)] := ptruint(@obj.SpecType);
    PropertyOffset2[ord(TProp.typ)] := PtrInt(TypeEnum);

    // integer properties
    PropertyType[ord(TProp.phases)] := TPropertyType.IntegerProperty;
    PropertyOffset[ord(TProp.phases)] := ptruint(@obj.FNPhases);
    PropertyFlags[ord(TProp.phases)] := [TPropertyFlag.NonNegative, TPropertyFlag.NonZero];

    // bus properties
    PropertyType[ord(TProp.BusH)] := TPropertyType.BusProperty;
    PropertyType[ord(TProp.BusNH)] := TPropertyType.BusProperty;
    PropertyType[ord(TProp.BusX)] := TPropertyType.BusProperty;
    PropertyType[ord(TProp.BusNX)] := TPropertyType.BusProperty;
    PropertyOffset[ord(TProp.BusH)] := 1;
    PropertyOffset[ord(TProp.BusNH)] := 2;
    PropertyOffset[ord(TProp.BusX)] := 3;
    PropertyOffset[ord(TProp.BusNX)] := 4;

    PropertyFlags[ord(TProp.BusX)] := [TPropertyFlag.WriteByFunction];
    PropertyWriteFunction[ord(TProp.BusX)] := @SetBusX;

    // object properties
    PropertyType[ord(TProp.VarCurve)] := TPropertyType.DSSObjectReferenceProperty;
    PropertyOffset[ord(TProp.VarCurve)] := ptruint(@obj.FVarCurveObj);
    PropertyOffset2[ord(TProp.VarCurve)] := ptruint(DSS.XYCurveClass);

    // double properties
    PropertyOffset[ord(TProp.KVLL1)] := ptruint(@obj.FkV1);
    PropertyFlags[ord(TProp.KVLL1)] := [TPropertyFlag.Units_kV];

    PropertyOffset[ord(TProp.KVLL2)] := ptruint(@obj.FkV2);
    PropertyFlags[ord(TProp.KVLL2)] := [TPropertyFlag.Units_kV];

    PropertyOffset[ord(TProp.MVA)] := ptruint(@obj.FMVArating);
    PropertyFlags[ord(TProp.MVA)] := [TPropertyFlag.Units_MVA];

    PropertyOffset[ord(TProp.pctR1)] := ptruint(@obj.FpctR1);
    PropertyFlags[ord(TProp.pctR1)] := [TPropertyFlag.RequiredInSpecSet, TPropertyFlag.NoDefault];
    
    PropertyOffset[ord(TProp.pctR2)] := ptruint(@obj.FpctR2);
    PropertyFlags[ord(TProp.pctR2)] := [TPropertyFlag.NoDefault];

    PropertyOffset[ord(TProp.k)] := ptruint(@obj.FKFactor);

    // adv doubles
    PropertyOffset[ord(TProp.R1)] := ptruint(@obj.G1);
    PropertyFlags[ord(TProp.R1)] := [TPropertyFlag.InverseValue, TPropertyFlag.RequiredInSpecSet, TPropertyFlag.Units_ohm];

    PropertyOffset[ord(TProp.R2)] := ptruint(@obj.G2);
    PropertyFlags[ord(TProp.R2)] := [TPropertyFlag.InverseValue, TPropertyFlag.Units_ohm];

    ActiveProperty := NumPropsThisClass;
    inherited DefineProperties;
end;

function TGICTransformer.NewObject(const ObjName: String; Activate: Boolean): Pointer;
var
    Obj: TObj;
begin
    Obj := TObj.Create(Self, ObjName);
    if Activate then 
        ActiveCircuit.ActiveCktElement := Obj;
    Obj.ClassIndex := AddObjectToList(Obj, Activate);
    Result := Obj;
end;

procedure TGICTransformerObj.PropertySideEffects(Idx: Integer; previousIntVal: Integer; setterFlags: TDSSPropertySetterFlags);
var
    S, S2: String;
    dotpos: Integer;
begin
    case Idx of
        ord(TProp.BusH):
        begin
            // Set Bus2 = BusH1.0.0.0
            // Default Bus2 to zero node of Bus1. (Wye Grounded connection)
            // Strip node designations from S
            S := GetBus(1);
            dotpos := Pos('.', S);
            if dotpos > 0 then
                S2 := Copy(S, 1, dotpos - 1)  // copy up to Dot
            else
                S2 := Copy(S, 1, Length(S));

            S2 := S2 + '.0.0.0';     // Set Default for up to 3 phases

            SetBus(2, S2);
            IsShunt := TRUE;
        end;
        ord(TProp.BusX):
        begin
            // Special handling for Bus X

            // Strip node designations from S
            S := GetBus(3);
            dotpos := Pos('.', S);
            if dotpos > 0 then
                S2 := Copy(S, 1, dotpos - 1)  // copy up to Dot
            else
                S2 := Copy(S, 1, Length(S));

            // Default Bus4 to zero node of Bus3. (Wye Grounded connection)
            S2 := S2 + '.0.0.0';     // Set Default for up to 3 phases
            SetBus(4, S2);
            IsShunt := TRUE;

            if SpecType = SPEC_AUTO then
            begin   // automatically make up series-to-common connection
                SetBus(2, GetBus(3));
            end;
        end;
        ord(TProp.phases):
            if Fnphases <> previousIntVal then
            begin
                NConds := Fnphases;  // Force Reallocation of terminal info if different size
                ActiveCircuit.BusNameRedefined := TRUE;  // Set Global Flag to signal circuit to rebuild busdefs
            end;
        ord(TProp.Typ):
            case Spectype of
                SPEC_AUTO:
                begin
                    if Nterms = 2 then
                    begin
                        Nterms := 4;
                        NConds := Fnphases;
                    end;
                    SetBus(2, GetBus(3));
                end;
            end;
        ord(TProp.R1):
        begin
            if G1 = 0.0 then
                G1 := 10000.0;  // Default to a low resistance
            FpctRSpecified := FALSE;
        end;
        ord(TProp.R2):
        begin
            if G2 = 0.0 then
                G2 := 10000.0;  // Default to a low resistance
            FpctRSpecified := FALSE;
        end;
        // ord(TProp.kVLL1),
        // ord(TProp.kVLL2):
        //     FkVSpecified := TRUE;
        ord(TProp.VarCurve):
            if FVarCurveObj <> NIL then
                Kspecified := FALSE;
        ord(TProp.pctR1),
        ord(TProp.pctR2):
            FpctRSpecified := TRUE;
        ord(TProp.K):
            KSpecified := TRUE;
    end;

    //YPrim invalidation on anything that changes impedance values or no. of terminals
    case Idx of
        ord(TProp.BusX),
        ord(TProp.BusNX),
        ord(TProp.phases),
        ord(TProp.Typ),
        ord(TProp.R1),
        ord(TProp.R2):
            YprimInvalid := TRUE;
    end;
    inherited PropertySideEffects(Idx, previousIntVal, setterFlags);
end;

procedure TGICTransformerObj.MakeLike(OtherPtr: Pointer);
var
    Other: TObj;
begin
    inherited MakeLike(OtherPtr);
    Other := TObj(OtherPtr);
    if Fnphases <> Other.Fnphases then
    begin
        Fnphases := Other.Fnphases;
        FnTerms := Other.FnTerms;
        NConds := Fnphases; // force reallocation of terminals and conductors

        Yorder := Fnconds * Fnterms;
        YPrimInvalid := TRUE;
    end;

    BaseFrequency := Other.BaseFrequency;
    G1 := Other.G1;
    G2 := Other.G2;
    SpecType := Other.SpecType;
    FMVARating := Other.FMVARating;
    FVarcurveObj := Other.FVarcurveObj;
    FkV1 := Other.FkV1;
    FkV2 := Other.FkV2;
    FpctR1 := Other.FpctR1;
    FpctR2 := Other.FpctR2;
    FpctRSpecified := Other.FpctRSpecified;
    // FkVSpecified := Other.FkVSpecified;
    FZBase1 := Other.FZBase1;
    FZBase2 := Other.FZBase2;
    FKfactor := Other.FKfactor;
    KSpecified := Other.KSpecified;
end;

constructor TGICTransformerObj.Create(ParClass: TDSSClass; const FaultName: String);
begin
    inherited Create(ParClass);
    DSSObjType := ParClass.DSSClassType;
    Name := AnsiLowerCase(FaultName);

    FNPhases := 3;  // Directly set conds and phases
    Fnconds := 3;
    Nterms := 2;  // Force allocation of terminals and conductors

    Setbus(2, (GetBus(1) + '.0'));  // Default to grounded
    IsShunt := TRUE;

    G1 := 10000.0;
    G2 := 10000.0;
    SpecType := SPEC_GSU;

    FMVARating := 100.0;
    FVarCurveObj := NIL;

    // FkVSpecified := FALSE;
    FkV1 := 500.0;
    FkV2 := 138.0;
    FpctR1 := 0.2;
    FpctR2 := 0.2;

    FKfactor := 2.2;
    KSpecified := TRUE;

    NormAmps := 0.0;
    EmergAmps := 0.0;
    FaultRate := 0.0;
    PctPerm := 100.0;
    HrsToRepair := 0.0;

    Yorder := Fnterms * Fnconds;

    FpctRSpecified := TRUE;  // Force computation of G1, G2
    RecalcElementData;
    FpctRSpecified := FALSE;  // Turn flag off
end;

destructor TGICTransformerObj.Destroy;
begin
    inherited destroy;
end;

procedure TGICTransformerObj.RecalcElementData;
begin
    FZbase1 := SQR(FkV1) / FMVArating;
    FZbase2 := SQR(FkV2) / FMVArating;

    if FpctRSpecified then
    begin
        G1 := 100.0 / (FZBase1 * FPctR1);
        G2 := 100.0 / (FZBase2 * FPctR1);
    end
    else
    begin
        FPctR1 := 100.0 / (FZBase1 * G1);
        FPctR2 := 100.0 / (FZBase2 * G2);
    end;
end;

procedure TGICTransformerObj.WriteVarOutputRecord(F: TStream);
var
    Curr: Complex;
    MVarMag: Double;
    GICperPhase: Double;
    puCurrMag: Double;
    i: Integer;
begin
    ComputeIterminal;
    Curr := 0;
    for i := 1 to Fnphases do
        Curr += Iterminal[i];
    GICperPhase := Cabs(Curr) / Fnphases;
    if Kspecified then
    begin
        MVarMag := FKfactor * FkV1 * GICperPhase / 1000.0;
    end
    else
    begin
        if Assigned(FVarCurveObj) then
        begin
                // MVA = sqrt(3) * kVLL * I/1000
                // pu A per phase (Avg)
            puCurrMag := GICperPhase / (FMVArating * 1000.0 / FkV1 / Sqrt3);
            MVarMag := FVarCurveObj.GetYValue(puCurrMag) * FMVARating / Sqrt2;
        end
        else
            MvarMag := 0.0;
    end;

    FSWriteln(F, Format('%s, %.8g, %.8g', [GetBus(1), MVarMag, (GICperPhase)]));
end;

procedure TGICTransformerObj.CalcYPrim;
var
    Value, Value2: Complex;
    i: Integer;
    YPrimTemp: TCMatrix;
begin
    if YPrimInvalid then
    begin    // Reallocate YPrim if something has invalidated old allocation
        if YPrim_Series <> NIL then
            YPrim_Series.Free;
        YPrim_Series := TCmatrix.CreateMatrix(Yorder);
        if YPrim_Shunt <> NIL then
            YPrim_Shunt.Free;
        YPrim_Shunt := TCmatrix.CreateMatrix(Yorder);
        if YPrim <> NIL then
            YPrim.Free;
        YPrim := TcMatrix.CreateMatrix(Yorder);
    end
    else
    begin
        YPrim_Series.Clear; // zero out YPrim
        YPrim_Shunt.Clear; // zero out YPrim
        Yprim.Clear;
    end;


    if IsShunt then
        YPrimTemp := YPrim_Shunt
    else
        YPrimTemp := Yprim_Series;


    // Now, Put in Yprim matrix
    case SpecType of

        SPEC_GSU:
        begin
            Value := G1;
            Value2 := -Value;
            for i := 1 to Fnphases do
            begin
                YPrimTemp[i, i] := Value;     // Elements are only on the diagonals
                YPrimTemp[i + Fnphases, i + Fnphases] := Value;
                YPrimTemp[i, i + Fnphases] := Value2;
                YPrimTemp[i + Fnphases, i] := Value2;
            end;
        end;

        SPEC_AUTO:
        begin
            // Terminals 1 and 2
            Value := G1;
            Value2 := -Value;
            for i := 1 to Fnphases do
            begin
                YPrimTemp[i, i] := Value;     // Elements are only on the diagonals
                YPrimTemp[i + Fnphases, i + Fnphases] := Value;
                YPrimTemp[i, i + Fnphases] := Value2;
                YPrimTemp[i + Fnphases, i] := Value2;
            end;
            // Terminals 3 and 4
            Value := G2;
            Value2 := -Value;
            for i := (2 * Fnphases + 1) to 3 * Fnphases do
            begin
                YPrimTemp[i, i] := Value;     // Elements are only on the diagonals
                YPrimTemp[i + Fnphases, i + Fnphases] := Value;
                YPrimTemp[i, i + Fnphases] := Value2;
                YPrimTemp[i + Fnphases, i] := Value2;
            end;
        end;

        SPEC_YY:
        begin
            // Terminals 1 and 2
            Value := G1;
            Value2 := -Value;
            for i := 1 to Fnphases do
            begin
                YPrimTemp[i, i] := Value;     // Elements are only on the diagonals
                YPrimTemp[i + Fnphases, i + Fnphases] := Value;
                YPrimTemp[i, i + Fnphases] := Value2;
                YPrimTemp[i + Fnphases, i] := Value2;
            end;
            // Terminals 3 and 4
            Value := G2;
            Value2 := -Value;
            for i := (2 * Fnphases + 1) to 3 * Fnphases do
            begin
                YPrimTemp[i, i] := Value;     // Elements are only on the diagonals
                YPrimTemp[i + Fnphases, i + Fnphases] := Value;
                YPrimTemp[i + Fnphases, i] := Value2;
                YPrimTemp[i, i + Fnphases] := Value2;
            end;
        end;
    end;

    YPrim.CopyFrom(YPrimTemp);

    inherited CalcYPrim;
    YprimInvalid := FALSE;
end;

procedure TGICTransformerObj.MakePosSequence();
begin
    if Fnphases > 1 then
        SetInteger(ord(TProp.Phases), 1, []);
    inherited;
end;

finalization
    TypeEnum.Free;
end.
