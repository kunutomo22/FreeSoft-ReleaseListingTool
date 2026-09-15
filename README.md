# FreeSoft-ReleaseListingTool
フリーソフトのリリース情報一覧ファイルを作成するツールです。
## 使い方
1. Releaseの最新版を取得する。  
2. zipを展開する。
3. `FreeSoft-ReleaseList.ps1`を実行する。  
  
この手順でリリース履歴一覧をCSV形式で取得できます。
### 必要最低限のもの
- Powershell 5.1以上
- このプロジェクトにある以下のファイルとフォルダ
    - `FreeSoft-ReleaseList.ps1`
    - `Common`
    - `Setting.txt`
    - `GetTypeList.csv`
    - `Output`  
Outputフォルダは、リリースノートの出力先として使用されます。  
Setting.txtの設定に応じて不要になりますが、デフォルトの設定を使用するには必要です。  
### ツールの設定について
`Setting.txt`を編集することで、出力するリリース履歴一覧ファイルの出力形式や文字コード、ファイルの拡張子を変更できます。  
詳細は`Setting.txt`の中にあるコメントを参照してください。  
### 拡張ツールについて
`ExtensionTool`にpowershellファイルを格納し`ExToolList.csv`に適切に追記すると、  
メインのgithubからの情報取得を実行した後に`ExtensionTool`に格納されたpowershellファイルを順次実行します。  
詳しくは`ExtensionTool`に格納されてるREADMEと`ExToolList.csv`のコメント行を参照してください。
