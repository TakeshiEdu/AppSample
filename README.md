# SimpleTasker

SimpleTaskerは、個人利用向けのシンプルなFlutter製タスク管理アプリです。タスクは端末内にだけ保存され、iOS・Android・Webで動作します。

## 機能

- タスクの追加、一覧表示、完了状態の切り替え、編集、削除
- 完了済みタスクの一括削除
- `shared_preferences`を使ったローカル保存
- ライト・ダークテーマ（端末設定に連動）
- 小さなiPhone画面から幅広いWeb画面まで対応するレスポンシブUI

## 使用技術

- Flutter / Dart / Material 3
- `ChangeNotifier` + `provider`
- `shared_preferences`（JSON文字列として保存）
- `uuid`

## Windowsでの開発

Flutter SDK、Android StudioまたはChromeを準備し、リポジトリのルートで次を実行します。

```powershell
flutter pub get
flutter analyze
flutter test
```

### Webで起動

```powershell
flutter run -d chrome
```

### Androidで起動

Android端末のUSBデバッグを有効にして接続するか、Android Emulatorを起動してから実行します。

```powershell
flutter run
```

## GitHub Actionsで未署名IPAを作る

1. このプロジェクトをGitHubリポジトリへpushします。
2. GitHubの **Actions** タブを開きます。
3. **Build iOS Unsigned IPA** を選択し、**Run workflow** を実行します。
4. 完了後、実行結果ページ下部の **Artifacts** から `unsigned-ipa` をダウンロードします。
5. ZIPを展開すると `unsigned.ipa` が得られます。

ワークフローはmacOSランナーで解析とテストを行い、`flutter build ios --release --no-codesign`で`Runner.app`を生成します。それを`Payload/`へ格納し、IPA形式にZIP化します。Apple Developerの証明書やProvisioning Profileは使用しません。

## iPhoneへインストールする際の注意

生成された`unsigned.ipa`は未署名なので、そのままiPhoneにはインストールできません。Windows上でSideloadlyなどを別途利用し、自分のApple IDで個人署名してインストールしてください。無料Apple IDによる署名は有効期間が短く、定期的な再署名が必要になる場合があります。

Apple ID、パスワード、証明書、秘密鍵、Provisioning ProfileをこのリポジトリやGitHub Secretsへ保存しないでください。このプロジェクトは個人での開発・検証用途を想定しており、Sideloadlyの操作やログインの自動化は含みません。

## 将来の拡張候補

期限、優先度、カテゴリ、検索、並び替え、通知、カレンダー表示、SQLite移行、Firebase/Supabase同期、PWA対応、署名付きAndroid APK、Apple Developer Program加入後のTestFlight配布。
