#!/bin/bash

echo "🌟 Launching Star Gauge (Xuanji Tu)..."

# Ensure we are in the star-guage directory
if [ -d "star-guage" ]; then
    cd star-guage
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Function to handle cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down Star Gauge..."
    # Kill the background process group
    kill -- -$$ 2>/dev/null
    exit 0
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Start the server in the background
echo "🚀 Starting server..."
npm run dev:full &

# Wait for server to be ready (a simple sleep for now)
sleep 3

# Open the browser
echo "🌐 Opening browser..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "http://localhost:5173"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "http://localhost:5173"
elif [[ "$OSTYPE" == "msys" ]]; then
    start "http://localhost:5173"
fi

echo "✨ Star Gauge is running! Press Ctrl+C to stop."

# Wait for the background process
wait
