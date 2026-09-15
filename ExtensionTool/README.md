# FreeSoft-ReleaseListingTool ExtensionToolFolder
githubのAPIだけで十分に情報が取得できない場合は、
ここに自作のpowershellファイルを格納し`ExToolList.csv`にツールの名前とファイル名を記載することで、
ツール実行後格納されたpowershellスクリプトが実行されます。  
実行順序は`ExToolList.csv`のリスト順です。  

## 利用例
- WinSCPのgithubにはリリース情報はなくタグ情報しかないので、変更内容や公開日情報を取得するWebサイトスクレイピングシェルをこのフォルダに入れて実行させる。  
**※格納されているものはこの利用例のものです**  
- 変更内容にCVEIDが含まれているリリースはCVEで公開されている脆弱性情報も加えたものにする