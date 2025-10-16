# spring-boot-sample

一个最小可运行的 Spring Boot 示例项目。支持本地运行、单元测试，以及用 **Podman**（多阶段 Dockerfile）或 **Jib**（无需 Docker/Podman 守护进程）两种方式构建并推送镜像。

* 关键文件：

  * Maven 构建：[`pom.xml`](./pom.xml)
  * 应用入口（示例）：[`src/main`](./src/main)（以你工程实际包路径为准）
  * 容器构建脚本（如已提供）：[`Dockerfile`](./Dockerfile)

> Java 版本与依赖以 [`pom.xml`](./pom.xml) 为准（通常通过 `<properties><java.version>...</java.version></properties>` 指定）。

---

## 环境要求

* JDK（建议与你的 `pom.xml` 保持一致，例如 8/11/17）
* Maven 3.8+
* （可选）Podman 4.x+ 或 Docker 20.10+（若使用 Dockerfile 构建）
* （可选）能访问你的私有镜像仓库

---

## 本地快速开始

```bash
# 1) 清理 + 编译 + 测试
mvn clean test

# 2) 打包可执行 Jar（或 WAR，视 pom 而定）
mvn -DskipTests=true package

# 3) 运行（Jar 场景）
java -jar target/*.jar
# 默认端口一般为 8080；如果应用配置了不同端口，请以实际配置为准
# http://localhost:8080
```

---

## 测试与报告（Jenkins 可收集）

```bash
# 带详细日志运行测试
mvn -B -U -fae -DskipTests=false -Dmaven.test.failure.ignore=true clean test

# （供 Jenkins “Publish JUnit test result report” 使用的通配）
# **/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml
```

---

## 方案 A：用 Podman + Dockerfile 构建/推送镜像

> 适合你当前的容器策略；镜像由 Dockerfile 负责（若你的仓库已包含 [`Dockerfile`](./Dockerfile)，直接复用）。

### 常用命令（示例仓库地址与镜像名请按需替换）

```bash
# 先在宿主机测试（可选但推荐，用于产出测试报告）
mvn -B -U -fae -DskipTests=false -Dmaven.test.failure.ignore=true clean test

# 若需要：归档 Jenkins 测试报告
# **/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml

# 打包产物（若 Dockerfile 的 builder 阶段会执行 mvn package，可不提前 package）
mvn -B -U -DskipTests=true package
```

```bash
# 登录私库（HTTP/自签名示例）
podman login --tls-verify=false 10.29.230.150:31381 -u admin -p Admin123

# 构建镜像（多阶段 Dockerfile 会在容器里完成打包与瘦身）
podman build --tls-verify=false \
  -t 10.29.230.150:31381/library/spring-boot-sample:latest .

# 推送
podman push --tls-verify=false 10.29.230.150:31381/library/spring-boot-sample:latest
```

> 运行容器：
> `podman run --rm -p 8080:8080 10.29.230.150:31381/library/spring-boot-sample:latest`

---

## 方案 B：用 Jib（无需 Docker/Podman 守护进程）

> 适合没有容器权限或受限环境；Jib 直接由 Maven 把产物分层打到镜像并推送。

流水线常用命令示例（把镜像仓库、凭据替换成你的）：

```bash
# 1) 先在宿主机做测试，便于 Jenkins 收集报告
mvn -B -U -fae -DskipTests=false -Dmaven.test.failure.ignore=true clean test

# 2) 使用 Jib 构建并推送（from/to 可使用你私库中的基础镜像与目标镜像）
mvn -B -U -DskipTests=true \
  -Djib.from.image=10.29.230.150:31381/library/eclipse-temurin:8-jre \
  -Djib.from.auth.username=admin -Djib.from.auth.password=Admin123 \
  -Djib.to.image=10.29.230.150:31381/library/spring-boot-sample:jib \
  -Djib.to.auth.username=admin -Djib.to.auth.password=Admin123 \
  -Djib.allowInsecureRegistries=true \
  -DsendCredentialsOverHttp=true \
  clean package jib:build
```

> 如 `pom.xml` 已内置 `<plugin>jib-maven-plugin</plugin>` 配置，可在上面命令中仅覆盖 `-Djib.to.image`、`-Djib.from.image` 与认证字段即可。

---

## CI/流水线片段（可直接粘贴到 Jenkins Shell 步骤）

### A. Podman + Dockerfile 路线

```bash
set -euxo pipefail

# 测试（报告可收集）
mvn -B -U -fae -DskipTests=false -Dmaven.test.failure.ignore=true clean test
echo "**/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml" >&2

# （可选）提前打包；如果 Dockerfile 的 builder 阶段会 package，可跳过
mvn -B -U -DskipTests=true package

# 容器化
IMG="10.29.230.150:31381/library/spring-boot-sample:latest"
podman login --tls-verify=false 10.29.230.150:31381 -u admin -p Admin123
podman build --tls-verify=false -t "$IMG" .
podman push  --tls-verify=false "$IMG"
```

### B. Jib 路线（无容器守护）

```bash
set -euxo pipefail

mvn -B -U -fae -DskipTests=false -Dmaven.test.failure.ignore=true clean test
echo "**/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml" >&2

mvn -B -U -DskipTests=true \
  -Djib.from.image=10.29.230.150:31381/library/eclipse-temurin:8-jre \
  -Djib.from.auth.username=admin -Djib.from.auth.password=Admin123 \
  -Djib.to.image=10.29.230.150:31381/library/spring-boot-sample:jib \
  -Djib.to.auth.username=admin -Djib.to.auth.password=Admin123 \
  -Djib.allowInsecureRegistries=true \
  -DsendCredentialsOverHttp=true \
  clean package jib:build
```

---

## 常见问题

**Q1：测试报告为什么 Jenkins 没抓到？**
A：确认 `maven-surefire-plugin`/`maven-failsafe-plugin` 已生成 XML，且在 Jenkins 中配置了对应通配符：
`**/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml`。

**Q2：Jib 报 “HTTP/HTTPS/证书” 问题？**
A：对只支持 HTTP 的私库加：`-Djib.allowInsecureRegistries=true -DsendCredentialsOverHttp=true`；
若需要从私库拉基础镜像，还需 `-Djib.from.image` 与 `-Djib.from.auth.*`。

**Q3：容器启动后访问不到？**
A：确认应用监听的端口与容器映射一致（默认 8080），并在 Dockerfile/Jib 中暴露了该端口。
