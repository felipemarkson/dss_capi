unit Executive;

{$IFDEF FPC}{$MODE Delphi}{$ENDIF}

{
  ----------------------------------------------------------
  Copyright (c) 2008-2015, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{  Change Log

  8/12/99  Added Show Zone Help string

  10/11/99 Added Dump Commands option.  Moved ExecCommand into Public area.
  10/12/99 ADded new AutoAdd options and revised behavior of New Command.
  10/14/99 Added UE weighting option
           Fixed Redirect/Compile to change default directory.
  11/2/99  Added message in Open and Close cmd for ckt element not found.
  12/3/99  Fixed bug in command parser - needed quotes when rebuilding command line
  12/6/99  Merged Set and Solve commands
  1-14-00 Added Get Command
          Added LossWeight, UEreg, lossreg properties
  2-20-00 Revised Helpform so that help strings won't go away after Clear
  3-2-00  Repaired some places where re-parsing would mess up on names with blanks
  3-10-00 Added FileEdit and Export commands
  3-20-00 Added DefaultDaily and DefaultYearly Options
  4-17-00 Moved bulk of functions to ExecHelper
          Added AllocateLoads Command and AllocationFactors option
  8-23-00 Added Price Signal Option
  9-18-00 Fixed Dump Command Help
  9-20-00 Added Dynamic Mode
  10-3-00 Removed test for comment since '//' is now done in the Parser
  5/22/01 Changed behavior of Compile and Redirect with respect to directory changes.
  5/30/01 Add Set maxControlIterations
  7/19/01 Added Totals command, Capacity Command
  8/1/01  Revise the way the Capacity Command works
  9/12/02 Added Classes and UserClasses
  2/4/03  Added Set Bus=
          Added Zsc, Zsc012.
          Changed way Voltages command works

}

interface

uses
    PointerList,
    Command;

type
    TExecutive = class(TObject)
    PRIVATE
        FRecorderOn: Boolean;
        FRecorderFile: String;

        function Get_LastError: String;
        function Get_ErrorResult: Integer;


        function Get_Command: String;
        procedure Set_Command(const Value: String);
        procedure Set_RecorderOn(const Value: Boolean);

    PUBLIC

        RecorderFile: TextFile;
        constructor Create;
        destructor Destroy; OVERRIDE;

        procedure CreateDefaultDSSItems;
        procedure Write_to_RecorderFile(const s: String);

        procedure Clear;
        property Command: String READ Get_Command WRITE Set_Command;
        property Error: Integer READ Get_ErrorResult;
        property LastError: String READ Get_LastError;
        property RecorderOn: Boolean READ FRecorderOn WRITE Set_RecorderOn;

    end;

var

    DSSExecutive: TExecutive;


implementation


uses
    ExecCommands,
    ExecOptions,
     {ExecHelper,} DSSClassDefs,
    DSSGlobals,
    ParserDel,
    SysUtils,
    Utilities,
    CmdForms;


//----------------------------------------------------------------------------
constructor TExecutive.Create;
begin
    inherited Create;


     // Exec Commands
    CommandList := TCommandList.Create(ExecCommand);

     // Exec options
    OptionList := TCommandList.Create(ExecOption);

     {Instantiate All DSS Classe Definitions, Intrinsic and User-defined}
    CreateDSSClasses;     // in DSSGlobals

    Circuits := TPointerList.Create(2);   // default buffer for 2 active circuits
    NumCircuits := 0;
    ActiveCircuit := NIL;

    Parser := TParser.Create;  // Create global parser object (in DSS globals)

    LastCmdLine := '';
    RedirFile := '';

    FRecorderOn := FALSE;
    FrecorderFile := '';

     {Get some global Variables from Registry}
    ReadDSS_Registry;

     {Override Locale defaults so that CSV files get written properly}
    FormatSettings.DecimalSeparator := '.';
    FormatSettings.ThousandSeparator := ',';

end;


//----------------------------------------------------------------------------
destructor TExecutive.Destroy;

begin

    {Write some global Variables to Registry}
    WriteDSS_Registry;

    ClearAllCircuits;

    CommandList.Free;
    OptionList.Free;
    Circuits.Free;

    DisposeDSSClasses;

    Parser.Free;

    inherited Destroy;
end;


//----------------------------------------------------------------------------
function TExecutive.Get_LastError: String;

begin
    Result := LastErrorMessage;
end;

//----------------------------------------------------------------------------
function TExecutive.Get_ErrorResult: Integer;
begin
    Result := ErrorNumber;
end;


//----------------------------------------------------------------------------
procedure TExecutive.CreateDefaultDSSItems;

{Create default loadshapes, growthshapes, and other general DSS objects
 used by all circuits.
}
begin

{ this load shape used for generator dispatching, etc.   Loads may refer to it, also.}
    Command := 'new loadshape.default npts=24 1.0 mult=(.677 .6256 .6087 .5833 .58028 .6025 .657 .7477 .832 .88 .94 .989 .985 .98 .9898 .999 1 .958 .936 .913 .876 .876 .828 .756)';
    if CmdResult = 0 then
    begin
        Command := 'new growthshape.default 2 year="1 20" mult=(1.025 1.025)';  // 20 years at 2.5%
        Command := 'new spectrum.default 7  Harmonic=(1 3 5 7 9 11 13)  %mag=(100 33 20 14 11 9 7) Angle=(0 0 0 0 0 0 0)';
        Command := 'new spectrum.defaultload 7  Harmonic=(1 3 5 7 9 11 13)  %mag=(100 1.5 20 14 1 9 7) Angle=(0 180 180 180 180 180 180)';
        Command := 'new spectrum.defaultgen 7  Harmonic=(1 3 5 7 9 11 13)  %mag=(100 5 3 1.5 1 .7 .5) Angle=(0 0 0 0 0 0 0)';
        Command := 'new spectrum.defaultvsource 1  Harmonic=(1 )  %mag=(100 ) Angle=(0 ) ';
        Command := 'new spectrum.linear 1  Harmonic=(1 )  %mag=(100 ) Angle=(0 ) ';
        Command := 'new spectrum.pwm6 13  Harmonic=(1 3 5 7 9 11 13 15 17 19 21 23 25) %mag=(100 4.4 76.5 62.7 2.9 24.8 12.7 0.5 7.1 8.4 0.9 4.4 3.3) Angle=(-103 -5 28 -180 -33 -59 79 36 -253 -124 3 -30 86)';
        Command := 'new spectrum.dc6 10  Harmonic=(1 3 5 7 9 11 13 15 17 19)  %mag=(100 1.2 33.6 1.6 0.4 8.7  1.2  0.3  4.5 1.3) Angle=(-75 28 156 29 -91 49 54 148 -57 -46)';
        Command := 'New TCC_Curve.A 5 c_array=(1, 2.5, 4.5, 8.0, 14.)  t_array=(0.15 0.07 .05 .045 .045) ';
        Command := 'New TCC_Curve.D 5 c_array=(1, 2.5, 4.5, 8.0, 14.)  t_array=(6 0.7 .2 .06 .02)';
        Command := 'New TCC_Curve.TLink 7 c_array=(2 2.1 3 4 6 22 50)  t_array=(300 100 10.1 4.0 1.4 0.1  0.02)';
        Command := 'New TCC_Curve.KLink 6 c_array=(2 2.2 3 4 6 30)    t_array=(300 20 4 1.3 0.41 0.02)';
    end;


end;


function TExecutive.Get_Command: String;
begin
    Result := LastCmdLine;
end;


procedure TExecutive.Set_Command(const Value: String);
begin

    ProcessCommand(Value);
end;

procedure TExecutive.Clear;
begin
    if (NumCircuits > 0) then
    begin

          {First get rid of all existing stuff}
        ClearAllCircuits;
        DisposeDSSClasses;

          {Now, Start over}
        CreateDSSClasses;
        CreateDefaultDSSItems;
        RebuildHelpForm := TRUE; // because class strings have changed
    end;

 //      If Not IsDLL Then ControlPanel.UpdateElementBox;  // TEMc

       {Prepare for new variables}
    ParserVars.Free;
    ParserVars := TParserVar.Create(100);  // start with space for 100 variables
end;

procedure TExecutive.Set_RecorderOn(const Value: Boolean);
begin
    if Value then
    begin
        if not FRecorderOn then
        begin
            FRecorderFile := GetOutputDirectory + 'DSSRecorder.DSS';
            AssignFile(RecorderFile, FRecorderFile);
        end;
        ReWrite(RecorderFile);
    end
    else
    if FRecorderOn then
    begin
        CloseFile(RecorderFile);
    end;
    GlobalResult := FRecorderFile;
    FRecorderOn := Value;
end;

procedure TExecutive.Write_to_RecorderFile(const s: String);
begin
    Writeln(Recorderfile, S);
end;

initialization

//WriteDLLDebugFile('Executive');


finalization


end.
