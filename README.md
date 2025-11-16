# Twingate Monitor Widget for KDE Plasma

KDE Plasma 6 widget to monitor and control Twingate VPN with Reality Check feature.

## Features

- **Start/Stop Twingate service** via systemd
- **Automatic authentication** after service start
- **Manual authentication** button
- **Internal network monitoring** (detects when local network is down)
- **Reality Check**: Verifies authentication by pinging remote networks behind Twingate
- **Resource list** from `twingate resources`
- **Color-coded status icon**:
  - 🔴 Red: Offline
  - 🟡 Yellow: Online but not authenticated OR internal network down
  - 🟢 Green: Connected & authenticated (verified via Reality Check)

## Requirements

- KDE Plasma 6.5+
- Twingate CLI client installed
- systemd service `twingate.service` configured

## Configuration

Right-click widget → Configure:

1. **Auth Resource**: The resource name for `twingate auth <resource>` (optional)
2. **Internal Network IP**: An IP in your LOCAL network (not behind Twingate), used to detect network issues
3. **Remote Networks**: Comma-separated IPs BEHIND Twingate for Reality Check (e.g., `10.0.0.1,10.1.0.1`)

### Example Configuration

Auth Resource: mycompany
Internal Network IP: 192.168.1.1
Remote Networks: 10.0.0.1,10.1.0.1,172.16.0.1


## How Reality Check Works

Every 60 seconds, the widget pings all configured Remote Network IPs. If **at least one** is reachable, Twingate is considered authenticated. This overrides unreliable `twingate status` output.

## Ue of Auth

As it is nit quite reliable to call the authentifivation from the widgte, pushing the "Auth" button in  the widget shows the command to use in a cli . After some time the cli comes up with a link (can be opened in a browser) and the authentucation process runs through in your browser.

## Installation

```bash
# Clone or download the widget
git clone https://github.com/yourusername/twingate-plasma-widget

# Copy to Plasma widgets directory
cp -r twingate-plasma-widget ~/.local/share/plasma/plasmoids/com.cachyos.twingate

# Restart Plasma Shell
kbuildsycoca6
kquitapp6 plasmashell && kstart plasmashell

## Or use Plasma’ s ”Install from file” feature with the packaged .plasmoid file.

# 1st installlation
plasmapkg2 -i ~/twingate-monitor.plasmoid

# Or Update:
plasmapkg2 -u ~/twingate-monitor.plasmoid


## License
## GPL-3.0+

## Contributing
## Pull requests welcome!

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.me/carlegends356)   


