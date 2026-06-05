## 镜像打包：

```shell
TAG="filebrowser:amd64-$(date +%Y%m%d-%H%M)" && OUT="filebrowser-${TAG#filebrowser:}.tar" && COMMIT="$(git rev-parse --short HEAD)" && VERSION="$(git describe --tags --abbrev=0 --match='v*' 2>/dev/null | cut -c 2- || true)" && task build:frontend && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w -X github.com/filebrowser/filebrowser/v2/version.Version=${VERSION} -X github.com/filebrowser/filebrowser/v2/version.CommitSHA=${COMMIT}" -o filebrowser . && docker build --platform linux/amd64 -f Dockerfile.ai-ftp -t filebrowser:latest -t "$TAG" . && docker save -o "$OUT" "$TAG" && gzip -f "$OUT"; STATUS=$?; task build:backend; RESTORE_STATUS=$?; [ "$STATUS" -eq 0 ] && [ "$RESTORE_STATUS" -eq 0 ] && echo "built $TAG, exported ${OUT}.gz, restored local binary"; [ "$STATUS" -eq 0 ] && [ "$RESTORE_STATUS" -eq 0 ]
```

## 启动命令：

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

## 账户：

- 系统管理员 sysadmin Cloud@s1
- 普通用户 ftp ftp
