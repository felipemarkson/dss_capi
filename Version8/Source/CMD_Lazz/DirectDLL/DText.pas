unit DText;

interface

function DSSPut_Command(a: Pansichar): Pansichar; CDECL;

implementation

uses
    DSSGlobals,
    Executive,
    Dialogs,
    SysUtils;

function DSSPut_Command(a: Pansichar): Pansichar; CDECL;
begin
    SolutionAbort := FALSE;  // Reset for commands entered from outside
    DSSExecutive.Command := Widestring(a);  {Convert to String}
    Result := Pansichar(Ansistring(GlobalResult));
end;

end.
