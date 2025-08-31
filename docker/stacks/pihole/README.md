# Pi-hole Stack

A network-wide ad blocker that acts as a DNS sinkhole, protecting your entire network from ads, trackers, and malicious domains. Enhanced with DNSCrypt-proxy for encrypted upstream DNS queries.

## Services Overview

- **server**: Pi-hole DNS server with web interface for ad blocking and network monitoring
- **dnscrypt-proxy**: Encrypted DNS proxy for secure upstream DNS resolution

## Key Features

- **Network-wide Ad Blocking**: Blocks ads for all devices on your network
- **DNS Sinkhole**: Prevents requests to known advertising and tracking domains
- **Encrypted DNS**: DNSCrypt-proxy provides encrypted communication with upstream DNS servers
- **Web Interface**: Comprehensive dashboard for monitoring and configuration
- **Query Logging**: Detailed logs of all DNS queries with filtering capabilities
- **Whitelist/Blacklist**: Custom domain allow/block lists
- **Multiple Blocklists**: Support for various community-maintained blocklists
- **Network Monitoring**: Real-time network activity and top blocked domains
- **DHCP Server**: Optional DHCP functionality for network management

## Architecture

### DNS Flow
1. Client DNS requests → Pi-hole (port 53)
2. Pi-hole checks blocklists → Blocks or allows
3. Allowed requests → DNSCrypt-proxy (port 5353)
4. DNSCrypt-proxy → Encrypted upstream DNS servers
5. Response flows back through the chain

### Security Features
- **Encrypted Upstream**: DNSCrypt-proxy encrypts DNS queries to upstream servers
- **Privacy Protection**: Prevents DNS queries from being monitored
- **Malware Protection**: Blocks known malicious domains

## Links & Documentation

### Pi-hole
- **Official Website**: https://pi-hole.net/
- **GitHub Repository**: https://github.com/pi-hole/pi-hole
- **Documentation**: https://docs.pi-hole.net/
- **Docker Hub**: https://hub.docker.com/r/pihole/pihole
- **Community**: https://discourse.pi-hole.net/

### DNSCrypt-proxy
- **GitHub Repository**: https://github.com/DNSCrypt/dnscrypt-proxy
- **Documentation**: https://github.com/DNSCrypt/dnscrypt-proxy/wiki
- **Docker Image**: https://hub.docker.com/r/klutchell/dnscrypt-proxy

### Blocklists
- **StevenBlack's List**: https://github.com/StevenBlack/hosts
- **AdguardTeam Lists**: https://github.com/AdguardTeam/AdguardFilters
- **Firebog Lists**: https://firebog.net/

## Configuration

### Environment Variables
Copy `stack.env` to `stack.env.real` and configure:

- `TZ`: Timezone for log timestamps
- `PIHOLE_WEBPASSWORD`: Password for Pi-hole web interface
- `PIHOLE_DNS_PORT`: DNS server port (default: 53)
- `PIHOLE_HTTP_PORT`: Web interface port (default: 80)
- `SERVICE_DATA_ROOT_PATH`: Base path for Pi-hole configuration data

### DNSCrypt Configuration
The DNSCrypt-proxy configuration file is located at:
`${SERVICE_DATA_ROOT_PATH}/dnscrypt/dnscrypt-proxy.toml`

### Network Access
- **DNS Service**: Port 53 (TCP/UDP) - Configure as DNS server for network devices
- **Web Interface**: Port 80 (or configured `PIHOLE_HTTP_PORT`)
- **Admin Panel**: Access via `http://your-server-ip:port/admin`

## Setup Instructions

### 1. Network Configuration
Configure your router or devices to use Pi-hole as the DNS server:
- **Router**: Set DNS server to Pi-hole IP address
- **Individual Devices**: Configure network settings to use Pi-hole IP

### 2. Initial Setup
1. Access web interface at `http://your-server-ip:port/admin`
2. Login with configured password
3. Configure blocklists under "Group Management" → "Adlists"
4. Update gravity database to apply blocklists

### 3. Testing
- Visit `http://doubleclick.net` - should be blocked
- Check Pi-hole dashboard for blocked queries
- Verify DNS resolution is working for legitimate domains

## Blocklist Management

### Default Lists
Pi-hole comes with several default blocklists. Popular additions include:

- **StevenBlack Unified**: Comprehensive hosts file
- **AdGuard Base Filter**: AdGuard's main blocklist  
- **EasyList**: Popular browser extension list
- **Malware Domain List**: Security-focused blocking

### Custom Lists
Add custom blocklists via:
- Web interface: Group Management → Adlists
- Manual file editing: Add domains to local blocklist files

## Advanced Features

### Conditional Forwarding
Configure local domain resolution for internal networks.

### DHCP Replacement
Pi-hole can replace your router's DHCP server for better integration.

### API Access
REST API available for external integrations and monitoring.

## Performance Considerations

- **Memory Usage**: Minimal resource requirements (~100MB RAM)
- **Storage**: Logs and configuration require modest disk space
- **Network Impact**: Negligible latency impact on DNS resolution
- **Query Volume**: Handles thousands of queries per minute efficiently

## Monitoring & Maintenance

### Dashboard Metrics
- Total queries processed
- Percentage of blocked queries
- Top blocked domains
- Query volume over time
- Client activity statistics

### Log Management
- Query logs with filtering options
- Long-term trend analysis
- Privacy-focused logging controls

## Dependencies

- Network access for initial blocklist downloads
- DNSCrypt-proxy configuration file
- Persistent storage for Pi-hole configuration and logs
