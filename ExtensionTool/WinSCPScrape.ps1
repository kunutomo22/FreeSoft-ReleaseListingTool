###############
#
#FreeSoft-ReleaseListingToolの拡張スクリプトの例です。
#実行の必要が無い場合は拡張スクリプトリストファイル(ExToolList.csv)を削除するか、当拡張スクリプトが記載されている行の行頭を#にすることでこのスクリプトの実行をスキップできます。
#
#*この拡張スクリプトの前提
#**FreeSoft-ReleaseListingToolの出力形式がファイルであること
#**FreeSoft-ReleaseListingToolの出力ファイル形式がCSVであること
#**FreeSoft-ReleaseListingToolの出力ファイル文字コードがUTF8であること
#
###############

#エラー挙動定義
$ErrorActionPreference = "Stop" #エラーが発生した場合にスクリプトを停止する

#変数初期設定
$MyPath = $MyInvocation.MyCommand.Path #スクリプトのパス
$MyBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MyPath) #スクリプトのベース名
$MyParentPath = Split-Path -Parent $MyInvocation.MyCommand.Path #スクリプトの親ディレクトリパス
$MyBasePath = Split-Path -Parent $MyParentPath #FreeSoft-ReleaseList.ps1の親ディレクトリパス
$MyOutputFolderPath = Join-Path -Path $MyBasePath -ChildPath "Output" #出力フォルダパス
$MyOutputFilePath = Join-Path -Path $MyOutputFolderPath -ChildPath "FreeSoft-ReleaseList.csv"
$MyLogFolderPath = Join-Path -Path $MyBasePath -ChildPath "Log" #ログフォルダパス
$MyLogFilePath = Join-Path -Path $MyLogFolderPath -ChildPath ($MyBaseName + ".log") #ログファイルパス
$MyCommonFolderPath = Join-Path -Path $MyBasePath -ChildPath "Common" #共通関数フォルダパス
$MyCommonFilePath = Join-Path -Path $MyCommonFolderPath -ChildPath "Common.ps1" #共通関数ファイルパス
.$MyCommonFilePath #共通関数読み込み
$MySettingFilePath = Join-Path -Path $MyBasePath -ChildPath "Setting.txt" #設定ファイルパス
$WinSCPHistoryURL = "https://winscp.net/eng/docs/history"
$WinSCPHistoryURLOldTail = "_old"

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
			[string]$Message
		)
		if($Level -ne "Question"){
			$Title = ""
		}
		return LoggerEX -Title $Title -Level $Level -Message $Message
	}
    #タグ削除関数
    function TagRemover{
        param(
            [bool]$Description,
            [string]$Line
        )
        $AddFlag = $false
        $ReturnArray = @()
        if(!$Description){
            $Count = 0
            foreach($Char in $Line.ToCharArray()){
                if($Char -eq "<"){
                    $Count++
                    if($Count -eq 2){
                        break
                    }
                }
                if($Char -eq ">"){
                    $AddFlag = !$AddFlag
                }else{
                    if($AddFlag){
                        $ReturnArray += $Char
                    }
                }
            }
        }else{
            foreach($Char in $Line.ToCharArray()){
                if(($Char -eq "<") -or ($Char -eq "&")){
                    $AddFlag = $false
                }
                if($AddFlag){
                    $ReturnArray += $Char
                }
                if(($Char -eq ">") -or ($Char -eq ";")){
                    $AddFlag = $true
                }
            }
        }
        return ($ReturnArray -join "")
    }

	#メイン
	Start-Transcript -Path $MyLogFilePath
	Write-Host ($MyBaseName + "を開始します。") -ForegroundColor Green
    Logger -Message "設定ファイルを読み込みます。"
    Invoke-Expression -Command ((cat $MySettingFilePath -Encoding UTF8 | sls -Pattern "TimeFormat","Encoding").Line -join "`r`n")
    Logger -Message "設定ファイルを読み込みました。"
	Logger -Message "出力済みCSVファイル内容を取り込み"
	$BeforeOutputObject = Import-Csv -Path $MyOutputFilePath -Encoding $Encoding
	$BeforeWinSCPObjects = $BeforeOutputObject | where -FilterScript {$_.soft_name -eq "WinSCP"}
	Logger -Message "出力済みCSVファイル内容を取り込み完了"
    $AfterWinSCPObjects = New-Object System.Collections.ArrayList
	$MatchCount = 0
    $h2flag = $false
    $timeflag = $false
    $ulflag = $false
    foreach($URL in @($WinSCPHistoryURL,($WinSCPHistoryURL + $WinSCPHistoryURLOldTail))){
        Logger -Message ($URL + "からHTML取得")
        $RequestReturnContentObject = (Simple-WebRequest -URL $URL).Content
        Logger -Message ($URL + "からHTML取得完了")
        foreach($ReturnHtmlLine in $RequestReturnContentObject.Split("`r`n")){
             if($ReturnHtmlLine.Contains("<h2 id=")){
                 if(($ReturnHtmlLine.Contains(">" + $BeforeWinSCPObjects[$MatchCount].tag_name.Replace("-"," ") + "<")) -or ($ReturnHtmlLine.Contains(">" + $BeforeWinSCPObjects[$MatchCount].tag_name.Replace("-"," ") + " (hotfix)<"))){
                    $tag_name = TagRemover -Line $ReturnHtmlLine -Description $false
                    $h2flag = !$h2flag
                    $MatchCount ++
                    $DescriptionLines = @()
                 }
             }
             if($h2flag -and $ReturnHtmlLine.Contains("<time class=")){
                $published_time = TagRemover -Line $ReturnHtmlLine -Description $false
                $timeflag = !$timeflag
             }
             if(($h2flag -or $timeflag) -and $ulflag){
                if($ReturnHtmlLine -eq "</ul>"){
                    $h2flag = $false
                    $timeflag = $false
                    $ulflag = $false
                    $description = $DescriptionLines -join "`r`n"
                    $WinSCPReleaseObject = [PSCustomObject]@{
                        soft_name      = "WinSCP"
                        tag_name       = $tag_name
                        published_time = $published_time | Get-Date -Format $TimeFormat
                        description    = $description
                    }
                    $AfterWinSCPObjects.Add($WinSCPReleaseObject) | Out-Null
                    $DescriptionLines = @()
                    if($BeforeWinSCPObjects[$MatchCount] -eq $null){
                       break
                    }
                }else{
                    $TempLine = TagRemover -Line $ReturnHtmlLine -Description $true
                    if($TempLine.Replace(" ","") -ne ""){
                        $DescriptionLines += $TempLine
                    }
                }
             }
             if($h2flag -and $timeflag -and ($ReturnHtmlLine -eq "<ul>")){
                $ulflag = !$ulflag
             }
        }
        if($BeforeWinSCPObjects[$MatchCount] -eq $null){
           break
        }
    }
    $BeforeOutputObject | where -FilterScript {$_.soft_name -ne "WinSCP"} | Export-Csv -Path $MyOutputFilePath -NoTypeInformation -Encoding $Encoding
    $AfterWinSCPObjects | Export-Csv -Path $MyOutputFilePath -Append -NoTypeInformation -Encoding $Encoding
}catch{
	Logger -Title ($MyBaseName + "の実行中にエラーが発生しました。") -Level "Error" -Message $Error[0].Exception.Message
}finally{
	Write-Host ($MyBaseName + "を終了します。") -ForegroundColor Green
	Stop-Transcript
}