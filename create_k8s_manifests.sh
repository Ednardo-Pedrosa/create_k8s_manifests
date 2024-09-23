#!/bin/bash

# Solicita o nome do aplicativo e domínio
read -p "Digite o nome do aplicativo: " APP_NAME
read -p "Digite o domínio a ser utilizado: " DOMAIN

# Cria diretório para os manifestos
mkdir -p ${APP_NAME}_k8s
cd ${APP_NAME}_k8s

# Cria o arquivo do ConfigMap
cat <<EOF > ${APP_NAME}_k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-config
  namespace: ${APP_NAME}
data:
  # Defina aqui suas variáveis de configuração
  example_key: example_value
EOF

# Cria o arquivo do Deployment
cat <<EOF > ${APP_NAME}_k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-deployment
  namespace: ${APP_NAME}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}-container
        image: nginx:latest
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: ${APP_NAME}-config
        - secretRef:
            name: ${APP_NAME}-secret
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
EOF

# Cria o arquivo do Secret
cat <<EOF > ${APP_NAME}_k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${APP_NAME}-secret
  namespace: ${APP_NAME}
type: Opaque
data:
  # Exemplo de dados secretos codificados em Base64
  username: $(echo -n 'admin' | base64)
  password: $(echo -n 'password123' | base64)
EOF

# Cria o arquivo do Service
cat <<EOF > ${APP_NAME}_k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  namespace: ${APP_NAME}
spec:
  selector:
    app: ${APP_NAME}
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Cria o arquivo do Ingress
cat <<EOF > ${APP_NAME}_k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: ${APP_NAME}
spec:
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${APP_NAME}-service
            port:
              number: 80
EOF

# Cria o arquivo do ClusterIssuer
cat <<EOF > ${APP_NAME}_k8s/clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: user@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Cria o arquivo do Horizontal Pod Autoscaler (HPA)
cat <<EOF > ${APP_NAME}_k8s/hpa.yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APP_NAME}-hpa
  namespace: ${APP_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${APP_NAME}-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 300
      selectPolicy: Max
      policies:
      - type: Pods
        value: 4
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      selectPolicy: Min
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60
EOF

# Cria o arquivo do PodDisruptionBudget (PDB)
cat <<EOF > ${APP_NAME}_k8s/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${APP_NAME}-pdb
  namespace: ${APP_NAME}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
EOF

# Cria o arquivo de comandos para facilitar a execução
cat <<EOF > ${APP_NAME}_k8s/comandos.sh
#!/bin/bash

# Cria o namespace
kubectl create namespace ${APP_NAME}

# Aplica os manifestos
kubectl apply -f configmap.yaml -n ${APP_NAME}
kubectl apply -f secret.yaml -n ${APP_NAME}
kubectl apply -f deployment.yaml -n ${APP_NAME}
kubectl apply -f service.yaml -n ${APP_NAME}
kubectl apply -f ingress.yaml -n ${APP_NAME}
kubectl apply -f clusterissuer.yaml -n ${APP_NAME}
kubectl apply -f hpa.yaml -n ${APP_NAME}
kubectl apply -f pdb.yaml -n ${APP_NAME}

echo "Todos os recursos foram aplicados com sucesso!"
EOF

# Torna o script de comandos executável
chmod +x ${APP_NAME}_k8s/comandos.sh

echo "Manifestos criados no diretório ${APP_NAME}_k8s. Execute o script comandos.sh para aplicar os recursos no Kubernetes."
