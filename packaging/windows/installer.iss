; Inno Setup script -> produces a proper Windows installer .exe (not just the
; raw build output). Install Inno Setup (https://jrsoftware.org/isinfo.php,
; also available via `choco install innosetup`), then either open this file
; in the Inno Setup Compiler GUI, or run headless:
;   iscc packaging\windows\installer.iss
;
; Prerequisite: `flutter build windows --release` has already been run, so
; build\windows\x64\runner\Release\ exists. If your Flutter version puts the
; output at build\windows\runner\Release\ instead (older Flutter, before x64
; became an explicit subfolder), update SourceDir below to match.

#define MyAppName "Petal"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Petal"
#define MyAppExeName "petal.exe"
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6C1E1E2B-9C1D-4B7B-9C7A-PETALPLAYER01}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=PetalSetup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Petal has no signing certificate baked in here — installers built this way
; will trigger a SmartScreen warning until you sign the .exe with your own
; code-signing certificate. That's a purchase/registration step on your end,
; not something that can be pre-filled.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
