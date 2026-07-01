# MR Remover for iPhone

個人利用を前提としたFlutter版です。原曲とインスト音源を位置合わせし、STFTスペクトル減算でボーカル成分をWAVとして保存します。

## 現在できること

- WAV / MP3 / M4A / AAC / CAFの読み込み
- FFT相互相関による約±30秒の自動位置合わせ
- 2048点FFT・512サンプルhopのSTFTスペクトル減算
- 除去強度の調整
- 端末内での抽出、WAV保存、再生
- 原曲URLとインスト音源URLからの個別ダウンロード
- iPhone IPAへのCPython・yt-dlp・Apple WebKit challenge provider同梱
- 最近の抽出履歴の保存
- GitHub Actionsによる未署名IPAの生成

WindowsではPython 3.10以上、Node.js 22以上、FFmpegが必要です。iPhone版では必要なPython実行環境とyt-dlpをIPAへ同梱します。

## IPAを作る

リポジトリ全体をGitHubへ置き、Actions画面で `Build unsigned iOS IPA` を実行します。artifactからIPAを取得し、Windows版Sideloadlyで署名してiPhoneへインストールします。

無料Apple IDで署名したアプリは7日ごとの更新が必要です。
