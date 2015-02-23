#!/bin/bash

# 初期化処理
work_path=`pwd`
target_path="$work_path/target/docker"
tmp_path="/tmp/play-git"

function rm_files(){
    rm -f $work_path/Dockerfile
    rm -f $work_path/Dockerfile.new
    rm -f $work_path/fig.yml
    rm -rf $work_path/service
    rm -rf $tmp_path
}

function print_file(){
    echo "---------------------------------------------------------------"
    cat $1
    echo "---------------------------------------------------------------"
    echo "[$1]"
}

rm_files
mkdir service

# コンテナ名とgithubリポジトリを設定。
if [ ! -e docker.conf ]; then
    echo "Dockerコンテナタグ名を入力してください。[a-z]のみ"
    while read in ; do
        tag_name=$in
        break
    done
    echo "gitのリポジトリURLを入力してください。(git@git://~)"
        while read in ; do
        git_repo=$in
        break
    done
    echo -e "tag-name $tag_name\ngit-repo $repo_url" > docker.conf
else
    line=(`awk '{print $2}' docker.conf`)
    tag_name=${line[0]}
    git_repo=${line[1]}
fi

# Typesafe activatorからDockerfileなどを自動生成
activator clean compile docker:stage
cp $target_path/Dockerfile .
bin_name=`ls -1 $target_path/files/opt/docker/bin | grep -v .bat$`

# DockerfileからForward port設定を取得(複数の場合はループ処理に変更)
array=`cat Dockerfile | grep EXPOSE`
r_port=`echo $array | awk '{print $2}'`
h_port=`echo $array | awk '{print $3}'`

# Dockerfileの修正
gsed "/^WORK*\|ENTRY*\|RUN*\|USER*/d" Dockerfile | gsed "/^CMD*/i WORKDIR /etc/supervisor/conf.d" |\
gsed "/^ADD*/a RUN \\\\\n apt-get update && \\\\\n apt-get install -y supervisor && \\\\\n \
apt-get install python-setuptools && \\\\\n easy_install superlance && \\\\\n \
rm -rf /var/lib/apt/lists/* && \\\\\n sed -i 's/^\\\\(\\\\[supervisord\\\\]\\\\)$/\\\\1\\\\nnodaemon=true/' /etc/supervisor/supervisord.conf" \
| gsed "/^CMD*/d" > Dockerfile.new && echo 'CMD ["supervisord", "-c",  "/etc/supervisor/supervisord.conf"]' >> Dockerfile.new

# fig.ymlの生成
echo "\
$tag_name:
  build: .
  ports:
    - \"$h_port:$r_port\"
  volumes:
    - ./service:/etc/supervisor/conf.d
    - ./files/opt:/opt" > fig.yml

# service.confの生成
echo "\
[supervisord]
nodaemon=true

[program:$bin_name]
command=/opt/docker/bin/$bin_name
autostart=true
autorestart=true

[eventlistener:memmon]
command=memmon -p $bin_name=500MB
events=TICK_60" > service/service.conf

# 出力内容の確認
print_file "Dockerfile.new"
print_file "fig.yml"
print_file "service/service.conf"

echo "以上の出力内容で良いですか？[y/n]"
while read in ; do
    if [ "$in" = "y" ]
      then
        git clone $git_repo $tmp_path
        cd $tmp_path
        rm -rf $tmp_path/docker
        cp -rf $target_path $tmp_path/docker
        cp -f $work_path/Dockerfile.new $tmp_path/docker/Dockerfile
        cp -f $work_path/fig.yml $tmp_path/docker
        cp -rf $work_path/service $tmp_path/docker
        git add .
        git add -u .
        git commit
        git push
        break
    else
        break
    fi
done

# 後処理
rm_files

