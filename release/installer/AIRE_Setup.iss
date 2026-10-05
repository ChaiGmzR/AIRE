; Build with:
;   iscc.exe /DAppVersion=1.2.7 release\installer\AIRE_Setup.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "AIRE ISEMM"
#define AppPublisher "Ilsan"
#define AppExeName "pcb_boxing_system.exe"
#define InstallDirName "IlsanPackingSystem"

[Setup]
AppId={{B4D2E88A-9C3A-4A67-9C72-2D8F0E4C8A11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/ChaiGmzR/AIRE
DefaultDirName={localappdata}\{#InstallDirName}
DefaultGroupName={#AppName}
OutputDir=..
OutputBaseFilename=AIRE_Setup_{#AppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
Uninstallable=yes
UninstallDisplayName={#AppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "IlsanPackingSystem"; ValueData: """{app}\{#AppExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Iniciar AIRE"; Flags: nowait postinstall
