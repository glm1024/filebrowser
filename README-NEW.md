启动命令：

```shell
mkdir -p /srv/ai-ftp /srv/ai-filebrowser/database /srv/ai-filebrowser/config
chown -R 1000:1000 /srv/ai-ftp /srv/ai-filebrowser

docker run -d \
  --name filebrowser \
  --restart unless-stopped \
  -e FB_PORT=8080 \
  -p 8000:8080 \
  -v /srv/ai-ftp:/srv \
  -v /srv/ai-filebrowser/database:/database \
  -v /srv/ai-filebrowser/config:/config \
  filebrowser:latest
```
