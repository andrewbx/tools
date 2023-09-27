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

Function RemovePrinter( printer )
	objNetwork.RemovePrinterConnection printer
End Function

' Customers/ITC: Drive Mapping

objNetwork.RemoveNetworkDrive "S:"
objNetwork.RemoveNetworkDrive "G:"
objNetwork.RemoveNetworkDrive "H:"

' Customers/ITC: Printer Mapping

RemovePrinter "\\fps-02\ITC-MFP01"
RemovePrinter "\\fps-02\ITC-C5550"
RemovePrinter "\\fps-02\C-4345"
RemovePrinter "\\fps-02\C-C5550"
