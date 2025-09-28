package main

import (
    "context"
    "fmt"
    "os"
    "time"

    coordinationv1 "k8s.io/api/coordination/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/leaderelection"
    "k8s.io/client-go/tools/leaderelection/resourcelock"
)

func main() {
    // Kubernetes in-cluster config
    config, err := rest.InClusterConfig()
    if err != nil {
        panic(err.Error())
    }

    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        panic(err.Error())
    }

    id, _ := os.Hostname()

    lock, err := resourcelock.New(
        resourcelock.LeasesResourceLock,
        "default",
        "singleton-leader",
        clientset.CoreV1(),
        clientset.CoordinationV1(),
        resourcelock.ResourceLockConfig{
            Identity: id,
        },
    )
    if err != nil {
        panic(err)
    }

    // coordinationv1 타입을 직접 참조해 사용
    //    (단순히 변수에 할당하고 _ 로 무시해도 import는 유효 처리됨)
    _ = coordinationv1.Lease{}

    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
        Lock:            lock,
        ReleaseOnCancel: true,
        LeaseDuration:   15 * time.Second,
        RenewDeadline:   10 * time.Second,
        RetryPeriod:     2 * time.Second,
        Callbacks: leaderelection.LeaderCallbacks{
            OnStartedLeading: func(ctx context.Context) {
                for {
                    fmt.Printf("%s is leader: running singleton task...\n", id)

                    // metav1 실제 사용 예
                    now := metav1.Now()
                    fmt.Printf("Current metav1 time: %s\n", now.String())

                    time.Sleep(10 * time.Second)
                }
            },
            OnStoppedLeading: func() {
                fmt.Printf("%s lost leadership\n", id)
            },
        },
    })
}
