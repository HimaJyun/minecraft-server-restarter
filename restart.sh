#!/bin/bash

# 霊夢いいよね。

# ======
#  設定 
# ======----
#  基本設定
# ----------
# 起動スクリプトの場所
START_SCRIPT='/hoge/server/start.sh'

# screenの名前
SCREEN_NAME='minecraft'

# ここで言うscreenの名前ってのは
# screen -UAmdS minecraft java -jar おっぱいサーバEX.jar nogui
# みたいにした時の「minecraft」の部分なの
# もしサーバがscreenで実行されてないならscreen起動に変更しておいてね。

# ----------------
#  停止メッセージ
# ----------------
MESSAGES=( \
  '毎日恒例、定期再起動の時間ダヨーッ！！' \
  'ちょっとすればまた接続可能になるから、安全のためにログアウトしてねっ(はぁと' \
  'ちなみにログアウトしなかったらぶった切るからな、覚えてろよ……ふふふ。' \
)

# -------------
#  MySQLダンプ
# -------------
# MySQLのホスト
MYSQL_HOST='127.0.0.1'

# MySQLのユーザ
MYSQL_USER='root'

# MySQLのパスワード
MYSQL_PASSWORD='ぱすわぁど'

# MySQLのバックアップ先ディレクトリ(要:トレイリング(末尾)スラッシュ)
MYSQL_TO='/hoge/backup/mysql/'

# 私はこうやって曜日置きにずらしてバックアップしていますの。
# そうしないとバックアップに時間が掛かっちゃって起動が遅くなりますの。
# mysqldumpは基本シングルスレッドだからめっちゃ遅いですの、才ラクﾉﾚ働け。

# 日曜日にバックアップ
MYSQL_SUNDAY=( 'jecon' )
# 月曜日にバックアップ
MYSQL_MONDAY=( 'lwc' )
# 火曜日にバックアップ
MYSQL_TUESDAY=( 'hawkeye' )
# 水曜日にバックアップ
MYSQL_WEDNESDAY=( 'jobs' )
# 木曜日にバックアップ
MYSQL_THURSDAY=( 'worldguard' )
# 金曜日にバックアップ
MYSQL_FRIDAY=( 'ほげ' )
# 土曜日にバックアップ
MYSQL_SATURDAY=( 'おっぱい' )

# ちなみにDynmapをここでバックアップするのはオススメしないなの。
# あれのバックアップは尋常じゃないくらいに時間がかかりますの。(AMiTサーバで5分以上、総量10GB近く
# 「--single-transaction」を付けた状態でのバックアップ処理を月に1回だけ実行する、みたいにしないと死んじゃうのね。
# と言うか、いつでも再生産出来るデータはバックアップしなくても良いなの、リソースの無駄遣いなのね。
# (まぁまず第一にバイナリをデータベースに入れようってのがそもそもの間違いなのだが……)

# --------------
#  バックアップ
# --------------
# バックアップをn日間保持(ハードリンク貼るので長くてもディスクの消耗は抑えられるけど、過ぎたるは猶及ばざるが如しなの)
BACKUP_OLD_AGO='180'

# バックアップ元のディレクトリ
# トレイリングスラッシュ:
#   あり: /home/server/2016-01-01/諸々のファイル
#   なし: /home/server/2016-01-01/server/諸々のファイル
BACKUP_FROM='/hoge/server/'

# バックアップ先のディレクトリ(要:トレイリングスラッシュ)
BACKUP_TO='/hoge/backup/server/'

# バックアップディレクトリ名のdateフォーマット
BACKUP_NAME=$(date +%Y-%m-%d)

# ##################### 処理 ##################### #
# ==========
#  停止処理
# ==========---------------------
#  複数存在するscreenに同じ処理
# ------------------------------
# screenのリストを抽出
screens=$(screen -list | grep -o "[0-9]*\.${SCREEN_NAME}")

# ブロックレベルで複数のサーバに対して終了通知
for screen in ${screens[@]}; do
{
  # >>>>>>>>>>>>>>>>
  #  停止メッセージ 
  # <<<<<<<<<<<<<<<<
  # 2秒ずつループしながらメッセージを出力
  for tmp in ${MESSAGES[@]}; do
    screen -p 0 -S ${screen} -X eval "stuff \"say ${tmp}\015\""
    sleep 2
  done

  # >>>>>>
  #  停止
  # <<<<<<
  # 少し猶予を与えるために30秒待つ
  sleep 30
  # 停止コマンド送信
  screen -p 0 -S ${screen} -X eval 'stuff stop\015'
} &
done

# ---------------------------------------
#  waitで全てにstopを送り終わるまで待つ
# ---------------------------------------
wait

# --------------
#  完全停止待ち
# --------------
# screen -listの結果から${SCREEN_NAME}が含まれるものを抽出し、空になるまでループ(結果、全て終了するまで待つ事になる)
while [ -n "$(screen -list | grep -o "${SCREEN_NAME}")" ]
do
  # 空回り防止
  sleep 1
done

# ==============
#  バックアップ
# ==============------------
#  まずは普通にバックアップ
# --------------------------
# ブロックレベルの非同期実行
{
  # ファイルパス
  backup_dir_path=${BACKUP_TO}${BACKUP_NAME}

  # 一番新しいバックアップを探す
  previous=$(ls -1t ${BACKUP_TO} | head -1)

  # 初回ならフルバックアップ、それ以降は前回を基準に変更のないファイルはハードリンク
  if [ -z "${previous}" ]; then
    rsync -a ${BACKUP_FROM} ${backup_dir_path}
  else
    rsync -a --link-dest=${BACKUP_TO}${previous} ${BACKUP_FROM} ${backup_dir_path}
  fi

  # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  #  touchしてタイムスタンプ更新
  # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  touch ${backup_dir_path}
} &

# =============
#  MySQLダンプ
# =============-----
#  ターゲットを確認
# ------------------
# ターゲット用変数
mysql_target=()

# caseで分岐してターゲットの配列をコピー
case $(date +%w) in
  0 ) mysql_target=("${MYSQL_SUNDAY[@]}") ;;
  1 ) mysql_target=("${MYSQL_MONDAY[@]}") ;;
  2 ) mysql_target=("${MYSQL_TUESDAY[@]}") ;;
  3 ) mysql_target=("${MYSQL_WEDNESDAY[@]}") ;;
  4 ) mysql_target=("${MYSQL_THURSDAY[@]}") ;;
  5 ) mysql_target=("${MYSQL_FRIDAY[@]}") ;;
  6 ) mysql_target=("${MYSQL_SATURDAY[@]}") ;;
esac

# ---------------------------
#  MySQLのバックアップを実施
# ---------------------------
# 私はMySQLは上書きでバックアップして行ってるので(実際それで問題なかった)こうなってますわ。
# 古いデータベースも保存する必要があれば……考えて
for tmp in ${mysql_target[@]}; do
  mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASSWORD} ${tmp} > ${MYSQL_TO}${tmp}.sql &
done

# 個々のプラグインがInnoDBかMyISAMか分からないので「--single-transaction」は付けない方が良い。
# 私のプラグインは一応全てInnoDBになっているはずですの。

# ==============
#  dump終了待ち
# ==============
wait

# ------------------------------
#  findで古いバックアップを削除
# ------------------------------
find ${BACKUP_TO} -maxdepth 1 -type d -mtime +${BACKUP_OLD_AGO} -print0 | xargs -0 rm -rf &

# ========
#  再起動
# ========
eval ${START_SCRIPT}
