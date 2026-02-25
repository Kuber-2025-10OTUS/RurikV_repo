 # 1. Delete deployment and PVC
  kubectl delete deployment web-server -n homework
  kubectl delete pvc homework-pvc -n homework

  # 2. Apply custom StorageClass and PVC
  kubectl apply -f kubernetes-volumes/storageClass.yaml
  kubectl apply -f kubernetes-volumes/pvc-custom.yaml

  # 3. Recreate deployment
  kubectl apply -f kubernetes-volumes/deployment.yaml

  # 4. Verify
  kubectl get pvc -n homework
  # Should show STORAGECLASS: homework-storage