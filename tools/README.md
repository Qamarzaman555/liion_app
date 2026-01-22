# 🔧 Leo CLI Tool

Command-line tool to connect to Leo hardware devices via **Bluetooth Low Energy (BLE)**
or **Serial** interfaces. Enables interactive sessions and supports OTA firmware
updates.

## 📂 Project Structure
```
tools/
├── connect.py                         # Entry point for CLI
├── requirements.txt                   # Python dependencies
├── README.md                          # Project documentation
└── leo/
    ├── bluetooth/
    │   ├── __init__.py
    │   ├── interface.py               # BLE interface logic
    │   └── manager.py                 # BLE manager (scan/connect)
    ├── serial/
    │   ├── __init__.py
    │   ├── interface.py               # Serial interface logic
    │   └── manager.py                 # Serial manager (scan/connect)
    ├── device/
        ├── __init__.py
        ├── base.py                    # Core device logic
        ├── core.py                    # Interactive and OTA behaviors
        ├── decorators.py              # Command wrappers
        ├── enums.py                   # Enum definitions
        ├── models.py                  # Device model structures
        └── utils.py                   # Shared helpers
```

## 🛠 Installation & Setup

### 1️⃣ Set Up a Virtual Environment (Recommended)

Before installing dependencies, create a **Python virtual environment** to isolate the
project.

#### **Create a Virtual Environment**

```sh
python -m venv .venv
```

#### **Activate the Virtual Environment**

##### Windows (Command Prompt):

```sh
.venv\Scripts\activate
```

##### Windows (PowerShell):

```sh
.venv\Scripts\Activate.ps1
```

##### Mac/Linux:

```sh
source .venv/bin/activate
```

### 2️⃣ Install Dependencies
If you're using a virtual environment, this will install dependencies inside your local
.venv/ environment.

```sh
pip install -r requirements.txt
```

## 🚀 Usage

Run the CLI using:

```sh
./connect.py [OPTIONS]
```

### 🔍 Scan for Devices

Bluetooth:
```sh
./connect.py --scan bluetooth
```

Serial:
```sh
./connect.py --scan serial
```

---

### 🔌 Connect to a Device

Serial Connection:
```sh
./connect.py --serial /dev/ttyUSB0
```

Bluetooth Connection:
```sh
./connect.py --bluetooth EVNCLM8KZ
```

This starts an interactive session. Type a command or `exit` to disconnect.

---

### 🧪 Interactive Session Commands

Once connected, you can issue the following types of commands:

- Device Info & Status:
  - help
  - version
  - swversion
  - hwversion
  - serial
  - mac

- Measurements & Metrics:
  - measure
  - mwh

- Stream Logs:
  - stream 254.CSV 254

- App Messaging:
  - py_msg
  - app_msg soc 80
  - app_msg limit 90 80 1 300

E.g.
```sh
> measure
```

To exit the session:
```sh
> exit
```

---

### 📦 Firmware Update (OTA)

```
./connect.py --bluetooth EVNCLM8KZ --ota Release_v1.5.22.img
```


### OTA Update
'''
source .venv/bin/activate && ./connect.py --bluetooth 'Leo USB O3HBOR0BO' --ota /Users/qamarzaman/StudioProjects/Liion-App/tools/Release_v1.5.23-rc4.img
'''

### Connect with LEO
'''
source .venv/bin/activate && ./connect.py --bluetooth 'Leo USB O3HBOR0BO'
'''

### connect
'''
source .venv/bin/activate && python3 connect.py --bluetooth EVNC1O6P6
'''
### Stream
# change first and last file number first -- tools/leo/bluetooth/interface.py
get all files