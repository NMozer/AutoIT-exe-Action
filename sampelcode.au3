#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
;#AutoIt3Wrapper_Icon=..\USBLogOn.ico
;#AutoIt3Wrapper_Outfile=USBLogOn.exe
#AutoIt3Wrapper_Res_Description=Background Task monitoring USB-Port
;#AutoIt3Wrapper_Res_Fileversion=1.3.0.0
;#AutoIt3Wrapper_Res_LegalCopyright=J. Zimmermann, Daimler AG, TF/VAS
;#AutoIt3Wrapper_Res_Language=1031
;#AutoIt3Wrapper_Run_Tidy=y
;#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;#AutoIt3Wrapper_Run_Debug_Mode=n
#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.14.2
	Author:         Jan Zimmermann

	Script Function:
	Programm um per USB-Stick am SIS_SE angemeldet zu werden

	Erstellt am:
	dd.mm.yyyy
	Letzte Änderung am:
	19.08.2014	JZ - V110 - Enternen des deutschen Textes wegen einstellbarer Sprache der Shell "Willkommen bei IntegraShell" -> "[CLASS:TfrmLogin]"
	21.10.2017	JZ - V120 - Anpassung an geänderten ControlName "TAdvGlowButton<Nr>" -> "TAdvGlowButton!dx<Nr>" zum "öffnen" des LogOn Fensters ab Sis V5
	25.02.2019	GH - V130 - Anpassung an geänderten ControlName "TAdvGlowButton<Nr>" -> "TAdvGlowButton!dx<Nr>" zum "öffnen" des LogOn Fensters ab Sis V5

#ce ----------------------------------------------------------------------------

;Include-Files
#include <Crypt.au3>
#include <Array.au3>

;Tray-Icon ohne Menü
AutoItSetOption("TrayMenuMode", 1)
;Variable Deklarieren und initialisieren
Dim $DrivesCount = 0
_Log("Programm gestartet")
;Endlosschleife wartet auf Interrupt
While 1
	;Sleep 250ms für weniger Prozessorauslastung
	Sleep(250)
	;Überwachung ob SIS_SE gestartet und Fenster vorhanden
	$RetVal = WinWait("integraSIS_SE", "", 1)
	If $RetVal <> 0 Then
		;Alle Removeable-Drives in lokale Variable laden
		If DriveGetDrive("REMOVABLE") <> "" Then
			$Drives = DriveGetDrive("REMOVABLE")
			;Überprüfen ob Anzahl Drives kleiner ist als vorher (Drives[0]=Anzahl)
			If $Drives[0] < $DrivesCount Then
				;Anzahl in lokale Variable laden
				$DrivesCount = $Drives[0]
				;Überprüfen ob Anzahl Drives größer ist als vorher (Drives[0]=Anzahl)
			ElseIf $Drives[0] > $DrivesCount Then
				;Anzahl in lokale Variable laden
				$DrivesCount = $Drives[0]
				If StringInStr(StringUpper(WinGetText("integraSIS_SE")), "NONE") Then
					_Decrypt()
				EndIf
			EndIf
		Else
			$DrivesCount = 0
		EndIf
	EndIf
WEnd

Func _Decrypt()
	_Log(@CRLF)
	_Log("Nach LogOn-File suchen gestartet")
	For $i = 1 To $Drives[0]
		If FileExists($Drives[$i] & "\USBLogOn.bin") Then
			_Log("USBLogOn.bin auf Drive " & $Drives[$i] & " gefunden")
			_Crypt_Startup()
			$Key = "!PWQwert12345#"
			$File = FileOpen($Drives[$i] & "\USBLogOn.bin", 0)
			If $File = -1 Then
				MsgBox(0, "Error", "Unable to open file")
				_Log("USBLogOn.bin konnte auf Drive " & $Drives[$i] & " nicht geöffnet werden")
				Return -1
			EndIf
			$EncryptedFile = FileRead($File)
			$result = StringInStr($EncryptedFile, "!;!")
			$EncryptedUser = StringLeft($EncryptedFile, $result - 1)
			$EncryptedPW = StringRight($EncryptedFile, StringLen($EncryptedFile) - $result - 2)
			FileClose($File)
			_Log("USBLogOn.bin auf Drive " & $Drives[$i] & " gelesen")
			$DecryptedUser = BinaryToString(_Crypt_DecryptData($EncryptedUser, $Key, $CALG_AES_256))
			$DecryptedPW = BinaryToString(_Crypt_DecryptData($EncryptedPW, $Key, $CALG_AES_256))
			_Crypt_DestroyKey($Key)
			_Crypt_Shutdown()
			For $i = 0 To 100
				If StringInStr(StringUpper(ControlGetText("integraSIS_SE", "", "TAdvGlowButton" & $i)), "NONE") Then
					_Log("Anmelde-Button betätigen (TAdvGlowButton)")
					ControlClick("integraSIS_SE", "", "TAdvGlowButton" & $i)
				ElseIf StringInStr(StringUpper(ControlGetText("integraSIS_SE", "", "TAdvGlowButton!dx" & $i)), "NONE") Then
					_Log("Anmelde-Button betätigen (TAdvGlowButton!dx)")
					ControlClick("integraSIS_SE", "", "TAdvGlowButton!dx" & $i)
				EndIf
			Next

			$RetVal = WinWait("[CLASS:TfrmLogin]", "", 2)
			If $RetVal = 0 Then
				_Log("Anmeldefenster konnte nicht gefunden werden")
				Return -1
			Else
				; bis SIS V5
				$RetVal = ControlSetText("[CLASS:TfrmLogin]", "", "TEdit2", $DecryptedUser)
				ControlSetText("[CLASS:TfrmLogin]", "", "TEdit1", $DecryptedPW)
				; ab SIS V6
				$RetVal = ControlSetText("[CLASS:TfrmLogin]", "Ok", "TEdit!dx2", $DecryptedUser)
				ControlSetText("[CLASS:TfrmLogin]", "Ok", "TEdit!dx1", $DecryptedPW)

				; bis SIS V5
				ControlClick("[CLASS:TfrmLogin]", "", "TButton2")
				; ab SIS V6
				ControlClick("[CLASS:TfrmLogin]", "", "TButton!dx2")
				_Log("Anmeldung für User: " & $DecryptedUser & " durchgeführt")
			EndIf
			Return 0
		EndIf
	Next
	_Log("Es wurde kein LogOn-File gefunden")
EndFunc   ;==>_Decrypt

Func _Log($Eintrag)
	$LogPath = @ScriptDir & "\USBLogOn.log"
	$LogFile = FileOpen($LogPath, 1)
	If $LogFile = -1 Then
		MsgBox($MB_SYSTEMMODAL, "", "An error occurred when reading the file.")
	EndIf

	FileWriteLine($LogFile, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & ": " & $Eintrag)
	FileClose($LogFile)
EndFunc   ;==>_Log
