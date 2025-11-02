import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_authResource: authResourceField.text
    property alias cfg_remoteNetworks: remoteNetworksField.text

    ColumnLayout {
        spacing: 20

        GroupBox {
            title: "🔐 Authentication Resource"
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent

                Label {
                    text: "FQDN or IP to open for authentication (xdg-open will be used):"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                TextField {
                    id: authResourceField
                    placeholderText: "e.g., myapp.internal.company.com"
                    Layout.fillWidth: true
                }

                Label {
                    text: "This resource will be opened in your browser when clicking 'Auth'"
                    opacity: 0.6
                    font.italic: true
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        GroupBox {
            title: "🌐 Remote Networks (Reality Check)"
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent

                Label {
                    text: "IP addresses to ping (comma-separated):"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                TextField {
                    id: remoteNetworksField
                    placeholderText: "e.g., 10.0.1.1, 10.0.2.1, 192.168.100.1"
                    Layout.fillWidth: true
                }

                Label {
                    text: "These IPs will be pinged every 60 seconds. If at least ONE responds, reality check = SUCCESS ✅"
                    opacity: 0.6
                    font.italic: true
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
