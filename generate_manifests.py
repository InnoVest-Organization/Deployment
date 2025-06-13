import os
from pathlib import Path
from string import Template

# Read templates
TEMPLATE_DEPLOY = Template(Path("base/deployment.yaml").read_text())
TEMPLATE_SERVICE = Template(Path("base/service.yaml").read_text())

# Read .env-style config
with open("services.env") as f:
    lines = [line.strip() for line in f if line.strip() and not line.startswith("#")]

# Generate per-service Deployment and Service YAML
for i in range(0, len(lines), 5):
    env = dict(line.split("=", 1) for line in lines[i:i + 5])
    svc_name = env["SERVICE_NAME"]

    os.makedirs(f"generated/{svc_name}", exist_ok=True)

    with open(f"generated/{svc_name}/deployment.yaml", "w") as out:
        out.write(TEMPLATE_DEPLOY.substitute(env))

    with open(f"generated/{svc_name}/service.yaml", "w") as out:
        out.write(TEMPLATE_SERVICE.substitute(env))

print("Microservice manifests generated in /generated")

# --- Generate NGINX-Compatible Ingress Manifest ---
ingress_header = """
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: innovest-ingress
  namespace: innovest-dev
  annotations:
    # nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "http://localhost:5173"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS, PUT, DELETE"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization,Content-Type"
spec:
  ingressClassName: nginx
  rules:
  - host: localhost
    http:
      paths:
""".lstrip()

paths = ""

# Add ingress paths
for i in range(0, len(lines), 5):
    env = dict(line.split("=", 1) for line in lines[i:i + 5])
    svc_name = env["SERVICE_NAME"]
    api_path = env.get("API_PATH", svc_name)

    # Prepend 'api/' before the api_path
    paths += f"""        - path: /api/{api_path}(/|$)(.*)
          pathType: Prefix
          backend:
            service:
              name: {svc_name}
              port:
                number: 80
"""


# Write ingress file
with open("generated/ingress.yaml", "w") as f:
    f.write(ingress_header + paths)

print("NGINX Ingress manifest generated at generated/ingress.yaml")
