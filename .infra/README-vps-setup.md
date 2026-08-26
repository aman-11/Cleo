# Cleo VPS Provisioning Guide

Complete manual provisioning instructions for deploying Cleo to a hardened Hetzner VPS.

## Prerequisites

- **Hetzner Account**: Create account at https://www.hetzner.com/
- **Local SSH Key**: Generate an ed25519 key pair for VPS access

```bash
ssh-keygen -t ed25519 -C "aman@cleo-vps" -f ~/.ssh/id_ed25519_cleo_vps
```

## Step 1: Provision VPS on Hetzner

1. Log into Hetzner Cloud Console: https://console.hetzner.cloud/
2. **Create New Server**:
   - **Server Type**: CX33
     - 4 vCPU
     - 8GB RAM
     - 80GB SSD NVMe
     - **Cost**: ~$7.19/month (with IPv4)
   - **Location**: Choose nearest datacenter (e.g., Ashburn, VA for US East)
   - **Image**: Ubuntu 24.04 LTS (latest)
   - **Networking**:
     - ✅ Enable IPv4 (required — adds ~$0.60/mo)
     - ❌ Skip IPv6 for Phase 1
   - **SSH Key**: Add your public key
     ```bash
     cat ~/.ssh/id_ed25519_cleo_vps.pub
     ```
     Copy output and paste into Hetzner SSH key field
   - **Server Name**: `cleo-vps` (or your preference)

3. **Note the IP Address** assigned after creation

## Step 2: Initial SSH Access

Connect as root using the SSH key provided during provisioning:

```bash
ssh -i ~/.ssh/id_ed25519_cleo_vps root@VPS_IP_ADDRESS
```

Once connected, prepare for security script:

```bash
# Copy authorized_keys to /tmp for aman user setup
cp ~/.ssh/authorized_keys /tmp/authorized_keys
```

## Step 3: Run Security Hardening Script

### Upload Script to VPS

From your **local machine** (not the VPS):

```bash
scp -i ~/.ssh/id_ed25519_cleo_vps \
    /Users/aayushaman/personal/Cleo/.infra/vps-setup.sh \
    root@VPS_IP_ADDRESS:/root/
```

### Execute Script

SSH back into the VPS as root and run the script:

```bash
ssh -i ~/.ssh/id_ed25519_cleo_vps root@VPS_IP_ADDRESS

# Make executable and run
chmod +x /root/vps-setup.sh
/root/vps-setup.sh
```

The script will:
- Create `aman` user with sudo privileges
- Set up SSH key authentication for `aman`
- Disable root login
- Disable password authentication
- Configure UFW firewall (SSH only)
- Install fail2ban for intrusion prevention
- Install Docker and Docker Compose
- Configure logging and automated security updates

**⚠️ IMPORTANT**: After this script completes, root SSH login will be **permanently disabled**. You will only be able to SSH as user `aman`.

## Step 4: Verify Security Configuration

### Test SSH Access as `aman`

```bash
ssh -i ~/.ssh/id_ed25519_cleo_vps aman@VPS_IP_ADDRESS
```

You should successfully connect without password prompt.

### Verify Root Login is Rejected

```bash
ssh -i ~/.ssh/id_ed25519_cleo_vps root@VPS_IP_ADDRESS
```

Should fail with: `Permission denied (publickey).`

### Verify Password Authentication is Disabled

```bash
ssh -o PubkeyAuthentication=no aman@VPS_IP_ADDRESS
```

Should fail with: `Permission denied (publickey).`

### Check Firewall Status

On the VPS (logged in as `aman`):

```bash
sudo ufw status verbose
```

Expected output:
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
```

### Check fail2ban Status

```bash
sudo systemctl status fail2ban
```

Should show: `Active: active (running)`

### Check Docker Installation

```bash
docker --version
docker compose version
```

Both commands should return version numbers.

### Verify aman User in Docker Group

```bash
groups
```

Output should include `docker` group.

### Review Setup Log

```bash
sudo cat /var/log/vps-setup.log
```

Review for any warnings or errors during setup.

## Step 5: Configure Local SSH Client

Add VPS to your **local** `~/.ssh/config` for easy access:

```bash
cat >> ~/.ssh/config <<'EOF'

# Cleo VPS
Host cleo-vps
    HostName VPS_IP_ADDRESS
    User aman
    IdentityFile ~/.ssh/id_ed25519_cleo_vps
    ServerAliveInterval 30
    ServerAliveCountMax 3
EOF
```

Replace `VPS_IP_ADDRESS` with the actual IP.

Now you can connect simply with:

```bash
ssh cleo-vps
```

## Step 6: Next Steps

After verifying security configuration, proceed to:

1. **Phase 1 Wave 2**: Docker Compose scaffold deployment
2. **Phase 1 Wave 3**: mem0 + PostgreSQL deployment
3. **Phase 1 Wave 4**: Cleo startup script + heartbeat

## Troubleshooting

### Locked Out of VPS

If you get locked out after running the security script:

1. **Use Hetzner Console Access**:
   - Log into Hetzner Cloud Console
   - Select your server
   - Click "Console" to access web-based terminal
   - Log in as `aman` (or `root` if script didn't complete)

2. **Check Setup Log**:
   ```bash
   sudo cat /var/log/vps-setup.log
   ```

3. **Rollback Information**:
   If the script failed partway through, rollback steps will be logged. Manual recovery may be needed.

### SSH Connection Refused

- **Firewall Issue**: Ensure port 22 is allowed
  ```bash
  sudo ufw allow ssh
  sudo ufw reload
  ```

- **SSH Service Not Running**:
  ```bash
  sudo systemctl status sshd
  sudo systemctl restart sshd
  ```

### Can't Run Docker Commands

If `docker` commands fail with permission denied:

```bash
# Verify you're in docker group
groups

# If not in docker group
sudo usermod -aG docker aman

# Log out and log back in for group changes to take effect
exit
ssh cleo-vps
```

### fail2ban Not Blocking Brute Force

Check fail2ban jails status:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### Script Failed Partway Through

1. Check `/var/log/vps-setup.log` for the exact failure point
2. The script is idempotent — fix the issue and re-run:
   ```bash
   sudo /root/vps-setup.sh
   ```

---

**Security Baseline Established**: After completing these steps, your VPS is hardened and ready for Docker Compose service deployment.
