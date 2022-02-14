unit DDSSProgress;

interface

function DSSProgressI(mode: Longint; arg: Longint): Longint; CDECL;
function DSSProgressS(mode: Longint; arg: Pansichar): Pansichar; CDECL;

implementation

uses
    DSSForms, {Progressform,} DSSGlobals;

function DSSProgressI(mode: Longint; arg: Longint): Longint; CDECL;
begin
    Result := 0; // Default return value
    case mode of
        0:
        begin // DSSProgress.PctProgress
            if NoFormsAllowed then
                Exit;
            InitProgressForm;
            ShowPctProgress(arg);
        end;
        1:
        begin // DSSProgress.Show()
            if NoFormsAllowed then
                Exit;
            InitProgressForm;
            ProgressFormCaption(' ');
            ShowPctProgress(0);
        end;
        2:
        begin  // DSSProgress.Close()
            if NoFormsAllowed then
                Exit;
            ProgressHide;
        end
    else
        Result := -1;
    end;
end;

//******************************String type properties*****************************
function DSSProgressS(mode: Longint; arg: Pansichar): Pansichar; CDECL;
begin
    Result := Pansichar(Ansistring('0')); // Default return value
    case mode of
        0:
        begin // DSSProgress.Caption
            if NoFormsAllowed then
                Exit;
            InitProgressForm;
            ProgressCaption(Widestring(arg));
        end
    else
        Result := Pansichar(Ansistring('Error, parameter not recognized'));
    end;
end;

end.
