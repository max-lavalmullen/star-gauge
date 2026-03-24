#!/bin/bash

# Configuration
PI_IP="192.168.1.254"
PROJECT_DIR="star-guage"

echo "🚀 Preparing to deploy Star Gauge to Raspberry Pi ($PI_IP)..."

# 1. Get Info
read -p "👤 Enter your Raspberry Pi username (default: pi): " PI_USER
PI_USER=${PI_USER:-pi}

read -p "🌐 Enter your Raspberry Pi IP address (default: $PI_IP): " INPUT_IP
PI_IP=${INPUT_IP:-$PI_IP}

echo "📦 Syncing files... (You may be asked for your Pi's password)"

# Check if .env exists locally
if [ ! -f "./$PROJECT_DIR/.env" ]; then
    echo "⚠️  WARNING: .env file not found in ./$PROJECT_DIR/.env"
    echo "   The application requires an API key to work correctly."
    read -p "   Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Found .env file locally."
fi

# 2. Transfer Files
rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude 'dist' \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude 'translation_cache.json' \
    ./$PROJECT_DIR \
    $PI_USER@$PI_IP:~/ 

echo "✅ Files transferred."
echo "🔧 Configuring remote server..."

# 3. Remote Setup & Launch
ssh -t $PI_USER@$PI_IP << 'EOF'
    PROJECT_DIR="star-guage"
    
    cd ~/$PROJECT_DIR

    if [ ! -f ".env" ]; then
        echo "⚠️  WARNING: .env file is MISSING on the Pi!"
    else
        echo "✅ .env file present on Pi."
    fi
    
    # --- Node.js Setup ---
    if ! command -v npm &> /dev/null; then
        echo "❌ Node.js is not installed. Installing..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # --- Cloudflared Setup (Tunnel) ---
    if ! command -v cloudflared &> /dev/null; then
        echo "🚇 Installing Cloudflared (Tunnel)..."
        # Detect architecture
        ARCH=$(dpkg --print-architecture)
        if [[ "$ARCH" == "armhf" ]]; then 
            URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
        elif [[ "$ARCH" == "arm64" ]]; then
            URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
        else
            URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        fi
        
        wget -q $URL -O cloudflared
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
    fi

    cd ~/$PROJECT_DIR
    
    echo "📦 Installing dependencies..."
    npm install
    
    echo "🏗️  Building frontend..."
    npm run build

    echo "🚀 Launching Server..."
    # Kill existing processes
    fuser -k 3001/tcp 2>/dev/null
    pkill -f "cloudflared tunnel" 2>/dev/null

    # Start Node Server
    echo "🔥 Starting Node.js server..."
    nohup npm start > server.log 2>&1 &
    SERVER_PID=$!

    # Wait for port 3001 to be active (max 30 seconds)
    echo "⏳ Waiting for server to initialize on port 3001..."
    for i in {1..30}; do
        if ss -lnt | grep -q :3001; then
            echo "✅ Server is UP and LISTENING on port 3001!"
            SERVER_UP=true
            break
        fi
        
        # Check if process died
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo "❌ Server process died unexpectedly."
            SERVER_UP=false
            break
        fi
        
        sleep 1
    done

    if [ "$SERVER_UP" != "true" ]; then
        echo "====================================================="
        echo "❌ SERVER FAILED TO START!"
        echo "HERE IS THE ERROR LOG (server.log):"
        echo "-----------------------------------------------------"
        cat server.log
        echo "-----------------------------------------------------"
        echo "====================================================="
        exit 1
    fi
    
    echo "🚇 Starting Public Tunnel..."
    # Start Cloudflare Tunnel and capture output to find the URL
    nohup cloudflared tunnel --url http://localhost:3001 > tunnel.log 2>&1 &

    echo "⏳ Waiting for tunnel URL..."
    sleep 5
    
    echo "====================================================="
    echo "🎉 DEPLOYMENT COMPLETE!"
    echo "====================================================="
    echo "👉 Local Network URL: http://$(hostname -I | awk '{print $1}'):3001"
    echo "👉 Public URL (Share this!):"
    grep -o 'https://.*\.trycloudflare\.com' tunnel.log | head -n 1
    echo "====================================================="
EOF