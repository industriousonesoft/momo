# Momo の SDL 機能をカスタマイズする

Momo の SDL 機能をカスタマイズする方法を実際のカスタマイズ例を交えて説明します。  
カスタマイズ例として、 Momo が送信する映像・音声をミュートするボタンを追加します。

## 既存の SDL の実装について

カスタマイズ例について説明する前に、既存の SDL の実装について簡単に説明します。

### ソース上の該当箇所

`src/sdl_renderer` ディレクトリ以下です。

### SDL で実装されている処理

Momo の SDL 機能で実装されている処理は大きく以下の2つに分けられます。

- SDL による映像の描画
- SDL_Event のハンドリング

### SDL による映像の描画

Momo の SDL 機能では以下の流れで WebRTC で受信した映像の描画を行っています。

1. SDL_Surface を作成する
    - WebRTC で受信したフレームのイメージを元に、SDL_CreateRGBSurfaceFrom を呼び出し SDL_Surface を作成する
2. SDL_CreateTextureFromSurface を呼び出し、 SDL_Surface から SDL_Texture を作成する
3. SDL_RenderCopy を呼び出し、 SDL_Texture の内容を SDL_Renderer にコピーする
4. SDL_RenderPresent を呼び出し、レンダリングを行う 

こちらの処理は `src/sdl_renderer/sdl_renderer.cpp` の `SDLRenderer::RenderThread` に実装されています。

#### SDL_Sutface と SDL_Texture の違い

SDL_Surface がソフトウェアを利用するのに対して、 SDL_Texture ではハードウェアを利用してレンダリングを行います。  
そのため、ハードウェアを利用して高速にレンダリングが行える SDL_Texture を使用することが推奨されます。

参照: https://stackoverflow.com/a/26113388

### SDL による映像の描画

SDL には [SDL_Event](https://wiki.libsdl.org/SDL_Event) という仕組みがあり、入力デバイスや各種イベントをトリガーして処理を実行できます。
Momo は SDL_Event を利用して以下の処理を実装しています。

- ウィンドウがリサイズされた際に、 WebRTC で受信した映像の大きさを再計算する処理
- F キーが押された際に、 SDL の画面をフル・スクリーンにする処理
- Q キーが押された際に、 Momo を終了する処理
- SDL 終了時の処理

これらの処理は `sdl_renderer.cpp` の `SDLRenderer::PollEvent()` に実装されています。

## カスタマイズ例: ミュート・ボタンを追加する

### 仕様

- TODO: カスタマイズ例の仕様を書く

### ミュート・ボタンを表示する方法の検討

- TODO: SDL_image を採用するまでの流れを書く

### SDL_image を追加して Momo をビルドする

MacOS における Momo のビルドは `./build/build.sh macos` で実行しますが、 `build.sh` の内部では、ビルドに必要な依存のインストールと cmake によるビルドが行われています。  
前者は `build/macos/install_deps.sh` 、後者は `CMakeLists.txt` に処理が記述されています。

SDL_image を追加してビルドを行うために、上記のファイルに以下の修正を加えています。

- SDL_image のソースを取得してビルドする
- SDL_image のヘッダー・ファイルを Momo のビルド時に参照する
- SDL_image をビルドしたライブラリを Momo のビルド時にリンクする

### ミュート・ボタンを表示する

### ミュート・ボタンを押した際のイベントを実装する

### ミュート・ボタンの機能を実装する

Momo の映像と音声の送信は libwebrtc　で行われています。
そのため、 libwebrtc の API を調査して、映像と音声をミュートする方法を調べる必要があります。

libwebrtc の API の調査には [Chromium Code Search](https://source.chromium.org/) が便利です。

今回は、libwebrtc の `VideoTrackInterface, AudioTrackInterface` に実装されている `set_enabled` を利用しました。

## カスタマイズ例を動かす

TODO
- スクショを貼る
- 動かし方 & 注意点を書く
