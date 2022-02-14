unit Solution;

{
  ----------------------------------------------------------
  Copyright (c) 2008-2015, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{ Change Log
 8-14-99 Added progress display and abort on longer solution types
 11-3-99 added calc voltage base
 11-21-99 modified to  calc the voltage bases at the current load level set by the user.
 12-1-99 Added code to estimate starting point for P-V Generators
 12-2-99 Made more properties visible
 12-6-99 Merged properties with Set Command and removed from here
 12-15-99 Added global generatordispatchreference
 1-8-00   Fixed bug in autoadd generators to work with new generator model
          set vminpu=0 and vmaxpu=1000000
 1-30-00 to 2-1-00 Implemented control action check in solution
 2-19-00 Frequency changed reset to FALSE after being used (was causing all YPrims to be recomputed)
 2-23-00 Modified so that reset of meters and monitors is done upon setting the solution mode property.
         After that the user must reset else the monitors just accumulate.
 3-20-00 Fixed bug with setting generator disp reference - made uniform for all types
 6-11-00 Split into two modules + moved auto add stuff to AutoAdd
 9-20-00 Added Dynamic Mode
 10-25-00 Added Fundamental Freq and other stuff for Harmonics Solution
 5-30-01  Added control iterations check, mostIterationsdone.
          Fixed bug with controls off doing the solution too many times.

 8-14-01 Reset IntervalHrs on Mode change
 7-11-02 Added check for system Y change after computing currents

 9-28-03 Redefined V to NodeV and changed from an array from 1..n to 0..n where
         0-th element is alway ground(complex zero volts).
 8-14-06 Revised power flow initialization; removed forward/backward sweep

}

interface

uses
    uCOMPLEX,
    Arraydef,
    Command,
    Monitor,
    DSSClass,
    DSSObject,
    Dynamics,
    EnergyMeter,
    SysUtils;
//    Diagnostics,
//    System.TimeSpan;

const

    NORMALSOLVE = 0;
    NEWTONSOLVE = 1;

type

    EControlProblem = class(Exception);
    ESolveError = class(Exception);  // Raised when solution aborted

    TNodeVarray = array[0..1000] of Complex;
    pNodeVarray = ^TNodeVarray;

    TDSSSolution = class(TDSSClass)
    PRIVATE
//       CommandList:TCommandlist;
    PROTECTED
        procedure DefineProperties;
    PUBLIC
        constructor Create;
        destructor Destroy; OVERRIDE;

        function Edit: Integer; OVERRIDE;
        function Init(Handle: Integer): Integer; OVERRIDE;
        function NewObject(const ObjName: String): Integer; OVERRIDE;

    end;

    TSolutionObj = class(TDSSObject)
    PRIVATE

        dV: pNodeVArray;   // Array of delta V for Newton iteration
        FFrequency: Double;

        function Converged: Boolean;
        function OK_for_Dynamics(const Value: Integer): Boolean;
        function OK_for_Harmonics(const Value: Integer): Boolean;


        procedure DoNewtonSolution;
        procedure DoNormalSolution;
//       PROCEDURE GetMachineInjCurrents;
        procedure SetGeneratordQdV;
        procedure SumAllCurrents;
        procedure Set_Frequency(const Value: Double);
        procedure Set_Mode(const Value: Integer);
        procedure Set_Year(const Value: Integer);
        procedure Set_Total_Time(const Value: Double);

    PUBLIC

        Algorithm: Integer;      // NORMALSOLVE or NEWTONSOLVE
        AuxCurrents: pComplexArray;  // For injections like AutoAdd
        ControlActionsDone: Boolean;
        ControlIteration: Integer;
        ControlMode: Integer;     // EVENTDRIVEN, TIMEDRIVEN
        ConvergenceTolerance: Double;
        ConvergedFlag: Boolean;
        DefaultControlMode: Integer;    // EVENTDRIVEN, TIMEDRIVEN
        DefaultLoadModel: Integer;     // 1=POWERFLOW  2=ADMITTANCE
        DoAllHarmonics: Boolean;
        DynamicsAllowed: Boolean;
        DynaVars: TDynamicsRec;
        ErrorSaved: pDoubleArray;
        FirstIteration: Boolean;
        FrequencyChanged: Boolean;  // Flag set to true if something has altered the frequency
        Fyear: Integer;
        Harmonic: Double;
        HarmonicList: pDoubleArray;
        HarmonicListSize: Integer;
        hYsystem: Nativeuint;   {Handle for main (system) Y matrix}
        hYseries: Nativeuint;   {Handle for series Y matrix}
        hY: Nativeuint;         {either hYsystem or hYseries}
        IntervalHrs: Double;   // Solution interval since last solution, hrs.
        IsDynamicModel: Boolean;
        IsHarmonicModel: Boolean;
        Iteration: Integer;
        LoadModel: Integer;        // 1=POWERFLOW  2=ADMITTANCE
        LastSolutionWasDirect: Boolean;
        LoadsNeedUpdating: Boolean;
        MaxControlIterations: Integer;
        MaxError: Double;
        MaxIterations: Integer;
        MostIterationsDone: Integer;
        NodeVbase: pDoubleArray;
        NumberOfTimes: Integer;  // Number of times to solve
        PreserveNodeVoltages: Boolean;
        RandomType: Integer;     //0 = none; 1 = gaussian; 2 = UNIFORM
        SeriesYInvalid: Boolean;
        SolutionCount: Integer;  // Counter incremented for each solution
        SolutionInitialized: Boolean;
        SystemYChanged: Boolean;
        UseAuxCurrents: Boolean;
        VmagSaved: pDoubleArray;
        VoltageBaseChanged: Boolean;

       {Voltage and Current Arrays}
        NodeV: pNodeVArray;    // Main System Voltage Array   allows NodeV^[0]=0
        Currents: pNodeVArray;      // Main System Currents Array

//****************************Timing variables**********************************
        SolveStartTime: Int64;
        SolveEndtime: Int64;
        GStartTime: Int64;
        Gendtime: Int64;
        LoopEndtime: Int64;
        Total_Time_Elapsed: Double;
        Solve_Time_Elapsed: Double;
        Total_Solve_Time_Elapsed: Double;
        Step_Time_Elapsed: Double;
//******************************************************************************

        constructor Create(ParClass: TDSSClass; const solutionname: String);
        destructor Destroy; OVERRIDE;

        procedure ZeroAuxCurrents;
        function SolveZeroLoadSnapShot: Integer;
        procedure DoPFLOWsolution;

        procedure Solve;                // Main Solution dispatch
        procedure SnapShotInit;
        function SolveSnap: Integer;    // solve for now once
        function SolveDirect: Integer;  // solve for now once, direct solution
        function SolveYDirect: Integer; // Similar to SolveDirect; used for initialization
        function SolveCircuit: Integer; // SolveSnap sans control iteration
        procedure CheckControls;       // Snapshot checks with matrix rebuild
        procedure SampleControlDevices;
        procedure DoControlActions;
        procedure Sample_DoControlActions;    // Sample and Do
        procedure Check_Fault_Status;

        procedure SetGeneratorDispRef;
        procedure SetVoltageBases;

        procedure SaveVoltages;
        procedure UpdateVBus; // updates voltages for each bus    from NodeV
        procedure RestoreNodeVfromVbus;  // opposite   of updatebus

        function VDiff(i, j: Integer): Complex;  // Difference between two node voltages

        procedure InitPropertyValues(ArrayOffset: Integer); OVERRIDE;
        procedure DumpProperties(var F: TextFile; Complete: Boolean); OVERRIDE;
        procedure WriteConvergenceReport(const Fname: String);
        procedure Update_dblHour;
        procedure Increment_time;

        procedure UpdateLoopTime;

        property Mode: Integer READ dynavars.SolutionMode WRITE Set_Mode;
        property Frequency: Double READ FFrequency WRITE Set_Frequency;
        property Year: Integer READ FYear WRITE Set_Year;
        property Time_Solve: Double READ Solve_Time_Elapsed;
        property Time_TotalSolve: Double READ Total_Solve_Time_Elapsed;
        property Time_Step: Double READ Step_Time_Elapsed;     // Solve + sample
        property Total_Time: Double READ Total_Time_Elapsed WRITE Set_Total_Time;

 // Procedures that use to be private before 01-20-2016

        procedure AddInAuxCurrents(SolveType: Integer);
        function SolveSystem(V: pNodeVArray): Integer;
        procedure GetPCInjCurr;
        procedure GetSourceInjCurrents;
        procedure ZeroInjCurr;

    end;


{==========================================================================}


var
    ActiveSolutionObj: TSolutionObj;


implementation

uses
    SolutionAlgs,
    DSSClassDefs,
    DSSGlobals,
    CmdForms,
    CktElement,
    ControlElem,
    Fault,
    AutoAdd,
    YMatrix,
    ParserDel,
    Generator,
{$IFDEF DLL_ENGINE}
    ImplGlobals,  // to fire events
{$ENDIF}
    Math,
    Circuit,
    Utilities,
    KLUSolve;

const
    NumPropsThisClass = 1;

{$DEFINE debugtrace}

{$UNDEF debugtrace}  {turn it off  delete this line to activate debug trace}

{$IFDEF debugtrace}
var
    FDebug: TextFile;

{$ENDIF}


// ===========================================================================================
constructor TDSSSolution.Create;  // Collection of all solution objects
begin
    inherited Create;
    Class_Name := 'Solution';
    DSSClassType := DSS_OBJECT + HIDDEN_ELEMENT;

    ActiveElement := 0;

    DefineProperties;

    CommandList := TCommandList.Create(Slice(PropertyName^, NumProperties));
    CommandList.Abbrev := TRUE;


end;

// ===========================================================================================
destructor TDSSSolution.Destroy;

begin
    // ElementList and  CommandList freed in inherited destroy
    inherited Destroy;

end;

// ===========================================================================================
procedure TDSSSolution.DefineProperties;
begin

    Numproperties := NumPropsThisClass;
    CountProperties;   // Get inherited property count
    AllocatePropertyArrays;


     // Define Property names
    PropertyName[1] := '-------';


     // define Property help values
    PropertyHelp[1] := 'Use Set Command to set Solution properties.';


    ActiveProperty := NumPropsThisClass;
    inherited DefineProperties;  // Add defs of inherited properties to bottom of list

end;


// ===========================================================================================
function TDSSSolution.NewObject(const ObjName: String): Integer;
begin
    // Make a new Solution Object and add it to Solution class list
    ActiveSolutionObj := TSolutionObj.Create(Self, ObjName);
    // this one is different than the rest of the objects.
    Result := AdDobjectToList(ActiveSolutionObj);
end;

// ===========================================================================================
constructor TSolutionObj.Create(ParClass: TDSSClass; const SolutionName: String);
// ===========================================================================================
begin
    inherited Create(ParClass);
    Name := LowerCase(SolutionName);

//    i := SetLogFile ('c:\\temp\\KLU_Log.txt', 1);

    FYear := 0;
    DynaVars.intHour := 0;
    DynaVars.t := 0.0;
    DynaVars.dblHour := 0.0;
    DynaVars.tstart := 0.0;
    DynaVars.tstop := 0.0;
    //duration := 0.0;
    DynaVars.h := 0.001;  // default for dynasolve

    LoadsNeedUpdating := TRUE;
    VoltageBaseChanged := TRUE;  // Forces Building of convergence check arrays

    MaxIterations := 15;
    MaxControlIterations := 10;
    ConvergenceTolerance := 0.0001;
    ConvergedFlag := FALSE;

    IsDynamicModel := FALSE;
    IsHarmonicModel := FALSE;

    Frequency := DefaultBaseFreq;
    {Fundamental := 60.0; Moved to Circuit and used as default base frequency}
    Harmonic := 1.0;

    FrequencyChanged := TRUE;  // Force Building of YPrim matrices
    DoAllHarmonics := TRUE;
    FirstIteration := TRUE;
    DynamicsAllowed := FALSE;
    SystemYChanged := TRUE;
    SeriesYInvalid := TRUE;

    {Define default harmonic list}
    HarmonicListSize := 5;
    HarmonicList := AllocMem(SizeOf(harmonicList^[1]) * HarmonicListSize);
    HarmonicList^[1] := 1.0;
    HarmonicList^[2] := 5.0;
    HarmonicList^[3] := 7.0;
    HarmonicList^[4] := 11.0;
    HarmonicList^[5] := 13.0;

    SolutionInitialized := FALSE;
    LoadModel := POWERFLOW;
    DefaultLoadModel := LoadModel;
    LastSolutionWasDirect := FALSE;

    hYseries := 0;
    hYsystem := 0;
    hY := 0;

    NodeV := NIL;
    dV := NIL;
    Currents := NIL;
    AuxCurrents := NIL;
    VMagSaved := NIL;
    ErrorSaved := NIL;
    NodeVbase := NIL;

    UseAuxCurrents := FALSE;

    SolutionCount := 0;

    Dynavars.SolutionMode := SNAPSHOT;
    ControlMode := CTRLSTATIC;
    DefaultControlMode := ControlMode;
    Algorithm := NORMALSOLVE;

    RandomType := GAUSSIAN;  // default to gaussian
    NumberOfTimes := 100;
    IntervalHrs := 1.0;

    InitPropertyValues(0);

end;

// ===========================================================================================
destructor TSolutionObj.Destroy;
begin
    Reallocmem(AuxCurrents, 0);
    Reallocmem(Currents, 0);
    Reallocmem(dV, 0);
    Reallocmem(ErrorSaved, 0);
    Reallocmem(NodeV, 0);
    Reallocmem(NodeVbase, 0);
    Reallocmem(VMagSaved, 0);

    if hYsystem <> 0 then
        DeleteSparseSet(hYsystem);
    if hYseries <> 0 then
        DeleteSparseSet(hYseries);

//      SetLogFile ('c:\\temp\\KLU_Log.txt', 0);

    Reallocmem(HarmonicList, 0);

    inherited Destroy;
end;


// ===========================================================================================
function TDSSSolution.Edit: Integer;

begin
    Result := 0;

    ActiveSolutionObj := ActiveCircuit.Solution;

    with ActiveSolutionObj do
    begin

       // This is all we do here now...
        Solve;

    end;  {WITH}
end;


// ===========================================================================================
procedure TSolutionObj.Solve;

begin

    ActiveCircuit.Issolved := FALSE;
    SolutionWasAttempted := TRUE;

    InitProgressForm; // initialize Progress Form;

{Check of some special conditions that must be met before executing solutions}

    if ActiveCircuit.EmergMinVolts >= ActiveCircuit.NormalMinVolts then
    begin
        DoSimpleMsg('Error: Emergency Min Voltage Must Be Less Than Normal Min Voltage!' +
            CRLF + 'Solution Not Executed.', 480);
        Exit;
    end;

    if SolutionAbort then
    begin
        GlobalResult := 'Solution aborted.';
        CmdResult := SOLUTION_ABORT;
        ErrorNumber := CmdResult;
        Exit;
    end;


    try

{Main solution Algorithm dispatcher}

        with ActiveCircuit do
        begin

            case Year of
                0:
                    DefaultGrowthFactor := 1.0;    // RCD 8-17-00
            else
                DefaultGrowthFactor := IntPower(DefaultGrowthRate, (year - 1));
            end;
        end;

{$IFDEF DLL_ENGINE}
        Fire_InitControls;
{$ENDIF}

    {CheckFaultStatus;  ???? needed here??}
//     QueryPerformanceCounter(GStartTime);
        case Dynavars.SolutionMode of
            SNAPSHOT:
                SolveSnap;
            YEARLYMODE:
                SolveYearly;
            DAILYMODE:
                SolveDaily;
            DUTYCYCLE:
                SolveDuty;
            DYNAMICMODE:
                SolveDynamic;
            MONTECARLO1:
                SolveMonte1;
            MONTECARLO2:
                SolveMonte2;
            MONTECARLO3:
                SolveMonte3;
            PEAKDAY:
                SolvePeakDay;
            LOADDURATION1:
                SolveLD1;
            LOADDURATION2:
                SolveLD2;
            DIRECT:
                SolveDirect;
            MONTEFAULT:
                SolveMonteFault;  // Monte Carlo Fault Cases
            FAULTSTUDY:
                SolveFaultStudy;
            AUTOADDFLAG:
                ActiveCircuit.AutoAddObj.Solve;
            HARMONICMODE:
                SolveHarmonic;
            GENERALTIME:
                SolveGeneralTime;
            HARMONICMODET:
                SolveHarmonicT;  //Declares the Hsequential-time harmonics
        else
            DosimpleMsg('Unknown solution mode.', 481);
        end;
//     QueryPerformanceCounter(GEndTime);
        Total_Solve_Time_Elapsed := ((GEndTime - GStartTime) / CPU_Freq) * 1000000;
        Total_Time_Elapsed := Total_Time_Elapsed + Total_Solve_Time_Elapsed;
    except

        On E: Exception do
        begin
            DoSimpleMsg('Error Encountered in Solve: ' + E.Message, 482);
            SolutionAbort := TRUE;
        end;

    end;

end;

// ===========================================================================================
function TSolutionObj.Converged: Boolean;

var
    i: Integer;
    VMag: Double;

begin

// base convergence on voltage magnitude

    MaxError := 0.0;
    for i := 1 to ActiveCircuit.NumNodes do
    begin

        VMag := Cabs(NodeV^[i]);

    { If base specified, use it; otherwise go on present magnitude  }
        if NodeVbase^[i] > 0.0 then
            ErrorSaved^[i] := Abs(Vmag - VmagSaved^[i]) / NodeVbase^[i]
        else
        if Vmag <> 0.0 then
            ErrorSaved^[i] := Abs(1.0 - VmagSaved^[i] / Vmag);

        VMagSaved^[i] := Vmag;  // for next go-'round

        MaxError := Max(MaxError, ErrorSaved^[i]);  // update max error

    end;

{$IFDEF debugtrace}
    Assignfile(Fdebug, 'Debugtrace.csv');
    Append(FDebug);
    if Iteration = 1 then
    begin
        Write(Fdebug, 'Iter');
        for i := 1 to ActiveCircuit.NumNodes do
            Write(Fdebug, ', ', ActiveCircuit.Buslist.get(ActiveCircuit.MapNodeToBus^[i].BusRef), '.', ActiveCircuit.MapNodeToBus^[i].NodeNum: 0);
        Writeln(Fdebug);
    end;
              {*****}
    Write(Fdebug, Iteration: 2);
    for i := 1 to ActiveCircuit.NumNodes do
        Write(Fdebug, ', ', VMagSaved^[i]: 8: 1);
    Writeln(Fdebug);
    Write(Fdebug, 'Err');
    for i := 1 to ActiveCircuit.NumNodes do
        Write(Fdebug, ', ', Format('%-.5g', [ErrorSaved^[i]]));
    Writeln(Fdebug);
    Write(Fdebug, 'Curr');
    for i := 1 to ActiveCircuit.NumNodes do
        Write(Fdebug, ', ', Cabs(Currents^[i]): 8: 1);
    Writeln(Fdebug);
              {*****}
    CloseFile(FDebug);
{$ENDIF}
    ;

    if MaxError <= ConvergenceTolerance then
        Result := TRUE
    else
        Result := FALSE;

    ConvergedFlag := Result;
end;


// ===========================================================================================
procedure TSolutionObj.GetSourceInjCurrents;

// Add in the contributions of all source type elements to the global solution vector InjCurr

var
    pElem: TDSSCktElement;

begin

    with ActiveCircuit do
    begin

        pElem := Sources.First;
        while pElem <> NIL do
        begin
            if pElem.Enabled then
                pElem.InjCurrents; // uses NodeRef to add current into InjCurr Array;
            pElem := Sources.Next;
        end;

    end;

end;

// ===========================================================================================
procedure TSolutionObj.SetGeneratorDispRef;

// Set the global generator dispatch reference

begin
    with ActiveCircuit do
        case Dynavars.SolutionMode of

            SNAPSHOT:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor;
            YEARLYMODE:
                GeneratorDispatchReference := DefaultGrowthFactor * DefaultHourMult.re;
            DAILYMODE:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            DUTYCYCLE:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            GENERALTIME:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            DYNAMICMODE:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor;
            HARMONICMODE:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor;
            MONTECARLO1:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor;
            MONTECARLO2:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            MONTECARLO3:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            PEAKDAY:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            LOADDURATION1:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            LOADDURATION2:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
            DIRECT:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor;
            MONTEFAULT:
                GeneratorDispatchReference := 1.0;  // Monte Carlo Fault Cases solve  at peak load only base case
            FAULTSTUDY:
                GeneratorDispatchReference := 1.0;
            AUTOADDFLAG:
                GeneratorDispatchReference := DefaultGrowthFactor;   // peak load only
            HARMONICMODET:
                GeneratorDispatchReference := LoadMultiplier * DefaultGrowthFactor * DefaultHourMult.re;
        else
            DosimpleMsg('Unknown solution mode.', 483);
        end;
end;
// ===========================================================================================
procedure TSolutionObj.SetGeneratordQdV;

var
    pGen: TGeneratorObj;
    Did_One: Boolean;
    GenDispSave: Double;

begin
    Did_One := FALSE;

     // Save the generator dispatch level and set on high enough to
     // turn all generators on
    GenDispSave := ActiveCircuit.GeneratorDispatchReference;
    ActiveCircuit.GeneratorDispatchReference := 1000.0;

    with ActiveCircuit do
    begin

        pGen := Generators.First;
        while pGen <> NIL do
        begin

            if pGen.Enabled then
            begin

              // for PV generator models only ...
                if pGen.genModel = 3 then
                begin

                    pGen.InitDQDVCalc;

                   // solve at base var setting
                    Iteration := 0;
                    repeat
                        Inc(Iteration);
                        ZeroInjCurr;
                        GetSourceInjCurrents;
                        pGen.InjCurrents;   // get generator currents with nominal vars
                        SolveSystem(NodeV);
                    until Converged or (Iteration >= Maxiterations);

                    pGen.RememberQV;  // Remember Q and V
                    pGen.BumpUpQ;

                   // solve after changing vars
                    Iteration := 0;
                    repeat
                        Inc(Iteration);
                        ZeroInjCurr;
                        GetSourceInjCurrents;
                        pGen.InjCurrents;   // get generator currents with nominal vars
                        SolveSystem(NodeV);
                    until Converged or (Iteration >= Maxiterations);

                    pGen.CalcdQdV; // bssed on remembered Q and V and present values of same
                    pGen.ResetStartPoint;

                    Did_One := TRUE;
                end;
            end;
            pGen := Generators.Next;
        end;

    end;

     // Restore generator dispatch reference
    ActiveCircuit.GeneratorDispatchReference := GenDispSave;
    try
        if Did_One        // Reset Initial Solution
        then
            SolveZeroLoadSnapShot;
    except
        ON E: EEsolv32Problem do
        begin
            DoSimpleMsg('From SetGenerator DQDV, SolveZeroLoadSnapShot: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7071);
            raise ESolveError.Create('Aborting');
        end;
    end;

end;

// ===========================================================================================
procedure TSolutionObj.DoNormalSolution;

{ Normal fixed-point solution

   Vn+1 = [Y]-1 Injcurr

   Where Injcurr includes only PC elements  (loads, generators, etc.)
   i.e., the shunt elements.

   Injcurr are the current injected INTO the NODE
        (need to reverse current direction for loads)
}

begin


    Iteration := 0;

 {**** Main iteration loop ****}
    with ActiveCircuit do
        repeat
            Inc(Iteration);

            if LogEvents then
                LogThisEvent('Solution Iteration ' + IntToStr(Iteration));

    { Get injcurrents for all PC devices  }
            ZeroInjCurr;
            GetSourceInjCurrents;  // sources
            GetPCInjCurr;  // Get the injection currents from all the power conversion devices and feeders

       // The above call could change the primitive Y matrix, so have to check
            if SystemYChanged then
                BuildYMatrix(WHOLEMATRIX, FALSE);  // Does not realloc V, I

            if UseAuxCurrents then
                AddInAuxCurrents(NORMALSOLVE);

      // Solve for voltages                      {Note:NodeV[0] = 0 + j0 always}
            if LogEvents then
                LogThisEvent('Solve Sparse Set DoNormalSolution ...');
            SolveSystem(NodeV);
            LoadsNeedUpdating := FALSE;

        until (Converged and (Iteration > 1)) or (Iteration >= MaxIterations);


end;


// ===========================================================================================
procedure TSolutionObj.DoNewtonSolution;

{ Newton Iteration

   Vn+1 =  Vn - [Y]-1 Termcurr

   Where Termcurr includes currents from all elements and we are
   attempting to get the  currents to sum to zero at all nodes.

   Termcurr is the sum of all currents going INTO THE TERMINALS of
   the elements.

   For PD Elements, Termcurr = Yprim*V

   For Loads, Termcurr = (Sload/V)*
   For Generators, Termcurr = -(Sgen/V)*

}

var
    i: Integer;

begin

    with ActiveCircuit do
    begin
        ReAllocMem(dV, SizeOf(dV^[1]) * (NumNodes + 1)); // Make sure this is always big enough

        if ControlIteration = 1 then
            GetPCInjCurr;  // Update the load multipliers for this solution

        Iteration := 0;
        repeat
            Inc(Iteration);
            Inc(SolutionCount);    // SumAllCurrents Uses ITerminal  So must force a recalc

        // Get sum of currents at all nodes for all  devices
            ZeroInjCurr;
            SumAllCurrents;

           // Call to current calc could change YPrim for some devices
            if SystemYChanged then
                BuildYMatrix(WHOLEMATRIX, FALSE);   // Does not realloc V, I

            if UseAuxCurrents then
                AddInAuxCurrents(NEWTONSOLVE);

        // Solve for change in voltages
            SolveSystem(dV);

            LoadsNeedUpdating := FALSE;

         // Compute new guess at voltages
            for i := 1 to NumNodes do     // 0 node is always 0
                with NodeV^[i] do
                begin
                    re := re - dV^[i].re;
                    im := im - dV^[i].im;
                end;

        until (Converged and (Iteration > 1)) or (Iteration >= MaxIterations);
    end;
end;


// ===========================================================================================
procedure TSolutionObj.DoPFLOWsolution;


begin

    Inc(SolutionCount);    //Unique number for this solution

    if VoltageBaseChanged then
        InitializeNodeVbase; // for convergence test

    if not SolutionInitialized then
    begin

        if ActiveCircuit.LogEvents then
            LogThisEvent('Initializing Solution');
        try
        //SolveZeroLoadSnapShot;
            SolveYDirect;  // 8-14-06 This should give a better answer than zero load snapshot
        except
            ON E: EEsolv32Problem do
            begin
                DoSimpleMsg('From DoPFLOWsolution.SolveYDirect: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7072);
                raise ESolveError.Create('Aborting');
            end;
        end;
        if SolutionAbort then
            Exit; // Initialization can result in abort

        try
            SetGeneratordQdV;  // Set dQdV for Model 3 generators
        except
            ON E: EEsolv32Problem do
            begin
                DoSimpleMsg('From DoPFLOWsolution.SetGeneratordQdV: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7073);
                raise ESolveError.Create('Aborting');
            end;
        end;

        { The above resets the active sparse set to hY }
        SolutionInitialized := TRUE;
    end;


    case Algorithm of
        NORMALSOLVE:
            DoNormalSolution;
        NEWTONSOLVE:
            DoNewtonSolution;
    end;

    ActiveCircuit.Issolved := ConvergedFlag;
    LastSolutionWasDirect := FALSE;

end;

// ===========================================================================================
function TSolutionObj.SolveZeroLoadSnapShot: Integer;

// Solve without load for initialization purposes;

begin
    Result := 0;

    if SystemYChanged or SeriesYInvalid then
        BuildYMatrix(SERIESONLY, TRUE);   // Side Effect: Allocates V

    Inc(SolutionCount);    //Unique number for this solution

    ZeroInjCurr;   // Side Effect: Allocates InjCurr
    GetSourceInjCurrents;    // Vsource, Isource and VCCS only

    {Make the series Y matrix the active matrix}
    if hYseries = 0 then
        raise EEsolv32Problem.Create('Series Y matrix not built yet in SolveZeroLoadSnapshot.');
    hY := hYseries;

    if ActiveCircuit.LogEvents then
        LogThisEvent('Solve Sparse Set ZeroLoadSnapshot ...');

    SolveSystem(NodeV);  // also sets voltages in radial part of the circuit if radial solution

    { Reset the main system Y as the solution matrix}
    if (hYsystem > 0) and not SolutionAbort then
        hY := hYsystem;
end;

// ===========================================================================================
procedure TSolutionObj.SetVoltageBases;

// Set voltage bases using voltage at first node (phase) of a bus

var
    i: Integer;
    bZoneCalc, bZoneLock: Boolean;

begin

    try
    // don't allow the meter zones to auto-build in this load flow solution, because the
    // voltage bases are not available yet

        bZoneCalc := ActiveCircuit.MeterZonesComputed;
        bZoneLock := ActiveCircuit.ZonesLocked;
        ActiveCircuit.MeterZonesComputed := TRUE;
        ActiveCircuit.ZonesLocked := TRUE;

        SolveZeroLoadSnapShot;

        with ActiveCircuit do
            for i := 1 to NumBuses do
                with Buses^[i] do
                    kVBase := NearestBasekV(Cabs(NodeV^[GetRef(1)]) * 0.001732) / SQRT3;  // l-n base kV

        InitializeNodeVbase;      // for convergence test

        ActiveCircuit.Issolved := TRUE;

    // now build the meter zones
        ActiveCircuit.MeterZonesComputed := bZoneCalc;
        ActiveCircuit.ZonesLocked := bZoneLock;
        ActiveCircuit.DoResetMeterZones;

    except
        ON E: EEsolv32Problem do
        begin
            DoSimpleMsg('From SetVoltageBases.SolveZeroLoadSnapShot: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7075);
            raise ESolveError.Create('Aborting');
        end;
    end;

end;

procedure TSolutionObj.SnapShotInit;

begin

    SetGeneratorDispRef;
    ControlIteration := 0;
    ControlActionsDone := FALSE;
    MostIterationsDone := 0;
    LoadsNeedUpdating := TRUE;  // Force the loads to update at least once

end;

procedure TSolutionObj.CheckControls;

begin
    if ControlIteration < MaxControlIterations then
    begin
        if ConvergedFlag then
        begin
            if ActiveCircuit.LogEvents then
                LogThisEvent('Control Iteration ' + IntToStr(ControlIteration));
            Sample_DoControlActions;
            Check_Fault_Status;
        end
        else
            ControlActionsDone := TRUE; // Stop solution process if failure to converge
    end;

    if SystemYChanged then
        BuildYMatrix(WHOLEMATRIX, FALSE); // Rebuild Y matrix, but V stays same
end;

// ===========================================================================================
function TSolutionObj.SolveSnap: Integer;  // solve for now once

var
    TotalIterations: Integer;

begin
    SnapShotInit;
    TotalIterations := 0;
//   QueryPerformanceCounter(SolveStartTime);
    repeat

        Inc(ControlIteration);

        Result := SolveCircuit;  // Do circuit solution w/o checking controls

       {Now Check controls}
{$IFDEF DLL_ENGINE}
        Fire_CheckControls;
{$ENDIF}
        CheckControls;

       {For reporting max iterations per control iteration}
        if Iteration > MostIterationsDone then
            MostIterationsDone := Iteration;

        TotalIterations := TotalIterations + Iteration;

    until ControlActionsDone or (ControlIteration >= MaxControlIterations);

    if not ControlActionsDone and (ControlIteration >= MaxControlIterations) then
    begin
        DoSimpleMsg('Warning Max Control Iterations Exceeded. ' + CRLF + 'Tip: Show Eventlog to debug control settings.', 485);
        SolutionAbort := TRUE;   // this will stop this message in dynamic power flow modes
    end;

    if ActiveCircuit.LogEvents then
        LogThisEvent('Solution Done');

{$IFDEF DLL_ENGINE}
    Fire_StepControls;
{$ENDIF}
//   QueryPerformanceCounter(SolveEndtime);
    Solve_Time_Elapsed := ((SolveEndtime - SolveStartTime) / CPU_Freq) * 1000000;
    Iteration := TotalIterations;  { so that it reports a more interesting number }

end;

// ===========================================================================================
function TSolutionObj.SolveDirect: Integer;  // solve for now once, direct solution

begin
    Result := 0;

    LoadsNeedUpdating := TRUE;  // Force possible update of loads and generators
//   QueryPerformanceCounter(SolveStartTime);

    if SystemYChanged then
        BuildYMatrix(WHOLEMATRIX, TRUE);   // Side Effect: Allocates V

    Inc(SolutionCount);   // Unique number for this solution

    ZeroInjCurr;   // Side Effect: Allocates InjCurr
    GetSourceInjCurrents;

   // Pick up PCELEMENT injections for Harmonics mode and Dynamics mode
   // Ignore these injections for powerflow; Use only admittance in Y matrix
    if IsDynamicModel or IsHarmonicModel then
        GetPCInjCurr;

    if SolveSystem(NodeV) = 1   // Solve with Zero injection current
    then
    begin
        ActiveCircuit.IsSolved := TRUE;
        ConvergedFlag := TRUE;
    end;

//   QueryPerformanceCounter(SolveEndtime);
    Solve_Time_Elapsed := ((SolveEndtime - SolveStartTime) / CPU_Freq) * 1000000;
    Total_Time_Elapsed := Total_Time_Elapsed + Solve_Time_Elapsed;
    Iteration := 1;
    LastSolutionWasDirect := TRUE;

end;


function TSolutionObj.SolveCircuit: Integer;
begin

    Result := 0;
    if LoadModel = ADMITTANCE then
        try
            SolveDirect     // no sense horsing around when it's all admittance
        except
            ON E: EEsolv32Problem do
            begin
                DoSimpleMsg('From SolveSnap.SolveDirect: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7075);
                raise ESolveError.Create('Aborting');
            end;
        end
    else
    begin
        try
            if SystemYChanged then
                BuildYMatrix(WHOLEMATRIX, TRUE);   // Side Effect: Allocates V
            DoPFLOWsolution;
        except
            ON E: EEsolv32Problem do
            begin
                DoSimpleMsg('From SolveSnap.DoPflowSolution: ' + CRLF + E.Message + CheckYMatrixforZeroes, 7074);
                raise ESolveError.Create('Aborting');
            end;
        end
    end;

end;

// ===========================================================================================
procedure TSolutionObj.ZeroInjCurr;
var
    I: Integer;
begin
    for i := 0 to ActiveCircuit.NumNodes do
        Currents^[i] := CZERO;
end;

//----------------------------------------------------------------------------
function TDSSSolution.Init(Handle: Integer): Integer;

begin
    DoSimpleMsg('Need to implement TSolution.Init', -1);
    Result := 0;
end;


// ===========================================================================================
procedure TSolutionObj.GetPCInjCurr;
var
    pElem: TDSSCktElement;

{ Get inj currents from all enabled PC devices }

begin

    with ActiveCircuit do
    begin
        pElem := PCElements.First;
        while pElem <> NIL do
        begin
            with pElem do
                if Enabled then
                    InjCurrents; // uses NodeRef to add current into InjCurr Array;
            pElem := PCElements.Next;
        end;
    end;

end;

procedure TSolutionObj.DumpProperties(var F: TextFile; complete: Boolean);

var
    i, j: Integer;

   // for dumping the matrix in compressed columns
    p: Longword;
    hY, nBus, nNZ: Longword;
    ColPtr, RowIdx: array of Longword;
    cVals: array of Complex;
begin

    Writeln(F, '! OPTIONS');

  // Inherited DumpProperties(F,Complete);

    Writeln(F, '! NumNodes = ', ActiveCircuit.NumNodes: 0);

    {WITH ParentClass Do
     FOR i := 1 to NumProperties Do
     Begin
        Writeln(F,'Set ',PropertyName^[i],'=',PropertyValue^[i]);
     End;
     }
    Writeln(F, 'Set Mode=', GetSolutionModeID);
    Writeln(F, 'Set ControlMode=', GetControlModeID);
    Writeln(F, 'Set Random=', GetRandomModeID);
    Writeln(F, 'Set hour=', DynaVars.intHour: 0);
    Writeln(F, 'Set sec=', Format('%-g', [DynaVars.t]));
    Writeln(F, 'Set year=', Year: 0);
    Writeln(F, 'Set frequency=', Format('%-g', [Frequency]));
    Writeln(F, 'Set stepsize=', Format('%-g', [DynaVars.h]));
    Writeln(F, 'Set number=', NumberOfTimes: 0);
    Writeln(F, 'Set circuit=', ActiveCircuit.Name);
    Writeln(F, 'Set editor=', DefaultEditor);
    Writeln(F, 'Set tolerance=', Format('%-g', [ConvergenceTolerance]));
    Writeln(F, 'Set maxiter=', MaxIterations: 0);
    Writeln(F, 'Set loadmodel=', GetLoadModel);

    Writeln(F, 'Set loadmult=', Format('%-g', [ActiveCircuit.LoadMultiplier]));
    Writeln(F, 'Set Normvminpu=', Format('%-g', [ActiveCircuit.NormalMinVolts]));
    Writeln(F, 'Set Normvmaxpu=', Format('%-g', [ActiveCircuit.NormalMaxVolts]));
    Writeln(F, 'Set Emergvminpu=', Format('%-g', [ActiveCircuit.EmergMinVolts]));
    Writeln(F, 'Set Emergvmaxpu=', Format('%-g', [ActiveCircuit.EmergMaxVolts]));
    Writeln(F, 'Set %mean=', Format('%-.4g', [ActiveCircuit.DefaultDailyShapeObj.Mean * 100.0]));
    Writeln(F, 'Set %stddev=', Format('%-.4g', [ActiveCircuit.DefaultDailyShapeObj.StdDev * 100.0]));
    Writeln(F, 'Set LDCurve=', ActiveCircuit.LoadDurCurve);  // Load Duration Curve
    Writeln(F, 'Set %growth=', Format('%-.4g', [((ActiveCircuit.DefaultGrowthRate - 1.0) * 100.0)]));  // default growth rate
    with ActiveCircuit.AutoAddObj do
    begin
        Writeln(F, 'Set genkw=', Format('%-g', [GenkW]));
        Writeln(F, 'Set genpf=', Format('%-g', [GenPF]));
        Writeln(F, 'Set capkvar=', Format('%-g', [Capkvar]));
        Write(F, 'Set addtype=');
        case Addtype of
            GENADD:
                Writeln(F, 'generator');
            CAPADD:
                Writeln(F, 'capacitor');
        end;
    end;
    Write(F, 'Set allowduplicates=');
    if ActiveCircuit.DuplicatesAllowed then
        Writeln(F, 'Yes')
    else
        Writeln(F, 'No');
    Write(F, 'Set zonelock=');
    if ActiveCircuit.ZonesLocked then
        Writeln(F, 'Yes')
    else
        Writeln(F, 'No');
    Writeln(F, 'Set ueweight=', ActiveCircuit.UEWeight: 8: 2);
    Writeln(F, 'Set lossweight=', ActiveCircuit.LossWeight: 8: 2);
    Writeln(F, 'Set ueregs=', IntArraytoString(ActiveCircuit.UEregs, ActiveCircuit.NumUERegs));
    Writeln(F, 'Set lossregs=', IntArraytoString(ActiveCircuit.Lossregs, ActiveCircuit.NumLossRegs));
    Write(F, 'Set voltagebases=(');  //  changes the default voltage base rules
    i := 1;
    with ActiveCircuit do
        while LegalVoltageBases^[i] > 0.0 do
        begin
            Write(F, LegalVoltageBases^[i]: 10: 2);
            inc(i);
        end;
    Writeln(F, ')');
    case Algorithm of
        NORMALSOLVE:
            Writeln(F, 'Set algorithm=normal');
        NEWTONSOLVE:
            Writeln(F, 'Set algorithm=newton');
    end;
    Write(F, 'Set Trapezoidal=');
    if ActiveCircuit.TrapezoidalIntegration then
        Writeln(F, 'yes')
    else
        Writeln(F, 'no');
    Writeln(F, 'Set genmult=', Format('%-g', [ActiveCircuit.GenMultiplier]));

    Writeln(F, 'Set Basefrequency=', Format('%-g', [ActiveCircuit.Fundamental]));

    Write(F, 'Set harmonics=(');  //  changes the default voltage base rules
    if DoAllHarmonics then
        Write(F, 'ALL')
    else
        for i := 1 to HarmonicListSize do
            Write(F, Format('%-g, ', [HarmonicList^[i]]));
    Writeln(F, ')');
    Writeln(F, 'Set maxcontroliter=', MaxControlIterations: 0);
    Writeln(F);

    if Complete then
        with ActiveCircuit do
        begin

            hY := Solution.hY;

      // get the compressed columns out of KLU
            FactorSparseMatrix(hY); // no extra work if already done
            GetNNZ(hY, @nNZ);
            GetSize(hY, @nBus);
            SetLength(ColPtr, nBus + 1);
            SetLength(RowIdx, nNZ);
            SetLength(cVals, nNZ);
            GetCompressedMatrix(hY, nBus + 1, nNZ, @ColPtr[0], @RowIdx[0], @cVals[0]);

            Writeln(F, 'System Y Matrix (Lower Triangle by Columns)');
            Writeln(F);
            Writeln(F, '  Row  Col               G               B');
            Writeln(F);

      // traverse the compressed column format
            for j := 0 to nBus - 1 do
            begin /// the zero-based column
                for p := ColPtr[j] to ColPtr[j + 1] - 1 do
                begin
                    i := RowIdx[p];  // the zero-based row
                    Writeln(F, Format('[%4d,%4d] = %12.5g + j%12.5g', [i + 1, j + 1, cVals[p].re, cVals[p].im]));
                end;
            end;
        end;
end;

function TSolutionObj.VDiff(i, j: Integer): Complex;

begin
    Result := Csub(NodeV^[i], NodeV^[j]);  // V1-V2
end;


procedure TSolutionObj.WriteConvergenceReport(const Fname: String);
var
    i: Integer;
    F: TextFile;
begin
    try
        Assignfile(F, Fname);
        ReWrite(F);

        Writeln(F);
        Writeln(F, '-------------------');
        Writeln(F, 'Convergence Report:');
        Writeln(F, '-------------------');
        Writeln(F, '"Bus.Node", "Error", "|V|","Vbase"');
        with ActiveCircuit do
            for i := 1 to NumNodes do
                with MapNodeToBus^[i] do
                begin
                    Write(F, '"', pad((BusList.Get(Busref) + '.' + IntToStr(NodeNum) + '"'), 18));
                    Write(F, ', ', ErrorSaved^[i]: 10: 5);
                    Write(F, ', ', VmagSaved^[i]: 14);
                    Write(F, ', ', NodeVbase^[i]: 14);
                    Writeln(F);
                end;

        Writeln(F);
        Writeln(F, 'Max Error = ', MaxError: 10: 5);

    finally

        CloseFile(F);
        FireOffEditor(Fname);

    end;

end;

// =========================================================================================== =
procedure TSolutionObj.SumAllCurrents;

var
    pelem: TDSSCktElement;

begin
    with  ActiveCircuit do
    begin
        pelem := CktElements.First;
        while pelem <> NIL do
        begin
            pelem.SumCurrents;   // sum terminal currents into system Currents Array
            pelem := CktElements.Next;
        end;
    end;
end;

// =========================================================================================== =
procedure TSolutionObj.DoControlActions;
var
    XHour: Integer;
    XSec: Double;
begin
    with ActiveCircuit do
    begin
        case ControlMode of

            CTRLSTATIC:
            begin  //  execute the nearest set of control actions but leaves time where it is
                if ControlQueue.IsEmpty then
                    ControlActionsDone := TRUE
                else
                    ControlQueue.DoNearestActions(xHour, XSec); // ignore time advancement
            end;
            EVENTDRIVEN:
            begin  //  execute the nearest set of control actions and advance time to that time
                 // **** Need to update this to set the "Intervalhrs" variable for EnergyMeters for Event-Driven Simulation ****
                if not ControlQueue.DoNearestActions(DynaVars.intHour, DynaVars.t) // these arguments are var type
                then
                    ControlActionsDone := TRUE;// Advances time to the next event
            end;
            TIMEDRIVEN:
            begin   // Do all actions having an action time <= specified time
                if not ControlQueue.DoActions(DynaVars.intHour, DynaVars.t) then
                    ControlActionsDone := TRUE;
            end;

        end;
    end;

end;

// =========================================================================================== =
procedure TSolutionObj.SampleControlDevices;

var
    ControlDevice: TControlElem;

begin
    with ActiveCircuit do
    begin
        ControlDevice := NIL;
        try
            // Sample all controls and set action times in control Queue
            ControlDevice := DSSControls.First;
            while ControlDevice <> NIL do
            begin
                if ControlDevice.Enabled then
                    ControlDevice.Sample;
                ControlDevice := DSSControls.Next;
            end;

        except
            On E: Exception do
            begin
                DoSimpleMsg(Format('Error Sampling Control Device "%s.%s" %s  Error = %s', [ControlDevice.ParentClass.Name, ControlDevice.Name, CRLF, E.message]), 484);
                raise EControlProblem.Create('Solution aborted.');
            end;
        end;
    end;

end;

// =========================================================================================== =
procedure TSolutionObj.Sample_DoControlActions;


begin

    if ControlMode = CONTROLSOFF then
        ControlActionsDone := TRUE
    else
    begin

        SampleControlDevices;
        DoControlActions;

     {This variable lets control devices know the bus list has changed}
        ActiveCircuit.Control_BusNameRedefined := FALSE;  // Reset until next change
    end;

end;

procedure TSolutionObj.Set_Mode(const Value: Integer);


begin

    DynaVars.intHour := 0;
    DynaVars.t := 0.0;
    Update_dblHour;
    ActiveCircuit.TrapezoidalIntegration := FALSE;

    if not OK_for_Dynamics(Value) then
        Exit;
    if not OK_for_Harmonics(Value) then
        Exit;

    Dynavars.SolutionMode := Value;

    ControlMode := DefaultControlMode;   // Revert to default mode
    LoadModel := DefaultLoadModel;

    IsDynamicModel := FALSE;
    IsHarmonicModel := FALSE;

    SolutionInitialized := FALSE;   // reinitialize solution when mode set (except dynamics)
    PreserveNodeVoltages := FALSE;  // don't do this unless we have to

   // Reset defaults for solution modes
    case Dynavars.SolutionMode of

        PEAKDAY,
        DAILYMODE:
        begin
            DynaVars.h := 3600.0;
            NumberOfTimes := 24;
        end;
        SNAPSHOT:
        begin
            IntervalHrs := 1.0;
            NumberOfTimes := 1;
        end;
        YEARLYMODE:
        begin
            IntervalHrs := 1.0;
            DynaVars.h := 3600.0;
            NumberOfTimes := 8760;
        end;
        DUTYCYCLE:
        begin
            DynaVars.h := 1.0;
            ControlMode := TIMEDRIVEN;
        end;
        DYNAMICMODE:
        begin
            DynaVars.h := 0.001;
            ControlMode := TIMEDRIVEN;
            IsDynamicModel := TRUE;
            PreserveNodeVoltages := TRUE;  // need to do this in case Y changes during this mode
        end;
        GENERALTIME:
        begin
            IntervalHrs := 1.0;
            DynaVars.h := 3600.0;
            NumberOfTimes := 1;  // just one time step per Solve call expected
        end;
        MONTECARLO1:
        begin
            IntervalHrs := 1.0;
        end;
        MONTECARLO2:
        begin
            DynaVars.h := 3600.0;
        end;
        MONTECARLO3:
        begin
            IntervalHrs := 1.0;
        end;
        MONTEFAULT:
        begin
            IsDynamicModel := TRUE;
        end;
        FAULTSTUDY:
        begin
            IsDynamicModel := TRUE;
        end;
        LOADDURATION1:
        begin
            DynaVars.h := 3600.0;
            ActiveCircuit.TrapezoidalIntegration := TRUE;
        end;
        LOADDURATION2:
        begin
            DynaVars.intHour := 1;
            ActiveCircuit.TrapezoidalIntegration := TRUE;
        end;
        AUTOADDFLAG:
        begin
            IntervalHrs := 1.0;
            ActiveCircuit.AutoAddObj.ModeChanged := TRUE;
        end;
        HARMONICMODE:
        begin
            ControlMode := CONTROLSOFF;
            IsHarmonicModel := TRUE;
            LoadModel := ADMITTANCE;
            PreserveNodeVoltages := TRUE;  // need to do this in case Y changes during this mode
        end;
        HARMONICMODET:
        begin
            IntervalHrs := 1.0;
            DynaVars.h := 3600.0;
            NumberOfTimes := 1;
            ControlMode := CONTROLSOFF;
            IsHarmonicModel := TRUE;
            LoadModel := ADMITTANCE;
            PreserveNodeVoltages := TRUE;  // need to do this in case Y changes during this mode
        end;
    end;

   {Moved here 9-8-2007 so that mode is changed before reseting monitors, etc.}

   // Reset Meters and Monitors
    MonitorClass.ResetAll;
    EnergyMeterClass.ResetAll;
    DoResetFaults;
    DoResetControls;

end;

procedure TSolutionObj.AddInAuxCurrents(SolveType: Integer);

begin
    {FOR i := 1 to ActiveCircuit.NumNodes Do Caccum(Currents^[i], AuxCurrents^[i]);}
    // For Now, only AutoAdd Obj uses this

    if Dynavars.SolutionMode = AUTOADDFLAG then
        ActiveCircuit.AutoAddObj.AddCurrents(SolveType);

end;

procedure TSolutionObj.ZeroAuxCurrents;
var
    i: Integer;
begin
    for i := 1 to ActiveCircuit.NumNodes do
        AuxCurrents^[i] := CZERO;
end;

procedure TSolutionObj.Check_Fault_Status;

var
    pFault: TFaultOBj;

begin
    with ActiveCircuit do
    begin

        pFault := TFaultObj(Faults.First);
        while pFault <> NIL do
        begin
            pFault.CheckStatus(ControlMode);
            pFault := TFaultObj(Faults.Next);
        end;

    end;  {End With}
end;


{ This procedure is called for Solve Direct and any other solution method
  that does not get the injection currents for PC elements normally. In Dynamics mode,
  Generators are voltage sources ...

Procedure TSolutionObj.GetMachineInjCurrents;

Var
  pElem:TDSSCktElement;

begin
     // do machines in Dynamics Mode
     IF   IsDynamicModel THEN
      With ActiveCircuit DO  Begin

         pElem := Generators.First;
         WHILE pElem<>nil Do Begin
             IF pElem.Enabled THEN pElem.InjCurrents; // uses NodeRef to add current into InjCurr Array;
             pElem := Generators.Next;
         End;

       End;

end;
}

function TSolutionObj.OK_for_Dynamics(const Value: Integer): Boolean;

var
    ValueIsDynamic: Boolean;

begin

    Result := TRUE;

    case Value of
        MONTEFAULT,
        DYNAMICMODE,
        FAULTSTUDY:
            ValueIsDynamic := TRUE;
    else
        ValueIsDynamic := FALSE;
    end;

   {When we go in and out of Dynamics mode, we have to do some special things}
    if IsDynamicModel and not ValueIsDynamic then
        InvalidateAllPCELEMENTS;  // Force Recomp of YPrims when we leave Dynamics mode

    if not IsDynamicModel and ValueIsDynamic then
    begin   // see if conditions right for going into dynamics

        if ActiveCircuit.IsSolved then
            CalcInitialMachineStates   // set state variables for machines (loads and generators)
        else
        begin
           {Raise Error Message if not solved}
            DoSimpleMsg('Circuit must be solved in a non-dynamic mode before entering Dynamics or Fault study modes!' + CRLF +
                'If you attempted to solve, then the solution has not yet converged.', 486);
            if In_ReDirect then
                Redirect_Abort := TRUE;  // Get outta here
            Result := FALSE;
        end;
    end;

end;

function TSolutionObj.OK_for_Harmonics(const Value: Integer): Boolean;

 {When we go in and out of Harmonics mode, we have to do some special things}
begin

    Result := TRUE;

    if IsHarmonicModel and not ((Value = HARMONICMODE) or (Value = HARMONICMODET)) then
    begin
        InvalidateAllPCELEMENTS;  // Force Recomp of YPrims when we leave Harmonics mode
        Frequency := ActiveCircuit.Fundamental;   // Resets everything to norm
    end;

    if not IsHarmonicModel and ((Value = HARMONICMODE) or (Value = HARMONICMODET)) then
    begin   // see if conditions right for going into Harmonics

        if (ActiveCircuit.IsSolved) and (Frequency = ActiveCircuit.Fundamental) then
        begin
            if not InitializeForHarmonics   // set state variables for machines (loads and generators) and sources
            then
            begin
                Result := FALSE;
                if In_ReDirect then
                    Redirect_Abort := TRUE;  // Get outta here
            end;
        end
        else
        begin

            DoSimpleMsg('Circuit must be solved in a fundamental frequency power flow or direct mode before entering Harmonics mode!', 487);
            if In_ReDirect then
                Redirect_Abort := TRUE;  // Get outta here
            Result := FALSE;
        end;
    end;

end;

procedure TSolutionObj.Set_Frequency(const Value: Double);
begin
    if FFrequency <> Value then
    begin
        FrequencyChanged := TRUE;  // Force Rebuild of all Y Primitives
        SystemYChanged := TRUE;  // Force rebuild of System Y
    end;

    FFrequency := Value;
    if ActiveCircuit <> NIL then
        Harmonic := FFrequency / ActiveCircuit.Fundamental;  // Make Sure Harmonic stays in synch
end;

procedure TSolutionObj.Increment_time;
begin
    with Dynavars do
    begin
        t := t + h;
        while t >= 3600.0 do
        begin
            Inc(intHour);
            t := t - 3600.0;
        end;
        Update_dblHour;
    end;
end;

procedure TSolutionObj.InitPropertyValues(ArrayOffset: Integer);
begin

    PropertyValue[1] := '';

    inherited InitPropertyValues(NumPropsThisClass);

end;

procedure TSolutionObj.Set_Year(const Value: Integer);
begin
    if DIFilesAreOpen then
        EnergyMeterClass.CloseAllDIFiles;
    FYear := Value;
    DynaVars.intHour := 0;  {Change year, start over}
    Dynavars.t := 0.0;
    Update_dblHour;
    EnergyMeterClass.ResetAll;  // force any previous year data to complete
end;

procedure TSolutionObj.Set_Total_Time(const Value: Double);
begin
    Total_Time_Elapsed := Value;
end;

procedure TSolutionObj.SaveVoltages;

var
    F: TextFile;
    Volts: Complex;
    i, j: Integer;
    BusName: String;

begin

    try

        try
            AssignFile(F, CircuitName_ + 'SavedVoltages.Txt');
            Rewrite(F);

            with ActiveCircuit do
                for i := 1 to NumBuses do
                begin
                    BusName := BusList.Get(i);
                    for j := 1 to Buses^[i].NumNodesThisBus do
                    begin
                        Volts := NodeV^[Buses^[i].GetRef(j)];
                        Writeln(F, BusName, ', ', Buses^[i].GetNum(j): 0, Format(', %-.7g, %-.7g', [Cabs(Volts), CDang(Volts)]));
                    end;
                end;

        except
            On E: Exception do
            begin
                DoSimpleMsg('Error opening Saved Voltages File: ' + E.message, 488);
                Exit;
            end;
        end;


    finally

        CloseFile(F);
        GlobalResult := CircuitName_ + 'SavedVoltages.Txt';

    end;

end;

{  *************  MAIN SOLVER CALL  ************************}

function TSolutionObj.SolveSystem(V: pNodeVArray): Integer;

var
    RetCode: Integer;
    iRes: Longword;
    dRes: Double;

begin

 {Note: NodeV[0] = 0 + j0 always.  Therefore, pass the address of the element 1 of the array.
 }
    try
    // new function to log KLUSolve.DLL function calls; same information as stepping through in Delphi debugger
    // SetLogFile ('KLU_Log.txt', 1);
        RetCode := SolveSparseSet(hY, @V^[1], @Currents^[1]);  // Solve for present InjCurr
    // new information functions
        GetFlops(hY, @dRes);
        GetRGrowth(hY, @dRes);
        GetRCond(hY, @dRes);
    // GetCondEst (hY, @dRes); // this can be expensive
        GetSize(hY, @iRes);
        GetNNZ(hY, @iRes);
        GetSparseNNZ(hY, @iRes);
        GetSingularCol(hY, @iRes);
    except
        On E: Exception do
            raise  EEsolv32Problem.Create('Error Solving System Y Matrix.  Sparse matrix solver reports numerical error: ' + E.Message);
    end;

    Result := RetCode;

end;

procedure TSolutionObj.Update_dblHour;
begin
    DynaVars.dblHour := DynaVars.intHour + dynavars.t / 3600.0;
end;

procedure TSolutionObj.UpdateLoopTime;
begin

// Update Loop time is called from end of time step cleanup
// Timer is based on beginning of SolveSnap time

//   QueryPerformanceCounter(LoopEndtime);
    Step_Time_Elapsed := ((LoopEndtime - SolveStartTime) / CPU_Freq) * 1000000;

end;

procedure TSolutionObj.UpdateVBus;

// Save present solution vector values to buses
var
    i, j: Integer;
begin
    with ActiveCircuit do
        for i := 1 to NumBuses do
            with Buses^[i] do
                if Assigned(Vbus) then
                    for j := 1 to NumNodesThisBus do
                        VBus^[j] := NodeV^[GetRef(j)];
end;

procedure TSolutionObj.RestoreNodeVfromVbus;
var
    i, j: Integer;
begin
    with ActiveCircuit do
        for i := 1 to NumBuses do
            with Buses^[i] do
                if Assigned(Vbus) then
                    for j := 1 to NumNodesThisBus do
                        NodeV^[GetRef(j)] := VBus^[j];

end;


function TSolutionObj.SolveYDirect: Integer;

{ Solves present Y matrix with no injection sources except voltage and current sources }

begin

    Result := 0;

    ZeroInjCurr;   // Side Effect: Allocates InjCurr
    GetSourceInjCurrents;
    if IsDynamicModel then
        GetPCInjCurr;  // Need this in dynamics mode to pick up additional injections

    SolveSystem(NodeV); // Solve with Zero injection current

end;

initialization

    {$IFDEF debugtrace}
    Assignfile(Fdebug, 'Debugtrace.csv');
    Rewrite(Fdebug);

    CloseFile(Fdebug);
   {$ENDIF}

end.
