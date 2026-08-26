# OpenClaw Dashboard Access

## Remote Access via Tailscale (Recommended)

OpenClaw is configured with Tailscale Serve mode for secure remote access.

### Access URL
**https://cleo-vps.tail499b42.ts.net/**

- Accessible from any device on your tailnet
- Automatic HTTPS encryption
- No SSH tunnel required
- Automatic authentication via Tailscale identity

### Configuration
- Mode: `tailscale.mode = "serve"`
- Bind: `loopback` (127.0.0.1)
- Auth: Token + Tailscale identity support

## Local SSH Tunnel (Alternative)

For local access or if Tailscale is unavailable:

```bash
./scripts/openclaw-dashboard.sh
```

Then access at: http://localhost:18789

## Gateway Token

For API/CLI access:
```
8117cfa4f1f873e523b4ead58753053a25458ebcdd2fca9862993a8150749dd8
```

## Technical Details

### VPS Configuration
- Tailscale installed on VPS: ✓
- Tailscale installed in Docker container: ✓
- Tailscale socket mounted: `/var/run/tailscale/tailscaled.sock`
- Operator permissions: aman (UID 1000)

### Docker Compose Changes
Added volume mount for Tailscale socket:
```yaml
volumes:
  - /var/run/tailscale/tailscaled.sock:/var/run/tailscale/tailscaled.sock
```

### Environment Variables
- `OPENCLAW_GATEWAY_BIND=loopback`
- Tailscale Serve mode configured in openclaw.json

## Troubleshooting

### Check Tailscale Serve Status
```bash
ssh aman@cleo-vps "docker logs openclaw-openclaw-gateway-1 2>&1 | grep tailscale"
```

Should show:
```
[tailscale] serve enabled: https://cleo-vps.tail499b42.ts.net/
```

### Restart Gateway
```bash
ssh aman@cleo-vps "cd /home/aman/openclaw && docker compose restart openclaw-gateway"
```

### Check Tailscale Status
```bash
ssh aman@cleo-vps "tailscale status"
```
