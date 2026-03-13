# CryptPad Deployment TODO

## 1. Generate OIDC secret and update both configs

```bash
# Generate a random secret
openssl rand -base64 32

# Hash it for Authelia
docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --password 'YOUR_SECRET'
```

- [+] Decrypt Authelia configmap: `cd kubernetes && sops -d -i infrastructure/controllers/authelia/configmap.sops.yaml`
- [+] Replace `REPLACE_WITH_PBKDF2_HASH` with the generated hash
- [+] Re-encrypt: `sops -e -i infrastructure/controllers/authelia/configmap.sops.yaml`
- [+] Decrypt CryptPad secret: `sops -d -i app/cryptpad/secret.sops.yaml`
- [+] Replace `REPLACE_WITH_CRYPTPAD_OIDC_SECRET` with the plaintext secret
- [+] Re-encrypt: `sops -e -i app/cryptpad/secret.sops.yaml`

## 2. Fill in and encrypt backup secret

```bash
cd kubernetes && sops -d -i app/cryptpad/secret-backup.sops.yaml
```

- [+] Replace `REPLACE_REST_PASSWORD` with the password for the `cryptpad` htpasswd user on rest-server
- [+] Replace `REPLACE_WITH_STRONG_PASSWORD` x2 with restic repo passwords for NAS and B2
- [+] Replace `REPLACE_WITH_B2_KEY_ID` with Backblaze B2 application key ID
- [+] Replace `REPLACE_WITH_B2_APPLICATION_KEY` with Backblaze B2 application key
- [+] Re-encrypt: `sops -e -i app/cryptpad/secret-backup.sops.yaml`

## 3. Create NFS directories on Synology

SSH into Synology and run:

```bash
mkdir -p /volume3/k8s-storage/cryptpad-data
mkdir -p /volume3/k8s-storage/cryptpad-config
```

- [+] Directories created

## 4. Set up restic repos and htpasswd user

```bash
# Generate htpasswd entry and append to /volume1/docker/rest-server/config/htpasswd on Synology
docker run --rm httpd:2-alpine htpasswd -nbB cryptpad 'YOUR_REST_PASSWORD'

# Init Synology repos
restic -r "rest:http://cryptpad:PASSWORD@synology.storage.lviv:8888/cryptpad-data/" init
restic -r "rest:http://cryptpad:PASSWORD@synology.storage.lviv:8888/cryptpad-config/" init

# Init B2 repos
B2_ACCOUNT_ID=... B2_ACCOUNT_KEY=... restic -r "b2:berezovskyi-backup-homelab-cryptpad:/data/" init
B2_ACCOUNT_ID=... B2_ACCOUNT_KEY=... restic -r "b2:berezovskyi-backup-homelab-cryptpad:/config/" init
```

- [+] cryptpad htpasswd user added to rest-server
- [+] Synology repos initialised
- [+] B2 repos initialised

## 5. Commit, push and verify deployment

- [ ] Commit and push all changes
- [ ] Pod comes up healthy (first start is slow: OnlyOffice download + SSO plugin clone):
  ```bash
  kubectl get pods -n cryptpad -w
  kubectl logs -n cryptpad -l app=cryptpad --tail=50 -f
  ```
- [ ] Both domains resolve with valid TLS:
  - https://cryptpad.berezovskyi.dev
  - https://sandbox.cryptpad.berezovskyi.dev
- [ ] OIDC login works: "Register with Authelia" button appears and completes successfully
- [ ] Run a backup job manually to verify repos:
  ```bash
  kubectl create job -n cryptpad --from=cronjob/cryptpad-data-backup test-backup-data
  kubectl logs -n cryptpad -l job-name=test-backup-data -f
  ```
