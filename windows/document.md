現在のワークフローは昨日、実際に未署名IPA生成まで成功しているため修正不要です。ただし、通知・カレンダー機能はまだローカル変更のままで、GitHub上は旧版です。先にpushしてから再ビルドしてください。

## 最短手順

PowerShellでプロジェクトフォルダを開き、次を実行します。

```powershell
cd C:\Users\takes\Desktop\code\flutterapp

flutter pub get
flutter analyze
flutter test

git status
git add -A
git commit -m "Add notifications and calendar"
git push origin main
```

push後、以下を開きます。

1. [AppSampleのActions](https://github.com/TakeshiEdu/AppSample/actions)
2. 左側の「Build iOS Unsigned IPA」を選択
3. 右側の「Run workflow」をクリック
4. Branchが`main`であることを確認
5. 緑色の「Run workflow」をクリック
6. 4〜10分ほど待つ
7. 完了した実行を開く
8. 画面最下部の「Artifacts」から`unsigned-ipa`をクリック
9. ダウンロードしたZIPを展開
10. 中の`unsigned.ipa`をSideloadlyでインストール

## 1. GitHubへ最新版を送る

現在のローカルには以下が未pushです。

- 通知機能
- 期限日時
- カレンダー画面
- iOS通知設定
- Android通知設定
- 新しいテスト

まず検証します。

```powershell
flutter pub get
flutter analyze
flutter test
```

期待する結果は次のとおりです。

```text
No issues found!
All tests passed!
```

次に変更内容を確認します。

```powershell
git status
```

`lib/`、`ios/`、`android/`、`test/`、`pubspec.yaml`などが変更済みとして表示されます。

コミットしてpushします。

```powershell
git add -A
git commit -m "Add notifications and calendar"
git push origin main
```

pushできたか確認します。

```powershell
git status
```

正常なら次のようになります。

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

GitHubの[コード画面](https://github.com/TakeshiEdu/AppSample)でも、最新コミットが表示されることを確認します。

## 2. ワークフローの場所

ワークフローは以下にあります。

[build-ios-unsigned.yml](C:/Users/takes/Desktop/code/flutterapp/.github/workflows/build-ios-unsigned.yml)

GitHub上では次の場所です。

```text
AppSample
└─ .github
   └─ workflows
      └─ build-ios-unsigned.yml
```

内容は現在この構成です。

```yaml
name: Build iOS Unsigned IPA

on:
  workflow_dispatch:

jobs:
  build-ios:
    runs-on: macos-latest
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test

      - name: Build iOS without codesign
        run: flutter build ios --release --no-codesign

      - name: Package unsigned IPA
        run: |
          rm -rf Payload unsigned.ipa
          mkdir -p Payload
          cp -R build/ios/iphoneos/Runner.app Payload/
          zip -r unsigned.ipa Payload

      - name: Upload unsigned IPA
        uses: actions/upload-artifact@v4
        with:
          name: unsigned-ipa
          path: unsigned.ipa
          if-no-files-found: error
```

`workflow_dispatch`があるため、GitHub画面から手動実行できます。ワークフローはデフォルトブランチに置かれている必要があります。[GitHub公式：ワークフローの手動実行](https://docs.github.com/ja/actions/how-tos/manage-workflow-runs/manually-run-a-workflow?tool=cli)

## 3. 各処理が何をしているか

### Checkout

```yaml
uses: actions/checkout@v4
```

GitHub上のソースコードをmacOSランナーへ取得します。

### Flutterのセットアップ

```yaml
uses: subosito/flutter-action@v2
with:
  channel: stable
  cache: true
```

macOSランナーへFlutter stableを準備します。`cache: true`により、2回目以降の依存取得が速くなる場合があります。

### 依存パッケージ取得

```yaml
run: flutter pub get
```

`provider`、`shared_preferences`、通知、カレンダーなどのパッケージを取得します。

### 静的解析

```yaml
run: flutter analyze
```

Dartコードの型エラー、未定義API、Lint違反などを検出します。

ここが失敗した場合、iOSビルドには進みません。

### テスト

```yaml
run: flutter test
```

タスク追加・削除・通知スケジュール・JSON互換などのテストを実行します。

### iOSアプリ生成

```yaml
run: flutter build ios --release --no-codesign
```

重要なのは`--no-codesign`です。

これにより、

- Apple Developer証明書
- 秘密鍵
- Provisioning Profile
- Apple ID

をGitHubへ登録せず、署名されていない`Runner.app`を作ります。Flutter公式でも、`--no-codesign`は署名を無効にしたiOSビルドとして案内されています。[Flutter公式](https://docs.flutter.dev/add-to-app/debugging)

生成場所は以下です。

```text
build/ios/iphoneos/Runner.app
```

### IPA形式へ変換

IPAは実質的に、次の構造を持ったZIPファイルです。

```text
unsigned.ipa
└─ Payload/
   └─ Runner.app/
```

ワークフローでは`Runner.app`を`Payload`へコピーしてZIP化しています。

### Artifactへ保存

```yaml
uses: actions/upload-artifact@v4
```

生成した`unsigned.ipa`を、ワークフロー終了後にもダウンロードできるよう保存します。[GitHub公式：Workflow Artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)

## 4. GitHub画面から実行する詳細手順

1. [TakeshiEdu/AppSample](https://github.com/TakeshiEdu/AppSample)を開きます。
2. 上部の「Actions」をクリックします。
3. 左側の一覧から「Build iOS Unsigned IPA」をクリックします。
4. 「This workflow has a workflow_dispatch event trigger」と表示されることを確認します。
5. 右側の「Run workflow」をクリックします。
6. Branchの選択欄で`main`を選びます。
7. 緑色の「Run workflow」をクリックします。
8. 数秒後に新しい実行が一覧へ追加されます。
9. 黄色い丸は実行中、緑のチェックは成功、赤い×は失敗です。
10. 実行をクリックすると各ステップを確認できます。

成功時には以下がすべて緑になります。

```text
Checkout
Setup Flutter
Flutter version
Install dependencies
Analyze
Test
Build iOS without codesign
Package unsigned IPA
Upload unsigned IPA
```

## 5. Artifactのダウンロード

成功した実行ページを開き、一番下までスクロールします。

```text
Artifacts
└─ unsigned-ipa
```

`unsigned-ipa`をクリックすると、ブラウザからZIPがダウンロードされます。

注意点として、GitHubがArtifact自体をZIP化するため、ファイルは次のようになります。

```text
unsigned-ipa.zip
└─ unsigned.ipa
```

Windowsで右クリックして「すべて展開」を選び、`unsigned.ipa`を取り出してください。

Artifactには保存期限があります。GitHubでは期限切れ前にダウンロードする必要があります。[GitHub公式：Artifactsのダウンロードと管理](https://docs.github.com/en/actions/how-tos/manage-workflow-runs?tool=cli)

## 6. GitHub CLIから実行する方法

このPCにはGitHub CLIをインストール・認証済みなので、画面を使わず実行できます。

```powershell
cd C:\Users\takes\Desktop\code\flutterapp

gh workflow run build-ios-unsigned.yml `
  --repo TakeshiEdu/AppSample `
  --ref main
```

最新の実行を確認します。

```powershell
gh run list `
  --repo TakeshiEdu/AppSample `
  --workflow build-ios-unsigned.yml `
  --limit 5
```

実行IDを指定して監視します。

```powershell
gh run watch 実行ID `
  --repo TakeshiEdu/AppSample `
  --interval 10 `
  --exit-status
```

成功後、Artifactを直接ダウンロードできます。

```powershell
New-Item -ItemType Directory -Force downloads\unsigned-ipa

gh run download 実行ID `
  --repo TakeshiEdu/AppSample `
  --name unsigned-ipa `
  --dir downloads\unsigned-ipa
```

取得場所は次のとおりです。

```text
C:\Users\takes\Desktop\code\flutterapp\downloads\unsigned-ipa\unsigned.ipa
```

## 7. SideloadlyでiPhoneへ入れる

1. WindowsでSideloadlyを起動します。
2. iPhoneをUSB接続します。
3. iPhone側で「このコンピュータを信頼」を許可します。
4. `unsigned.ipa`をSideloadlyへドラッグします。
5.自分のApple IDを入力します。
6. 「Start」を押します。
7. 必要に応じてApple IDの認証を完了します。
8. インストール後、iPhoneの「設定」→「一般」→「VPNとデバイス管理」から開発者を信頼します。
9. 「設定」→「プライバシーとセキュリティ」→「デベロッパモード」をオンにします。
10. iPhoneを再起動してアプリを開きます。

無料Apple IDの場合、署名の有効期限が短いため、期限後は同じ手順で再署名・再インストールします。

## 8. やってはいけないこと

GitHubへ以下を保存しないでください。

- Apple ID
- Apple IDのパスワード
- アプリ用パスワード
- 証明書
- `.p12`
- 秘密鍵
- Provisioning Profile
- Sideloadlyの認証情報

このワークフローは、これらを一切使わず`unsigned.ipa`だけを作ります。署名はWindows上のSideloadlyで個別に行います。

## 9. よくある失敗

### 「Run workflow」が表示されない

確認項目：

- ファイルが`.github/workflows/`にあるか
- YAMLに`workflow_dispatch:`があるか
- ワークフローが`main`へpush済みか
- Actionsがリポジトリ設定で無効になっていないか

### Analyzeで失敗する

ローカルで実行します。

```powershell
flutter analyze
```

修正後にcommit・pushして、ワークフローを再実行します。

### Testで失敗する

```powershell
flutter test
```

ローカルで同じエラーを再現してから修正します。

### Build iOS without codesignで失敗する

そのステップを展開し、最後のエラーを確認します。よくある原因は以下です。

- Flutter/パッケージのバージョン不整合
- CocoaPods依存関係
- iOS側のSwiftコードエラー
- プラグインが要求するiOS最低バージョン
- `Info.plist`や`AppDelegate.swift`の設定ミス

### Artifactが表示されない

「Upload unsigned IPA」まで成功しているか確認します。`if-no-files-found: error`が指定されているため、IPAが存在しなければワークフロー自体が失敗します。

### IPAをそのままインストールできない

正常です。生成物は未署名です。Sideloadlyなどで個人署名する必要があります。

今回の次の実作業は、通知・カレンダー変更をcommitして`main`へpushし、上記ワークフローを再実行することです。