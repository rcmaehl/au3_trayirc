#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=trayirc.ico
#AutoIt3Wrapper_outfile=TrayIRC.exe
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
; -----------------------------
; -         TrayIRC           -
; -        by Manadar         -
; -----------------------------

; Quick To-Do list:
; - /away or /brb and read it
; - Add a /help command, that lists commands

; Idea list:
; - Spell check
; - Add support for private messages, display them in the channel window
; - Add support for private messages, display them in the new windows
; - /msg other users: /msg Nick Hey what's up?!
; - A seperate codebox for the TrayIRC users... I might rename it to AutoItIRC as well.
; - Double click a user, and get some information about him, like his client
; - Respond to CTCP version requests - Note that CTCP is optional

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <Constants.au3>

#include <IE.au3>
#include <Array.au3>

Opt("GUIDataSeparatorChar", @LF) ; Some people have | in their names.. Ex.: Manadar|Away
Opt("TrayMenuMode", 1) ; 1 = no default menu - I need this later
Opt("TrayOnEventMode", 1)
Opt("GUIOnEventMode", 1)
Opt("GUIResizeMode", $GUI_DOCKAUTO)

$sHTML = "<HTML>" & @CR
$sHTML &= "<HEAD>" & @CR
$sHTML &= '<style type="text/css"><!-- body { margin: 4px; line-height: 16px;} --></style>'
$sHTML &= "</HEAD>" & @CR
$sHTML &= "<BODY>"
$sHTML &= "</BODY>"
$sHTML &= "</HTML>"

Global $sock, $version = 0.23
Global $server = IniRead("TrayIRC.ini", "options", "Server", "irc.freenode.net")
Global $port = 6667
Global $nick = IniRead("TrayIRC.ini", "options", "Nickname", "")
Global $channel = IniRead("TrayIRC.ini", "options", "Channel", "#AutoIt")
Global $BootWithWindow = IniRead("TrayIRC.ini", "options", "BootWithWindows", "0")
Global $ForceActivation = IniRead("TrayIRC.ini", "options", "ForceActivation", "0")

$GUIOpt = GUICreate("TrayIRC Options", 225, 223)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Opt_Close")

GUICtrlCreateGroup("Options", 5, 5, 215, 105)
GUICtrlCreateLabel("Nickname", 15, 28, 52, 17)
$InputNickname = GUICtrlCreateInput($nick, 75, 25, 126, 21)
$OptStartWithWindows = GUICtrlCreateCheckbox("Start TrayIRC with Windows", 15, 55, 187, 17)
If Not @Compiled Then GUICtrlSetState($OptStartWithWindows, $GUI_DISABLE)
$OptForceActivation = GUICtrlCreateCheckbox("Jump from Tray on Chat messages", 15, 80, 187, 17)

GUICtrlCreateGroup("Advanced", 5, 115, 215, 80)
GUICtrlCreateLabel("Server", 15, 138, 35, 17)
$InputServer = GUICtrlCreateInput($server, 75, 135, 126, 21)
GUICtrlCreateLabel("Channel", 15, 163, 43, 17)
$InputChannel = GUICtrlCreateInput($channel, 75, 160, 126, 21)

$ButtonAccept = GUICtrlCreateButton("Accept", 10, 199, 100, 21)
GUICtrlSetOnEvent($ButtonAccept, "_Opt_Accept")
$ButtonCancel = GUICtrlCreateButton("Cancel", 118, 199, 100, 21)
GUICtrlSetOnEvent($ButtonCancel, "_Opt_Cancel")

GUICtrlSetState($InputNickname, $GUI_FOCUS)

Global $members[1] = [$nick]
Dim $i = 0

If $server = "" Or $nick = "" Or $channel = "" Then
	GUISetState(@SW_SHOW, $GUIOpt)

	While $server = "" Or $nick = "" Or $channel = "" ; wait for the option window to have fixed the problem
		Sleep(100)
	WEnd
EndIf

$oIE = _IECreateEmbedded()

$GUI = GUICreate($channel & " on " & $server & " - TrayIRC " & $version & " (Unicode)", 600, 398, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_SIZEBOX, $WS_MAXIMIZEBOX))
GUISetOnEvent($GUI_EVENT_CLOSE, "_GUI_Close")
GUISetOnEvent($GUI_EVENT_MINIMIZE, "_GUI_ToTray")
GUISetFont(10, 400, 0, "Verdana")

$OutputEdit = GUICtrlCreateObj($oIE, 5, 5, 470, 324)
GUICtrlSetResizing(-1, $GUI_DOCKBORDERS)
$NameList = GUICtrlCreateList("", 475, 5, 121, 329, -1, $WS_EX_STATICEDGE)
GUICtrlSetResizing(-1, $GUI_DOCKBORDERS - $GUI_DOCKLEFT + $GUI_DOCKWIDTH)
$InputEdit = GUICtrlCreateEdit("", 5, 329 + 5, 590, 60, BitOR($ES_AUTOHSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
GUICtrlSetState($InputEdit, $GUI_DISABLE)

_IENavigate($oIE, "about:blank")
_IEDocWriteHTML($oIE, $sHTML)
_IEHeadInsertEventScript($oIE, "document", "oncontextmenu", "return false")

GUISetState(@SW_SHOW, $GUI)

TraySetOnEvent($TRAY_EVENT_PRIMARYUP, "_GUI_FromTray")

_GUI_AddGlobalMessage("Thank you for using Manadars TrayIRC (Version " & $version & ")", "000000")
_GUI_AddGlobalMessage("Connecting to " & $server &" ...")

TCPStartup()
$sock = _IRCConnect($server, $port, $nick); Connects to IRC and Identifies its Nickname

While 1
	$recv = TCPRecv($sock, 8192)
	If @error and Not @error = -1 Then
		_GUI_AddGlobalMessage("Server has disconnected... Bye :[")
		Sleep(4000)
		Exit
	Else
		ConsoleWrite($recv)
	EndIf
	If $recv Then
		$sData = StringSplit($recv, @CRLF); Splits the messages
		For $i = 1 To $sData[0] Step 1
			$sTemp = StringSplit($sData[$i], " ")

			If $sTemp[1] = "" Then ContinueLoop; If its empty, Continue!
			If $sTemp[1] = "PING"  Then _IRCPing($sock, $sTemp[2]); Checks for PING replys (There smaller then usual messages so its special!
			If $sTemp[0] <= 2 Then ContinueLoop; Useless messages for the most part

			If StringLeft($sData[$i], 1) = ":"  Then
				$sData[$i] = StringTrimLeft($sData[$i], 1)

				;kubrick.freenode.net 353 Manadar = #autoit :Manadar poisonkiller2 poisonkiller WhOOt hansengel WebPrag\work Tobsn Rickbert
				If $sTemp[0] >= 5 And $sTemp[3] = $nick And $sTemp[5] = $channel And StringRegExp($sData[$i], "(?i)" & StringReplace($nick, "|", "\|") & " [@%&~=] " & $channel & " :") Then
					; This contains names of people in the channel
					$sNameList = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					$members = StringSplit($sNameList, " ",2)
					_GUI_MemberListSet($members)
				EndIf

				;kubrick.freenode.net 376 Manadar :End of /MOTD command.
				If $sTemp[3] = $nick And $sTemp[4] = ":End"  And $sTemp[6] = "/MOTD"  Then
					_GUI_AddGlobalMessage("You have joined " & $channel)
					GUICtrlSetState($InputEdit, $GUI_ENABLE)
					GUICtrlSetState($InputEdit, $GUI_FOCUS)
;					_GUI_AddGlobalMessage("You have connected successfully")
					_IRCJoinChannel($sock, $channel)
				EndIf

				;kubrick.freenode.net 433 * Manadar :Nickname is already in use.
				If $sTemp[0] >= 9 And $sTemp[4] = $nick And $sTemp[5] = ":Nickname"  Then
					_GUI_AddGlobalMessage($nick & " is already in use. Renamed to " & $nick & "1", "B05A76")
					$nick &= "1"
					GUICtrlSetData($InputNickname, $nick)
					_IRCSendMessage($sock, "NICK " & $nick)
				EndIf

				;Manadar!n=Miranda@84-104-140-8.cable.quicknet.nl PRIVMSG #a :Hai
				If $sTemp[0] >= 3 And $sTemp[2] = "PRIVMSG"  And $sTemp[3] = $channel Then
					$text = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					$snick = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					If StringLeft($text, 1) = Chr(1) Then ; /me message
						$text = StringTrimLeft($text, 8)
						_GUI_AddGlobalMessage($snick & " " & $text, "B05AA0")
					Else
						_GUI_AddPersonalMessage($text, $snick)
					EndIf
				EndIf

				;Manadar!n=Miranda@84-104-140-8.cable.quicknet.nl PART #a :Bye
				If $sTemp[0] >= 3 And $sTemp[2] = "PART"  And $sTemp[3] = $channel Then
					$name = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					$element = __ArraySearch($members, $name)
					_ArrayDelete($members, $element)
					$message = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					_GUI_AddGlobalMessage($name & " has left the channel:" & $message, "B05A76")
					_GUI_MemberListSet($members)
				EndIf

				;Zerosploit!n=homgwtfb@84-104-9-159.cable.quicknet.nl QUIT :"im gay"
				If $sTemp[0] >= 2 And $sTemp[2] = "QUIT"  Then
					$name = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					$element = __ArraySearch($members, $name)
					_ArrayDelete($members, $element)
					$message = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					_GUI_AddGlobalMessage($name & " quit the server: " & $message, "B05A76")
					_GUI_MemberListSet($members)
				EndIf

				;Manadar!n=Miranda@84-104-140-8.cable.quicknet.nl JOIN :#A
				If $sTemp[0] >= 3 And $sTemp[2] = "JOIN"  And $sTemp[3] = ":" & $channel Then
					$name = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					If $name <> $nick Then
						_ArrayAdd($members, $name)
						_GUI_AddGlobalMessage($name & " has joined the channel.")
						_GUI_MemberListSet($members)
;					Else
;						_GUI_AddGlobalMessage("You have joined " & $channel)
;						GUICtrlSetState($InputEdit, $GUI_ENABLE)
;						GUICtrlSetState($InputEdit, $GUI_FOCUS)
					EndIf
				EndIf

				;XaoCTheoRY!n=homgwtfb@84-104-9-159.cable.quicknet.nl NICK :Zer0sploit
				If $sTemp[0] >= 3 And $sTemp[2] = "NICK"  Then
					$name = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					$element = __ArraySearch($members, $name)
					_ArrayDelete($members, $element)
					$name_after = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					_ArrayAdd($members, $name_after)

					If $name = $nick Then
						$nick = $name_after
						GUICtrlSetData($InputNickname, $nick)
					EndIf

					_GUI_AddGlobalMessage($name & " changed name to " & $name_after)
					_GUI_MemberListSet($members)
				EndIf

				;Nick!Name@Host KICK #Channel User :Reason
				If $sTemp[0] >= 2 And $sTemp[2] = "KICK"  Then
					$name = StringLeft($sData[$i], StringInStr($sData[$i], "!") - 1)
					$element = __ArraySearch($members, $name)
					_ArrayDelete($members, $element)

					_GUI_AddGlobalMessage($name & " has been kicked from the channel.")
					_GUI_MemberListSet($members)
				EndIf

				;kubrick.freenode.net 433 Manadar test :Nickname is already in use.
				If $sTemp[0] >= 9 And $sTemp[3] = $nick And $sTemp[5] = ":Nickname"  Then
					$name = $sTemp[4]

					_GUI_AddGlobalMessage("Nickname " & $name & " is already in use.", "B05A76")
				EndIf

				;kubrick.freenode.net 332 Manadar #AutoIt :Current AutoIt Version: 3.2.10.0 || Post code longer than 3 lines @ http://autoit.pastebin.com || Don't ask to ask; just ask
				If $sTemp[0] >= 7 And $sTemp[3] = $nick And $sTemp[4] = $channel Then
					$msg = StringTrimLeft($sData[$i], StringInStr($sData[$i], ":"))
					If $msg <> "End of /NAMES list."  Then
						_GUI_AddGlobalMessage($msg, "4684DF")
					EndIf
				EndIf

				;Manadar!n=Miranda@84-104-25-84.cable.quicknet.nl TOPIC #autoit :Current AutoIt Version: 3.2.10.0 || Post code longer than 3 lines @ ht...


				;kubrick.freenode.net NOTICE Hickname kiss.gif** Notice -- Too many nick changes; wait 4 seconds before trying again
			EndIf
		Next
	EndIf
	If StringInStr(GUICtrlRead($InputEdit), @CRLF) Then
		_GUI_Enter()
	EndIf
	Sleep(10)
WEnd

Func _Opt_Accept()
	$temp1 = GUICtrlRead($InputServer)
	$temp2 = GUICtrlRead($InputNickname)
	$temp3 = GUICtrlRead($InputChannel)
	$temp4 = GUICtrlRead($OptStartWithWindows)
	$temp5 = GUICtrlRead($OptForceActivation)

	If $temp1 <> "" Then
		IniWrite("TrayIRC.ini", "options", "Server", $temp1)
		If $server <> $temp1 Then
			_Reboot()
		EndIf
		$server = $temp1
	EndIf
	If $temp2 <> "" Then
		IniWrite("TrayIRC.ini", "options", "Nickname", $temp2)
		If $sock Then _IRCSendMessage($sock, "NICK " & $temp2)
	EndIf
	If $temp3 <> "" Then
		IniWrite("TrayIRC.ini", "options", "Channel", $temp3)
		If $channel <> $temp3 Then
			_Reboot()
		EndIf
		$channel = $temp3
	EndIf
	If $temp4 = $GUI_CHECKED Then
		IniWrite("TrayIRC.ini", "options", "BootWithWindows", 1)
		If @Compiled Then RegWrite("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "TrayIRC", "REG_SZ", @ScriptFullPath)
	Else
		IniWrite("TrayIRC.ini", "options", "BootWithWindows", 0)
		RegDelete("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "TrayIRC")
	EndIf
	If $temp5 = $GUI_CHECKED Then
		IniWrite("TrayIRC.ini", "options", "ForceActivation", 1)
	Else
		IniWrite("TrayIRC.ini", "options", "ForceActivation", 0)
	EndIf

	GUISetState(@SW_HIDE, $GUIOpt)
	$server = IniRead("TrayIRC.ini", "options", "Server", "irc.freenode.net")
	$port = 6667
	$nick = IniRead("TrayIRC.ini", "options", "Nickname", "")
	$channel = IniRead("TrayIRC.ini", "options", "Channel", "#AutoIt")
	$BootWithWindow = IniRead("TrayIRC.ini", "options", "BootWithWindows", "0")
	$ForceActivation = IniRead("TrayIRC.ini", "options", "ForceActivation", "0")
EndFunc   ;==>_Opt_Accept

Func _Opt_Close()
	If MsgBox(0x24, "TrayIRC", "Are you sure you wish to close TrayIRC?") == 6 Then
		If $sock Then _IRCQuit($sock, "TrayIRC. ©2007 Manadar.")
		Exit
	EndIf
EndFunc   ;==>_Opt_Close

Func _Reboot()
	MsgBox(0x40, "TrayIRC", "TrayIRC must be rebooted to apply the changes.")
	If @Compiled Then
		Run(@ScriptFullPath)
	Else
		Run(@AutoItExe & " " & @ScriptFullPath)
	EndIf
	Exit
EndFunc   ;==>_Reboot

Func _Opt_Cancel()
	If $server = "" Or $nick = "" Or $channel = "" Then
		MsgBox(0x10, "TrayIRC", "Please fill in the server, channel and nickname fields.")
	Else
		GUISetState(@SW_HIDE, $GUIOpt)
		GUICtrlSetData($InputServer, $server)
		GUICtrlSetData($InputChannel, $channel)
		GUICtrlSetData($InputNickname, $nick)
		If $BootWithWindow = 1 Then
			GUICtrlSetState($OptStartWithWindows, $GUI_CHECKED)
		Else
			GUICtrlSetState($OptStartWithWindows, $GUI_UNCHECKED)
		EndIf
		If $ForceActivation = 1 Then
			GUICtrlSetState($OptForceActivation, $GUI_CHECKED)
		Else
			GUICtrlSetState($OptForceActivation, $GUI_UNCHECKED)
		EndIf
	EndIf
EndFunc   ;==>_Opt_Cancel

Func _Flash()
	If WinGetState($GUI) = 21 And $ForceActivation = 1 Then
		GUISetState(@SW_SHOW, $GUI)
	EndIf
	If Not WinActive($GUI) Then
		WinFlash($GUI, "", 2, 150)
	EndIf
EndFunc   ;==>_Flash

Func _GUI_Format(ByRef $sText)
	Local $sReturn = ""
	$sText = StringReplace($sText, "&", "&amp;")
	$sText = StringReplace($sText, "<", "&lt;") ;no user tags
	$sText = StringReplace($sText, ">", "&gt;")
	$sChar = StringSplit($sText, "")
	For $i = 1 To $sChar[0]
		$asc = Asc($sChar[$i])
		Switch $asc
			Case 0x20 To 0x7E, 0x80, 0x82 To 0x8C, 0x8E, 0x91 To 0x9C, 0x9E To 0xAC, 0xAE To 0xFF ; Support for Extended ASCII, some characters are not displayed
				$sReturn &= Chr($asc)
		EndSwitch
	Next
	$sText = $sReturn
EndFunc   ;==>_GUI_Format

Func _IRC_SendMessage($msg)
	_IRCSendMessage($sock, $msg, $channel)
EndFunc   ;==>_IRC_SendMessage

Func _GUI_Close()
	_IRCQuit($sock, "TrayIRC. ©2007 Manadar.")
	Exit
EndFunc   ;==>_GUI_Close

Func _GUI_ToTray()
	GUISetState(@SW_HIDE, $GUI)
EndFunc   ;==>_GUI_ToTray

Func _GUI_FromTray()
	GUISetState(@SW_SHOW, $GUI)
	WinActivate($GUI)
EndFunc   ;==>_GUI_FromTray

Func _GUI_Enter()
	If ControlGetFocus($GUI) = "Edit1"  Then
		$text = _Uni2Ansi(StringTrimRight(GUICtrlRead($InputEdit), 2))
		GUICtrlSetData($InputEdit, "")
		If $text <> "" Then
			If StringInStr($text, " ") Then
				$command = StringLeft($text, StringInStr($text, " ") - 1)
			Else
				$command = $text
			EndIf
			Switch $command
				Case "/nick"
					_IRCSendMessage($sock, "NICK " & StringTrimLeft($text, StringInStr($text, " ")))
					_GUI_MemberListSet($members)
				Case "/quit", "/part"
					If MsgBox(0x24, "TrayIRC", "Are you sure you wish to close TrayIRC?") == 6 Then
						$msg = StringTrimLeft($text, 6)
						If $msg = "" Then
							_IRCQuit($sock, "TrayIRC. ©2007 Manadar.")
						Else
							_IRCQuit($sock, $msg)
						EndIf
						Exit
					EndIf
				Case "/me"
					$msg = StringTrimLeft($text, 4)
					$text = Chr(1) & "ACTION " & $msg & Chr(1)
					_IRC_SendMessage($text)
					_GUI_AddGlobalMessage($nick & " " & $msg, "B05AA0")
				Case "/opt"
					GUISetState(@SW_SHOW, $GUIOpt)
				Case Else
					If StringLeft($text, 1) = "/"  Then
						_GUI_AddGlobalMessage($command & " is not (yet) a valid command.")
					Else
						_GUI_AddPersonalMessage($text, $nick)
						_IRC_SendMessage($text)
					EndIf
			EndSwitch
		EndIf
	EndIf
EndFunc   ;==>_GUI_Enter

Func _GUI_MemberListSet($names)
	_ArraySort($names)
	GUICtrlSetData($NameList, "")
	For $i = 0 To UBound($names) - 1
		GUICtrlSetData($NameList, $names[$i] & @LF)
	Next
EndFunc   ;==>_GUI_MemberListSet

Func _GUI_AddGlobalMessage($msg, $color = "5AA05A")
	$msg = _HTMLEntityNumEncode(_Ansi2Uni($msg))
	$sText = _IEBodyReadHTML($oIE)
	If $sText == 0 Then $sText = ""
	_IEBodyWriteHTML($oIE, $sText & "<font face=""Terminal"" color=""#3254F8"" size=""1"">[" & @HOUR & ":" & @MIN & "]</font>  <font face=""Verdana"" color=""#" & $color & """ size=""-1""> " & $msg & "</font><br>")
	_GUI_AutoScroll()
EndFunc   ;==>_GUI_AddGlobalMessage

Func _GUI_AddPersonalMessage($msg, $nickname)
	$msg = _HTMLEntityNumEncode(_Ansi2Uni($msg))
	$nickname = _HTMLEntityNumEncode(_Ansi2Uni($nickname))
	$sText = _IEBodyReadHTML($oIE)
	If $sText == 0 Then $sText = ""
	_IEBodyWriteHTML($oIE, $sText & "<font face=""Terminal"" color=""#3254F8"" size=""1"">[" & @HOUR & ":" & @MIN & "]</font>  <font face=""Verdana"" size=""-1""><b>" & $nickname & ":</b></font><font face=""Verdana"" color=""#5A5A5A"" size=""-1""> " & $msg & "</font><br>")
	_GUI_AutoScroll()
	_Flash()
EndFunc   ;==>_GUI_AddPersonalMessage

Func _GUI_AutoScroll()
	$iDocHeight = $oIE.document.body.scrollHeight
	$oIE.document.parentWindow.scrollTo(0, $iDocHeight)
EndFunc   ;==>_GUI_AutoScroll


Func __ArraySearch(Const ByRef $avArray, $vWhat2Find, $iStart = 0, $iEnd = 0, $iCaseSense = 0, $fPartialSearch = False)
	Local $iCurrentPos, $iUBound, $iResult
	If Not IsArray($avArray) Then
		SetError(1)
		Return -1
	EndIf
	$iUBound = UBound($avArray) - 1
	If $iEnd = 0 Then $iEnd = $iUBound
	If $iStart > $iUBound Then
		SetError(2)
		Return -1
	EndIf
	If $iEnd > $iUBound Then
		SetError(3)
		Return -1
	EndIf
	If $iStart > $iEnd Then
		SetError(4)
		Return -1
	EndIf
	If Not ($iCaseSense = 0 Or $iCaseSense = 1) Then
		SetError(5)
		Return -1
	EndIf
	For $iCurrentPos = $iStart To $iEnd
		Select
			Case $iCaseSense = 0
				If $fPartialSearch = False Then
					If ($avArray[$iCurrentPos] = $vWhat2Find) Or ($avArray[$iCurrentPos] = "@" & $vWhat2Find) Or ($avArray[$iCurrentPos] = "+" & $vWhat2Find) Or ($avArray[$iCurrentPos] = "&" & $vWhat2Find) Or ($avArray[$iCurrentPos] = "~" & $vWhat2Find) Or ($avArray[$iCurrentPos] = "%" & $vWhat2Find) Then
						SetError(0)
						Return $iCurrentPos
					EndIf
				Else
					$iResult = StringInStr($avArray[$iCurrentPos], $vWhat2Find, $iCaseSense)
					If $iResult > 0 Then
						SetError(0)
						Return $iCurrentPos
					EndIf
				EndIf
			Case $iCaseSense = 1
				If $fPartialSearch = False Then
					If $avArray[$iCurrentPos] == $vWhat2Find Then
						SetError(0)
						Return $iCurrentPos
					EndIf
				Else
					$iResult = StringInStr($avArray[$iCurrentPos], $vWhat2Find, $iCaseSense)
					If $iResult > 0 Then
						SetError(0)
						Return $iCurrentPos
					EndIf
				EndIf
		EndSelect
	Next
	SetError(6)
	Return -1
EndFunc   ;==>__ArraySearch

#cs

== Common Recieved Messages ==

Server = Server who sent the message
Nick = A User who the message is from
Name = Settable by user, set in the USER command
Host = Host Mask (Can be your IP or something that represents it)

Any 3 digit Code:
    Contains information based on various events
    Check https://www.alien.net.au/irc/irc2numerics.html for specifics

    SYNTAXES:
        :Server ### Recipient
        :Server ### Recipient :Info
        :Server ### Recipient Info :Info

    EXAMPLES:
        :hobana.freenode.net 001 Au3Bot :Welcome to the freenode Internet Relay Chat Network Au3Bot
        :hobana.freenode.net 002 Au3Bot :Your host is hobana.freenode.net[62.231.75.133/6667], running version ircd-seven-1.1.3
        :hobana.freenode.net 461 Au3Bot PING :Not enough parameters

JOIN:
    You receive this when someone, including yourself, joins a channel.
    Check http://tools.ietf.org/html/rfc1459#section-4.2.1 and http://tools.ietf.org/html/rfc2812#section-3.2.1 for specifics

    SYNTAXES:
        :Nick!Name@Host JOIN Channel

    EXAMPLES:
        :Au3Bot!~Au3Bot@unaffiliated/why JOIN #fcofix


KICK:
    You receive this when someone gets kicked (Including yourself!)
    Check http://tools.ietf.org/html/rfc1459#section-4.2.8 and http://tools.ietf.org/html/rfc2812#section-3.2.8 for specifics

    SYNTAXES:
        :Nick!Name@Host KICK Channel User1 :Reason

    EXAMPLE:
        :rcmaehl!~why@unaffiliated/why KICK #fcofix Au3Bot :No Bots Allowed

MODE:
    You receive this when a user or channel mode is changed.
    Check http://tools.ietf.org/html/rfc1459#section-4.2.3.1, http://tools.ietf.org/html/rfc1459#section-4.2.3.2,
    http://tools.ietf.org/html/rfc2812#section-3.1.5, and http://tools.ietf.org/html/rfc2812#section-3.2.3

    SYNTAXES:
        :Nick MODE Nick :+Mode
        :Nick MODE Nick :-Mode
        :Nick!Name@host MODE Channel :+Mode
        :Nick!Name@host MODE Channel :-Mode
        :Nick!Name@host MODE Channel :+Mode User
        :Nick!Name@host MODE Channel :-Mode User

    EXAMPLES:
        :Au3Bot MODE Au3Bot :+i
        :rcmaehl!~why@unaffiliated/why MODE #fcofix +s
        :rcmaehl!~why@unaffiliated/why MODE #fcofix +o rcmaehl
        :ChanServ!ChanServ@services. MODE #fcofix -o rcmaehl


NICK:
    You receive this when someone, including yourself, changes their nick.
    Check http://tools.ietf.org/html/rfc1459#section-4.1.2 and http://tools.ietf.org/html/rfc2812#section-3.1.2 for specifics

    SYNTAXES:
        :Nick!Name@Host NICK :NewNick

    EXAMPLES:
        :rcmaehl!~why@unaffiliated/why NICK :rcmaehl2

PART:
    You receive this when someone, including yourself, parts a channel.
    Check http://tools.ietf.org/html/rfc1459#section-4.2.2 and http://tools.ietf.org/html/rfc2812#section-3.2.2 for specifics

    SYNTAXES:
        :Nick!Name@Host PART Channel
        :Nick!Name@Host PART Channel :"message"

    EXAMPLES:
        :rcmaehl!~why@unaffiliated/why PART #fcofix
        :rcmaehl!~why@unaffiliated/why PART #fcofix :"test message"

PING:
    You receive this when there's been no activity on your connection to the server for a certain period of time to confirm you're still connected.
    Check https://tools.ietf.org/html/rfc1459#section-4.6.2 and http://tools.ietf.org/html/rfc2812#section-3.7.2 for specifics

    SYNTAXES:
        PING :Server
        PING :RandomString

    EXAMPLES:
        PING :cameron.freenode.net
        PING :3dS4UmiS

PRIVMSG:
    You receive this when someone has sent a message in a channel or to you personally.
    Check http://tools.ietf.org/html/rfc1459#section-4.4.1 and http://tools.ietf.org/html/rfc2812#section-3.3.1 for specifics

    SYNTAXES:
        :Nick!Name@Host PRIVMSG Channel :Message
        :Nick!Name@Host PRIVMSG Recipient :Message

    EXAMPLES:
        :rcmaehl!~why@unaffiliated/why PRIVMSG #Channel :test message
        :rcmaehl!~why@unaffiliated/why PRIVMSG Au3Bot :Hi Au3bot

#ce


;===============================================================================
;
; Description:      Connects you to a IRC Server, and gives your chosen Nick
; Parameter(s):     $server - IRC Server you wish to connect to
;                   $port - Port to connect to (Usually 6667)
;                   $nick - Nick you choose to use (You can change later)
; Requirement(s):   TCPStartup () to be run
; Return Value(s):  On Success - Socket identifer
;                   On Failure - It will exit on error
; Author(s):        Chip
; Note(s):          English only
;
;===============================================================================
Func _IRCConnect($server, $port, $nick)
	Local $i = TCPConnect(TCPNameToIP($server), $port)
	If $i = -1 Then Exit MsgBox(1, "IRC.au3 Error", "Server " & $server & " is not responding.")
	TCPSend($i, "NICK " & $nick & @CRLF)
	TCPSend($i, "USER " & $nick & " 0 0 " & $nick & @CRLF)
	Return $i
EndFunc   ;==>_IRCConnect

;===============================================================================
;
; Description:      Joins an IRC Channel
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;                   $chan - Channel you wish to join
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
; Author(s):        Chip
; Note(s):          English only
;
;===============================================================================
Func _IRCJoinChannel($irc, $chan)
	If $irc = -1 Then Return 0
	TCPSend($irc, "JOIN " & $chan & @CRLF)
	If @error Then
		MsgBox(1, "IRC.au3", "Server has disconnected.")
		Return -1
	EndIf
	Return 1
EndFunc   ;==>_IRCJoinChannel

;===============================================================================
;
; Description:      Sends a message using IRC
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;               $msg - Message you want to send
;                   $chan - Channel/Nick you wish to send to
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
; Author(s):        Chip
; Note(s):          English only
;
;===============================================================================
Func _IRCSendMessage($irc, $msg, $chan = "")
	If $irc = -1 Then Return 0
	If $chan = "" Then
		TCPSend($irc, $msg & @CRLF)
		If @error Then
			MsgBox(1, "IRC.au3", "Server has disconnected.")
			Return -1
		EndIf
		Return 1
	EndIf
	TCPSend($irc, "PRIVMSG " & $chan & " :" & $msg & @CRLF)
	If @error Then
		MsgBox(1, "IRC.au3", "Server has disconnected.")
		Return -1
	EndIf
	Return 1
EndFunc   ;==>_IRCSendMessage

;===============================================================================
;
; Description:      Changes a MODE on IRC
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;               $mode - Mode you wish to change
;                   $chan - Channel/Nick you wish to send to
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
; Author(s):        Chip
; Note(s):          English only
;
;===============================================================================
Func _IRCChangeMode($irc, $mode, $chan = "")
	If $irc = -1 Then Return 0
	If $chan = "" Then
		TCPSend($irc, "MODE " & $mode & @CRLF)
		If @error Then
			MsgBox(1, "IRC.au3", "Server has disconnected.")
			Return -1
		EndIf
		Return 1
	EndIf
	TCPSend($irc, "MODE " & $chan & " " & $mode & @CRLF)
	If @error Then
		MsgBox(1, "IRC.au3", "Server has disconnected.")
		Return -1
	EndIf
	Return 1
EndFunc   ;==>_IRCChangeMode

;===============================================================================
;
; Description:      Returns a PING to Server
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;               $ret - The end of the PING to return
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
; Author(s):        Chip
; Note(s):          English only
;
;===============================================================================
Func _IRCPing($irc, $ret)
	If $ret = "" Then Return -1
	TCPSend($irc, "PONG " & $ret & @CRLF)
	If @error Then
		MsgBox(1, "IRC.au3", "Server has disconnected.")
		Return -1
	EndIf
	Return 1
EndFunc   ;==>_IRCPing

;===============================================================================
;
; Description:      Leave the IRC Channel
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;               $msg - Message to send with PART, optional
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
;
;===============================================================================
Func _IRCLeaveChannel($irc, $msg = "", $chan = "")
	If $irc = -1 Then Return 0
	TCPSend($irc, "PART " & $chan & " :" & $msg & @CRLF)
	If @error Then
		MsgBox(1, "IRC.au3", "Server has disconnected.")
		Return -1
	EndIf
	Return 1
EndFunc   ;==>_IRCLeaveChannel

;===============================================================================
;
; Description:      Close the IRC Connection
; Parameter(s):     $irc - Socket Identifer from _IRCConnect ()
;               $msg - Message to send with quit, optional (not able to see with all clients)
; Requirement(s):   _IRCConnect () to be run
; Return Value(s):  On Success - 1
;                   On Failure - -1 = Server disconnected.
;
;===============================================================================
Func _IRCQuit($irc, $msg = "")
	If $irc = -1 Then Return 0
	TCPSend($irc, "QUIT :" & $msg & @CRLF)
	Sleep(100) ; I think the message has to sink in or something tongue.gif
	Return 1
EndFunc   ;==>_IRCQuit


;===============================================================================
;
; Description:      Unicode support for TrayIRC
; Requirement(s):   Unicode version of AutoIt
; Return Value(s):  Encoded/Decoded String(s)
; Author(s):        Dhilip89
;
;===============================================================================

Func _Uni2Ansi($Unicode)
	$Binary = StringToBinary($Unicode, 4)
	$Hex = StringReplace($Binary, '0x', '', 1)
	$BinaryLength = StringLen($Hex)
	Local $ANSI
	For $i = 1 To $BinaryLength Step 2
		$Char = StringMid($Hex, $i, 2)
		$ANSI &= BinaryToString('0x' & $Char)
	Next
	Return $ANSI
EndFunc   ;==>_Uni2Ansi

Func _Ansi2Uni($ANSI)
	$Binary = StringToBinary($ANSI)
	$Unicode = BinaryToString($Binary, 4)
	Return $Unicode
EndFunc   ;==>_Ansi2Uni

;===============================================================================

;===============================================================================
;
; Function Name:    _HTMLEntityNumEncode()
; Description:      Encode the normal string into HTML Entity Number
; Parameter(s):     $String  - The string you want to encode.
;
; Requirement(s):   AutoIt v3.2.4.9 or higher (Unicode)
; Return Value(s):  On Success  - Returns HTML Entity Number
;                   On Failure  - Nothing
;
; Author(s):        Dhilip89
;
;===============================================================================

Func _HTMLEntityNumEncode($String)
	$StringLength = StringLen($String)
	Local $HTMLEntityNum
	If $StringLength = 0 Then Return ''
	For $i = 1 To $StringLength
		$StringChar = StringMid($String, $i, 1)
		$HTMLEntityNum &= '&#' & AscW($StringChar) & ';'
	Next
	Return $HTMLEntityNum
EndFunc   ;==>_HTMLEntityNumEncode

;===============================================================================
;
; Function Name:    _HTMLEntityNumDecode()
; Description:      Decode the HTML Entity Number into normal string
; Parameter(s):     $HTMLEntityNum  - The HTML Entity Number you want to decode.
;
; Requirement(s):   AutoIt v3.2.4.9 or higher (Unicode)
; Return Value(s):  On Success  - Returns decoded strings
;                   On Failure  - Nothing
;
; Author(s):        Dhilip89
;
;===============================================================================

Func _HTMLEntityNumDecode($HTMLEntityNum)
	If $HTMLEntityNum = '' Then Return ''
	$A = StringReplace($HTMLEntityNum, '&#', '')
	$B = StringSplit($A, ';')
	$C = $B[0]
	Local $String
	For $i = 1 To $C
		$String &= ChrW($B[$i])
	Next
	Return $String
EndFunc   ;==>_HTMLEntityNumDecode