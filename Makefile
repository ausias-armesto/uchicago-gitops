
encrypt-sealed-private-key:
	cat .vault_pass | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 ./clusters/k8s-$(env)/security/sealed-secret-private-key.yaml

VAULT_PASS := $(shell cat .vault_pass)

decrypt-sealed-private-key:
	gpg --quiet --batch --yes --decrypt --passphrase="$(VAULT_PASS)" --output ./clusters/k8s-$(env)/security/sealed-secret-private-key.yaml ./clusters/k8s-$(env)/security/sealed-secret-private-key.yaml.gpg

flux-bootstrap:
	flux check --pre && \
	flux bootstrap github --owner=$(ghuser) --repository=uchicago-gitops --branch=master --path=./clusters/k8s-$(env) --personal

MYSQL_WORDPRESS_PASSWORD := $(shell aws secretsmanager get-secret-value --secret-id wordpress-mysql-uchicago-$(env) --query SecretString --output text | jq -r .password)
flux-secret-mysql:
	cd clusters/k8s-$(env) && \
	kubectl -n wordpress create secret generic mysql-database-secret --from-literal=mariadb-password='$(MYSQL_WORDPRESS_PASSWORD)' --dry-run=client -o yaml > ./wordpress/mysql-database-secret.yaml && \
	kubeseal --format=yaml --cert=./security/sealed-secret-public-key.pem < ./wordpress/mysql-database-secret.yaml > ./wordpress/mysql-database-secret-sealed.yaml && \
	kubectl apply -f ./wordpress/mysql-database-secret-sealed.yaml

ADMIN_WORDPRESS_PASSWORD := $(shell aws secretsmanager get-secret-value --secret-id admin-wordpress-uchicago-$(env) --query SecretString --output text | jq -r .password)
flux-secret-wordpress:
	cd clusters/k8s-$(env) && \
	kubectl -n wordpress create secret generic wordpress-admin-secret --from-literal=wordpress-password='$(ADMIN_WORDPRESS_PASSWORD)' --dry-run=client -o yaml > ./wordpress/wordpress-admin-secret.yaml && \
	kubeseal --format=yaml --cert=./security/sealed-secret-public-key.pem < ./wordpress/wordpress-admin-secret.yaml > ./wordpress/wordpress-admin-secret-sealed.yaml && \
	kubectl apply -f ./wordpress/wordpress-admin-secret-sealed.yaml

flux-security: decrypt-sealed-private-key
	kubectl apply -f clusters/k8s-$(env)/security/sealed-secret-private-key.yaml && \
	kubectl scale deployment -n flux-system sealed-secrets-controller --replicas=0 && \
	sleep 5 && \
	kubectl scale deployment -n flux-system sealed-secrets-controller --replicas=1 && \
	make flux-secret-mysql && \
	make flux-secret-wordpress


flux-uninstall:
	flux uninstall && \
	kubectl delete namespace monitoring && \
	kubectl delete namespace wordpress && \
	kubectl delete deployment -n kube-system metrics-server