### 0) Local Path StorageClass 준비
# 환경변수로 넘어온 LOCALPATH_NS를 우선 사용, 없으면 기본값 사용
LOCALPATH_NS="${LOCALPATH_NS:-local-path-storage}"
echo "[0] Local Path StorageClass (local-path-provisioner) 준비 (namespace=${LOCALPATH_NS})"

# 네임스페이스 생성
kubectl get ns "$LOCALPATH_NS" >/dev/null 2>&1 || kubectl create ns "$LOCALPATH_NS"

# Helm repo 등록 및 업데이트
helm repo add rancher-lpp https://rancher.github.io/local-path-provisioner >/dev/null 2>&1 || true
helm repo update >/dev/null

# local-path-provisioner 설치 (StorageClass 자동 생성)
helm upgrade --install local-path-provisioner rancher-lpp/local-path-provisioner \
  -n "$LOCALPATH_NS" \
  --set storageClass.create=true \
  --set storageClass.defaultClass=true \
  --set nodePathMap[0].node=DEFAULT_PATH_FOR_NON_LISTED_NODES \
  --set nodePathMap[0].paths[0]="/opt/local-path-provisioner"

# 기존 기본 StorageClass 비활성화 및 local-path를 기본으로 지정
echo "[0] 기존 기본 StorageClass 해제 및 local-path 기본 지정"
for sc in $(kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
  kubectl patch storageclass "${sc}" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null 2>&1 || true
done
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1 || true

# local-path StorageClass가 없을 경우 대비해 수동 생성
if ! kubectl get sc local-path >/dev/null 2>&1; then
  echo "[0] local-path StorageClass가 없어 수동 생성합니다"
  kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  path: "/opt/local-path-provisioner"
EOF
fi

# 노드에 경로 없으면 자동 생성 (DaemonSet) - namespace도 LOCALPATH_NS 반영
echo "[0] (선택) 각 노드에 /opt/local-path-provisioner 디렉터리 생성 DaemonSet 적용 (ns=${LOCALPATH_NS})"
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ensure-local-path-dir
  namespace: ${LOCALPATH_NS}
spec:
  selector:
    matchLabels:
      app: ensure-local-path-dir
  template:
    metadata:
      labels:
        app: ensure-local-path-dir
    spec:
      tolerations:
        - operator: "Exists"
      containers:
        - name: mkdir
          image: busybox:1.36
          command: ["sh", "-c", "mkdir -p /opt/local-path-provisioner && sleep 5d"]
          volumeMounts:
            - name: hostpath
              mountPath: /opt/local-path-provisioner
      volumes:
        - name: hostpath
          hostPath:
            path: /opt/local-path-provisioner
            type: DirectoryOrCreate
  updateStrategy:
    type: OnDelete
EOF

# 상태 출력
kubectl get sc
