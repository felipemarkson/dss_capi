unit Storage2;

{
  ----------------------------------------------------------
  Copyright (c) 2009-2016, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{   Change Log

    10/04/2009 Created from Generator Model


  To Do:
    Make connection to User model
    Yprim for various modes
    Define state vars and dynamics mode behavior
    Complete Harmonics mode algorithm (generator mode is implemented)
}
{
  The Storage2 element is essentially a generator that can be dispatched
  to either produce power or consume power commensurate with rating and
  amount of stored energy.

  The Storage2 element can also produce or absorb vars within the kVA rating of the inverter.
  That is, a StorageController2 object requests kvar and the Storage2 element provides them if
  it has any capacity left. The Storage2 element can produce/absorb kvar while idling.
}

//  The Storage2 element is assumed balanced over the no. of phases defined


interface

USES  Storage2Vars, StoreUserModel, DSSClass, PCClass, PCElement, ucmatrix, ucomplex, LoadShape, Spectrum, ArrayDef, Dynamics, XYCurve;

Const  NumStorage2Registers = 6;    // Number of energy meter registers
       NumStorage2Variables = 23;    // No state variables
       VARMODEPF   = 0;
       VARMODEKVAR = 1;
//= = = = = = = = = = = = = = DEFINE STATES = = = = = = = = = = = = = = = = = = = = = = = = =

  STORE_CHARGING    = -1;
  STORE_IDLING      =  0;
  STORE_DISCHARGING =  1;
//= = = = = = = = = = = = = = DEFINE DISPATCH MODES = = = = = = = = = = = = = = = = = = = = = = = = =

  STORE_DEFAULT = 0;
  STORE_LOADMODE = 1;
  STORE_PRICEMODE = 2;
  STORE_EXTERNALMODE = 3;
  STORE_FOLLOW = 4;

TYPE


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   TStorage2 = CLASS(TPCClass)
     private

       PROCEDURE InterpretConnection(const S:String);
       PROCEDURE SetNcondsForConnection;
     Protected
       PROCEDURE DefineProperties;
       FUNCTION MakeLike(Const OtherStorage2ObjName:STring):Integer;Override;
     public
       RegisterNames:Array[1..NumStorage2Registers] of String;

       constructor Create;
       destructor Destroy; override;

       FUNCTION Edit(ActorID : Integer):Integer; override;
       FUNCTION Init(Handle:Integer; ActorID : Integer):Integer; override;
       FUNCTION NewObject(const ObjName:String):Integer; override;

       PROCEDURE ResetRegistersAll;
       PROCEDURE SampleAll(ActorID : Integer);
       PROCEDURE UpdateAll(ActorID : Integer);

   End;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   TStorage2Obj = class(TPCElement)
      Private
        Yeq             :Complex;   // at nominal
        Yeq95           :Complex;   // at 95%
        Yeq105          :Complex;   // at 105%
        PIdling         :Double;
        YeqDischarge    :Complex;   // equiv at rated power of Storage2 element only
        PhaseCurrentLimit :Complex;
        MaxDynPhaseCurrent   :Double;

        DebugTrace      :Boolean;
        FState          :Integer;
        FStateChanged   :Boolean;
        FirstSampleAfterReset  :Boolean;
        Storage2SolutionCount   :Integer;
        Storage2Fundamental     :Double;  {Thevenin equivalent voltage mag and angle reference for Harmonic model}
        Storage2ObjSwitchOpen   :Boolean;


        ForceBalanced   :Boolean;
        CurrentLimited  :Boolean;

//        LoadSpecType     :Integer;    // 0=kW, PF;  1= kw, kvar;
        kvar_out         :Double;
        kW_out           :Double;
        FkvarRequested   :Double;
        FkWRequested     :Double;
        FvarMode         :Integer;
        FDCkW            :Double;

        // Variables for Inverter functionalities
        FpctCutIn          :Double;
        FpctCutOut         :Double;
        FVarFollowInverter :Boolean;
        CutInkW            :Double;
        CutOutkW           :Double;

        FCutOutkWAC        :Double;  // CutInkW  reflected to the AC side of the inverter
        FCutInkWAC         :Double;   // CutOutkW reflected to the AC side of the inverter

        FStateDesired      :Integer;  // Stores desired state (before any change due to kWh limits or %CutIn/%CutOut

        FInverterON          :Boolean;
        FpctPminNoVars       :Double;
        FpctPminkvarLimit    :Double;
        PminNoVars           :Double;
        PminkvarLimit        :Double;
        kVA_exceeded         :Boolean;



        kvarLimitSet    :Boolean;
        kvarLimitNegSet :Boolean;
        kVASet          :Boolean;

        pctR               :Double;
        pctX               :Double;

        OpenStorage2SolutionCount :Integer;
        Pnominalperphase   :Double;
        Qnominalperphase   :Double;
        RandomMult         :Double;

        Reg_Hours       :Integer;
        Reg_kvarh       :Integer;
        Reg_kWh         :Integer;
        Reg_MaxkVA      :Integer;
        Reg_MaxkW       :Integer;
        Reg_Price       :Integer;
        ShapeFactor     :Complex;

        Tracefile       :TextFile;
        IsUserModel     :Boolean;
        UserModel       :TStoreUserModel;   {User-Written Models}
        DynaModel       :TStoreDynaModel;

//        VBase           :Double;  // Base volts suitable for computing currents  made public
        VBase105        :Double;
        VBase95         :Double;
        Vmaxpu          :Double;
        Vminpu          :Double;
        YPrimOpenCond   :TCmatrix;

        // Variables for InvControl's Volt-Watt function
        FVWMode         :Boolean; //boolean indicating if under volt-watt control mode from InvControl (not ExpControl)
        FVVMode         :Boolean; //boolean indicating if under volt-var mode from InvControl
        FDRCMode        :Boolean; //boolean indicating if under DRC mode from InvControl


        PROCEDURE CalcDailyMult(Hr:double; ActorID : Integer);
        PROCEDURE CalcDutyMult(Hr:double; ActorID : Integer);
        PROCEDURE CalcYearlyMult(Hr:double; ActorID : Integer);

        PROCEDURE ComputePresentkW; // Included
        PROCEDURE ComputeInverterPower; // Included

        PROCEDURE ComputekWkvar;        // Included
        PROCEDURE ComputeDCkW; // For Storage2 Update
        PROCEDURE CalcStorage2ModelContribution(ActorID : Integer);
        PROCEDURE CalcInjCurrentArray(ActorID : Integer);
        (*PROCEDURE CalcVterminal;*)
        PROCEDURE CalcVTerminalPhase(ActorID : Integer);

        PROCEDURE CalcYPrimMatrix(Ymatrix:TcMatrix;ActorID : Integer);

        PROCEDURE DoConstantPQStorage2Obj(ActorID : Integer);
        PROCEDURE DoConstantZStorage2Obj(ActorID : Integer);
        PROCEDURE DoDynamicMode(ActorID : Integer);
        PROCEDURE DoHarmonicMode(ActorID : Integer);
        PROCEDURE DoUserModel(ActorID : Integer);
        PROCEDURE DoDynaModel(ActorID : Integer);

        PROCEDURE Integrate(Reg:Integer; const Deriv:Double; Const Interval:Double;ActorID : Integer);
        PROCEDURE SetDragHandRegister(Reg:Integer; const Value:Double);
        PROCEDURE StickCurrInTerminalArray(TermArray:pComplexArray; Const Curr:Complex; i:Integer);

        PROCEDURE WriteTraceRecord(const s:string;ActorID : Integer);

        PROCEDURE CheckStateTriggerLevel(Level:Double;ActorID : Integer);
        PROCEDURE UpdateStorage2(ActorID : Integer);    // Update Storage2 elements based on present kW and IntervalHrs variable
        FUNCTION  NormalizeToTOD(h: Integer; sec: Double): Double;

        FUNCTION  InterpretState(const S:String):Integer;
//        FUNCTION  StateToStr:String;
        FUNCTION  DecodeState:String;

        FUNCTION  Get_PresentkW:Double;
        FUNCTION  Get_Presentkvar:Double;
        FUNCTION  Get_PresentkV: Double;
        FUNCTION  Get_kvarRequested: Double;
        FUNCTION  Get_kWRequested:   Double;

        PROCEDURE Set_kW(const Value: Double);
        FUNCTION  Get_kW: Double;
        PROCEDURE Set_PresentkV(const Value: Double);

        PROCEDURE Set_PowerFactor(const Value: Double);
        PROCEDURE Set_kWRequested(const Value: Double);
        PROCEDURE Set_kvarRequested(const Value: Double);


        PROCEDURE Set_Storage2State(const Value: Integer);
        PROCEDURE Set_pctkWOut(const Value: Double);
        PROCEDURE Set_pctkWIn(const Value: Double);

        FUNCTION  Get_DCkW: Double;
        FUNCTION  Get_kWTotalLosses: Double;
        FUNCTION  Get_InverterLosses: Double;
        FUNCTION  Get_kWIdlingLosses: Double;
        FUNCTION  Get_kWChDchLosses: Double;
        PROCEDURE Update_EfficiencyFactor;

        PROCEDURE Set_StateDesired(i:Integer);
        FUNCTION  Get_kWDesired: Double;

        // Procedures and functions for inverter functionalities
        PROCEDURE Set_kVARating(const Value: Double);
        PROCEDURE Set_pctkWrated(const Value: Double);
        FUNCTION  Get_Varmode: Integer;

        PROCEDURE Set_Varmode(const Value: Integer);
        FUNCTION  Get_VWmode: Boolean;

        PROCEDURE Set_VVmode(const Value: Boolean);
        FUNCTION  Get_VVmode: Boolean;

        PROCEDURE Set_DRCmode(const Value: Boolean);
        FUNCTION  Get_DRCmode: Boolean;

        PROCEDURE Set_VWmode(const Value: Boolean);
        PROCEDURE kWOut_Calc;

        FUNCTION  Get_CutOutkWAC: Double;
        FUNCTION  Get_CutInkWAC: Double;

      Protected
        PROCEDURE Set_ConductorClosed(Index:Integer; ActorID:integer; Value:Boolean); Override;
        PROCEDURE GetTerminalCurrents(Curr:pComplexArray; ActorID : Integer); Override ;

      public

        Storage2Vars     :TStorage2Vars;

        VBase           :Double;  // Base volts suitable for computing currents

        Connection      :Integer;  {0 = line-neutral; 1=Delta}
        DailyShape      :String;  // Daily (24 HR) Storage2 element shape
        DailyShapeObj   :TLoadShapeObj;  // Daily Storage2 element Shape for this load
        DutyShape       :String;  // Duty cycle load shape for changes typically less than one hour
        DutyShapeObj    :TLoadShapeObj;  // Shape for this Storage2 element
        YearlyShape     :String;  // ='fixed' means no variation  on all the time
        YearlyShapeObj  :TLoadShapeObj;  // Shape for this Storage2 element

        FpctkWout       :Double;   // percent of kW rated output currently dispatched
        FpctkWin         :Double;

        pctReserve      :Double;
        DispatchMode    :Integer;
        pctIdlekW       :Double;

        kWOutIdling        :Double;

        pctIdlekvar     :Double;
        pctChargeEff    :Double;
        pctDischargeEff :Double;
        DischargeTrigger:Double;
        ChargeTrigger   :Double;
        ChargeTime      :Double;
        kWhBeforeUpdate :Double;
        CurrentkvarLimit   :Double;
        CurrentkvarLimitNeg:Double;

        // Inverter efficiency curve
        InverterCurve      :String;
        InverterCurveObj   :TXYCurveObj;

        FVWStateRequested    :Boolean;   // TEST Flag indicating if VW function has requested a specific state in last control iteration

        Storage2Class      :Integer;
        VoltageModel      :Integer;   // Variation with voltage
        PFNominal         :Double;

        Registers,  Derivatives         :Array[1..NumStorage2Registers] of Double;

        constructor Create(ParClass :TDSSClass; const SourceName :String);
        destructor  Destroy; override;

        PROCEDURE RecalcElementData(ActorID : Integer); Override;
        PROCEDURE CalcYPrim(ActorID : Integer); Override;

        FUNCTION  InjCurrents(ActorID : Integer):Integer; Override;
        PROCEDURE GetInjCurrents(Curr:pComplexArray; ActorID : Integer); Override;
        FUNCTION  NumVariables:Integer;Override;
        PROCEDURE GetAllVariables(States:pDoubleArray);Override;
        FUNCTION  Get_Variable(i: Integer): Double; Override;
        PROCEDURE Set_Variable(i: Integer; Value: Double);  Override;
        FUNCTION  VariableName(i:Integer):String ;Override;

        FUNCTION  Get_InverterON:Boolean;
        PROCEDURE Set_InverterON(const Value: Boolean);
        FUNCTION  Get_VarFollowInverter:Boolean;
        PROCEDURE Set_VarFollowInverter(const Value: Boolean);

        PROCEDURE Set_Maxkvar(const Value: Double);
        PROCEDURE Set_Maxkvarneg(const Value: Double);

        PROCEDURE SetNominalStorage2Output(ActorID : Integer);
        PROCEDURE Randomize(Opt:Integer);   // 0 = reset to 1.0; 1 = Gaussian around mean and std Dev  ;  // 2 = uniform

        PROCEDURE ResetRegisters;
        PROCEDURE TakeSample(ActorID : Integer);

        // Support for Dynamics Mode
        PROCEDURE InitStateVars(ActorID : Integer); Override;
        PROCEDURE IntegrateStates(ActorID : Integer);Override;

        // Support for Harmonics Mode
        PROCEDURE InitHarmonics(ActorID : Integer); Override;

        PROCEDURE MakePosSequence(ActorID : Integer);Override;  // Make a positive Sequence Model

        PROCEDURE InitPropertyValues(ArrayOffset:Integer);Override;
        PROCEDURE DumpProperties(VAR F:TextFile; Complete:Boolean);Override;
        FUNCTION  GetPropertyValue(Index:Integer):String;Override;


        Property kW                 :Double  Read Get_kW                     Write Set_kW;
        Property kWDesired          :Double  Read Get_kWDesired;
        Property StateDesired       :Integer Write Set_StateDesired;
        Property kWRequested        :Double  Read Get_kWRequested            Write Set_kWRequested;
        Property kvarRequested      :Double  Read Get_kvarRequested          Write Set_kvarRequested;

        Property PresentkW          :Double  Read Get_PresentkW;             // Present kW   at inverter output
        Property Presentkvar        :Double  Read Get_Presentkvar;           // Present kvar at inverter output

        Property PresentkV          :Double  Read Get_PresentkV              Write Set_PresentkV;
        Property PowerFactor        :Double  Read PFNominal                  Write Set_PowerFactor;
        Property kVARating          :Double  Read Storage2Vars.FkVARating     Write Set_kVARating;
        Property pctkWrated         :Double  Read Storage2Vars.FpctkWrated    Write Set_pctkWrated;
        Property Varmode            :Integer Read Get_Varmode                Write Set_Varmode;  // 0=constant PF; 1=kvar specified
        Property VWmode             :Boolean Read Get_VWmode                 Write Set_VWmode;
        Property VVmode             :Boolean Read Get_VVmode                 Write Set_VVmode;
        Property DRCmode            :Boolean Read Get_DRCmode                Write Set_DRCmode;
        Property InverterON         :Boolean Read Get_InverterON             Write Set_InverterON;
        Property CutOutkWAC         :Double  Read Get_CutOutkWAC;
        Property CutInkWAC          :Double  Read Get_CutInkWAC;

        Property VarFollowInverter  :Boolean Read Get_VarFollowInverter      Write Set_VarFollowInverter;
        Property kvarLimit          :Double  Read Storage2Vars.Fkvarlimit     Write Set_Maxkvar;
        Property kvarLimitneg       :Double  Read Storage2Vars.Fkvarlimitneg  Write Set_Maxkvarneg;

        Property Storage2State       :Integer Read FState                     Write Set_Storage2State;
        Property PctkWOut           :Double  Read FpctkWOut                  Write Set_pctkWOut;
        Property PctkWIn            :Double  Read FpctkWIn                   Write Set_pctkWIn;

        Property kWTotalLosses      :Double  Read Get_kWTotalLosses;
        Property kWIdlingLosses     :Double  Read Get_kWIdlingLosses;
        Property kWInverterLosses   :Double  Read Get_InverterLosses;
        Property kWChDchLosses      :Double  Read Get_kWChDchLosses;
        Property DCkW               :Double  Read Get_DCkW;

        Property MinModelVoltagePU  :Double Read VminPu;
   End;

VAR
    ActiveStorage2Obj:TStorage2Obj;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
implementation


USES  ParserDel, Circuit,  Sysutils, Command, Math, MathUtil, DSSClassDefs, DSSGlobals, Utilities;

Const

{  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   To add a property,
    1) add a property constant to this list
    2) add a handler to the CASE statement in the Edit FUNCTION
    3) add a statement(s) to InitPropertyValues FUNCTION to initialize the string value
    4) add any special handlers to DumpProperties and GetPropertyValue, If needed
 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =}

  propKV                 =  3;
  propKW                 =  4;
  propPF                 =  5;
  propMODEL              =  6;
  propYEARLY             =  7;
  propDAILY              =  8;
  propDUTY               =  9;
  propDISPMODE           = 10;
  propCONNECTION         = 11;
  propKVAR               = 12;
  propPCTR               = 13;
  propPCTX               = 14;
  propIDLEKW             = 15;
  propCLASS              = 16;
  propDISPOUTTRIG        = 17;
  propDISPINTRIG         = 18;
  propCHARGEEFF          = 19;
  propDISCHARGEEFF       = 20;
  propPCTKWOUT           = 21;
  propVMINPU             = 22;
  propVMAXPU             = 23;
  propSTATE              = 24;
  propKVA                = 25;
  propKWRATED            = 26;
  propKWHRATED           = 27;
  propKWHSTORED          = 28;
  propPCTRESERVE         = 29;
  propUSERMODEL          = 30;
  propUSERDATA           = 31;
  propDEBUGTRACE         = 32;
  propPCTKWIN            = 33;
  propPCTSTORED          = 34;
  propCHARGETIME         = 35;
  propDynaDLL            = 36;
  propDynaData           = 37;
  propBalanced           = 38;
  propLimited            = 39;

  propInvEffCurve        = 40;
  propCutin              = 41;
  propCutout             = 42;
  proppctkWrated         = 43;
  propVarFollowInverter  = 44;
  propkvarLimit          = 45;
  propPpriority          = 46;
  propPFPriority         = 47;
  propPminNoVars         = 48;
  propPminkvarLimit      = 49;

  propkvarLimitneg       = 50;

  NumPropsThisClass = 50; // Make this agree with the last property constant

VAR

  cBuffer:Array[1..24] of Complex;  // Temp buffer for calcs  24-phase Storage2 element?
  CDOUBLEONE: Complex;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
constructor TStorage2.Create;  // Creates superstructure for all Storage2 elements
Begin
     Inherited Create;
     Class_Name := 'Storage2';
     DSSClassType := DSSClassType + Storage2_ELEMENT;  // In both PCelement and Storage2 element list

     ActiveElement := 0;

     // Set Register names
     RegisterNames[1]  := 'kWh';
     RegisterNames[2]  := 'kvarh';
     RegisterNames[3]  := 'Max kW';
     RegisterNames[4]  := 'Max kVA';
     RegisterNames[5]  := 'Hours';
     RegisterNames[6]  := 'Price($)';

     DefineProperties;

     CommandList := TCommandList.Create(Slice(PropertyName^, NumProperties));
     CommandList.Abbrev := TRUE;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Destructor TStorage2.Destroy;

Begin
    // ElementList and  CommandList freed in inherited destroy
    Inherited Destroy;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2.DefineProperties;
Begin

     Numproperties := NumPropsThisClass;
     CountProperties;   // Get inherited property count
     AllocatePropertyArrays;   {see DSSClass}

     // Define Property names
     {
      Using the AddProperty FUNCTION, you can list the properties here in the order you want
      them to appear when properties are accessed sequentially without tags.   Syntax:

      AddProperty( <name of property>, <index in the EDIT Case statement>, <help text>);

     }
     AddProperty('phases',    1,
                              'Number of Phases, this Storage2 element.  Power is evenly divided among phases.');
     AddProperty('bus1',      2,
                              'Bus to which the Storage2 element is connected.  May include specific node specification.');
     AddProperty('kv',        propKV,
                              'Nominal rated (1.0 per unit) voltage, kV, for Storage2 element. For 2- and 3-phase Storage2 elements, specify phase-phase kV. '+
                              'Otherwise, specify actual kV across each branch of the Storage2 element. '+  CRLF + CRLF +
                              'If wye (star), specify phase-neutral kV. '+  CRLF + CRLF +
                              'If delta or phase-phase connected, specify phase-phase kV.');  // line-neutral voltage//  base voltage
     AddProperty('conn',      propCONNECTION,
                              '={wye|LN|delta|LL}.  Default is wye.');
     AddProperty('kW',        propKW,
                              'Get/set the requested kW value. Final kW is subjected to the inverter ratings. A positive value denotes power coming OUT of the element, '+
                              'which is the opposite of a Load element. A negative value indicates the Storage2 element is in Charging state. ' +
                              'This value is modified internally depending on the dispatch mode.' );
     AddProperty('kvar',      propKVAR,
                              'Get/set the requested kvar value. Final kvar is subjected to the inverter ratings. Sets inverter to operate in constant kvar mode.');
     AddProperty('pf',        propPF,
                              'Get/set the requested PF value. Final PF is subjected to the inverter ratings. Sets inverter to operate in constant PF mode. Nominally, ' +
                              'the power factor for discharging (acting as a generator). Default is 1.0. ' + CRLF + CRLF +
                              'Enter negative for leading power factor '+
                              '(when kW and kvar have opposite signs.)'+CRLF + CRLF +
                              'A positive power factor signifies kw and kvar at the same direction.');
     AddProperty('kVA',       propKVA,
                              'Indicates the inverter nameplate capability (in kVA). ' +
                              'Used as the base for Dynamics mode and Harmonics mode values.');
     AddProperty('%Cutin',     propCutin,
                              'Cut-in power as a percentage of inverter kVA rating. It is the minimum DC power necessary to turn the inverter ON when it is OFF. ' +
                              'Must be greater than or equal to %CutOut. Defaults to 2 for PVSystems and 0 for Storage2 elements which means that the inverter state ' +
                              'will be always ON for this element.');
     AddProperty('%Cutout',    propCutout,
                              'Cut-out power as a percentage of inverter kVA rating. It is the minimum DC power necessary to keep the inverter ON. ' +
                              'Must be less than or equal to %CutIn. Defaults to 0, which means that, once ON, the inverter state ' +
                              'will be always ON for this element.');

     AddProperty('EffCurve',  propInvEffCurve,
                              'An XYCurve object, previously defined, that describes the PER UNIT efficiency vs PER UNIT of rated kVA for the inverter. ' +
                              'Power at the AC side of the inverter is discounted by the multiplier obtained from this curve.');

     AddProperty('VarFollowInverter',     propVarFollowInverter,
                              'Boolean variable (Yes|No) or (True|False). Defaults to False, which indicates that the reactive power generation/absorption does not respect the inverter status.' +
                              'When set to True, the reactive power generation/absorption will cease when the inverter status is off, due to DC kW dropping below %CutOut.  The reactive power '+
                              'generation/absorption will begin again when the DC kW is above %CutIn.  When set to False, the Storage2 will generate/absorb reactive power regardless of the status of the inverter.');
     AddProperty('kvarMax',     propkvarLimit,
                              'Indicates the maximum reactive power GENERATION (un-signed numerical variable in kvar) for the inverter. Defaults to kVA rating of the inverter.');

     AddProperty('kvarMaxAbs', propkvarLimitneg,
                             'Indicates the maximum reactive power ABSORPTION (un-signed numerical variable in kvar) for the inverter. Defaults to kvarMax.');

     AddProperty('WattPriority', propPPriority,
                               '{Yes/No*/True/False} Set inverter to watt priority instead of the default var priority.');

     AddProperty('PFPriority', propPFPriority,
                             'If set to true, priority is given to power factor and WattPriority is neglected. It works only if operating in either constant PF ' +
                              'or constant kvar modes. Defaults to False.');

     AddProperty('%PminNoVars', propPminNoVars,
                             'Minimum active power as percentage of kWrated under which there is no vars production/absorption. Defaults to 0 (disabled).');

     AddProperty('%PminkvarMax', propPminkvarLimit,
                             'Minimum active power as percentage of kWrated that allows the inverter to produce/absorb reactive power up to its maximum ' +
                             'reactive power, which can be either kvarMax or kvarMaxAbs, depending on the current operation quadrant. Defaults to 0 (disabled).');

     AddProperty('kWrated',   propKWRATED,
                              'kW rating of power output. Base for Loadshapes when DispMode=Follow. Sets kVA property if it has not been specified yet. ' +
                              'Defaults to 25.');
     AddProperty('%kWrated', proppctkWrated,
                              'Upper limit on active power as a percentage of kWrated. Defaults to 100 (disabled).');

     AddProperty('kWhrated',  propKWHRATED,
                              'Rated Storage2 capacity in kWh. Default is 50.');
     AddProperty('kWhstored', propKWHSTORED,
                              'Present amount of energy stored, kWh. Default is same as kWhrated.');
     AddProperty('%stored',   propPCTSTORED,
                              'Present amount of energy stored, % of rated kWh. Default is 100.');
     AddProperty('%reserve',  propPCTRESERVE,
                              'Percentage of rated kWh Storage2 capacity to be held in reserve for normal operation. Default = 20. ' + CRLF +
                              'This is treated as the minimum energy discharge level unless there is an emergency. For emergency operation ' +
                              'set this property lower. Cannot be less than zero.');
     AddProperty('State',     propSTATE,
                              '{IDLING | CHARGING | DISCHARGING}  Get/Set present operational state. In DISCHARGING mode, the Storage2 element ' +
                              'acts as a generator and the kW property is positive. The element continues discharging at the scheduled output power level ' +
                              'until the Storage2 reaches the reserve value. Then the state reverts to IDLING. ' +
                              'In the CHARGING state, the Storage2 element behaves like a Load and the kW property is negative. ' +
                              'The element continues to charge until the max Storage2 kWh is reached and then switches to IDLING state. ' +
                              'In IDLING state, the element draws the idling losses plus the associated inverter losses.');
     AddProperty('%Discharge',  propPCTKWOUT,
                              'Discharge rate (output power) in percentage of rated kW. Default = 100.');
     AddProperty('%Charge',  propPCTKWIN,
                              'Charging rate (input power) in percentage of rated kW. Default = 100.');
     AddProperty('%EffCharge',propCHARGEEFF,
                              'Percentage efficiency for CHARGING the Storage2 element. Default = 90.');
     AddProperty('%EffDischarge',propDISCHARGEEFF,
                              'Percentage efficiency for DISCHARGING the Storage2 element. Default = 90.');
     AddProperty('%IdlingkW', propIDLEKW,
                              'Percentage of rated kW consumed by idling losses. Default = 1.');
     AddProperty('%R',        propPCTR,
                              'Equivalent percentage internal resistance, ohms. Default is 0. Placed in series with internal voltage source' +
                              ' for harmonics and dynamics modes. Use a combination of %IdlingkW, %EffCharge and %EffDischarge to account for ' +
                              'losses in power flow modes.');
     AddProperty('%X',        propPCTX,
                              'Equivalent percentage internal reactance, ohms. Default is 50%. Placed in series with internal voltage source' +
                              ' for harmonics and dynamics modes. (Limits fault current to 2 pu.');
     AddProperty('model',     propMODEL,
                              'Integer code (default=1) for the model to be used for power output variation with voltage. '+
                              'Valid values are:' +CRLF+CRLF+
                              '1:Storage2 element injects/absorbs a CONSTANT power.'+CRLF+
                              '2:Storage2 element is modeled as a CONSTANT IMPEDANCE.'  +CRLF+
                              '3:Compute load injection from User-written Model.');

     AddProperty('Vminpu',       propVMINPU,
                                 'Default = 0.90.  Minimum per unit voltage for which the Model is assumed to apply. ' +
                                 'Below this value, the load model reverts to a constant impedance model.');
     AddProperty('Vmaxpu',       propVMAXPU,
                                 'Default = 1.10.  Maximum per unit voltage for which the Model is assumed to apply. ' +
                                 'Above this value, the load model reverts to a constant impedance model.');
     AddProperty('Balanced',     propBalanced, '{Yes | No*} Default is No. Force balanced current only for 3-phase Storage2. Forces zero- and negative-sequence to zero. ');
     AddProperty('LimitCurrent', propLimited,  'Limits current magnitude to Vminpu value for both 1-phase and 3-phase Storage2 similar to Generator Model 7. For 3-phase, ' +
                                 'limits the positive-sequence current but not the negative-sequence.');
     AddProperty('yearly',       propYEARLY,
                                 'Dispatch shape to use for yearly simulations.  Must be previously defined '+
                                 'as a Loadshape object. If this is not specified, the Daily dispatch shape, if any, is repeated '+
                                 'during Yearly solution modes. In the default dispatch mode, ' +
                                 'the Storage2 element uses this loadshape to trigger State changes.');
     AddProperty('daily',        propDAILY,
                                 'Dispatch shape to use for daily simulations.  Must be previously defined '+
                                 'as a Loadshape object of 24 hrs, typically.  In the default dispatch mode, '+
                                 'the Storage2 element uses this loadshape to trigger State changes.'); // daily dispatch (hourly)
     AddProperty('duty',          propDUTY,
                                 'Load shape to use for duty cycle dispatch simulations such as for solar ramp rate studies. ' +
                                 'Must be previously defined as a Loadshape object. '+  CRLF + CRLF +
                                 'Typically would have time intervals of 1-5 seconds. '+  CRLF + CRLF +
                                 'Designate the number of points to solve using the Set Number=xxxx command. '+
                                 'If there are fewer points in the actual shape, the shape is assumed to repeat.');  // as for wind generation
     AddProperty('DispMode',     propDISPMODE,
                                 '{DEFAULT | FOLLOW | EXTERNAL | LOADLEVEL | PRICE } Default = "DEFAULT". Dispatch mode. '+  CRLF + CRLF +
                                 'In DEFAULT mode, Storage2 element state is triggered to discharge or charge at the specified rate by the ' +
                                 'loadshape curve corresponding to the solution mode. '+ CRLF + CRLF +
                                 'In FOLLOW mode the kW output of the Storage2 element follows the active loadshape multiplier ' +
                                 'until Storage2 is either exhausted or full. ' +
                                 'The element discharges for positive values and charges for negative values.  The loadshape is based on rated kW. ' + CRLF + CRLF +
                                 'In EXTERNAL mode, Storage2 element state is controlled by an external Storagecontroller2. '+
                                 'This mode is automatically set if this Storage2 element is included in the element list of a Storage2Controller element. ' + CRLF + CRLF +
                                 'For the other two dispatch modes, the Storage2 element state is controlled by either the global default Loadlevel value or the price level. ');
     AddProperty('DischargeTrigger', propDISPOUTTRIG,
                                 'Dispatch trigger value for discharging the Storage2. '+CRLF+
                                 'If = 0.0 the Storage2 element state is changed by the State command or by a StorageController2 object. ' +CRLF+
                                 'If <> 0  the Storage2 element state is set to DISCHARGING when this trigger level is EXCEEDED by either the specified ' +
                                 'Loadshape curve value or the price signal or global Loadlevel value, depending on dispatch mode. See State property.');
     AddProperty('ChargeTrigger', propDISPINTRIG,
                                 'Dispatch trigger value for charging the Storage2. '+CRLF + CRLF +
                                 'If = 0.0 the Storage2 element state is changed by the State command or StorageController2 object.  ' +CRLF + CRLF +
                                 'If <> 0  the Storage2 element state is set to CHARGING when this trigger level is GREATER than either the specified ' +
                                 'Loadshape curve value or the price signal or global Loadlevel value, depending on dispatch mode. See State property.');
     AddProperty('TimeChargeTrig', propCHARGETIME,
                                 'Time of day in fractional hours (0230 = 2.5) at which Storage2 element will automatically go into charge state. ' +
                                 'Default is 2.0.  Enter a negative time value to disable this feature.');
     AddProperty('class',       propCLASS,
                                'An arbitrary integer number representing the class of Storage2 element so that Storage2 values may '+
                                'be segregated by class.'); // integer
     AddProperty('DynaDLL',     propDynaDLL,
                                'Name of DLL containing user-written dynamics model, which computes the terminal currents for Dynamics-mode simulations, ' +
                                'overriding the default model.  Set to "none" to negate previous setting. ' +
                                'This DLL has a simpler interface than the UserModel DLL and is only used for Dynamics mode.');
     AddProperty('DynaData',    propDYNADATA,
                                'String (in quotes or parentheses if necessary) that gets passed to the user-written dynamics model Edit function for defining the data required for that model.');
     AddProperty('UserModel',   propUSERMODEL,
                                'Name of DLL containing user-written model, which computes the terminal currents for both power flow and dynamics, ' +
                                'overriding the default model.  Set to "none" to negate previous setting.');
     AddProperty('UserData',    propUSERDATA,
                                'String (in quotes or parentheses) that gets passed to user-written model for defining the data required for that model.');
     AddProperty('debugtrace',  propDEBUGTRACE,
                                '{Yes | No }  Default is no.  Turn this on to capture the progress of the Storage2 model ' +
                                'for each iteration.  Creates a separate file for each Storage2 element named "Storage2_name.CSV".' );

     ActiveProperty := NumPropsThisClass;
     inherited DefineProperties;  // Add defs of inherited properties to bottom of list

     // Override default help string
     PropertyHelp[NumPropsThisClass +1] := 'Name of harmonic voltage or current spectrum for this Storage2 element. ' +
                         'Current injection is assumed for inverter. ' +
                         'Default value is "default", which is defined when the DSS starts.';

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TStorage2.NewObject(const ObjName:String):Integer;
Begin
    // Make a new Storage2 element and add it to Storage2 class list
    With ActiveCircuit[ActiveActor] Do
    Begin
      ActiveCktElement := TStorage2Obj.Create(Self, ObjName);
      Result := AddObjectToList(ActiveDSSObject[ActiveActor]);
    End;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2.SetNcondsForConnection;

Begin
      With ActiveStorage2Obj Do
      Begin
           CASE Connection OF
             0: NConds := Fnphases +1;
             1: CASE Fnphases OF
                    1,2: NConds := Fnphases +1; // L-L and Open-delta
                ELSE
                    NConds := Fnphases;
                END;
           END;
      End;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2.UpdateAll(ActorID : Integer);
VAR
     i :Integer;
Begin
     For i := 1 to ElementList.ListSize  Do
        With TStorage2Obj(ElementList.Get(i)) Do
          If Enabled Then UpdateStorage2(ActorID);
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2.InterpretConnection(const S:String);

// Accepts
//    delta or LL           (Case insensitive)
//    Y, wye, or LN
VAR
     TestS:String;

Begin
      With ActiveStorage2Obj Do Begin
          TestS := lowercase(S);
          CASE TestS[1] OF
            'y','w': Connection := 0;  {Wye}
            'd': Connection := 1;  {Delta or line-Line}
            'l': CASE Tests[2] OF
                 'n': Connection := 0;
                 'l': Connection := 1;
                 END;
          END;

          SetNCondsForConnection;

          {VBase is always L-N voltage unless 1-phase device or more than 3 phases}

          CASE Fnphases Of
               2,3: VBase := Storage2Vars.kVStorage2Base * InvSQRT3x1000;    // L-N Volts
          ELSE
               VBase := Storage2Vars.kVStorage2Base * 1000.0 ;   // Just use what is supplied
          END;

          VBase95  := Vminpu * VBase;
          VBase105 := Vmaxpu * VBase;

          Yorder := Fnconds * Fnterms;
          YprimInvalid[ActiveActor] := True;
      End;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION InterpretDispMode(const S:String):Integer;
BEGIN
        CASE lowercase(S)[1] of
             'e': Result := STORE_EXTERNALMODE;
             'f': Result := STORE_FOLLOW;
             'l': Result := STORE_LOADMODE;
             'p': Result := STORE_PRICEMODE;
        ELSE
             Result := STORE_DEFAULT;
        END;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION ReturnDispMode(const imode:Integer):String;
BEGIN
        CASE imode of
             STORE_EXTERNALMODE: Result := 'External';
             STORE_FOLLOW:       Result := 'Follow';
             STORE_LOADMODE:     Result := 'Loadshape';
             STORE_PRICEMODE:    Result := 'Price';
        ELSE
             Result := 'default';
        END;
End;



//- - - - - - - - - - - - - - -MAIN EDIT FUNCTION - - - - - - - - - - - - - - -
FUNCTION TStorage2.Edit(ActorID : Integer):Integer;

VAR
       i, iCase,
       ParamPointer:Integer;
       ParamName:String;
       Param:String;

Begin

  // continue parsing with contents of Parser
  ActiveStorage2Obj := ElementList.Active;
  ActiveCircuit[ActorID].ActiveCktElement := ActiveStorage2Obj;

  Result := 0;

  With ActiveStorage2Obj Do
  Begin

     ParamPointer := 0;
     ParamName    := Parser[ActorID].NextParam;  // Parse next property off the command line
     Param        := Parser[ActorID].StrValue;   // Put the string value of the property value in local memory for faster access
     While Length(Param)>0 Do
     Begin

         If  (Length(ParamName) = 0) Then Inc(ParamPointer)       // If it is not a named property, assume the next property
         ELSE ParamPointer := CommandList.GetCommand(ParamName);  // Look up the name in the list for this class

         If  (ParamPointer>0) and (ParamPointer<=NumProperties)
         Then PropertyValue[PropertyIdxMap[ParamPointer]] := Param   // Update the string value of the property
         ELSE DoSimpleMsg('Unknown parameter "'+ParamName+'" for Storage2 "'+Name+'"', 560);

         If ParamPointer > 0 Then
         Begin
             iCase := PropertyIdxMap[ParamPointer];
             CASE iCASE OF
                0               : DoSimpleMsg('Unknown parameter "' + ParamName + '" for Object "' + Class_Name +'.'+ Name + '"', 561);
                1               : NPhases            := Parser[ActorID].Intvalue;
                2               : SetBus(1, param);
               propKV           : PresentkV          := Parser[ActorID].DblValue;
               propKW           : kW                 := Parser[ActorID].DblValue;
               propPF           : Begin
                                    varMode          := VARMODEPF;
                                    PFnominal        := Parser[ActorID].DblValue;
                                  end;
               propMODEL        : VoltageModel       := Parser[ActorID].IntValue;
               propYEARLY       : YearlyShape        := Param;
               propDAILY        : DailyShape         := Param;
               propDUTY         : DutyShape          := Param;
               propDISPMODE     : DispatchMode       := InterpretDispMode(Param);
               propCONNECTION   : InterpretConnection(Param);
               propKVAR         : Begin
                                    varMode          := VARMODEKVAR;
                                    kvarRequested    := Parser[ActorID].DblValue;
                                  End;
               propPCTR         : pctR               := Parser[ActorID].DblValue;
               propPCTX         : pctX               := Parser[ActorID].DblValue;
               propIDLEKW       : pctIdlekW          := Parser[ActorID].DblValue;
               propCLASS        : Storage2Class       := Parser[ActorID].IntValue;
               propInvEffCurve  : InverterCurve      := Param;
               propDISPOUTTRIG  : DischargeTrigger   := Parser[ActorID].DblValue;
               propDISPINTRIG   : ChargeTrigger      := Parser[ActorID].DblValue;
               propCHARGEEFF    : pctChargeEff       := Parser[ActorID].DblValue;
               propDISCHARGEEFF : pctDischargeEff    := Parser[ActorID].DblValue;
               propPCTKWOUT     : pctkWout           := Parser[ActorID].DblValue;
               propCutin        : FpctCutIn          := Parser[ActorID].DblValue;
               propCutout       : FpctCutOut         := Parser[ActorID].DblValue;
               propVMINPU       : VMinPu             := Parser[ActorID].DblValue;
               propVMAXPU       : VMaxPu             := Parser[ActorID].DblValue;
               propSTATE        : FState             := InterpretState(Param); //****
               propKVA          : With Storage2Vars Do Begin
                                      FkVArating     := Parser[ActorID].DblValue;
                                      kVASet         := TRUE;
                                      if not kvarLimitSet                         then Storage2Vars.Fkvarlimit    := Parser[ActorID].DblValue;
                                      if not kvarLimitSet and not kvarLimitNegSet then Storage2Vars.Fkvarlimitneg := Parser[ActorID].DblValue;
                                  End;
               propKWRATED      : Storage2Vars.kWrating     := Parser[ActorID].DblValue ;
               propKWHRATED     : Storage2Vars.kWhrating    := Parser[ActorID].DblValue;
               propKWHSTORED    : Storage2Vars.kWhstored    := Parser[ActorID].DblValue;
               propPCTRESERVE   : pctReserve               := Parser[ActorID].DblValue;
               propUSERMODEL    : UserModel.Name           := Parser[ActorID].StrValue;  // Connect to user written models
               propUSERDATA     : UserModel.Edit           := Parser[ActorID].StrValue;  // Send edit string to user model
               propDEBUGTRACE   : DebugTrace               := InterpretYesNo(Param);
               propPCTKWIN      : pctkWIn                  := Parser[ActorID].DblValue;
               propPCTSTORED    : Storage2Vars.kWhStored    := Parser[ActorID].DblValue * 0.01 * Storage2Vars.kWhRating;
               propCHARGETIME   : ChargeTime               := Parser[ActorID].DblValue;
               propDynaDLL      : DynaModel.Name           := Parser[ActorID].StrValue;
               propDynaData     : DynaModel.Edit           := Parser[ActorID].StrValue;
               proppctkWrated   : Storage2Vars.FpctkWrated  := Parser[ActorID].DblValue / 100.0;  // convert to pu
               propBalanced     : ForceBalanced            := InterpretYesNo(Param);
               propLimited      : CurrentLimited           := InterpretYesNo(Param);
               propVarFollowInverter
                                : FVarFollowInverter       := InterpretYesNo(Param);
               propkvarLimit    : Begin
                                    Storage2Vars.Fkvarlimit := Abs(Parser[ActorID].DblValue);
                                    kvarLimitSet := True;
                                    if not kvarLimitNegSet then Storage2Vars.Fkvarlimitneg := Abs(Parser[ActorID].DblValue);

                                  End;
               propPPriority    : Storage2Vars.P_priority   := InterpretYesNo(Param);  // watt priority flag
               propPFPriority   : Storage2Vars.PF_priority  := InterpretYesNo(Param);

               propPminNoVars   : FpctPminNoVars           := Parser[ActorID].DblValue;
               propPminkvarLimit: FpctPminkvarLimit        := Parser[ActorID].DblValue;

               propkvarLimitneg:  Begin
                                    Storage2Vars.Fkvarlimitneg := Abs(Parser[ActorID].DblValue);
                                    kvarLimitNegSet           := True;
                                  End;

             ELSE
               // Inherited parameters
                 ClassEdit(ActiveStorage2Obj, ParamPointer - NumPropsThisClass)
             END;

             CASE iCase OF
                1: SetNcondsForConnection;  // Force Reallocation of terminal info
                // (PR) Make sure if we will need it
                { removed
                propKW,propPF: Begin
                                 SyncUpPowerQuantities;   // keep kvar nominal up to date with kW and PF

                               End;       }

        {Set loadshape objects;  returns nil If not valid}
                propYEARLY: YearlyShapeObj                 := LoadShapeClass[ActorID].Find(YearlyShape);
                propDAILY:  DailyShapeObj                  := LoadShapeClass[ActorID].Find(DailyShape);
                propDUTY:   DutyShapeObj                   := LoadShapeClass[ActorID].Find(DutyShape);

                propKWRATED:  If not kVASet Then Storage2Vars.FkVArating := Storage2Vars.kWrating;
                propKWHRATED: Begin Storage2Vars.kWhStored  := Storage2Vars.kWhRating; // Assume fully charged
                                    kWhBeforeUpdate        := Storage2Vars.kWhStored;
                                    Storage2Vars.kWhReserve := Storage2Vars.kWhRating * pctReserve * 0.01;
                              End;

                propPCTRESERVE: Storage2Vars.kWhReserve     := Storage2Vars.kWhRating * pctReserve * 0.01;

                propInvEffCurve  : InverterCurveObj        := XYCurveClass[ActorID].Find(InverterCurve);

                propDEBUGTRACE: IF DebugTrace
                THEN Begin   // Init trace file
                         AssignFile(TraceFile, GetOutputDirectory + 'STOR_'+Name+'.CSV');
                         ReWrite(TraceFile);
                         Write(TraceFile, 't, Iteration, LoadMultiplier, Mode, LoadModel, Storage2Model,  Qnominalperphase, Pnominalperphase, CurrentType');
                         For i := 1 to nphases Do Write(Tracefile,  ', |Iinj'+IntToStr(i)+'|');
                         For i := 1 to nphases Do Write(Tracefile,  ', |Iterm'+IntToStr(i)+'|');
                         For i := 1 to nphases Do Write(Tracefile,  ', |Vterm'+IntToStr(i)+'|');
                         For i := 1 to NumVariables Do Write(Tracefile, ', ', VariableName(i));

                         Write(TraceFile, ',Vthev, Theta');
                         Writeln(TraceFile);
                         CloseFile(Tracefile);
                      End;

                propUSERMODEL: IsUserModel := UserModel.Exists;
                propDynaDLL:   IsUserModel := DynaModel.Exists;

//                propPFPriority: For i := 1 to ControlElementList.ListSize Do
//                Begin
//
//                  if TControlElem(ControlElementList.Get(i)).ClassName = 'InvControl'  Then
//                      // Except for VW mode, all other modes (including combined ones) can operate with PF priority
//                      if (TInvControlObj(ControlElementList.Get(i)).Mode <> 'VOLTWATT') Then
//                          Storage2Vars.PF_Priority := FALSE; // For all other modes
//
//                End;

             END;
         End;

         ParamName := Parser[ActorID].NextParam;
         Param     := Parser[ActorID].StrValue;
     End;

     RecalcElementData(ActorID);
     YprimInvalid[ActorID] := TRUE;
  End;

End;

//----------------------------------------------------------------------------
FUNCTION TStorage2.MakeLike(Const OtherStorage2ObjName:String):Integer;

// Copy over essential properties from other object

VAR
     OtherStorage2Obj:TStorage2Obj;
     i:Integer;
Begin
     Result := 0;
     {See If we can find this line name in the present collection}
     OtherStorage2Obj := Find(OtherStorage2ObjName);
     If   (OtherStorage2Obj <> Nil)
     Then With ActiveStorage2Obj
     Do Begin
         If (Fnphases <> OtherStorage2Obj.Fnphases)
         Then Begin
           Nphases := OtherStorage2Obj.Fnphases;
           NConds := Fnphases;  // Forces reallocation of terminal stuff
           Yorder := Fnconds*Fnterms;
           YprimInvalid[ActiveActor] := TRUE;
         End;

         Storage2Vars.kVStorage2Base := OtherStorage2Obj.Storage2Vars.kVStorage2Base;
         Vbase          := OtherStorage2Obj.Vbase;
         Vminpu         := OtherStorage2Obj.Vminpu;
         Vmaxpu         := OtherStorage2Obj.Vmaxpu;
         Vbase95        := OtherStorage2Obj.Vbase95;
         Vbase105       := OtherStorage2Obj.Vbase105;
         kW_out         := OtherStorage2Obj.kW_out;
         kvar_out       := OtherStorage2Obj.kvar_out;
         Pnominalperphase   := OtherStorage2Obj.Pnominalperphase;
         PFNominal      := OtherStorage2Obj.PFNominal;
         Qnominalperphase   := OtherStorage2Obj.Qnominalperphase;
         Connection     := OtherStorage2Obj.Connection;
         YearlyShape    := OtherStorage2Obj.YearlyShape;
         YearlyShapeObj := OtherStorage2Obj.YearlyShapeObj;
         DailyShape     := OtherStorage2Obj.DailyShape;
         DailyShapeObj  := OtherStorage2Obj.DailyShapeObj;
         DutyShape      := OtherStorage2Obj.DutyShape;
         DutyShapeObj   := OtherStorage2Obj.DutyShapeObj;
         DispatchMode   := OtherStorage2Obj.DispatchMode;
         InverterCurve      := OtherStorage2Obj.InverterCurve;
         InverterCurveObj   := OtherStorage2Obj.InverterCurveObj;
         Storage2Class   := OtherStorage2Obj.Storage2Class;
         VoltageModel   := OtherStorage2Obj.VoltageModel;

         Fstate         := OtherStorage2Obj.Fstate;
         FstateChanged  := OtherStorage2Obj.FstateChanged;
         kvarLimitSet      := OtherStorage2Obj.kvarLimitSet;
         kvarLimitNegSet   := OtherStorage2Obj.kvarLimitNegSet;

         FpctCutin                   := OtherStorage2Obj.FpctCutin;
         FpctCutout                  := OtherStorage2Obj.FpctCutout;
         FVarFollowInverter          := OtherStorage2Obj.FVarFollowInverter;
         Storage2Vars.Fkvarlimit      := OtherStorage2Obj.Storage2Vars.Fkvarlimit;
         Storage2Vars.Fkvarlimitneg   := OtherStorage2Obj.Storage2Vars.Fkvarlimitneg;
         Storage2Vars.FkVArating      := OtherStorage2Obj.Storage2Vars.FkVArating;

         FpctPminNoVars                  := OtherStorage2Obj.FpctPminNoVars;
         FpctPminkvarLimit               := OtherStorage2Obj.FpctPminkvarLimit;

         kWOutIdling                     := OtherStorage2Obj.kWOutIdling;

         Storage2Vars.kWRating        := OtherStorage2Obj.Storage2Vars.kWRating;
         Storage2Vars.kWhRating       := OtherStorage2Obj.Storage2Vars.kWhRating;
         Storage2Vars.kWhStored       := OtherStorage2Obj.Storage2Vars.kWhStored;
         Storage2Vars.kWhReserve      := OtherStorage2Obj.Storage2Vars.kWhReserve;
         kWhBeforeUpdate := OtherStorage2Obj.kWhBeforeUpdate;
         pctReserve      := OtherStorage2Obj.pctReserve;
         DischargeTrigger := OtherStorage2Obj.DischargeTrigger;
         ChargeTrigger   := OtherStorage2Obj.ChargeTrigger;
         pctChargeEff    := OtherStorage2Obj.pctChargeEff;
         pctDischargeEff := OtherStorage2Obj.pctDischargeEff;
         pctkWout        := OtherStorage2Obj.pctkWout;
         pctkWin         := OtherStorage2Obj.pctkWin;
         pctIdlekW       := OtherStorage2Obj.pctIdlekW;
         pctIdlekvar     := OtherStorage2Obj.pctIdlekvar;
         ChargeTime      := OtherStorage2Obj.ChargeTime;

         pctR            := OtherStorage2Obj.pctR;
         pctX            := OtherStorage2Obj.pctX;

         RandomMult      :=  OtherStorage2Obj.RandomMult;
         FVWMode         := OtherStorage2Obj.FVWMode;
         FVVMode         := OtherStorage2Obj.FVVMode;
         FDRCMode        := OtherStorage2Obj.FDRCMode;

         UserModel.Name   := OtherStorage2Obj.UserModel.Name;  // Connect to user written models
         DynaModel.Name   := OtherStorage2Obj.DynaModel.Name;
         IsUserModel      := OtherStorage2Obj.IsUserModel;
         ForceBalanced    := OtherStorage2Obj.ForceBalanced;
         CurrentLimited   := OtherStorage2Obj.CurrentLimited;

         ClassMakeLike(OtherStorage2Obj);

         For i := 1 to ParentClass.NumProperties Do
             FPropertyValue^[i] := OtherStorage2Obj.FPropertyValue^[i];

         Result := 1;
     End
     ELSE  DoSimpleMsg('Error in Storage2 MakeLike: "' + OtherStorage2ObjName + '" Not Found.', 562);

End;

//----------------------------------------------------------------------------
FUNCTION TStorage2.Init(Handle:Integer; ActorID : Integer):Integer;
VAR
   p:TStorage2Obj;

Begin
     If (Handle = 0) THEN
       Begin  // init all
             p := elementList.First;
             WHILE (p <> nil) Do
             Begin
                  p.Randomize(0);
                  p := elementlist.Next;
             End;
       End
     ELSE
       Begin
             Active := Handle;
             p := GetActiveObj;
             p.Randomize(0);
       End;

     DoSimpleMsg('Need to implement TStorage2.Init', -1);
     Result := 0;
End;

{--------------------------------------------------------------------------}
PROCEDURE TStorage2.ResetRegistersAll;  // Force all EnergyMeters in the circuit to reset

VAR
      idx  :Integer;

Begin
      idx := First;
      WHILE idx > 0 Do
      Begin
           TStorage2Obj(GetActiveObj).ResetRegisters;
           idx := Next;
      End;
End;

{--------------------------------------------------------------------------}
PROCEDURE TStorage2.SampleAll(ActorID : Integer);  // Force all Storage2 elements in the circuit to take a sample

VAR
      i :Integer;
Begin
      For i := 1 to ElementList.ListSize  Do
        With TStorage2Obj(ElementList.Get(i)) Do
          If Enabled Then TakeSample(ActorID);
End;

//----------------------------------------------------------------------------
Constructor TStorage2Obj.Create(ParClass:TDSSClass; const SourceName:String);
Begin

     Inherited create(ParClass);
     Name := LowerCase(SourceName);
     DSSObjType := ParClass.DSSClassType ; // + Storage2_ELEMENT;  // In both PCelement and Storage2element list

     Nphases    := 3;
     Fnconds    := 4;  // defaults to wye
     Yorder     := 0;  // To trigger an initial allocation
     Nterms     := 1;  // forces allocations

     YearlyShape       := '';
     YearlyShapeObj    := nil;  // If YearlyShapeobj = nil Then the load alway stays nominal * global multipliers
     DailyShape        := '';
     DailyShapeObj     := nil;  // If DaillyShapeobj = nil Then the load alway stays nominal * global multipliers
     DutyShape         := '';
     DutyShapeObj      := nil;  // If DutyShapeobj = nil Then the load alway stays nominal * global multipliers

     InverterCurveObj  := Nil;
     InverterCurve     := '';

     Connection                   := 0;    // Wye (star)
     VoltageModel                 := 1;  {Typical fixed kW negative load}
     Storage2Class                 := 1;

     Storage2SolutionCount         := -1;  // For keep track of the present solution in Injcurrent calcs
     OpenStorage2SolutionCount     := -1;
     YPrimOpenCond                := nil;

     Storage2Vars.kVStorage2Base    := 12.47;
     VBase                        := 7200.0;
     Vminpu                       := 0.90;
     Vmaxpu                       := 1.10;
     VBase95                      := Vminpu * Vbase;
     VBase105                     := Vmaxpu * Vbase;
     Yorder                       := Fnterms * Fnconds;
     RandomMult                   := 1.0 ;

     varMode              := VARMODEPF;
     FInverterON          := TRUE; // start with inverterON
     kVA_exceeded         := FALSE;
     FVarFollowInverter   := FALSE;

     ForceBalanced        := FALSE;
     CurrentLimited       := FALSE;

     With Storage2Vars Do Begin
        kWRating          := 25.0;
        FkVArating        := kWRating;
        kWhRating         := 50;
        kWhStored         := kWhRating;
        kWhBeforeUpdate   := kWhRating;
        kWhReserve        := kWhRating * pctReserve /100.0;
        Fkvarlimit        := FkVArating;
        Fkvarlimitneg     := FkVArating;
        FpctkWrated       := 1.0;
        P_Priority        := FALSE;
        PF_Priority       := FALSE;

        EffFactor         := 1.0;

        Vreg              := 9999;
        Vavg              := 9999;
        VVOperation       := 9999;
        VWOperation       := 9999;
        DRCOperation      := 9999;
        VVDRCOperation    := 9999;

     End;

     FDCkW := 25.0;

     FpctCutIn         := 0.0;
     FpctCutOut        := 0.0;

     FpctPminNoVars    := -1.0; // Deactivated by default
     FpctPminkvarLimit := -1.0; // Deactivated by default

     {Output rating stuff}
     kvar_out     := 0.0;
     // removed kvarBase     := kvar_out;     // initialize
     PFNominal    := 1.0;

     pctR            := 0.0;;
     pctX            := 50.0;

     {Make the Storage2Vars struct as public}
     PublicDataStruct := @Storage2Vars;
     PublicDataSize   := SizeOf(TStorage2Vars);

     IsUserModel := FALSE;
     UserModel  := TStoreUserModel.Create;
     DynaModel  := TStoreDynaModel.Create;

     FState           := STORE_IDLING;  // Idling and fully charged
     FStateChanged    := TRUE;  // Force building of YPrim
     pctReserve      := 20.0;  // per cent of kWhRating
     pctIdlekW       := 1.0;
     pctIdlekvar     := 0.0;

     DischargeTrigger := 0.0;
     ChargeTrigger    := 0.0;
     pctChargeEff     := 90.0;
     pctDischargeEff  := 90.0;
     FpctkWout        := 100.0;
     FpctkWin          := 100.0;

     ChargeTime       := 2.0;   // 2 AM

     kVASet          := False;
     kvarLimitSet    := False;
     kvarLimitNegSet := False;

     Reg_kWh    := 1;
     Reg_kvarh  := 2;
     Reg_MaxkW  := 3;
     Reg_MaxkVA := 4;
     Reg_Hours  := 5;
     Reg_Price  := 6;

     DebugTrace := FALSE;
     Storage2ObjSwitchOpen := FALSE;
     Spectrum := '';  // override base class
     SpectrumObj := nil;
     FVWMode     := FALSE;
     FVVMode     := FALSE;
     FDRCMode    := FALSE;

     InitPropertyValues(0);
     RecalcElementData(ActiveActor);

End;


//----------------------------------------------------------------------------
FUNCTION TStorage2Obj.DecodeState: String;
Begin
     CASE Fstate of
         STORE_CHARGING :    Result := 'CHARGING';
         STORE_DISCHARGING : Result := 'DISCHARGING';
     ELSE
         Result := 'IDLING';
     END;
End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.InitPropertyValues(ArrayOffset: Integer);

// Define default values for the properties

Begin

     PropertyValue[1]                         := '3';         //'phases';
     PropertyValue[2]                         := Getbus(1);   //'bus1';

     PropertyValue[propKV]                    := Format('%-g', [Storage2Vars.kVStorage2Base]);
     PropertyValue[propKW]                    := Format('%-g', [kW_out]);
     PropertyValue[propPF]                    := Format('%-g', [PFNominal]);
     PropertyValue[propMODEL]                 := '1';
     PropertyValue[propYEARLY]                := '';
     PropertyValue[propDAILY]                 := '';
     PropertyValue[propDUTY]                  := '';
     PropertyValue[propDISPMODE]              := 'Default';
     PropertyValue[propCONNECTION]            := 'wye';
     PropertyValue[propKVAR]                  := Format('%-g', [Presentkvar]);

     PropertyValue[propPCTR]                  := Format('%-g', [pctR]);
     PropertyValue[propPCTX]                  := Format('%-g', [pctX]);

     PropertyValue[propIDLEKW]                := '1';       // PERCENT
     PropertyValue[propCLASS]                 := '1'; //'class'
     PropertyValue[propDISPOUTTRIG]           := '0';   // 0 MEANS NO TRIGGER LEVEL
     PropertyValue[propDISPINTRIG]            := '0';
     PropertyValue[propCHARGEEFF]             := '90';
     PropertyValue[propDISCHARGEEFF]          := '90';
     PropertyValue[propPCTKWOUT]              := '100';
     PropertyValue[propPCTKWIN]               := '100';

     PropertyValue[propInvEffCurve]           := '';
     PropertyValue[propCutin]                 := '0';
     PropertyValue[propCutout]                := '0';
     PropertyValue[propVarFollowInverter]     := 'NO';

     PropertyValue[propVMINPU]                := '0.90';
     PropertyValue[propVMAXPU]                := '1.10';
     PropertyValue[propSTATE]                 := 'IDLING';

     With Storage2Vars Do Begin
           PropertyValue[propKVA]             := Format('%-g', [Storage2Vars.FkVARating]);
           PropertyValue[propkvarLimit]       := Format('%-g', [Fkvarlimit]);
           PropertyValue[propkvarLimitneg]    := Format('%-g', [Fkvarlimitneg]);
           PropertyValue[propKWRATED]         := Format('%-g', [kWRating]);
           PropertyValue[propKWHRATED]        := Format('%-g', [kWhRating]);
           PropertyValue[propKWHSTORED]       := Format('%-g', [kWhStored]);
           PropertyValue[propPCTSTORED]       := Format('%-g', [kWhStored/kWhRating * 100.0])
     End;

     PropertyValue[propPCTRESERVE]            := Format('%-g', [pctReserve]);
     PropertyValue[propCHARGETIME]            := Format('%-g', [ChargeTime]);

     PropertyValue[propUSERMODEL]             := '';  // Usermodel
     PropertyValue[propUSERDATA]              := '';  // Userdata
     PropertyValue[propDYNADLL]               := '';  //
     PropertyValue[propDYNADATA]              := '';  //
     PropertyValue[propDEBUGTRACE]            := 'NO';
     PropertyValue[propBalanced]              := 'NO';
     PropertyValue[propLimited]               := 'NO';
     PropertyValue[proppctkWrated]            := '100';  // Included
     PropertyValue[propPpriority]             := 'NO';   // Included
     PropertyValue[propPFPriority]            := 'NO';

  inherited  InitPropertyValues(NumPropsThisClass);

End;


//----------------------------------------------------------------------------
FUNCTION TStorage2Obj.GetPropertyValue(Index: Integer): String;
Begin

      Result := '';
      With Storage2Vars Do
      CASE Index of
          propKV         : Result := Format('%.6g', [Storage2Vars.kVStorage2Base]);
          propKW         : Result := Format('%.6g', [kW_out]);
          propPF         : Result := Format('%.6g', [PFNominal]);
          propMODEL      : Result := Format('%d',   [VoltageModel]);
          propYEARLY     : Result := YearlyShape;
          propDAILY      : Result := DailyShape;
          propDUTY       : Result := DutyShape;

          propDISPMODE   : Result := ReturnDispMode(DispatchMode);

          {propCONNECTION :;}
          propKVAR       : Result := Format('%.6g', [kvar_out]);
          propPCTR       : Result := Format('%.6g', [pctR]);
          propPCTX       : Result := Format('%.6g', [pctX]);
          propIDLEKW     : Result := Format('%.6g', [pctIdlekW]);
          {propCLASS      = 17;}
          propInvEffCurve: Result := InverterCurve;
          propCutin      : Result := Format('%.6g', [FpctCutin]);
          propCutOut     : Result := Format('%.6g', [FpctCutOut]);
          propVarFollowInverter : If FVarFollowInverter Then Result:='Yes' Else Result := 'No';

          propPminNoVars    : Result := Format('%.6g', [FpctPminNoVars]);
          propPminkvarLimit : Result := Format('%.6g', [FpctPminkvarLimit]);

          propDISPOUTTRIG:    Result := Format('%.6g', [DischargeTrigger]);
          propDISPINTRIG :    Result := Format('%.6g', [ChargeTrigger]);
          propCHARGEEFF  :    Result := Format('%.6g', [pctChargeEff]);
          propDISCHARGEEFF :  Result := Format('%.6g', [pctDischargeEff]);
          propPCTKWOUT   :    Result := Format('%.6g', [pctkWout]);

          propVMINPU     :    Result := Format('%.6g', [VMinPu]);
          propVMAXPU     :    Result := Format('%.6g', [VMaxPu]);
          propSTATE      :    Result := DecodeState;

          {Storage2Vars}
          propKVA        : Result := Format('%.6g', [FkVArating]);
          propKWRATED    : Result := Format('%.6g', [kWrating]);
          propKWHRATED   : Result := Format('%.6g', [kWhrating]);
          propKWHSTORED  : Result := Format('%.6g', [kWHStored]);



          propPCTRESERVE : Result := Format('%.6g', [pctReserve]);
          propUSERMODEL  : Result := UserModel.Name;
          propUSERDATA   : Result := '(' + inherited GetPropertyValue(index) + ')';
          proppctkWrated    : Result := Format('%.6g', [FpctkWrated * 100.0]);
          propDynaDLL    : Result := DynaModel.Name;
          propdynaDATA   : Result := '(' + inherited GetPropertyValue(index) + ')';
          {propDEBUGTRACE = 33;}
          propPCTKWIN    : Result := Format('%.6g', [pctkWin]);
          propPCTSTORED  : Result := Format('%.6g', [kWhStored/kWhRating * 100.0]);
          propCHARGETIME : Result := Format('%.6g', [Chargetime]);
          propBalanced   : If ForceBalanced  Then Result:='Yes' Else Result := 'No';
          propLimited    : If CurrentLimited Then Result:='Yes' Else Result := 'No';
          propkvarLimit    : Result := Format('%.6g', [Fkvarlimit]);
          propkvarLimitneg    : Result := Format('%.6g', [Fkvarlimitneg]);

      ELSE  // take the generic handler
           Result := Inherited GetPropertyValue(index);
      END;
End;


//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.Randomize(Opt:Integer);
Begin

   CASE Opt OF
       0:         RandomMult := 1.0;
       GAUSSIAN:  RandomMult := Gauss(YearlyShapeObj.Mean, YearlyShapeObj.StdDev);
       UNIfORM:   RandomMult := Random;  // number between 0 and 1.0
       LOGNORMAL: RandomMult := QuasiLognormal(YearlyShapeObj.Mean);
   END;

End;

//----------------------------------------------------------------------------
Destructor TStorage2Obj.Destroy;
Begin
      YPrimOpenCond.Free;
      UserModel.Free;
      DynaModel.Free;
      Inherited Destroy;
End;


//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CalcDailyMult(Hr:Double; ActorID : Integer);

Begin
     If (DailyShapeObj <> Nil) Then
       Begin
            ShapeFactor := DailyShapeObj.GetMult(Hr);
       End
     ELSE ShapeFactor := CDOUBLEONE;  // Default to no  variation

     CheckStateTriggerLevel(ShapeFactor.re, ActorID);   // last recourse
End;


//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CalcDutyMult(Hr:Double; ActorID : Integer);

Begin
     If DutyShapeObj <> Nil Then
       Begin
             ShapeFactor := DutyShapeObj.GetMult(Hr);
             CheckStateTriggerLevel(ShapeFactor.re, ActorID);
       End
     ELSE CalcDailyMult(Hr, ActorID);  // Default to Daily Mult If no duty curve specified
End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CalcYearlyMult(Hr:Double; ActorID : Integer);

Begin
     If YearlyShapeObj<>Nil Then
       Begin
            ShapeFactor := YearlyShapeObj.GetMult(Hr) ;
            CheckStateTriggerLevel(ShapeFactor.re, ActorID);
       End
     ELSE CalcDailyMult(Hr, ActorID);  // Defaults to Daily curve
End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.RecalcElementData(ActorID : Integer);
Begin

    VBase95  := VMinPu * VBase;
    VBase105 := VMaxPu * VBase;

   // removed 5/8/17 kvarBase := kvar_out ;  // remember this for Follow Mode

    With Storage2Vars Do Begin

      YeqDischarge := Cmplx((kWrating*1000.0/SQR(vbase)/FNPhases), 0.0);

      // values in ohms for thevenin equivalents
      RThev := pctR * 0.01 * SQR(PresentkV)/FkVARating * 1000.0;      // Changed
      XThev := pctX * 0.01 * SQR(PresentkV)/FkVARating * 1000.0;      // Changed

      CutInkW := FpctCutin * FkVArating / 100.0;
      CutOutkW := FpctCutOut * FkVArating / 100.0;

      if FpctPminNoVars <= 0 then PminNoVars    := -1.0
      else PminNoVars := FpctPminNoVars * kWrating / 100.0;

      if FpctPminkvarLimit <= 0 then PminkvarLimit := -1.0
      else PminkvarLimit := FpctPminkvarLimit * kWrating / 100.0;

      // efficiencies
      ChargeEff    := pctChargeEff    * 0.01;
      DisChargeEff := pctDisChargeEff * 0.01;

      PIdling      := pctIdlekW * kWrating/100.0;

      If Assigned(InverterCurveObj) then
      Begin
        kWOutIdling := PIdling / (InverterCurveObj.GetYValue(Pidling/(FkVArating)));
      End
      Else kWOutIdling := PIdling;

    End;

    SetNominalStorage2Output(ActorID);

    {Now check for errors.  If any of these came out nil and the string was not nil, give warning}
    If YearlyShapeObj=Nil Then
      If Length(YearlyShape)>0 Then DoSimpleMsg('WARNING! Yearly load shape: "'+ YearlyShape +'" Not Found.', 563);
    If DailyShapeObj=Nil Then
      If Length(DailyShape)>0 Then DoSimpleMsg('WARNING! Daily load shape: "'+ DailyShape +'" Not Found.', 564);
    If DutyShapeObj=Nil Then
      If Length(DutyShape)>0 Then DoSimpleMsg('WARNING! Duty load shape: "'+ DutyShape +'" Not Found.', 565);

    If Length(Spectrum)> 0 Then Begin
          SpectrumObj := SpectrumClass[ActorID].Find(Spectrum);
          If SpectrumObj=Nil Then DoSimpleMsg('ERROR! Spectrum "'+Spectrum+'" Not Found.', 566);
    End
    Else SpectrumObj := Nil;

    // Initialize to Zero - defaults to PQ Storage2 element
    // Solution object will reset after circuit modifications

    Reallocmem(InjCurrent, SizeOf(InjCurrent^[1])*Yorder);

    {Update any user-written models}
    If Usermodel.Exists  Then UserModel.FUpdateModel;  // Checks for existence and Selects
    If Dynamodel.Exists  Then Dynamodel.FUpdateModel;  // Checks for existence and Selects

End;
//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.SetNominalStorage2Output(ActorID : Integer);
Begin

   ShapeFactor := CDOUBLEONE;  // init here; changed by curve routine
    // Check to make sure the Storage2 element is ON
   With ActiveCircuit[ActorID], ActiveCircuit[ActorID].Solution Do
   Begin
    IF NOT (IsDynamicModel or IsHarmonicModel) THEN     // Leave Storage2 element in whatever state it was prior to entering Dynamic mode
      Begin
          // Check dispatch to see what state the Storage2 element should be in
          CASE DispatchMode of

                STORE_EXTERNALMODE: ;  // Do nothing
                STORE_LOADMODE: CheckStateTriggerLevel(GeneratorDispatchReference, ActorID);
                STORE_PRICEMODE:CheckStateTriggerLevel(PriceSignal, ActorID);

          ELSE // dispatch off element's loadshapes, If any

           With Solution Do
            CASE Mode OF
                SNAPSHOT:    ; {Just solve for the present kW, kvar}  // Don't check for state change
                DAILYMODE:    CalcDailyMult(DynaVars.dblHour, ActorID); // Daily dispatch curve
                YEARLYMODE:   CalcYearlyMult(DynaVars.dblHour, ActorID);
             (*
                MONTECARLO1,
                MONTEFAULT,
                FAULTSTUDY,
                DYNAMICMODE:   ; // {do nothing for these modes}
             *)
                GENERALTIME: Begin
                                // This mode allows use of one class of load shape
                                case ActiveCircuit[ActorID].ActiveLoadShapeClass of
                                  USEDAILY:   CalcDailyMult(DynaVars.dblHour, ActorID);
                                  USEYEARLY:  CalcYearlyMult(DynaVars.dblHour, ActorID);
                                  USEDUTY:    CalcDutyMult(DynaVars.dblHour, ActorID);
                                else
                                  ShapeFactor := CDOUBLEONE     // default to 1 + j1 if not known
                                end;
                             End;
                // Assume Daily curve, If any, for the following
                MONTECARLO2,
                MONTECARLO3,
                LOADDURATION1,
                LOADDURATION2: CalcDailyMult(DynaVars.dblHour, ActorID);
                PEAKDAY:       CalcDailyMult(DynaVars.dblHour, ActorID);

                DUTYCYCLE:     CalcDutyMult(DynaVars.dblHour, ActorID) ;
                {AUTOADDFLAG:  ; }
            End;

          END;

          ComputekWkvar;

          {
           Pnominalperphase is net at the terminal.  If supplying idling losses, when discharging,
           the Storage2 supplies the idling losses. When charging, the idling losses are subtracting from the amount
           entering the Storage2 element.
          }

          With Storage2Vars Do
          Begin
            Pnominalperphase   := 1000.0 * kW_out  / Fnphases;
            Qnominalperphase   := 1000.0 * kvar_out  / Fnphases;
          End;


          CASE VoltageModel  of
            //****  Fix this when user model gets connected in
               3: // Yeq := Cinv(cmplx(0.0, -StoreVARs.Xd))  ;  // Gets negated in CalcYPrim
          ELSE
             {
              Yeq no longer used for anything other than this calculation of Yeq95, Yeq105 and
              constant Z power flow model
             }
              Yeq  := CDivReal(Cmplx(Pnominalperphase, -Qnominalperphase), Sqr(Vbase));   // Vbase must be L-N for 3-phase
              If   (Vminpu <> 0.0) Then Yeq95 := CDivReal(Yeq, sqr(Vminpu))  // at 95% voltage
                                   Else Yeq95 := Yeq; // Always a constant Z model

              If   (Vmaxpu <> 0.0) Then  Yeq105 := CDivReal(Yeq, Sqr(Vmaxpu))   // at 105% voltage
                                   Else  Yeq105 := Yeq;
          END;
          { Like Model 7 generator, max current is based on amount of current to get out requested power at min voltage
          }
          With Storage2Vars Do
          Begin
              PhaseCurrentLimit  := Cdivreal( Cmplx(Pnominalperphase,Qnominalperphase), VBase95) ;
              MaxDynPhaseCurrent := Cabs(PhaseCurrentLimit);
          End;

              { When we leave here, all the Yeq's are in L-N values}

     End;  {If  NOT (IsDynamicModel or IsHarmonicModel)}
   End;  {With ActiveCircuit[ActiveActor]}

   // If Storage2 element state changes, force re-calc of Y matrix
   If FStateChanged Then  Begin
      YprimInvalid[ActorID]  := TRUE;
      FStateChanged := FALSE;  // reset the flag
   End;

End;
// ===========================================================================================
PROCEDURE TStorage2Obj.ComputekWkvar;
Begin

     ComputePresentkW;
     ComputeInverterPower; // apply inverter eff after checking for cutin/cutout

end;
//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.ComputePresentkW;
VAR
    OldState :Integer;
Begin
    OldState := Fstate;
    FStateDesired := OldState;
    With Storage2Vars Do
    CASE FState of

       STORE_CHARGING: Begin
                            If kWhStored < kWhRating Then
                                CASE DispatchMode of
                                    STORE_FOLLOW: Begin
                                      kW_out := kWRating * ShapeFactor.re;
                                      FpctkWin := abs(ShapeFactor.re) * 100.0;  // keep %charge updated
                                    End
                                ELSE
                                     kW_out := -kWRating * pctkWin / 100.0;
                                END
                            ELSE Fstate := STORE_IDLING;   // all charged up
                       End;


       STORE_DISCHARGING: Begin
                                If kWhStored > kWhReserve Then
                                    CASE DispatchMode of
                                        STORE_FOLLOW: Begin
                                            kW_out := kWRating * ShapeFactor.re;
                                            FpctkWOut := abs(ShapeFactor.re) * 100.0;  // keep %discharge updated
                                        End
                                    ELSE
                                         kW_out := kWRating * pctkWout / 100.0;
                                    END
                                ELSE Fstate := STORE_IDLING;  // not enough Storage2 to discharge
                          End;

    END;

    {If idling output is only losses}

    If Fstate=STORE_IDLING Then  Begin
      kW_out := -kWOutIdling;
    End;

    If OldState <> Fstate Then FstateChanged := TRUE;

End;

// ===========================================================================================
PROCEDURE TStorage2Obj.ComputeInverterPower;
VAR

   kVA_Gen :Double;
   OldState :Integer;
   TempPF: Double; // temporary power factor
   Qramp_limit: Double;

Begin

    // Reset CurrentkvarLimit to kvarLimit
    CurrentkvarLimit:= Storage2Vars.Fkvarlimit;
    CurrentkvarLimitNeg:= Storage2Vars.Fkvarlimitneg;

    With Storage2Vars Do
    Begin

      If Assigned(InverterCurveObj) then
      Begin
        if Fstate = STORE_DISCHARGING then
          Begin
            FCutOutkWAC := CutOutkW * InverterCurveObj.GetYValue(abs(CutOutkW)/FkVArating);
            FCutInkWAC  := CutInkW  * InverterCurveObj.GetYValue(abs(CutInkW)/FkVArating);
          End
        else  // Charging or Idling
          Begin
            FCutOutkWAC := CutOutkW / InverterCurveObj.GetYValue(abs(CutOutkW)/FkVArating);
            FCutInkWAC  := CutInkW  / InverterCurveObj.GetYValue(abs(CutInkW)/FkVArating);
          End;
      End
      Else // Assume Ideal Inverter
      Begin
        FCutOutkWAC := CutOutkW;
        FCutInkWAC  := CutInkW;
      End;

      OldState := Fstate;

      // CutIn/CutOut checking performed on the AC side.
       If FInverterON
        Then Begin
          If abs(kW_Out) < FCutOutkWAC
            Then  Begin
              FInverterON := FALSE;
              Fstate := STORE_IDLING;
            End;
        End
        ELSE
        Begin
          If abs(kW_Out) >= FCutInkWAC
            Then  Begin
              FInverterON := TRUE;
            End
            Else Begin
              Fstate := STORE_IDLING;
            End;
        End;


      If OldState <> Fstate Then FstateChanged := TRUE;

      // Set inverter output
      If FInverterON
      Then Begin
          kWOut_Calc;
      End
      ELSE Begin
        // Idling
          kW_Out := -kWOutIdling; // In case it has just turned off due to %CutIn/%CutOut. Necessary to make sure SOC will be kept constant (higher priority than the %CutIn/%CutOut operation)
      End;


      // Calculate kvar value based on operation mode (PF or kvar)
      if FState = STORE_IDLING then
        // If in Idling state, check for kvarlimit only
        begin
          if varMode = VARMODEPF Then
            begin
//              kvar_out := 0.0; //kW = 0 leads to kvar = 0 in constant PF Mode
              kvar_out := kW_out * sqrt(1.0/SQR(PFnominal) - 1.0) * sign(PFnominal);

              if (kvar_out > 0.0) and (abs(kvar_out) > Fkvarlimit) then kvar_Out := Fkvarlimit
              else if (kvar_out < 0.0) and (abs(kvar_out) > Fkvarlimitneg) then kvar_Out := Fkvarlimitneg*sign(kvarRequested)

            end
          else  // kvarRequested might have been set either internally or by an InvControl
            begin

              if (kvarRequested > 0.0) and (abs(kvarRequested) > Fkvarlimit) then kvar_Out := Fkvarlimit
              else if (kvarRequested < 0.0) and (abs(kvarRequested) > Fkvarlimitneg) then kvar_Out := Fkvarlimitneg*sign(kvarRequested)
              else kvar_Out := kvarRequested;

            end;
        end
      else
        // If in either Charging or Discharging states
        begin
            if (abs(kW_Out) < PminNoVars) then
              Begin
                kvar_out := 0.0;  // Check minimum P for Q gen/absorption. if PminNoVars is disabled (-1), this will always be false

                CurrentkvarLimit:=0; CurrentkvarLimitNeg:= 0.0;  // InvControl uses this.
              End
            Else if varMode = VARMODEPF Then
              Begin
                   IF     PFnominal = 1.0 Then kvar_out := 0.0
                   ELSE
                      Begin
                        kvar_out := kW_out * sqrt(1.0/SQR(PFnominal) - 1.0) * sign(PFnominal); //kvar_out desired by constant PF

                        // Check Limits
                        if abs(kW_out) < PminkvarLimit then // straight line limit check. if PminkvarLimit is disabled (-1), this will always be false.
                          begin
                            // straight line starts at max(PminNoVars, FCutOutkWAC)
                            // if CutOut differs from CutIn, take cutout since it is assumed that CutOut <= CutIn always.
                            if abs(kW_out) >= max(PminNoVars, FCutOutkWAC) then
                              begin
                                if (kvar_Out > 0.0) then
                                  begin
                                    Qramp_limit := Fkvarlimit / PminkvarLimit * abs(kW_out);   // generation limit
                                  end
                                else if (kvar_Out < 0.0) then
                                  begin
                                    Qramp_limit := Fkvarlimitneg / PminkvarLimit * abs(kW_out);   // absorption limit
                                  end;

                                  if abs(kvar_Out) > Qramp_limit then
                                  Begin
                                    kvar_out := Qramp_limit * sign(kW_out) * sign(PFnominal);

                                    if kvar_out > 0 then CurrentkvarLimit    := Qramp_limit;  // For use in InvControl
                                    if kvar_out < 0 then CurrentkvarLimitNeg := Qramp_limit;  // For use in InvControl

                                  End;

                              end
                          end
                        Else if (abs(kvar_Out) > Fkvarlimit) or (abs(kvar_Out) > Fkvarlimitneg) then  // Other cases, check normal kvarLimit and kvarLimitNeg
                          begin
                            if (kvar_Out > 0.0) then kvar_out := Fkvarlimit * sign(kW_out) * sign(PFnominal)
                            else kvar_out := Fkvarlimitneg * sign(kW_out) * sign(PFnominal);

                            if PF_Priority then // Forces constant power factor when kvar limit is exceeded and PF Priority is true.
                              Begin
                                kW_out :=  kvar_out* sqrt(1.0/(1.0 - Sqr(PFnominal)) - 1.0) * sign(PFnominal);
                              End;

                          end;

                      end;
              End
            ELSE  // VARMODE kvar
              Begin
                  // Check limits
                  if abs(kW_out) < PminkvarLimit then // straight line limit check. if PminkvarLimit is disabled (-1), this will always be false.
                    begin
                      // straight line starts at max(PminNoVars, FCutOutkWAC)
                      // if CutOut differs from CutIn, take cutout since it is assumed that CutOut <= CutIn always.
                      if abs(kW_out) >= max(PminNoVars, FCutOutkWAC) then
                        begin
                          if (kvarRequested > 0.0) then
                            begin
                              Qramp_limit         := Fkvarlimit / PminkvarLimit * abs(kW_out);   // generation limit
                              CurrentkvarLimit    := Qramp_limit;    // For use in InvControl
                            end
                          else if (kvarRequested < 0.0) then
                            begin
                              Qramp_limit         := Fkvarlimitneg / PminkvarLimit * abs(kW_out);   // absorption limit
                              CurrentkvarLimitNeg := Qramp_limit;   // For use in InvControl
                            end;

                           if abs(kvarRequested) > Qramp_limit then kvar_out := Qramp_limit * sign(kvarRequested)
                           else kvar_out := kvarRequested;

                        end;

                    end
                  else if ((kvarRequested > 0.0) and (abs(kvarRequested) > Fkvarlimit)) or ((kvarRequested < 0.0) and (abs(kvarRequested) > Fkvarlimitneg)) then
                    begin

                      if (kvarRequested > 0.0) then kvar_Out := Fkvarlimit * sign(kvarRequested)
                      else kvar_Out := Fkvarlimitneg * sign(kvarRequested);

                      // Forces constant power factor when kvar limit is exceeded and PF Priority is true. Temp PF is calculated based on kvarRequested
                      // PF Priority is not valid if controlled by an InvControl operating in at least one amongst VV and DRC modes
                      if PF_Priority and (not FVVMode or not FDRCMode) then
                        Begin
                          if abs(kvarRequested) > 0.0  then
                            begin

                                TempPF := cos(arctan(abs(kvarRequested/kW_out)));
                                kW_out := abs(kvar_out) * sqrt(1.0/(1.0 - Sqr(TempPF)) - 1.0) * sign(kW_out);
                            end
                        End

                    end
                  else kvar_Out := kvarRequested;
              end;
        end;

      if (FInverterON = FALSE) and (FVarFollowInverter = TRUE) then kvar_out := 0.0;

      // Limit kvar and kW so that kVA of inverter is not exceeded
      kVA_Gen := Sqrt(Sqr(kW_out) + Sqr(kvar_out));

      if kVA_Gen > FkVArating Then
        Begin

          kVA_exceeded := True;

          // Expectional case: When kVA is exceeded and in idling state, we force P priority always
          if (FState = STORE_IDLING) then
            Begin
              kvar_Out :=  Sqrt(SQR(FkVArating) - SQR(kW_Out)) * sign(kvar_Out);
            End

          // Regular Cases
          Else If (varMode = VARMODEPF) and PF_Priority then
            // Operates under constant power factor when kVA rating is exceeded. PF must be specified and PFPriority must be TRUE
            Begin
                kW_out := FkVArating * abs(PFnominal) * sign(kW_out);

                kvar_out := FkVArating * sqrt(1 - Sqr(PFnominal)) * sign(kW_out) * sign(PFnominal);
            End
          Else if (varMode = VARMODEKVAR) and PF_Priority and (not FVVMode or not FDRCMode) then
            // Operates under constant power factor (PF implicitly calculated based on kw and kvar)
            Begin
                if abs(kvar_out) = Fkvarlimit then
                  begin   // for handling cases when kvar limit and inverter's kVA limit are exceeded
                      kW_out := FkVArating * abs(TempPF) * sign(kW_out);  // Temp PF has already been calculated at this point
                  end
                else
                  begin
                      kW_out := FkVArating * abs(cos(ArcTan(kvarRequested/kW_out))) * sign(kW_out);
                  end;

                kvar_out := FkVArating * abs(sin(ArcCos(kW_out/FkVArating))) * sign(kvarRequested)
            end
          else
            Begin
                If P_Priority Then
                  Begin  // back off the kvar
                      If kW_out > FkVArating Then
                        Begin
                            kW_out   := FkVArating;
                            kvar_out := 0.0;
                        End

                      ELSE kvar_Out :=  Sqrt(SQR(FkVArating) - SQR(kW_Out)) * sign(kvar_Out);
                  End
                Else  kW_Out :=  Sqrt(SQR(FkVArating) - SQR(kvar_Out)) * sign(kW_Out); // Q Priority   (Default) back off the kW

            End;

        End  {With Storage2Vars}
        else if abs(kVA_Gen - FkVArating)/FkVArating < 0.0005 then kVA_exceeded := True
        else kVA_exceeded := False;

    End;

end;
//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CalcYPrimMatrix(Ymatrix:TcMatrix;ActorID : Integer);

VAR
       Y , Yij  :Complex;
       i, j     :Integer;
       FreqMultiplier :Double;

Begin

   FYprimFreq := ActiveCircuit[ActorID].Solution.Frequency  ;
   FreqMultiplier := FYprimFreq / BaseFrequency;

   With  ActiveCircuit[ActorID].solution  Do
   IF {IsDynamicModel or} IsHarmonicModel Then
     Begin
       {Yeq is computed from %R and %X -- inverse of Rthev + j Xthev}
           CASE Fstate of
               STORE_CHARGING:    Y := YeqDischarge;
               STORE_IDLING:      Y := cmplx(0, 0);
               STORE_DISCHARGING: Y := cnegate(YeqDischarge);

               // old way Y  := Yeq   // L-N value computed in initialization routines
           END;

           IF Connection=1 Then Y := CDivReal(Y, 3.0); // Convert to delta impedance
           Y.im := Y.im / FreqMultiplier;
           Yij := Cnegate(Y);
           FOR i := 1 to Fnphases Do
             Begin
                   CASE Connection of
                     0: Begin
                             Ymatrix.SetElement(i, i, Y);
                             Ymatrix.AddElement(Fnconds, Fnconds, Y);
                             Ymatrix.SetElemsym(i, Fnconds, Yij);
                        End;
                     1: Begin   {Delta connection}
                             Ymatrix.SetElement(i, i, Y);
                             Ymatrix.AddElement(i, i, Y);  // put it in again
                             For j := 1 to i-1 Do Ymatrix.SetElemsym(i, j, Yij);
                        End;
                   END;
             End;
     End

   ELSE
     Begin  //  Regular power flow Storage2 element model

       {Yeq is always expected as the equivalent line-neutral admittance}


           CASE Fstate of
               STORE_CHARGING:    Y := YeqDischarge;
               STORE_IDLING:      Y := cmplx(0.0,0.0);
               STORE_DISCHARGING: Y := cnegate(YeqDischarge);
           END;

       //---DEBUG--- WriteDLLDebugFile(Format('t=%.8g, Change To State=%s, Y=%.8g +j %.8g',[ActiveCircuit[ActiveActor].Solution.dblHour, StateToStr, Y.re, Y.im]));

       // ****** Need to modify the base admittance for real harmonics calcs
       Y.im           := Y.im / FreqMultiplier;

         CASE Connection OF

           0: With YMatrix Do
              Begin // WYE
                     Yij := Cnegate(Y);
                     FOR i := 1 to Fnphases Do
                     Begin
                          SetElement(i, i, Y);
                          AddElement(Fnconds, Fnconds, Y);
                          SetElemsym(i, Fnconds, Yij);
                     End;
              End;

           1: With YMatrix Do
              Begin  // Delta  or L-L
                    Y    := CDivReal(Y, 3.0); // Convert to delta impedance
                    Yij  := Cnegate(Y);
                    FOR i := 1 to Fnphases Do
                    Begin
                         j := i+1;
                         If j>Fnconds Then j := 1;  // wrap around for closed connections
                         AddElement(i,i, Y);
                         AddElement(j,j, Y);
                         AddElemSym(i,j, Yij);
                    End;
              End;

         END;
     End;  {ELSE IF Solution.mode}

End;

//----------------------------------------------------------------------------
FUNCTION TStorage2Obj.NormalizeToTOD(h: Integer; sec: Double): Double;
// Normalize time to a floating point number representing time of day If Hour > 24
// time should be 0 to 24.
VAR
    HourOfDay :Integer;

Begin

   IF    h > 23
   THEN  HourOfDay := (h - (h div 24)*24)
   ELSE  HourOfDay := h;

   Result := HourOfDay + sec/3600.0;

   If   Result > 24.0
   THEN Result := Result - 24.0;   // Wrap around

End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CheckStateTriggerLevel(Level: Double;ActorID : Integer);
{This is where we set the state of the Storage2 element}

VAR
     OldState :Integer;

Begin
     FStateChanged := FALSE;

     OldState := Fstate;

     With Storage2Vars Do
     If DispatchMode =  STORE_FOLLOW Then
     Begin

         // set charge and discharge modes based on sign of loadshape
         If      (Level > 0.0) and (kWhStored > kWhReserve) Then Storage2State := STORE_DISCHARGING
         ELSE If (Level < 0.0) and (kWhStored < kWhRating)  Then Storage2State := STORE_CHARGING
         ELSE Storage2State := STORE_IDLING;

     End
     ELSE
     Begin   // All other dispatch modes  Just compare to trigger value

        If (ChargeTrigger=0.0) and (DischargeTrigger=0.0) Then   Exit;

      // First see If we want to turn off Charging or Discharging State
         CASE Fstate of
             STORE_CHARGING:    If (ChargeTrigger    <> 0.0) Then If (ChargeTrigger    < Level) or (kWhStored >= kWHRating)  Then Fstate := STORE_IDLING;
             STORE_DISCHARGING: If (DischargeTrigger <> 0.0) Then If (DischargeTrigger > Level) or (kWhStored <= kWHReserve) Then Fstate := STORE_IDLING;
         END;

      // Now check to see If we want to turn on the opposite state
         CASE Fstate of
             STORE_IDLING: Begin
                               If      (DischargeTrigger <> 0.0) and (DischargeTrigger < Level) and (kWhStored > kWHReserve) Then FState := STORE_DISCHARGING
                               Else If (ChargeTrigger    <> 0.0) and (ChargeTrigger    > Level) and (kWhStored < kWHRating)  Then Fstate := STORE_CHARGING;

                               // Check to see If it is time to turn the charge cycle on If it is not already on.
                               If Not (Fstate = STORE_CHARGING) Then
                                 If ChargeTime > 0.0 Then
                                       WITH ActiveCircuit[ActorID].Solution Do Begin
                                           If abs(NormalizeToTOD(DynaVars.intHour, DynaVARs.t) - ChargeTime) < DynaVARs.h/3600.0 Then Fstate := STORE_CHARGING;
                                       End;
                           End;
         END;
     End;

     If OldState <> Fstate
     Then Begin
          FstateChanged := TRUE;
          YprimInvalid[ActorID] := TRUE;
     End;
End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.CalcYPrim(ActorID : Integer);

VAR
        i:integer;

Begin

     // Build only shunt Yprim
     // Build a dummy Yprim Series so that CalcV Does not fail
     If YprimInvalid[ActorID]
     Then  Begin
         If YPrim_Shunt<>nil Then YPrim_Shunt.Free;
         YPrim_Shunt := TcMatrix.CreateMatrix(Yorder);
         IF YPrim_Series <> nil THEN Yprim_Series.Free;
         YPrim_Series := TcMatrix.CreateMatrix(Yorder);
          If YPrim <> nil Then  YPrim.Free;
         YPrim := TcMatrix.CreateMatrix(Yorder);
     End
     ELSE Begin
          YPrim_Shunt.Clear;
          YPrim_Series.Clear;
          YPrim.Clear;
     End;

     SetNominalStorage2Output(ActorID);
     CalcYPrimMatrix(YPrim_Shunt, ActorID);

     // Set YPrim_Series based on diagonals of YPrim_shunt  so that CalcVoltages Doesn't fail
     For i := 1 to Yorder Do Yprim_Series.SetElement(i, i, CmulReal(Yprim_Shunt.Getelement(i, i), 1.0e-10));

     YPrim.CopyFrom(YPrim_Shunt);

     // Account for Open Conductors
     Inherited CalcYPrim(ActorID);

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.StickCurrInTerminalArray(TermArray:pComplexArray; Const Curr:Complex; i:Integer);
 {Add the current into the proper location according to connection}

 {Reverse of similar routine in load  (Cnegates are switched)}

VAR j :Integer;

Begin
    CASE Connection OF
         0: Begin  //Wye
                 Caccum(TermArray^[i], Curr );
                 Caccum(TermArray^[Fnconds], Cnegate(Curr) ); // Neutral
            End;
         1: Begin //DELTA
                 Caccum(TermArray^[i], Curr );
                 j := i + 1;
                 If j > Fnconds Then j := 1;
                 Caccum(TermArray^[j], Cnegate(Curr) );
            End;
    End;
End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.WriteTraceRecord(const s:string; ActorID : Integer);

VAR i:Integer;

Begin

      Try
      If (Not InshowResults) Then
      Begin
           Append(TraceFile);
           Write(TraceFile,Format('%-.g, %d, %-.g, ',
                    [ActiveCircuit[ActorID].Solution.DynaVars.dblHour,
                    ActiveCircuit[ActorID].Solution.Iteration,
                    ActiveCircuit[ActorID].LoadMultiplier]),
                    GetSolutionModeID,', ',
                    GetLoadModel,', ',
                    VoltageModel:0,', ',
                   (Qnominalperphase*3.0/1.0e6):8:2,', ',
                   (Pnominalperphase*3.0/1.0e6):8:2,', ',
                   s,', ');
           For i := 1 to nphases Do Write(TraceFile,(Cabs(InjCurrent^[i])):8:1 ,', ');
           For i := 1 to nphases Do Write(TraceFile,(Cabs(ITerminal^[i])):8:1 ,', ');
           For i := 1 to nphases Do Write(TraceFile,(Cabs(Vterminal^[i])):8:1 ,', ');
           For i := 1 to NumVariables Do Write(TraceFile, Format('%-.g, ',[Variable[i]]));


   //****        Write(TraceFile,VThevMag:8:1 ,', ', StoreVARs.Theta*180.0/PI);
           Writeln(TRacefile);
           CloseFile(TraceFile);
      End;
      Except
            On E:Exception Do Begin End;

      End;
End;
// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.DoConstantPQStorage2Obj(ActorID : Integer);

{Compute total terminal current for Constant PQ}

VAR
   i : Integer;
   Curr,
//   CurrIdlingZ,
   VLN, VLL :  Complex;
   //---DEBUG--- S:Complex;
   VmagLN,
   VmagLL : Double;
   V012 : Array[0..2] of Complex;  // Sequence voltages

Begin
     //Treat this just like the Load model

    CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
    ZeroITerminal;

    //---DEBUG--- WriteDLLDebugFile(Format('t=%.8g, State=%s, Iyprim= %s', [ActiveCircuit[ActiveActor].Solution.dblHour, StateToStr, CmplxArrayToString(InjCurrent, Yprim.Order) ]));

//    CASE FState of
//      STORE_IDLING:  // YPrim current is only current
//             Begin
//                For i := 1 to FNPhases Do
//                Begin
//                    Curr :=  InjCurrent^[i];
//                    StickCurrInTerminalArray(ITerminal, Curr, i);  // Put YPrim contribution into Terminal array taking into account connection
//                    set_ITerminalUpdated(True, ActorID);
//                    StickCurrInTerminalArray(InjCurrent, Cnegate(Curr), i);    // Compensation current is zero since terminal current is same as Yprim contribution
//                    //---DEBUG--- S := Cmul(Vterminal^[i] , Conjg(Iterminal^[i]));  // for debugging below
//                    //---DEBUG--- WriteDLLDebugFile(Format('        Phase=%d, Pnom=%.8g +j %.8g',[i, S.re, S.im ]));
//                End;
//             //---DEBUG--- WriteDLLDebugFile(Format('        Icomp=%s ', [CmplxArrayToString(InjCurrent, Yprim.Order) ]));
//             End;
//    ELSE   // For Charging and Discharging

        CalcVTerminalPhase(ActorID); // get actual voltage across each phase of the load

        If ForceBalanced and (Fnphases=3)
        Then Begin  // convert to pos-seq only
            Phase2SymComp(Vterminal, @V012);
            V012[0] := CZERO; // Force zero-sequence voltage to zero
            V012[2] := CZERO; // Force negative-sequence voltage to zero
            SymComp2Phase(Vterminal, @V012);  // Reconstitute Vterminal as balanced
        End;

        FOR i := 1 to Fnphases Do Begin

            CASE Connection of

             0: Begin  {Wye}
                  VLN    := Vterminal^[i];
                  VMagLN := Cabs(VLN);
                  IF   VMagLN <= VBase95 Then Curr := Cmul(Yeq95, VLN)  // Below 95% use an impedance model
                  ELSE If VMagLN > VBase105 Then Curr := Cmul(Yeq105, VLN)  // above 105% use an impedance model
                  ELSE Curr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLN));  // Between 95% -105%, constant PQ

                  If CurrentLimited Then
                       If Cabs(Curr) >  MaxDynPhaseCurrent Then
                          Curr := Conjg( Cdiv( PhaseCurrentLimit, CDivReal(VLN, VMagLN)) );
                End;

              1: Begin  {Delta}
                  VLL    := Vterminal^[i];
                  VMagLL := Cabs(VLL);
                  If Fnphases > 1 Then VMagLN := VMagLL/SQRT3 Else VMagLN := VmagLL;  // L-N magnitude
                  IF   VMagLN <= VBase95  THEN  Curr := Cmul(CdivReal(Yeq95, 3.0), VLL)  // Below 95% use an impedance model
                  ELSE If VMagLN > VBase105 Then  Curr := Cmul(CdivReal(Yeq105, 3.0), VLL)  // above 105% use an impedance model
                  ELSE Curr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLL));  // Between 95% -105%, constant PQ

                  If CurrentLimited Then
                      If Cabs(Curr)*SQRT3 >  MaxDynPhaseCurrent Then
                          Curr := Conjg( Cdiv( PhaseCurrentLimit, CDivReal(VLL, VMagLN)) ); // Note VmagLN has sqrt3 factor in it
                End;

             END;

         //---DEBUG--- WriteDLLDebugFile(Format('        Phase=%d, Pnom=%.8g +j %.8g', [i, Pnominalperphase, Qnominalperphase ]));

            StickCurrInTerminalArray(ITerminal, Cnegate(Curr), i);  // Put into Terminal array taking into account connection
            set_ITerminalUpdated(TRUE, ActorID);
            StickCurrInTerminalArray(InjCurrent, Curr, i);  // Put into Terminal array taking into account connection
        End;
        //---DEBUG--- WriteDLLDebugFile(Format('        Icomp=%s ', [CmplxArrayToString(InjCurrent, Yprim.Order) ]));
//    END;

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.DoConstantZStorage2Obj(ActorID : Integer);

{constant Z model}
VAR
   i    :Integer;
   Curr,
   Yeq2 :Complex;
   V012 : Array[0..2] of Complex;  // Sequence voltages

Begin

// Assume Yeq is kept up to date

    CalcYPrimContribution(InjCurrent,ActorID);  // Init InjCurrent Array
    CalcVTerminalPhase(ActorID); // get actual voltage across each phase of the load
    ZeroITerminal;
    If Connection=0 Then Yeq2 := Yeq Else Yeq2 := CdivReal(Yeq, 3.0);

    If ForceBalanced and (Fnphases=3)
    Then Begin  // convert to pos-seq only
        Phase2SymComp(Vterminal, @V012);
        V012[0] := CZERO; // Force zero-sequence voltage to zero
        V012[2] := CZERO; // Force negative-sequence voltage to zero
        SymComp2Phase(Vterminal, @V012);  // Reconstitute Vterminal as balanced
    End;

     FOR i := 1 to Fnphases Do Begin

        Curr := Cmul(Yeq2, Vterminal^[i]);   // Yeq is always line to neutral
        StickCurrInTerminalArray(ITerminal, Cnegate(Curr), i);  // Put into Terminal array taking into account connection
        set_ITerminalUpdated(TRUE, ActorID);
        StickCurrInTerminalArray(InjCurrent, Curr, i);  // Put into Terminal array taking into account connection

     End;

End;


// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.DoUserModel(ActorID : Integer);
{Compute total terminal Current from User-written model}
VAR
   i:Integer;

Begin

   CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array

   If UserModel.Exists Then    // Check automatically selects the usermodel If true
     Begin
         UserModel.FCalc (Vterminal, Iterminal);
         set_ITerminalUpdated(TRUE, ActorID);
         With ActiveCircuit[ActorID].Solution Do  Begin          // Negate currents from user model for power flow Storage2 element model
               FOR i := 1 to FnConds Do Caccum(InjCurrent^[i], Cnegate(Iterminal^[i]));
         End;
     End
   Else
     Begin
        DoSimpleMsg('Storage2.' + name + ' model designated to use user-written model, but user-written model is not defined.', 567);
     End;

End;



// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.DoDynamicMode;

{Compute Total Current and add into InjTemp}
{
   For now, just assume the Storage2 element Thevenin voltage is constant
   for the duration of the dynamic simulation.
}
{****}
Var
    i :Integer;
    V012,
    I012  : Array[0..2] of Complex;


    procedure CalcVthev_Dyn;
    begin
         With Storage2Vars Do Vthev := pclx(VthevMag, Theta);   // keeps theta constant
    end;

Begin

{****}  // Test using DESS model
   // Compute Vterminal

  If DynaModel.Exists  Then  DoDynaModel(ActorID)   // do user-written model

  Else Begin

        CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
        ZeroITerminal;

       // Simple Thevenin equivalent
       // compute terminal current (Iterminal) and take out the Yprim contribution

        With Storage2Vars Do
        case Fnphases of
            1:Begin
                  CalcVthev_Dyn;  // Update for latest phase angle
                  ITerminal^[1] := CDiv(CSub(Csub(VTerminal^[1], Vthev), VTerminal^[2]), Zthev);
                  If CurrentLimited Then
                    If Cabs(Iterminal^[1]) > MaxDynPhaseCurrent Then   // Limit the current but keep phase angle
                        ITerminal^[1] := ptocomplex(topolar(MaxDynPhaseCurrent, cang(Iterminal^[1])));
                   ITerminal^[2] := Cnegate(ITerminal^[1]);
              End;
            3: Begin
                  Phase2SymComp(Vterminal, @V012);

                  // Positive Sequence Contribution to Iterminal
                  CalcVthev_Dyn;  // Update for latest phase angle

                  // Positive Sequence Contribution to Iterminal
                  I012[1] := CDiv(Csub(V012[1], Vthev), Zthev);

                  If CurrentLimited and (Cabs(I012[1]) > MaxDynPhaseCurrent) Then   // Limit the pos seq current but keep phase angle
                     I012[1] := ptocomplex(topolar(MaxDynPhaseCurrent, cang(I012[1])));

                  If ForceBalanced Then Begin
                      I012[2] := CZERO;
                  End Else
                      I012[2] := Cdiv(V012[2], Zthev);  // for inverter

                  I012[0] := CZERO ;

                  SymComp2Phase(ITerminal, @I012);  // Convert back to phase components

                End;
        Else
                DoSimpleMsg(Format('Dynamics mode is implemented only for 1- or 3-phase Storage2 Element. Storage2.%s has %d phases.', [name, Fnphases]), 5671);
                SolutionAbort := TRUE;
        END;

    {Add it into inj current array}
        FOR i := 1 to FnConds Do Caccum(InjCurrent^[i], Cnegate(Iterminal^[i]));

  End;

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
procedure TStorage2Obj.DoDynaModel(ActorID : Integer);
Var
    DESSCurr: Array[1..6] of Complex;  // Temporary biffer
    i :Integer;

begin
// do user written dynamics model

  With ActiveCircuit[ActorID].Solution Do
  Begin  // Just pass node voltages to ground and let dynamic model take care of it
     For i := 1 to FNconds Do VTerminal^[i] := NodeV^[NodeRef^[i]];
     Storage2Vars.w_grid := TwoPi * Frequency;
  End;

  DynaModel.FCalc(Vterminal, @DESSCurr);

  CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
  ZeroITerminal;

  For i := 1 to Fnphases Do
  Begin
      StickCurrInTerminalArray(ITerminal, Cnegate(DESSCurr[i]), i);  // Put into Terminal array taking into account connection
      set_ITerminalUpdated(TRUE, ActorID);
      StickCurrInTerminalArray(InjCurrent, DESSCurr[i], i);  // Put into Terminal array taking into account connection
  End;

end;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.DoHarmonicMode(ActorID : Integer);

{Compute Injection Current Only when in harmonics mode}

{Assumes spectrum is a voltage source behind subtransient reactance and YPrim has been built}
{Vd is the fundamental frequency voltage behind Xd" for phase 1}

VAR
   i     :Integer;
   E     :Complex;
   Storage2Harmonic :double;

Begin

   ComputeVterminal(ActorID);

   WITH ActiveCircuit[ActorID].Solution Do
     Begin
        Storage2Harmonic := Frequency/Storage2Fundamental;
        If SpectrumObj <> Nil Then
             E := CmulReal(SpectrumObj.GetMult(Storage2Harmonic), Storage2Vars.VThevHarm) // Get base harmonic magnitude
        Else E := CZERO;

        RotatePhasorRad(E, Storage2Harmonic, Storage2Vars.ThetaHarm);  // Time shift by fundamental frequency phase shift
        FOR i := 1 to Fnphases DO Begin
           cBuffer[i] := E;
           If i < Fnphases Then RotatePhasorDeg(E, Storage2Harmonic, -120.0);  // Assume 3-phase Storage2 element
        End;
     END;

   {Handle Wye Connection}
   IF Connection=0 THEN cbuffer[Fnconds] := Vterminal^[Fnconds];  // assume no neutral injection voltage

   {Inj currents = Yprim (E) }
   YPrim.MVMult(InjCurrent,@cBuffer);

End;


// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.CalcVTerminalPhase(ActorID : Integer);

VAR i,j:Integer;

Begin

{ Establish phase voltages and stick in Vterminal}
   Case Connection OF

     0:Begin
         With ActiveCircuit[ActorID].Solution Do
           FOR i := 1 to Fnphases Do Vterminal^[i] := VDiff(NodeRef^[i], NodeRef^[Fnconds]);
       End;

     1:Begin
         With ActiveCircuit[ActorID].Solution Do
          FOR i := 1 to Fnphases Do  Begin
             j := i + 1;
             If j > Fnconds Then j := 1;
             Vterminal^[i] := VDiff( NodeRef^[i] , NodeRef^[j]);
          End;
       End;

   End;

   Storage2SolutionCount := ActiveCircuit[ActorID].Solution.SolutionCount;

End;



// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
(*
PROCEDURE TStorage2Obj.CalcVTerminal;
{Put terminal voltages in an array}
Begin
   ComputeVTerminal;
   Storage2SolutionCount := ActiveCircuit[ActiveActor].Solution.SolutionCount;
End;
*)


// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.CalcStorage2ModelContribution(ActorID : Integer);

// Calculates Storage2 element current and adds it properly into the injcurrent array
// routines may also compute ITerminal  (ITerminalUpdated flag)

Begin
     set_ITerminalUpdated(FALSE, ActorID);
     WITH  ActiveCircuit[ActorID], ActiveCircuit[ActorID].Solution DO
     Begin
          IF      IsDynamicModel THEN  DoDynamicMode(ActorID)
          ELSE IF IsHarmonicModel and (Frequency <> Fundamental) THEN  DoHarmonicMode(ActorID)
          ELSE
            Begin
               //  compute currents and put into InjTemp array;
                 CASE VoltageModel OF
                      1: DoConstantPQStorage2Obj(ActorID);
                      2: DoConstantZStorage2Obj(ActorID);
                      3: DoUserModel(ActorID);
                 ELSE
                      DoConstantPQStorage2Obj(ActorID);  // for now, until we implement the other models.
                 End;
            End; {ELSE}
     END; {WITH}

   {When this is Done, ITerminal is up to date}

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.CalcInjCurrentArray(ActorID : Integer);
// Difference between currents in YPrim and total current
Begin
      // Now Get Injection Currents
       If Storage2ObjSwitchOpen Then ZeroInjCurrent
       Else CalcStorage2ModelContribution(ActorID);
End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.GetTerminalCurrents(Curr:pComplexArray; ActorID : Integer);

// Compute total Currents

Begin
   WITH ActiveCircuit[ActorID].Solution  DO
     Begin
        If IterminalSolutionCount[ActorID] <> ActiveCircuit[ActorID].Solution.SolutionCount Then Begin     // recalc the contribution
          IF Not Storage2ObjSwitchOpen Then CalcStorage2ModelContribution(ActorID);  // Adds totals in Iterminal as a side effect
        End;
        Inherited GetTerminalCurrents(Curr, ActorID);
     End;

   If (DebugTrace) Then WriteTraceRecord('TotalCurrent', ActorID);

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
FUNCTION TStorage2Obj.InjCurrents(ActorID : Integer):Integer;

Begin
     With ActiveCircuit[ActorID].Solution Do
      Begin
         If LoadsNeedUpdating Then SetNominalStorage2Output(ActorID); // Set the nominal kW, etc for the type of solution being Done

         CalcInjCurrentArray(ActorID);          // Difference between currents in YPrim and total terminal current

         If (DebugTrace) Then WriteTraceRecord('Injection', ActorID);

         // Add into System Injection Current Array

         Result := Inherited InjCurrents(ActorID);
      End;
End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.GetInjCurrents(Curr:pComplexArray; ActorID : Integer);

// Gives the currents for the last solution performed

// Do not call SetNominalLoad, as that may change the load values

VAR
   i:Integer;

Begin

   CalcInjCurrentArray(ActorID);  // Difference between currents in YPrim and total current

   TRY
   // Copy into buffer array
     FOR i := 1 TO Yorder Do Curr^[i] := InjCurrent^[i];

   EXCEPT
     ON E: Exception Do
        DoErrorMsg('Storage2 Object: "' + Name + '" in GetInjCurrents FUNCTION.',
                    E.Message,
                   'Current buffer not big enough.', 568);
   End;

End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.ResetRegisters;

VAR
   i : Integer;

Begin
     For i := 1 to NumStorage2Registers Do Registers[i]   := 0.0;
     For i := 1 to NumStorage2Registers Do Derivatives[i] := 0.0;
     FirstSampleAfterReset := TRUE;  // initialize for trapezoidal integration
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.Integrate(Reg:Integer; const Deriv:Double; Const Interval:Double;ActorID : Integer);

Begin
     IF ActiveCircuit[ActorID].TrapezoidalIntegration THEN
       Begin
        {Trapezoidal Rule Integration}
        If Not FirstSampleAfterReset Then Registers[Reg] := Registers[Reg] + 0.5 * Interval * (Deriv + Derivatives[Reg]);
       End
     ELSE   {Plain Euler integration}
         Registers[Reg] := Registers[Reg] + Interval * Deriv;

     Derivatives[Reg] := Deriv;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TStorage2Obj.TakeSample(ActorID : Integer);
// Update Energy from metered zone

VAR
     S         :Complex;
     Smag      :double;
     HourValue :Double;

Begin

// Compute energy in Storage2 element branch
     IF  Enabled  THEN Begin

     // Only tabulate discharge hours
       IF FSTate = STORE_DISCHARGING Then
       Begin
          S := cmplx(Get_PresentkW, Get_Presentkvar);
          Smag := Cabs(S);
          HourValue := 1.0;
       End Else
       Begin
          S := CZERO;
          Smag := 0.0;
          HourValue := 0.0;
       End;

        IF (FState = STORE_DISCHARGING) or ActiveCircuit[ActorID].TrapezoidalIntegration THEN
        {Make sure we always integrate for Trapezoidal case
         Don't need to for Gen Off and normal integration}
        WITH ActiveCircuit[ActorID].Solution Do
          Begin
             IF ActiveCircuit[ActorID].PositiveSequence THEN Begin
                S    := CmulReal(S, 3.0);
                Smag := 3.0*Smag;
             End;
             Integrate            (Reg_kWh,   S.re, IntervalHrs, ActorID);   // Accumulate the power
             Integrate            (Reg_kvarh, S.im, IntervalHrs, ActorID);
             SetDragHandRegister  (Reg_MaxkW, abs(S.re));
             SetDragHandRegister  (Reg_MaxkVA, Smag);
             Integrate            (Reg_Hours, HourValue, IntervalHrs, ActorID);  // Accumulate Hours in operation
             Integrate            (Reg_Price, S.re*ActiveCircuit[ActorID].PriceSignal*0.001 , IntervalHrs, ActorID);  // Accumulate Hours in operation
             FirstSampleAfterReset := False;
          End;
     End;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.UpdateStorage2(ActorID : Integer);
{Update Storage2 levels}
Begin

    WITH Storage2Vars Do
    Begin

      kWhBeforeUpdate :=  kWhStored;   // keep this for reporting change in Storage2 as a variable

      {Assume User model will take care of updating Storage2 in dynamics mode}
      If ActiveCircuit[ActorID].solution.IsDynamicModel and  IsUserModel Then  Exit;

      With ActiveCircuit[ActorID].Solution Do
      Case FState of

          STORE_DISCHARGING: Begin

                                 kWhStored := kWhStored - (DCkW + kWIdlingLosses) / DischargeEff * IntervalHrs;
                                 If kWhStored < kWhReserve Then Begin
                                     kWhStored := kWhReserve;
                                     Fstate := STORE_IDLING;  // It's empty Turn it off
                                     FstateChanged := TRUE;
                                 End;
                             End;

          STORE_CHARGING:    Begin

                                 if (abs(DCkW) - kWIdlingLosses) >= 0 then // 99.9 % of the cases will fall here
                                 begin
                                     kWhStored := kWhStored + (abs(DCkW) - kWIdlingLosses) * ChargeEff * IntervalHrs ;
                                     If kWhStored > kWhRating Then Begin
                                         kWhStored := kWhRating;
                                         Fstate := STORE_IDLING;  // It's full Turn it off
                                         FstateChanged := TRUE;
                                     End;
                                 end
                                 else   // Exceptional cases when the idling losses are higher than the DCkW such that the net effect is that the
                                 // the ideal Storage2 will discharge
                                 begin
                                     kWhStored := kWhStored + (abs(DCkW) - kWIdlingLosses) / DischargeEff * IntervalHrs ;
                                     If kWhStored < kWhReserve Then Begin
                                         kWhStored := kWhReserve;
                                         Fstate := STORE_IDLING;  // It's empty Turn it off
                                         FstateChanged := TRUE;
                                     End;
                                 end;

                             End;

          STORE_IDLING:;
      End;

    END;

      // the update is done at the end of a time step so have to force
      // a recalc of the Yprim for the next time step.  Else it will stay the same.
      If FstateChanged Then YprimInvalid[ActorID] := TRUE;

End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.ComputeDCkW;
// Computes actual DCkW to Update Storage2 SOC
var

     coefGuess: TCoeff;
     coef: TCoeff;
     N_tentatives: Integer;
Begin

  coefGuess[1] := 0.0;
  coefGuess[2] := 0.0;

  coef[1] := 1.0;
  coef[2] := 1.0;  // just a guess

  FDCkW := Power[1,ActiveActor].re*0.001;  // Assume ideal inverter


  if Not Assigned(InverterCurveObj) then
  Begin
    // make sure sign is correct
    if (FState = STORE_IDLING) Then FDCkW := abs(FDCkW) * -1
    Else FDCkW := abs(FDCkW) * FState;
    Exit;
  End;


  N_tentatives := 0;
  while (coef[1] <> coefGuess[1]) and  (coef[2] <> coefGuess[2]) or (N_tentatives > 9) do
  begin
    N_tentatives := N_tentatives + 1;
    coefGuess := InverterCurveObj.GetCoefficients(abs(FDCkW)/Storage2Vars.FkVArating);


    Case FState of

        STORE_DISCHARGING: FDCkW := QuadSolver(coefGuess[1]/Storage2Vars.FkVArating, coefGuess[2], -1.0*abs(Power[1,ActiveActor].re*0.001));
        STORE_CHARGING,
        STORE_IDLING:    FDCkW := abs(FDCkW)*coefGuess[2] / (1.0 - (coefGuess[1]*abs(FDCkW)/Storage2Vars.FkVArating));
    End;

      // Final coefficients
      coef := InverterCurveObj.GetCoefficients(abs(FDCkW)/Storage2Vars.FkVArating);
    end;

    // make sure sign is correct
    if (FState = STORE_IDLING) Then FDCkW := abs(FDCkW) * -1
    Else FDCkW := abs(FDCkW) * FState;

End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_PresentkW:Double;
Begin
     Result := Pnominalperphase * 0.001 * Fnphases;
End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_DCkW: Double;
Begin

    ComputeDCkW;
    Result:= FDCkW;

End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kWDesired: Double;
Begin

  CASE FStateDesired of
    STORE_CHARGING    :    Result:= -pctkWIn * Storage2Vars.kWRating / 100.0;
    STORE_DISCHARGING :    Result:= pctkWOut * Storage2Vars.kWRating / 100.0;
    STORE_IDLING      :    Result:= 0.0;
  END;

End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_StateDesired(i:Integer);
Begin

  FStateDesired := i;

End;

//-----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kWTotalLosses: Double;
begin
     Result := kWIdlingLosses + kWInverterLosses + kWChDchLosses;
end;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_InverterLosses: Double;
begin
  Result := 0.0;

  With Storage2Vars do
  Begin
    CASE Storage2State of

              STORE_IDLING: Result:= abs(Power[1,ActiveActor].re*0.001) - abs(DCkW);
              STORE_CHARGING: Result := abs(Power[1,ActiveActor].re*0.001) - abs(DCkW);
              STORE_DISCHARGING: Result := DCkW - abs(Power[1,ActiveActor].re*0.001);
    END;
  End;
end;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kWIdlingLosses: Double;
begin

  if (FState = STORE_IDLING) Then
  Begin
     Result:= abs(DCkW); // For consistency keeping with voltage variations
  End
  Else  Result := Pidling;
end;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kWChDchLosses: Double;
Begin
  Result := 0.0;

  With Storage2Vars do
  Begin
    CASE Storage2State of

        STORE_IDLING:  Result := 0.0;

        STORE_CHARGING:
                          if (abs(DCkW) - Pidling > 0) then Result:= (abs(DCkW) - Pidling) *(1.0 - 0.01*pctChargeEff) // most cases will fall here
                          else Result := -1*(abs(DCkW) - Pidling) * (1.0 / (0.01*pctDischargeEff) - 1.0);             // exceptional cases when Pidling is higher than DCkW (net effect is that the ideal Storage2 will be discharged)

        STORE_DISCHARGING: Result := (DCkW + Pidling) * (1.0 / (0.01*pctDischargeEff) - 1.0);
    END;
  End;
End;

//----------------------------------------------------------------------------

Procedure TStorage2Obj.Update_EfficiencyFactor;
begin
  With Storage2Vars do
  Begin
    if Not Assigned(InverterCurveObj) Then EffFactor:= 1.0
    Else EffFactor := InverterCurveObj.GetYValue(abs(DCkW)/FkVArating);
  End;
end;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_PresentkV: Double;
Begin
     Result := Storage2Vars.kVStorage2Base;
End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_Presentkvar:Double;
Begin
     Result := Qnominalperphase * 0.001 * Fnphases;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.DumpProperties(VAR F:TextFile; Complete:Boolean);

VAR
   i, idx :Integer;

Begin
      Inherited DumpProperties(F, Complete);

      With ParentClass Do
       For i := 1 to NumProperties Do
       Begin
            idx := PropertyIdxMap[i] ;
            Case idx of
                propUSERDATA: Writeln(F,'~ ',PropertyName^[i],'=(',PropertyValue[idx],')');
                propDynaData: Writeln(F,'~ ',PropertyName^[i],'=(',PropertyValue[idx],')');
            Else
                Writeln(F,'~ ',PropertyName^[i],'=',PropertyValue[idx]);
            End;
       End;

      Writeln(F);
End;


//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.InitHarmonics(ActorID : Integer);

// This routine makes a thevenin equivalent behis the reactance spec'd in %R and %X

VAR
  E, Va:complex;

Begin
     YprimInvalid[ActorID]       := TRUE;  // Force rebuild of YPrims
     Storage2Fundamental := ActiveCircuit[ActorID].Solution.Frequency ;  // Whatever the frequency is when we enter here.

     Yeq := Cinv(Cmplx(Storage2Vars.RThev,Storage2Vars.XThev));      // used for current calcs  Always L-N

     {Compute reference Thevinen voltage from phase 1 current}

     IF FState = STORE_DISCHARGING Then
       Begin
           ComputeIterminal(ActorID);  // Get present value of current

           With ActiveCircuit[ActorID].solution Do
           Case Connection of
             0: Begin {wye - neutral is explicit}
                     Va := Csub(NodeV^[NodeRef^[1]], NodeV^[NodeRef^[Fnconds]]);
                End;
             1: Begin  {delta -- assume neutral is at zero}
                     Va := NodeV^[NodeRef^[1]];
                End;
           End;

           E := Csub(Va, Cmul(Iterminal^[1], cmplx(Storage2Vars.Rthev, Storage2Vars.Xthev)));
           Storage2Vars.Vthevharm := Cabs(E);   // establish base mag and angle
           Storage2Vars.ThetaHarm := Cang(E);
       End
     ELSE
       Begin
           Storage2Vars.Vthevharm := 0.0;
           Storage2Vars.ThetaHarm := 0.0;
       End;
End;


//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.InitStateVars(ActorID : Integer);

// for going into dynamics mode
VAR
    VNeut :Complex;
    VThevPolar :Polar;
    i     :Integer;
    V012,
    I012  :Array[0..2] of Complex;
    Vabc  :Array[1..3] of Complex;


Begin

     YprimInvalid[ActorID] := TRUE;  // Force rebuild of YPrims

     With Storage2Vars do Begin
        ZThev :=  Cmplx(RThev, XThev);
        Yeq := Cinv(ZThev);  // used to init state vars
     End;


     If DynaModel.Exists  Then   // Checks existence and selects
     Begin
          ComputeIterminal(ActorID);
          ComputeVterminal(ActorID);
          With Storage2Vars do
          Begin
              NumPhases := Fnphases;
              NumConductors := Fnconds;
              w_grid := twopi * ActiveCircuit[ActorID].Solution.Frequency ;
          End;
          DynaModel.FInit(Vterminal, Iterminal);
     End

     Else Begin

     {Compute nominal Positive sequence voltage behind equivalent filter impedance}

       IF FState = STORE_DISCHARGING Then With ActiveCircuit[ActorID].Solution Do
       Begin
             ComputeIterminal(ActorID);

             If FnPhases=3 Then
             Begin
                Phase2SymComp(ITerminal, @I012);
                // Voltage behind Xdp  (transient reactance), volts
                Case Connection of
                   0: Vneut :=  NodeV^[NodeRef^[Fnconds]]
                Else
                   Vneut :=  CZERO;
                End;

                For i := 1 to FNphases Do Vabc[i] := NodeV^[NodeRef^[i]];   // Wye Voltage

                Phase2SymComp(@Vabc, @V012);
                With Storage2Vars Do Begin
                      Vthev    := Csub( V012[1] , Cmul(I012[1], ZThev));    // Pos sequence
                      VThevPolar := cToPolar(VThev);
                      VThevMag := VThevPolar.mag;
                      Theta    := VThevPolar.ang;  // Initial phase angle
                End;
             End Else
             Begin   // Single-phase Element
                  For i := 1 to Fnconds Do Vabc[i] :=  NodeV^[NodeRef^[i]];
                  With Storage2Vars Do Begin
                         Vthev    := Csub( VDiff(NodeRef^[1], NodeRef^[2]) , Cmul(ITerminal^[1], ZThev));    // Pos sequence
                         VThevPolar := cToPolar(VThev);
                         VThevMag := VThevPolar.mag;
                         Theta    := VThevPolar.ang;  // Initial phase angle
                   End;

             End;
       End;
       End;

End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.IntegrateStates(ActorID : Integer);

// dynamics mode integration routine

VAR
    TracePower:Complex;

Begin
   // Compute Derivatives and Then integrate

   ComputeIterminal(ActorID);

    If Dynamodel.Exists  Then   // Checks for existence and Selects

         DynaModel.Integrate

    Else

    With ActiveCircuit[ActorID].Solution, Storage2Vars Do
    Begin

      With Storage2Vars Do
      If (Dynavars.IterationFlag = 0) Then Begin {First iteration of new time step}
//****          ThetaHistory := Theta + 0.5*h*dTheta;
//****          SpeedHistory := Speed + 0.5*h*dSpeed;
      End;

      // Compute shaft dynamics
      TracePower := TerminalPowerIn(Vterminal,Iterminal,FnPhases) ;

//****      dSpeed := (Pshaft + TracePower.re - D*Speed) / Mmass;
//      dSpeed := (Torque + TerminalPowerIn(Vtemp,Itemp,FnPhases).re/Speed) / (Mmass);
//****      dTheta  := Speed ;

     // Trapezoidal method
      With Storage2Vars  Do Begin
//****       Speed := SpeedHistory + 0.5*h*dSpeed;
//****       Theta := ThetaHistory + 0.5*h*dTheta;
      End;

   // Write Dynamics Trace Record
        IF DebugTrace Then
          Begin
             Append(TraceFile);
             Write(TraceFile,Format('t=%-.5g ', [Dynavars.t]));
             Write(TraceFile,Format(' Flag=%d ',[Dynavars.Iterationflag]));
             Writeln(TraceFile);
             CloseFile(TraceFile);
         End;

   End;

End;

//----------------------------------------------------------------------------
FUNCTION TStorage2Obj.InterpretState(const S: String): Integer;
Begin
     CASE LowerCase(S)[1] of
         'c' : Result := STORE_CHARGING;
         'd' : Result := STORE_DISCHARGING;
     ELSE
         Result := STORE_IDLING;
     END;
End;

{ apparently for debugging only
//----------------------------------------------------------------------------
Function TStorage2Obj.StateToStr:String;
Begin
      CASE FState of
          STORE_CHARGING: Result := 'Charging';
          STORE_IDLING: Result := 'Idling';
          STORE_DISCHARGING: Result := 'Discharging';
      END;
End;
}

//----------------------------------------------------------------------------
FUNCTION TStorage2Obj.Get_Variable(i: Integer): Double;
{Return variables one at a time}

VAR
      N, k:Integer;

Begin
    Result := -9999.99;  // error return value; no state vars
    If i < 1 Then Exit;
    // for now, report kWhstored and mode
    With Storage2Vars do
    CASE i of
       1:  Result    := kWhStored;
       2:  Result    := FState;
       3:  If Not (FState=STORE_DISCHARGING) Then Result := 0.0 Else Result := abs(Power[1,ActiveActor].re*0.001);
       4:  If (FState=STORE_CHARGING) or (FState = STORE_IDLING)  Then Result := abs(Power[1,ActiveActor].re*0.001) Else Result:=0;
       5:  Result    := -1*Power[1,ActiveActor].im*0.001;
       6:  Result    := DCkW;
       7:  Result    := kWTotalLosses; {Present kW charge or discharge loss incl idle losses}
       8:  Result    := kWInverterLosses; {Inverter Losses}
       9:  Result    := kWIdlingLosses; {Present kW Idling Loss}
       10: Result    := kWChDchLosses;  // Charge/Discharge Losses
       11: Result    := kWhStored - kWhBeforeUpdate;
       12: Begin
            Update_EfficiencyFactor;
            Result := EffFactor;  //Old: Result    := Get_EfficiencyFactor;
           End;
       13: If (FInverterON) Then Result:= 1.0 Else Result:= 0.0;
       14: Result    := Vreg;
       15: Result    := Vavg;
       16: Result    := VVOperation;
       17: Result    := VWOperation;
       18: Result    := DRCOperation;
       19: Result    := VVDRCOperation;
       20: Result    := Get_kWDesired;
       21: if not (VWMode) Then Result:= 9999 Else Result := kWRequested;
       22: Result    := pctkWrated*kWrating;
       23: If (kVA_exceeded) Then Result:= 1.0 Else Result:= 0.0;

     ELSE
        Begin
             If UserModel.Exists Then   // Checks for existence and Selects
             Begin
                  N := UserModel.FNumVars;
                  k := (i - NumStorage2Variables);
                  If k <= N Then Begin
                      Result := UserModel.FGetVariable(k);
                      Exit;
                  End;
             End;
             If DynaModel.Exists Then  // Checks for existence and Selects
             Begin
                  N := DynaModel.FNumVars;
                  k := (i - NumStorage2Variables);
                  If k <= N Then Begin
                      Result := DynaModel.FGetVariable(k);
                      Exit;
                  End;
             End;
        End;
     END;
End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.Set_Variable(i: Integer;  Value: Double);
var N, k:Integer;

Begin
  If i<1 Then Exit;  // No variables to set

    With Storage2Vars Do
    CASE i of
       1:  kWhStored      := Value;
       2:  Fstate         := Trunc(Value);
       3..13:; {Do Nothing; read only}
       14: Vreg           := Value;
       15: Vavg           := Value;
       16: VVOperation    := Value;
       17: VWOperation    := Value;
       18: DRCOperation   := Value;
       19: VVDRCOperation := Value;
       20..23:; {Do Nothing; read only}

     ELSE
       Begin
         If UserModel.Exists Then    // Checks for existence and Selects
         Begin
              N := UserModel.FNumVars;
              k := (i-NumStorage2Variables) ;
              If  k<= N Then
              Begin
                  UserModel.FSetVariable( k, Value );
                  Exit;
              End;
          End;
         If DynaModel.Exists Then     // Checks for existence and Selects
         Begin
              N := DynaModel.FNumVars;
              k := (i-NumStorage2Variables) ;
              If  k<= N Then
              Begin
                  DynaModel.FSetVariable( k, Value );
                  Exit;
              End;
          End;
       End;
     END;

End;

//----------------------------------------------------------------------------
PROCEDURE TStorage2Obj.GetAllVariables(States: pDoubleArray);

VAR  i{, N}:Integer;
Begin
     For i := 1 to NumStorage2Variables Do States^[i] := Variable[i];

     If UserModel.Exists Then Begin    // Checks for existence and Selects
        {N := UserModel.FNumVars;}
        UserModel.FGetAllVars(@States^[NumStorage2Variables+1]);
     End;
     If DynaModel.Exists Then Begin    // Checks for existence and Selects
        {N := UserModel.FNumVars;}
        DynaModel.FGetAllVars(@States^[NumStorage2Variables+1]);
     End;

End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.NumVariables: Integer;
Begin
     Result  := NumStorage2Variables;

     // Exists does a check and then does a Select
     If UserModel.Exists    Then Result := Result + UserModel.FNumVars;
     If DynaModel.Exists    Then Result := Result + DynaModel.FNumVars;
End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.VariableName(i: Integer):String;

Const
    BuffSize = 255;
VAR
    n,
    i2    :integer;
    Buff  :Array[0..BuffSize] of AnsiChar;
    pName :pAnsichar;

Begin
      If i<1 Then Exit;  // Someone goofed

      CASE i of
          1:Result  := 'kWh';
          2:Result  := 'State';
//          3:Result  := 'Pnom';
//          4:Result  := 'Qnom';
          3:Result  := 'kWOut';
          4:Result  := 'kWIn';
          5:Result  := 'kvarOut';
          6:Result  := 'DCkW';
          7:Result  := 'kWTotalLosses';
          8:Result  := 'kWInvLosses';
          9:Result  := 'kWIdlingLosses';
          10:Result := 'kWChDchLosses';
          11:Result := 'kWh Chng';
          12:Result := 'InvEff';
          13:Result := 'InverterON';
          14:Result := 'Vref';
          15:Result := 'Vavg (DRC)';
          16:Result := 'VV Oper';
          17:Result := 'VW Oper';
          18:Result := 'DRC Oper';
          19:Result := 'VV_DRC Oper';
          20:Result := 'kWDesired';
          21:Result := 'kW VW Limit';
          22:Result := 'Limit kWOut Function';
          23:Result := 'kVA Exceeded';


      ELSE
          Begin
            If UserModel.Exists Then    // Checks for existence and Selects
            Begin
                  pName := @Buff;
                  n := UserModel.FNumVars;
                  i2 := i-NumStorage2Variables;
                  If i2 <= n Then
                  Begin
                       UserModel.FGetVarName(i2, pName, BuffSize);
                       Result := String(pName);
                       Exit;
                  End;
            End;
            If DynaModel.Exists Then   // Checks for existence and Selects
            Begin
                  pName := @Buff;
                  n := DynaModel.FNumVars;
                  i2 := i-NumStorage2Variables; // Relative index
                  If i2 <= n Then
                  Begin
                       DynaModel.FGetVarName(i2, pName, BuffSize);
                       Result := String(pName);
                       Exit;
                  End;
            End;
          End;
      END;

End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.MakePosSequence(ActorID : Integer);

VAR
    S :String;
    V :Double;

Begin

  S := 'Phases=1 conn=wye';

  // Make sure voltage is line-neutral
  If (Fnphases>1) or (connection<>0)
  Then V :=  Storage2Vars.kVStorage2Base/SQRT3
  Else V :=  Storage2Vars.kVStorage2Base;

  S := S + Format(' kV=%-.5g',[V]);

  If Fnphases>1 Then
  Begin
       S := S + Format(' kWrating=%-.5g  PF=%-.5g',[Storage2Vars.kWrating/Fnphases, PFNominal]);
  End;

  Parser[ActorID].CmdString := S;
  Edit(ActorID);

  inherited;   // write out other properties
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_ConductorClosed(Index: Integer; ActorID: Integer;
  Value: Boolean);
Begin
   inherited;

 // Just turn Storage2 element on or off;

   If Value Then Storage2ObjSwitchOpen := FALSE Else Storage2ObjSwitchOpen := TRUE;

End;

//----------------------------------------------------------------------------

function  TStorage2Obj.Get_InverterON:Boolean;
begin
  if FInverterON then Result := TRUE else Result := FALSE;

end;

//----------------------------------------------------------------------------

Procedure TStorage2Obj.kWOut_Calc;
Var
    limitkWpct:Double;

    Begin
       With Storage2Vars Do
       Begin

          FVWStateRequested:= FALSE;

          if FState = STORE_DISCHARGING then limitkWpct := kWrating * FpctkWrated
          else limitkWpct := kWrating * FpctkWrated * -1;

//          if VWmode and (FState = STORE_DISCHARGING) then if (abs(kwRequested) < abs(limitkWpct)) then limitkWpct :=  kwRequested * sign(kW_Out);
          // VW works only if element is not in idling state.
          // When the VW is working in the 'limiting' region, kWRequested will be positive.
          // When in 'requesting' region, it will be negative.
          if VWmode and not (FState = STORE_IDLING) then
          begin

             if (kWRequested >=0.0) and (abs(kwRequested) < abs(limitkWpct)) then  // Apply VW limit
             begin
                if FState = STORE_DISCHARGING then limitkWpct :=  kwRequested
                else limitkWpct :=  -1*kwRequested;
             end
             else if kWRequested < 0.0 then // IEEE 1547 Requesting Region (not fully implemented)
             begin
                if FState = STORE_DISCHARGING then
                Begin
                    if (kWhStored < kWhRating) then
                    Begin  // let it charge only if enough not fully charged
                      FState := STORE_CHARGING;
                      kW_out := kWRequested;
                    End
                    else
                    Begin
                      FState := STORE_IDLING;
                      kW_out := -kWOutIdling;
                    End;
                End
                ELSE  // Charging
                Begin
                    if (kWhStored > kWhReserve) then
                    Begin  // let it charge only if enough not fully charged
                      Fstate := STORE_DISCHARGING;
                      kW_out := -1*kWRequested;
                    End
                    else
                    Begin
                      FState := STORE_IDLING;
                      kW_out := -kWOutIdling;
                    End;


                End;
                FStateChanged := TRUE;
                FVWStateRequested:= TRUE;

                // Update limitkWpct because state might have been changed
                if FState = STORE_DISCHARGING then limitkWpct := kWrating * FpctkWrated
                else limitkWpct := kWrating * FpctkWrated * -1;

             end;

          end;

          if (limitkWpct > 0) and (kW_Out > limitkWpct) then kW_Out := limitkWpct
          else if (limitkWpct < 0) and (kW_Out < limitkWpct) then kW_Out := limitkWpct;

       End;
    End;

//----------------------------------------------------------------------------

function TStorage2Obj.Get_Varmode: Integer;
begin
      Result := FvarMode;
end;

//----------------------------------------------------------------------------

function TStorage2Obj.Get_VWmode: Boolean;
begin
      If FVWmode Then Result := TRUE else Result := FALSE;    // TRUE if volt-watt mode
                                                              //  engaged from InvControl (not ExpControl)
end;

//----------------------------------------------------------------------------

function TStorage2Obj.Get_VVmode: Boolean;
begin
      If FVVmode Then Result := TRUE else Result := FALSE;
end;


//----------------------------------------------------------------------------

function TStorage2Obj.Get_DRCmode: Boolean;
begin
      If FDRCmode Then Result := TRUE else Result := FALSE;
end;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_CutOutkWAC: Double;
begin
      Result := FCutOutkWAC;
end;

//----------------------------------------------------------------------------

FUNCTION  TStorage2Obj.Get_CutInkWAC: Double;
begin
      Result := FCutInkWAC;
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_pctkWOut(const Value: Double);
begin
     FpctkWOut := Value;
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_pctkWIn(const Value: Double);
begin
     FpctkWIn := Value;
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_kW(const Value: Double);
begin
     if Value > 0 then
     Begin
      FState    := STORE_DISCHARGING;
      FpctkWOut  := Value / Storage2Vars.kWRating * 100.0;
     End
     Else if Value < 0 then
     Begin
      FState    := STORE_CHARGING;
      FpctkWIn  := abs(Value) / Storage2Vars.kWRating * 100.0;
     End
     Else
     Begin
      FState    := STORE_IDLING;
     End;
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_Maxkvar(const Value: Double);
begin
      Storage2Vars.Fkvarlimit := Value;
      PropertyValue[propkvarLimit]       := Format('%-g', [Storage2Vars.Fkvarlimit]);
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_Maxkvarneg(const Value: Double);
begin
      Storage2Vars.Fkvarlimitneg := Value;
      PropertyValue[propkvarLimitneg]       := Format('%-g', [Storage2Vars.Fkvarlimitneg]);
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_kVARating(const Value: Double);
begin
      Storage2Vars.FkVARating := Value;
      PropertyValue[propKVA]       := Format('%-g', [Storage2Vars.FkVArating]);
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_PowerFactor(const Value: Double);
Begin
     PFNominal := Value;
     varMode := VARMODEPF;
End;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_Varmode(const Value: Integer);
begin
  FvarMode:= Value;
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_VWmode(const Value: Boolean);
begin
      FVWmode := Value;
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_VVmode(const Value: Boolean);
begin
      FVVmode := Value;
end;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_DRCmode(const Value: Boolean);
begin
      FDRCmode := Value;
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_PresentkV(const Value: Double);
Begin
      Storage2Vars.kVStorage2Base := Value ;
      CASE FNphases Of
           2,3: VBase := Storage2Vars.kVStorage2Base * InvSQRT3x1000;
      ELSE
           VBase := Storage2Vars.kVStorage2Base * 1000.0 ;
      END;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_kvarRequested(const Value: Double);
Begin
     FkvarRequested := Value;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_kWRequested(const Value: Double);
Begin
     FkWRequested := Value;
End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kW: Double;
Begin

  CASE Fstate of
    STORE_CHARGING    :    Result:= -pctkWIn * Storage2Vars.kWRating / 100.0;
    STORE_DISCHARGING :    Result:= pctkWOut * Storage2Vars.kWRating / 100.0;
    STORE_IDLING      :    Result:= -kWOutIdling;
  END;

End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kWRequested: Double;
Begin
     Result := FkWRequested;
End;

//----------------------------------------------------------------------------

FUNCTION TStorage2Obj.Get_kvarRequested: Double;
Begin
     Result := FkvarRequested;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_VarFollowInverter(const Value: Boolean);
Begin
    FVarFollowInverter := Value;
End;

//----------------------------------------------------------------------------

FUNCTION  TStorage2Obj.Get_VarFollowInverter:Boolean;
Begin
   if FVarFollowInverter then Result := TRUE else Result := FALSE;

End;

//----------------------------------------------------------------------------

procedure TStorage2Obj.Set_pctkWrated(const Value: Double);
begin
     Storage2Vars.FpctkWrated := Value;
end;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_InverterON(const Value: Boolean);
Begin
     FInverterON := Value;
End;

//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.Set_Storage2State(const Value: Integer);
Var
     SavedState:Integer;
Begin
     SavedState := Fstate;

     // Decline if Storage2 is at its limits ; set to idling instead

     With Storage2Vars Do
     CASE Value of

            STORE_CHARGING:   Begin
                                If kWhStored < kWhRating Then Fstate := Value
                                ELSE Fstate := STORE_IDLING;   // all charged up
                              End;

           STORE_DISCHARGING: Begin
                                If kWhStored > kWhReserve Then Fstate := Value
                                ELSE Fstate := STORE_IDLING;  // not enough Storage2 to discharge
                              End;
     ELSE
           Fstate := STORE_IDLING;
     END;

     If SavedState <> Fstate Then FStateChanged := TRUE;

     //---DEBUG--- WriteDLLDebugFile(Format('t=%.8g, ---State Set To %s', [ActiveCircuit[ActiveActor].Solution.dblHour, StateToStr ]));
End;
//----------------------------------------------------------------------------

PROCEDURE TStorage2Obj.SetDragHandRegister(Reg: Integer; const Value: Double);
Begin
    If Value>Registers[reg] Then Registers[Reg] := Value;
End;

//----------------------------------------------------------------------------
initialization

   CDOUBLEONE := CMPLX(1.0, 1.0);

end.

