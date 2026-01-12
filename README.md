
This script expects an env variable called `SECRET_SSH_PRIVATE_KEY_B64` to be present. This can be created using a generated private ssh key:


```bash
ssh-keygen -t ed25519 -C "runpod-github" -f ./runpod_github_ed25519 -N ""
cat ./runpod_github_ed25519.pub  #  <-- copy this to github > settings > ssh keys

base64 -i ~/.ssh/runpod_github_ed25519 | tr -d '\n' > key.b64  # <-- copy this into Runpod > Secrets > new secret called `RUNPOD_SECRET_SECRET_RUNPOD_SSH_KEY_B64`
```

```bash
cd /workspace
wget -q https://raw.githubusercontent.com/jackboyla/runpod-dev-tools/main/runpod-ssh-setup.sh \
  && chmod +x runpod-ssh-setup.sh \
  && ./runpod-ssh-setup.sh

```