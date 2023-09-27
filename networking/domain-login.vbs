Option Explicit

On Error Resume Next

Dim aLogin, objShell, objFs, objNetwork, objEnv, objConnection, objRecordSet, objCommand, objNS, objUser
Dim domusername, dompassword, usercompany

const ldap_domain = "ldap-01.domain-local.com"
const netb_domain = "DOMAIN.LOCAL"
const domain = "@domain-local.com"
const file_svr = "fps-01"
const print_svr = "fps-02"
const data_path = "Data"
const global_dir = "Global"
const user_dir = "Users"
const shared_dir = "Shared"

Set objShell = WScript.CreateObject("WScript.Shell")
Set objFs = WScript.CreateObject("Scripting.FileSystemObject")
Set objNetwork = CreateObject("WScript.Network")
Set objEnv = objShell.Environment("Process")

Function MakeDesktopShortcut( name, target )
	Dim Shortcut,DesktopPath,StartupPath
	DesktopPath = objShell.SpecialFolders("Desktop")
	Set Shortcut = objShell.CreateShortcut(DesktopPath & "\" & name & ".lnk")
	Shortcut.TargetPath = target
	StartupPath = objFs.GetParentFolderName( target )
	If objFs.FolderExists( StartupPath ) then
		Shortcut.WorkingDirectory = StartupPath
	End If
	Shortcut.Save
End Function

Function MachineAuth( machine, username, password )
    objNetwork.MapNetworkDrive "", "\\" & machine & "\" & "IPC$", "False", username, password
	If Err.Number <> 0 Then
		objNetwork.RemoveNetworkDrive machine
		objNetwork.MapNetworkDrive "", machine, "False", username, password
	End If
End Function

Function MapDrive( drive, share )
    objNetwork.MapNetworkDrive drive, share
	If Err.Number <> 0 Then
		objNetwork.RemoveNetworkDrive drive
		objNetwork.MapNetworkDrive drive, share
	End If
End Function

Function MapPrinter( printer, def )
	objNetwork.AddWindowsPrinterConnection printer
	If def = 1 Then
		objNetwork.SetDefaultPrinter printer
	End If
    Set printer = nothing
	Set def = nothing
End Function

Function RemovePrinter( printer )
	objNetwork.RemovePrinterConnection printer
End Function

Function IELogin( )
	Dim objIE
	Set objIE = WScript.CreateObject("InternetExplorer.Application","objIE_")
	objIE.Navigate "about:blank"
	objIE.Document.Title = "Company Login"
	objIE.ToolBar        = False
	objIE.Resizable      = False
	objIE.StatusBar      = False
	objIE.Width          = 380
	objIE.Height         = 210
	With objIE.Document.ParentWindow.Screen
		objIE.Left = (.AvailWidth  - objIE.Width ) \ 2
		objIE.Top  = (.Availheight - objIE.Height) \ 2
	End With
	Do While objIE.Busy
		WScript.Sleep 500
	Loop
	objIE.Document.Body.InnerHTML = "<font face=""Tahoma""><div align=""center""><font size=""-1"">" _
				      & "Please enter your Domain username & password below:<br><br>" & vbcrlf _
	                              & "<table cellspacing=""5""><tr nowrap>" _
	                              & "<td>Username:</td><td>" _
	                              & "<input type=""text"" size=""20"" " _
	                              & "autocomplete=""off"" " _
	                              & "id=""LoginName""></td></tr>" & vbcrlf _
	                              & "<tr nowrap><td>Password:</td>" _
	                              & "<td><input type=""password"" size=""20"" " _
	                              & "id=""Password""></td>" & vbcrlf _
	                              & "</tr></table>" & vbcrlf _
	                              & "<p><input type=""hidden"" id=""OK"" " _
	                              & "name=""OK"" value=""0"">" _
	                              & "<input type=""submit"" value="" OK "" " _
	                              & "onClick=""VBScript:OK.Value=1"">" _
				      & "<input type=""hidden"" id=""Cancel"" " _
	                              & "name=""Cancel"" value=""0"">" _
	                              & "<input type=""submit"" value="" Cancel "" " _
	                              & "onClick=""VBScript:Cancel.Value=1""></p></div></font>"
	objIE.Visible = True
	
	Do While objIE.Document.All.OK.Value = 0
	If objIE.Document.All.Cancel.Value = 1 Then
	   objIE.Document.All.OK.Value = 1
	Else
           WScript.Sleep 500
	End If
	Loop
 	IELogin = Array( objIE.Document.All.LoginName.Value, objIE.Document.All.Password.Value, objIE.Document.All.OK.Value, objIE.Document.All.Cancel.Value )
	objIE.Quit
	WScript.Sleep 1000
	Set objIE = Nothing
End Function

Function IEProgress( )
	Dim objIE
	Set objIE = WScript.CreateObject("InternetExplorer.Application","objIE_")
	objIE.Navigate "about:blank"
	objIE.Document.Title = "Company Progress"
	objIE.ToolBar        = False
	objIE.Resizable      = False
	objIE.StatusBar      = False
	objIE.Width          = 380
	objIE.Height         = 110
	With objIE.Document.ParentWindow.Screen
		objIE.Left = (.AvailWidth  - objIE.Width ) \ 2
		objIE.Top  = (.Availheight - objIE.Height) \ 2
	End With
	Do While objIE.Busy
		WScript.Sleep 500
	Loop
	objIE.Document.Body.InnerHTML = "<font face=""Tahoma""><div align=""center"">" _
				      & "Please wait while drives and printers are configured...</div></font>"
	objIE.Visible = True
	WScript.Sleep 5000
	objIE.Quit
	Set objIE = Nothing
End Function

Function IEComplete( )
	Dim objIE
	Set objIE = WScript.CreateObject("InternetExplorer.Application","objIE_")
	objIE.Navigate "about:blank"
	objIE.Document.Title = "Company Completed"
	objIE.ToolBar        = False
	objIE.Resizable      = False
	objIE.StatusBar      = False
	objIE.Width          = 380
	objIE.Height         = 100
	With objIE.Document.ParentWindow.Screen
		objIE.Left = (.AvailWidth  - objIE.Width ) \ 2
		objIE.Top  = (.Availheight - objIE.Height) \ 2
	End With
	Do While objIE.Busy
		WScript.Sleep 500
	Loop
	objIE.Document.Body.InnerHTML = "<font face=""Tahoma""><div align=""center"">" _
				      & "Operation Completed.</div></font>"
	objIE.Visible = True
	WScript.Sleep 5000
	objIE.Quit
	Set objIE = Nothing
End Function

Function IEAuthError( )
	Dim objIE
	Set objIE = WScript.CreateObject("InternetExplorer.Application","objIE_")
	objIE.Navigate "about:blank"
	objIE.Document.Title = "Company Error"
	objIE.ToolBar        = False
	objIE.Resizable      = False
	objIE.StatusBar      = False
	objIE.Width          = 380
	objIE.Height         = 130
	With objIE.Document.ParentWindow.Screen
		objIE.Left = (.AvailWidth  - objIE.Width ) \ 2
		objIE.Top  = (.Availheight - objIE.Height) \ 2
	End With
	Do While objIE.Busy
		WScript.Sleep 500
	Loop
	objIE.Document.Body.InnerHTML = "<font face=""Tahoma""><div align=""center"">" _
				      & "Error: Invalid Username or Password.<br><br>" & vbcrlf _
	                              & "<p><input type=""hidden"" id=""OK"" " _
	                              & "name=""OK"" value=""0"">" _
	                              & "<input type=""submit"" value="" OK "" " _
	                              & "onClick=""VBScript:OK.Value=1""></p></div></font>"
	objIE.Visible = True
	
	Do While objIE.Document.All.OK.Value = 0
           WScript.Sleep 500
	Loop
	objIE.Quit
	WScript.Sleep 1000
	Set objIE = Nothing
End Function

' Open Login

aLogin = IELogin()
domusername = aLogin(0)
dompassword = aLogin(1)

' Check Cancellation

if aLogin(3) = "1" Then
   WScript.Quit(1)
End If

' Customers: Check User & Determine SubCompany

Set objConnection = CreateObject("ADODB.Connection")
objConnection.Open "Provider=ADsDSOObject; User Id=" & netb_domain & "\" & domusername & "; Password=" & dompassword & ";"
Set objCommand = CreateObject("ADODB.Command")
objCommand.ActiveConnection = objConnection
objCommand.CommandText = "<LDAP://" & ldap_domain & ">;(&(objectCategory=User)(samAccountName=" & domusername & "));ADsPath;subtree"
Set objRecordSet = objCommand.Execute

If objRecordSet.RecordCount <> 1 Then
	aLogin = IEAuthError()
   	WScript.Quit(1)
End	If

While Not objRecordSet.EOF
        Set objNS = GetObject("LDAP:")
        Set objUser = objNS.OpenDSObject(objRecordset.Fields("ADsPath"), domusername, dompassword, 1)
	usercompany = objUser.Get("Company")
	objRecordSet.MoveNext
Wend
objConnection.Close

aLogin = IEProgress()

' Customers: Drive Mapping

MachineAuth file_svr, domusername & domain, dompassword

MapDrive "S:", "\\" & file_svr & "\" & data_path & "\" & shared_dir & "\" & usercompany
MapDrive "G:", "\\" & file_svr & "\" & data_path & "\" & global_dir
MapDrive "H:", "\\" & file_svr & "\" & data_path & "\" & user_dir & "\" & domusername & "\" & "Home"

' Customers: Printer Mapping

MachineAuth print_svr, domusername & domain, dompassword

if usercompany = "ITC" Then
	MapPrinter "\\" & print_svr & "\" & "ITC-MFP01", 0
	MapPrinter "\\" & print_svr & "\" & "ITC-C5550", 0
Else
	MapPrinter "\\" & print_svr & "\" & "C-4345", 0
	MapPrinter "\\" & print_svr & "\" & "C-C5550", 0
End If

' Operation Completed

aLogin = IEComplete()
