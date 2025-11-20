# Kubernetes Sidecar Pattern 실습 예제

이 디렉토리에는 Kubernetes Sidecar 패턴을 실습할 수 있는 다양한 예제가 포함되어 있습니다.

## 예제 목록

### 1. 기본 Sidecar 패턴 (`01-basic-sidecar.yaml`)
HTTP 서버와 Git 동기화 사이드카를 사용하는 기본 예제

```bash
# Pod 생성
kubectl apply -f 01-basic-sidecar.yaml

# Pod 상태 확인
kubectl get pods web-app-basic

# 컨테이너 로그 확인
kubectl logs web-app-basic -c app
kubectl logs web-app-basic -c git-sync

# 서비스 테스트
kubectl port-forward pod/web-app-basic 8080:80
curl http://localhost:8080

# 정리
kubectl delete -f 01-basic-sidecar.yaml
```

### 2. Native Sidecar (v1.33+) (`02-native-sidecar-v1.33.yaml`)
`restartPolicy: Always`를 사용한 Init Container 기반 Native Sidecar

```bash
# Pod 생성
kubectl apply -f 02-native-sidecar-v1.33.yaml

# Init Container와 메인 컨테이너 상태 확인
kubectl get pods web-app-native-sidecar -o jsonpath='{.status.initContainerStatuses[*].name}'
kubectl get pods web-app-native-sidecar -o jsonpath='{.status.containerStatuses[*].name}'

# Sidecar 로그 확인
kubectl logs web-app-native-sidecar -c log-collector
kubectl logs web-app-native-sidecar -c metrics-exporter

# 메트릭 확인
kubectl port-forward pod/web-app-native-sidecar 9100:9100
curl http://localhost:9100/metrics

# 정리
kubectl delete -f 02-native-sidecar-v1.33.yaml
```

### 3. Per-Container Restart Policy (v1.34+) (`03-per-container-restart-v1.34.yaml`)
컨테이너별 세밀한 재시작 정책 제어

**주의**: 이 예제는 Kubernetes v1.34+ 버전에서 `ContainerRestartRules` feature gate가 활성화되어야 합니다.

```bash
# Feature gate 확인
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}'

# Pod 생성
kubectl apply -f 03-per-container-restart-v1.34.yaml

# 각 컨테이너의 재시작 정책 확인
kubectl describe pod web-app-per-container-restart

# 컨테이너별 재시작 횟수 모니터링
kubectl get pod web-app-per-container-restart -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.restartCount}{"\n"}{end}'

# 정리
kubectl delete -f 03-per-container-restart-v1.34.yaml
```

### 4. Transparent Sidecar - Envoy (`04-transparent-sidecar-envoy.yaml`)
네트워크 트래픽을 투명하게 처리하는 Envoy Proxy

```bash
# ConfigMap과 Pod 생성
kubectl apply -f 04-transparent-sidecar-envoy.yaml

# Envoy 관리자 인터페이스 접근
kubectl port-forward pod/app-with-envoy 9901:9901
curl http://localhost:9901/stats
curl http://localhost:9901/clusters

# 애플리케이션 테스트 (Envoy를 통해)
kubectl port-forward pod/app-with-envoy 8080:8080
curl http://localhost:8080

# 로그에서 Envoy의 자동 재시도 확인
kubectl logs app-with-envoy -c envoy-proxy

# 정리
kubectl delete -f 04-transparent-sidecar-envoy.yaml
```

### 5. Explicit Sidecar - Dapr (`05-explicit-sidecar-dapr.yaml`)
명시적 API를 통해 상호작용하는 Dapr Sidecar

**주의**: 실제 Dapr를 사용하려면 클러스터에 Dapr가 설치되어 있어야 합니다.

```bash
# Dapr 설치 (선택사항)
# dapr init -k

# Deployment 생성
kubectl apply -f 05-explicit-sidecar-dapr.yaml

# Pod 확인
kubectl get pods -l app=nodeapp

# 애플리케이션 테스트
kubectl port-forward deployment/nodeapp-with-dapr 3000:3000

# 상태 저장
curl -X POST http://localhost:3000/save \
  -H "Content-Type: application/json" \
  -d '{"key":"mykey","value":"myvalue"}'

# 상태 조회
curl http://localhost:3000/get/mykey

# Dapr 메트릭 확인
kubectl port-forward deployment/nodeapp-with-dapr 9090:9090
curl http://localhost:9090/metrics

# 정리
kubectl delete -f 05-explicit-sidecar-dapr.yaml
```

### 6. 로깅 Sidecar (`06-logging-sidecar.yaml`)
Fluent Bit을 사용한 로그 수집 및 전송

```bash
# ConfigMap과 Pod 생성
kubectl apply -f 06-logging-sidecar.yaml

# 애플리케이션 로그 확인
kubectl logs app-with-logging-sidecar -c app

# Fluent Bit 로그 확인 (파싱된 로그)
kubectl logs app-with-logging-sidecar -c fluent-bit

# 로그 파일 확인
kubectl exec app-with-logging-sidecar -c app -- cat /var/log/app/application.log

# 정리
kubectl delete -f 06-logging-sidecar.yaml
```

## 버전 호환성

| 예제 | 최소 Kubernetes 버전 | Feature Gate |
|------|---------------------|--------------|
| 01-basic-sidecar | v1.0+ | - |
| 02-native-sidecar-v1.33 | v1.29+ (stable in v1.33) | SidecarContainers |
| 03-per-container-restart-v1.34 | v1.34+ | ContainerRestartRules |
| 04-transparent-sidecar-envoy | v1.29+ | SidecarContainers |
| 05-explicit-sidecar-dapr | v1.29+ | SidecarContainers |
| 06-logging-sidecar | v1.29+ | SidecarContainers |

## 트러블슈팅

### Native Sidecar가 작동하지 않는 경우

```bash
# Feature gate 확인
kubectl get --raw /metrics | grep sidecar_containers

# API 서버 버전 확인
kubectl version --short

# kubelet 로그 확인
journalctl -u kubelet | grep -i sidecar
```

### Per-Container Restart Policy가 지원되지 않는 경우

```bash
# Feature gate 활성화 (API Server, Kubelet, Controller Manager)
# --feature-gates=ContainerRestartRules=true
```

## 모니터링

### Pod 내 모든 컨테이너 상태 확인

```bash
# Init Containers
kubectl get pod <pod-name> -o jsonpath='{.status.initContainerStatuses[*].state}'

# Main Containers
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].state}'
```

### 리소스 사용량 확인

```bash
kubectl top pod <pod-name> --containers
```

## 참고 자료

- [Kubernetes Native Sidecar Containers](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)
- [KEP-753: Sidecar Containers](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers)
- [Kubernetes v1.34: Per-Container Restart Policy](https://kubernetes.io/blog/2025/08/29/kubernetes-v1-34-per-container-restart-policy/)
