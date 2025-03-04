# Step-by-Step Setup: Home Assistant Network Device Control

This guide provides detailed step-by-step instructions for setting up Home Assistant to control Aruba PoE switch ports using SSH with public key authentication.

## Prerequisites
- Home Assistant OS or Core installation
- Network access to your Aruba switch
- Admin credentials for your Aruba switch
- Enable password for Aruba switch (set up in web GUI)
- Edit configuration files within your browser or with a text editor on your PC using either the File Editor or Samba Share add-ons

## Step 0: Prepare Home Assistant Environment

### 0.1 Install Advanced SSH & Web Terminal Add-on

1. In Home Assistant, go to **Settings** > **Add-ons**
2. Click the **Add-on Store** button in the bottom right
3. Search for "Advanced SSH & Web Terminal" and select it
4. Click **Install**
5. Once installed, go to the **Configuration** tab
6. **Important**: Disable Protection Mode by toggling it off
7. Configure a password or SSH keys as needed
8. Go to the **Info** tab and click **Start**

### 0.2 Access Home Assistant Container Context

All commands in this guide must be executed in the proper Home Assistant container context:

1. Access the SSH terminal through the add-on interface or connect via SSH
2. Enter the Home Assistant container with the following command:
   ```bash
   docker exec -it homeassistant bash
   ```
3. You should now be in the correct container context where all subsequent commands should be executed

> **Note**: Running commands in the correct container context is critical as it ensures access to the proper filesystem and permissions needed for these scripts to work properly.

## Step 1: Set Up Authentication and Switch Configuration

For Aruba S2500 switches, X.509 client certificate authentication is the required method for Home Assistant integration.

### Important Switch Configuration for Automation

Before proceeding with authentication setup, you must enable bypass mode on the switch:

1. Connect to your Aruba switch via SSH using your existing credentials:
   ```bash
   ssh -o HostKeyAlgorithms=ssh-rsa -o Ciphers=aes128-cbc,aes256-cbc -o MACs=hmac-sha1,hmac-sha1-96 -o StrictHostKeyChecking=no admin@192.168.1.80
   ```
   (Replace 192.168.1.80 with your switch's IP address)

2. Enter admin password
3. Enter `enable` and enable password to enter enable mode

4. Enter configuration mode:
   ```
   configure terminal
   ```

5. **Critical Step**: Enable bypass mode to allow automation without enable password prompts:
   ```
   enable bypass
   ```
   
6. Save the configuration:
   ```
   write memory
   ```
   
7. Verify the bypass mode is working by logging out and back in:
   ```
   exit
   exit
   ```
   Then reconnect and confirm you go directly to privileged mode without an enable password prompt.
   > **Note**: enable bypass mode can be disabled again if needed by repeating the steps above but entering `no enable bypass` in step 5.

### X.509 Client Certificate Authentication Setup

### 1.1 Access Home Assistant via SSH

1. Open the "Terminal" from the Advanced SSH & Web Terminal add-on
   - Either click **OPEN WEB UI** from the add-on page
   - Or find Terminal in the sidebar if you've added it there

2. Ensure you're in the Home Assistant container context:
   ```bash
   docker exec -it homeassistant bash
   ```
   
3. Confirm you're in the right context by checking the prompt, which should include `homeassistant`

### 1.1.1 Generate X.509 Certificate Files

1. Enter the Home Assistant container context as described in Step 0

2. Create the SSH directory if it doesn't exist:
   ```bash
   mkdir -p /config/.ssh
   chmod 700 /config/.ssh
   ```

3. Generate a compatible RSA key in PEM format:
   ```bash
   ssh-keygen -t rsa -b 2048 -f /config/.ssh/aruba_compatible -m PEM
   ```
   When prompted for a passphrase, press Enter twice (no passphrase)

4. Extract the public key:
   ```bash
   ssh-keygen -y -f /config/.ssh/aruba_compatible > /config/.ssh/aruba_compatible.pub
   ```

5. Generate an X.509 certificate from this key:
   ```bash
   openssl req -new -x509 -key /config/.ssh/aruba_compatible -out /config/.ssh/aruba_compatible.pem -days 1500
   ```
   
6. When prompted for certificate information:
   - You can use defaults for most fields (press Enter)
   - **For Common Name, enter "hass"** (or the username you'll use on the switch)
   
7. Set proper permissions:
   ```bash
   chmod 600 /config/.ssh/aruba_compatible
   chmod 600 /config/.ssh/aruba_compatible.pub
   chmod 600 /config/.ssh/aruba_compatible.pem
   ```
   **Critical**: SSH will refuse to use private keys with permissions that are too open

#### 1.2 Upload Certificate to Aruba Switch

1. Access the switch's web interface in your browser (http://192.168.1.80)
   (Replace 192.168.1.80 with your switch's IP address)

2. Log in with administrator credentials

3. Navigate to **Configuration → Certificates → Upload**

4. Set the following fields: (See screen shot below)
   - Certificate Name: `aruba_compatible.pem`
   - Certificate Filename: Click **Browse** and select the `/config/.ssh/aruba_compatible.pem` file
   - Passphrase (optional): *leave blank*
   - Retype Passphrase: *leave blank*
   - Certificate Format: Select **PEM** from drop-down menu
   - Certificate Type: Select **Public Cert** from drop-down menu
     
   ![enter image description here](https://i.imgur.com/adsraiH.png)

5. Click the **Upload** button

6. Click the **Save Configuration** button at the top of the window

7. After successful upload, you can navigate to **Configuration → Certificates → Certificate Lists** to verify the certificate was uploaded. It should appear in the list with "PublicCert" type.

#### 1.3 Configure the Switch to Use the Certificate

1. Connect to your Aruba switch via SSH:
   ```bash
   ssh -o HostKeyAlgorithms=ssh-rsa -o Ciphers=aes128-cbc,aes256-cbc -o MACs=hmac-sha1,hmac-sha1-96 -o PubkeyAcceptedKeyTypes=ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa admin@192.168.1.80
   ```
   (Replace 192.168.1.80 with your switch's IP address)

2. Enter configuration mode:
   ```
   configure terminal
   ```

3. Associate the certificate with your user account:
   ```
   mgmt-user ssh-pubkey client-cert aruba_compatible.pem hass root
   ```
   (Replace "hass" with your username if different)

4. **Critical Step**: Enable public key authentication on the switch:
   ```
   ssh mgmt-auth public-key
   ```

5. Verify the SSH authentication settings:
   ```
   show ssh
   ```
   You should see output confirming that public-key authentication is enabled:
   ```
   SSH Settings:
   -------------
   DSA                                 Enabled
   Mgmt User Authentication Method     username/password public-key
   ```

6. Save the configuration:
   ```
   write memory
   exit
   ```

7. Refresh the web interface and navigate to **Configuration → Certificates**. The "Reference" column for your certificate should have changed from "0" to "1", indicating it's now associated with a user.
![enter image description here](https://i.imgur.com/bYWItkW.png)
> **Note**: If you want to disable specific authentication methods, you can use:
> - To disable public-key auth: `no ssh mgmt-auth public-key`
> - To disable username/password auth: `no ssh mgmt-auth username/password`

#### 1.4 Test the Certificate Authentication

1. Try connecting with the certificate and all required SSH options:
   ```bash
   ssh -i /config/.ssh/aruba_compatible -o HostKeyAlgorithms=ssh-rsa -o Ciphers=aes128-cbc,aes256-cbc -o MACs=hmac-sha1,hmac-sha1-96 -o PubkeyAcceptedKeyTypes=ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa hass@192.168.1.80
   ```
   (Replace "hass" with your username if different, and 192.168.1.80 with your switch's IP address)

2. If successful, you should connect without a password prompt

#### 1.5 Create SSH Config for Certificate Authentication

1. Create or edit your SSH config file:
   ```bash
   nano /config/.ssh/config
   ```

2. Add the following content with all required options:
   ```
   Host 192.168.1.80
       HostName 192.168.1.80
       User hass
       IdentityFile /config/.ssh/aruba_compatible
       HostKeyAlgorithms ssh-rsa
       Ciphers aes128-cbc,aes256-cbc
       MACs hmac-sha1,hmac-sha1-96
       PubkeyAcceptedKeyTypes ssh-rsa
       PubkeyAcceptedAlgorithms +ssh-rsa
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   ```
   (Replace "hass" with your username if different, and 192.168.1.80 with your switch's IP address)

   **Important**: The compatibility options (HostKeyAlgorithms, Ciphers, MACs, PubkeyAcceptedKeyTypes, and PubkeyAcceptedAlgorithms) are absolutely essential due to the older SSH server implementation on the S2500 switch. Without these options, modern SSH clients will reject the connection with security-related errors.

3. Save the file (Ctrl+O, then Enter, then Ctrl+X)

4. Set appropriate permissions:
   ```bash
   chmod 600 /config/.ssh/config
   ```

5. Test the connection using the config file:
   ```bash
   ssh -F /config/.ssh/config 192.168.1.80
   ```
   (Replace 192.168.1.80 with your switch's IP address)

## Step 2: Create the Command Scripts

### 2.1 Create Scripts Directory

1. Create a directory for your scripts:
   ```bash
   mkdir -p /config/scripts
   ```

### 2.2 Create the Expect Script

1. Create the file:
   ```bash
   nano /config/scripts/aruba_poe.exp
   ```

2. Paste the content of the expect script as provided in previous examples

3. Save the file (Ctrl+O, then Enter, then Ctrl+X)

4. Set appropriate permissions:
   ```bash
   chmod 755 /config/scripts/aruba_poe.exp
   ```

### 2.3 Create the Wrapper Script

1. Create the file:
   ```bash
   nano /config/scripts/aruba_poe_wrapper.sh
   ```

2. Paste the content of the wrapper script as provided in previous examples

3. Save the file (Ctrl+O, then Enter, then Ctrl+X)

4. Set appropriate permissions:
   ```bash
   chmod 755 /config/scripts/aruba_poe_wrapper.sh
   ```

### 2.4 Test the Scripts

1. Test enabling a port (replace 0 with your port number):
   ```bash
   /bin/bash /config/scripts/aruba_poe_wrapper.sh 0 enable
   ```

2. Test disabling a port:
   ```bash
   /bin/bash /config/scripts/aruba_poe_wrapper.sh 0 disable
   ```

3. Test checking port status:
   ```bash
   /bin/bash /config/scripts/aruba_poe_wrapper.sh 0 status
   ```

4. Verify the expect package is installed or let the wrapper install it

## Step 3: Create Home Assistant Command Line Integration

### 3.1 Create the Command Line Configuration

1. Edit your configuration:
   - If using YAML mode: Edit configuration.yaml directly
   - If using UI mode: Add a new configuration YAML file under Configuration > YAML

2. Create or edit the command_line.yaml file with the following structure:
   ```yaml
   # Command Line Switches for Aruba s2500-24P
   - switch:
       name: "PoE Port 0"
       unique_id: "aruba_poe_port_0"
       command_on: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 enable'
       command_off: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 disable'
       #command_state: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 status'
       command_timeout: 30
       value_template: "{{ 'Administratively Enable' in value }}"
       availability: "{{ value is defined and value | trim != '' }}"
       icon: "{{ 'mdi:power-plug' if ('Administratively Enable' in value or 'Successfully enabled' in value) else 'mdi:power-plug-off' }}"
       scan_interval: 900
   ```

   **Important Notes**: 
   - The `command_state` line is commented out to prevent timing issues with rapid command execution
   - Using staggered `scan_interval` values for multiple ports helps prevent simultaneous requests
   - This format follows current Home Assistant syntax standards
   - Note the correct structure with `- switch:` at the top level (not nested under platform)

3. Save the file

4. In Home Assistant, navigate to Configuration > Server Controls
   
5. Click on "RESTART" to restart Home Assistant and apply configuration changes

### 3.2 Include the Command Line YAML in Configuration

If using a separate command_line.yaml file, ensure it's included in configuration.yaml:

```yaml
# configuration.yaml
command_line: !include command_line.yaml
```

### 3.3 Restart Home Assistant

1. In Home Assistant, navigate to Configuration > Server Controls
   
2. Click on "RESTART" to restart Home Assistant and apply configuration changes

### 3.4 Test the Integration

1. Go to Configuration > Entities
   
2. Find your new "PoE Port 0" entity
   
3. Toggle the switch to test turning the port on and off
   
4. Verify the device connected to that port responds accordingly

## Step 4: Create Status Directory for Output Files

1. Create a directory for status output files:
   ```bash
   mkdir -p /config/www
   ```

2. Set appropriate permissions:
   ```bash
   chmod 755 /config/www
   ```

3. Ensure Home Assistant has write access:
   ```bash
   chown homeassistant:homeassistant /config/www
   ```
   (Adjust username if different in your setup)

## Step 5: Advanced Configuration (Optional)

### 5.1 Add Additional PoE Ports

1. Edit your command_line.yaml to add more ports:
   ```yaml
   # Command Line Switches for Aruba s2500-24P
   - switch:
       name: "PoE Port 0"
       unique_id: "aruba_poe_port_0"
       command_on: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 enable'
       command_off: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 disable'
       #command_state: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 0 status'
       command_timeout: 30
       value_template: "{{ 'Administratively Enable' in value }}"
       availability: "{{ value is defined and value | trim != '' }}"
       icon: "{{ 'mdi:power-plug' if ('Administratively Enable' in value or 'Successfully enabled' in value) else 'mdi:power-plug-off' }}"
       scan_interval: 900

   - switch:
       name: "PoE Port 1"
       unique_id: "aruba_poe_port_1"
       command_on: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 1 enable'
       command_off: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 1 disable'
       #command_state: '/bin/bash /config/scripts/aruba_poe_wrapper.sh 1 status'
       command_timeout: 30
       value_template: "{{ 'Administratively Enable' in value }}"
       availability: "{{ value is defined and value | trim != '' }}"
       icon: "{{ 'mdi:power-plug' if ('Administratively Enable' in value or 'Successfully enabled' in value) else 'mdi:power-plug-off' }}"
       scan_interval: 905
       
   # Add more ports as needed, with staggered scan_interval values
   ```

2. Restart Home Assistant

### 5.2 Create Custom Dashboard Cards

1. Go to Dashboards > Edit Dashboard
2. Click "+ ADD CARD"
3. Choose "Entities" card
4. Add your PoE port entities
5. Customize title, icons, etc.
6. Save the card

## Step 6: Troubleshooting

### 6.1 Check Script Permissions

If scripts fail to run:
```bash
chmod 755 /config/scripts/aruba_poe*.sh
chmod 755 /config/scripts/aruba_poe.exp
```

### 6.2 Check SSH Authentication

If SSH fails:
```bash
ssh -vvv -F /config/.ssh/config 192.168.1.80
```

### 6.3 Check Output Files

If status commands don't work:
```bash
ls -la /config/www/
cat /config/www/poe_status_port_0.txt
```

### 6.4 Enable Debug Logging

Add to configuration.yaml:
```yaml
logger:
  default: warn
  logs:
    homeassistant.components.command_line: debug
```

## Completion

You have now successfully:
- Set up SSH key authentication with your Aruba switch
- Created scripts to control PoE ports
- Integrated these controls into Home Assistant
- Created entities to control PoE ports through the UI

Your Home Assistant can now control PoE ports on your Aruba switch, allowing you to power cycle connected devices, create automations based on power state, and more.

