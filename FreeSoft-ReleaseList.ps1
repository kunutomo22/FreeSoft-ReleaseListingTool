#エラー挙動定義
$ErrorActionPreference = "Stop" #エラーが発生した場合にスクリプトを停止する

#変数初期設定
$MyPath = $MyInvocation.MyCommand.Path #スクリプトのパス
$MyBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MyPath) #スクリプトのベース名
$MyParentPath = Split-Path -Parent $MyInvocation.MyCommand.Path #スクリプトの親ディレクトリパス
$MyOutputFolderPath = Join-Path -Path $MyParentPath -ChildPath "Output" #出力フォルダパス
$MyLogFolderPath = Join-Path -Path $MyParentPath -ChildPath "Log" #ログフォルダパス
$MyLogFilePath = Join-Path -Path $MyLogFolderPath -ChildPath ($MyBaseName + ".log") #ログファイルパス
$MyExtensionToolFolderPath = Join-Path -Path $MyParentPath -ChildPath "ExtensionTool"
$MyExtensionToolListFilePath = Join-Path -Path $MyParentPath -ChildPath "ExToolList.csv"
$MyCommonFolderPath = Join-Path -Path $MyParentPath -ChildPath "Common" #共通関数フォルダパス
$MyCommonFilePath = Join-Path -Path $MyCommonFolderPath -ChildPath "Common.ps1" #共通関数ファイルパス
.$MyCommonFilePath #共通関数読み込み
$MySettingFilePath = Join-Path -Path $MyParentPath -ChildPath "Setting.txt" #設定ファイルパス
$GetTypeListFilePath = Join-Path -Path $MyParentPath -ChildPath "GetTypeList.csv" #取得タイプリストファイルパス

#アセンブリ読み込み
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try{
	#ログ出力関数
	function Logger{
		param(
			[string]$Title,
			[ValidateSet(
				"None",
				"Error",
				"Question",
				"Warning",
				"Information"
			)][string]$Level = "Information",
			[string]$Message,
			[string]$LogLevel,
			[bool]$Popup
		)
		if(!$Popup -and ($Level -ne "Question")){
			$Title = ""
		}
		$OutputLevelArray = @()
		switch ($LogLevel){
			"Error"       { $OutputLevelArray = @("Error","Question") }
			"Warning"     { $OutputLevelArray = @("Warning","Error","Question") }
			"Information" { $OutputLevelArray = @("Information","Warning","Error","Question") }
			"None"        { $OutputLevelArray = @("None","Information","Warning","Error","Question") }
		}
		if($Level -in $OutputLevelArray){
			return LoggerEX -Title $Title -Level $Level -Message $Message
		}
	}

	#CSVファイル内容取り込み(複数行コメントアウト対応版)
	function Smart-Import-Csv {
		param(
			[string]$Path,
			[string]$Encoding
		)
		return (cat $Path -Encoding $Encoding | sls -Pattern "#" -NotMatch | ConvertFrom-Csv)
	}

	#出力ファイル作成
	function FileOutputer{
		param(
			$Object,
			[string]$OutPath,
			[string]$Encoding,
			[string]$CSS
		)
		if(!([System.IO.Path]::GetExtension($OutPath) -in ".csv",".json",".xml",".html",".md",".txt")){
			Logger -Title "無効なファイル拡張子" -Level "Warning" -Message ("指定された"+[System.IO.Path]::GetExtension($OutPath)+"ファイル拡張子はサポートされていません。") -LogLevel $LogLevel -Popup $popup
			if("yes" -eq (Logger -Title "無効なファイル拡張子" -Level "Question" -Message "続行しますか？" -LogLevel $LogLevel -Popup $popup)){
				Logger -Title "無効なファイル拡張子" -Level "Warning" -Message "出力内容のみCSVファイルの内容になります。" -LogLevel $LogLevel -Popup $true
			}else{
				throw "無効なファイル拡張子が設定ファイルで指定されたため、処理を中止します。"
			}
		}
		switch([System.IO.Path]::GetExtension($OutPath)){
			".json" {$Object | ConvertTo-Json | Out-File -FilePath $OutPath -Encoding $Encoding}
			".xml"  {$Object | Export-Clixml -Path $OutPath -Encoding $Encoding}
			".html" {$Object | ConvertTo-Html -Head $CSS | Out-File -FilePath $OutPath -Encoding $Encoding}
			".txt"  {Export-Text -FilePath $OutPath -Encoding $Encoding -InputObject $Object}
			".md"   {Export-Markdown -FilePath $OutPath -Encoding $Encoding -InputObject $Object}
            default {$Object | Export-Csv -Path $OutPath -Encoding $Encoding -NoTypeInformation}
		}
	}

	#テキストファイル作成
	function Export-Text{
		param(
			$InputObject,
			[string]$FilePath,
			[string]$Encoding
		)
		foreach($LineObject in $InputObject){
			ac -Path $FilePath -Value ($LineObject.soft_name + "`t" + $LineObject.tag_name + "`t" + $LineObject.published_time) -Encoding $Encoding
			ac -Path $FilePath -Value $LineObject.description -Encoding $Encoding
		}
	}

	#マークダウンファイル作成
	function Export-Markdown{
		param(
			$InputObject,
			[string]$FilePath,
			[string]$Encoding
		)
		$MainTitles = $InputObject.soft_name | Sort-Object -Unique
        foreach($MainTitle in $MainTitles){
            ac -Path $FilePath -Value ("# " + $MainTitle) -Encoding $Encoding
            foreach($LineObject in ($InputObject | where -FilterScript {$_.soft_name -eq $MainTitle})){
                ac -Path $FilePath -Value ("## version " + $LineObject.tag_name + " published at " + $LineObject.published_time) -Encoding $Encoding
                ac -Path $FilePath -Value $LineObject.description -Encoding $Encoding
            }
        }
	}
	
	#拡張ツール実行
	function ExtensionTool-Excute{
		param(
			[string]$FileName,
			[string]$NickName
		)
		$PSScriptFilePath = Join-Path -Path $MyExtensionToolFolderPath -ChildPath $FileName
		$Proc = start -FilePath powershell -ArgumentList $PSScriptFilePath -Wait -PassThru -NoNewWindow
		if($Proc.ExitCode -ne 0){
			throw ("拡張ツール:" + $NickName + "がエラーです。")
		}
	}

	#メイン
	Start-Transcript -Path $MyLogFilePath
	Write-Host "FreeSoft-ReleaseListingToolを開始します。" -ForegroundColor Green
	Write-Host "設定ファイルを読み込みます。"
	Invoke-Expression -Command (cat -Path $MySettingFilePath -Raw)
	Write-Host "設定ファイルを読み込みました。"
	
	Logger -Title "設定ファイル読み込み結果" -Level "None" -Message ("[" + ((cat $MySettingFilePath -Encoding UTF8 | ForEach-Object {if(($_)[0] -eq "`$"){$_ | cfs -Delimiter "#"}} | ForEach-Object {$_.P1.Trim()}) -join ",") + "]") -LogLevel $LogLevel -Popup $Popup

	$OutputFilePath = Join-Path -Path $MyOutputFolderPath -ChildPath ($MyBaseName + "." + $FileExtension)#出力ファイルパス決定
    Logger -Message ("出力ファイルパス[" + $OutputFilePath + "]") -LogLevel $LogLevel -Popup $Popup

	Logger -Message ("ファイル" + $GetTypeListFilePath + "を読み込みます。") -LogLevel $LogLevel -Popup $Popup
	$GetTypeListObject = Smart-Import-Csv -Path $GetTypeListFilePath -Encoding "UTF8"
	$ReleaseListObject = New-Object System.Collections.ArrayList
	foreach($GetTypeObject in $GetTypeListObject){
		Logger -Level "None" -Message ($GetTypeObject.SoftName + "の情報取得") -LogLevel $LogLevel -Popup $Popup
		$ApiUrl = $GetTypeObject.GetInfo.Replace("/github.com","/api.github.com/repos") + "/" + $GetTypeObject.GetApi
		$RequestReturnObject = Simple-WebRequest -URL $ApiUrl
		$RequestReturnContentObject = $RequestReturnObject.Content | ConvertFrom-Json
		foreach($ReleaseObject in $RequestReturnContentObject){
			switch($GetTypeObject.GetApi){
				"releases"{
					$ListLineObject = [PSCustomObject]@{
						soft_name      = $GetTypeObject.SoftName
						tag_name       = $ReleaseObject.tag_name
						published_time = $ReleaseObject.published_at | Get-Date -Format $TimeFormat
						description    = $ReleaseObject.body
					}
				}
				"tags"{
					$ListLineObject = [PSCustomObject]@{
						soft_name      = $GetTypeObject.SoftName
						tag_name       = $ReleaseObject.name
					}
				}
			}
			$ReleaseListObject.Add($ListLineObject) | Out-Null
			if($LogLevel -eq "None"){
				echo $ListLineObject
			}
			if($GetTypeObject.ListType -eq "Last"){
				break
			}
		}
	}
	switch($OutType){
		"File"    {FileOutputer -Object $ReleaseListObject -OutPath $OutputFilePath -Encoding $Encoding -CSS $css}
		"Popup"   {
			foreach($GetTypeObject in $GetTypeListObject){
				TablePopup -Title $GetTypeObject.SoftName -SizeXY @($PopupSizeX,$PopupSizeY) -ObjectArray ($ReleaseListObject | where -FilterScript {$_.soft_name -eq $GetTypeObject.SoftName}) -ViewNotePropertyArray @("tag_name","published_time","description")
			}
		}
		"Console" {
			foreach($ReleaseObject in $ReleaseListObject){
				Write-Host "------------------------------------------" -ForegroundColor Blue
				Write-Host "#####" -ForegroundColor Red
				Write-Host $ReleaseObject.soft_name
				Write-Host $ReleaseObject.tag_name
				Write-Host $ReleaseObject.published_time
				Write-Host "#####" -ForegroundColor Red
				Write-Host $ReleaseObject.description
				Write-Host "------------------------------------------" -ForegroundColor Blue
			}
			Read-Host -Prompt "Enter"
		}
	}
	if(Test-Path $MyExtensionToolListFilePath){
		$ExtensionToolListObject = Smart-Import-Csv -Path $MyExtensionToolListFilePath -Encoding UTF8
		foreach($ExtensionToolObject in $ExtensionToolListObject){
			Logger -Message ($ExtensionToolObject.ToolName + "を実行します") -LogLevel $LogLevel -Popup $Popup
			ExtensionTool-Excute -FileName $ExtensionToolObject.ToolFileName -NickName $ExtensionToolObject.ToolName
			Logger -Message ($ExtensionToolObject.ToolName + "を完了しました") -LogLevel $LogLevel -Popup $Popup
		}
	}else{
		Logger -Message "拡張ツールリストファイルがありません" -LogLevel $LogLevel -Popup $Popup
		Logger -Message "拡張ツールの実行はしません" -LogLevel $LogLevel -Popup $Popup
	}
}catch{
	Logger -Title "FreeSoft-ReleaseListingToolの実行中にエラーが発生しました。" -Level "Error" -Message $Error[0].Exception.Message -LogLevel $LogLevel -Popup $true
}finally{
	Write-Host "FreeSoft-ReleaseListingToolを終了します。" -ForegroundColor Green
	Stop-Transcript
}