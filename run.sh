#!/bin/bash
# Launch Pixal3D on GPU 2 (RTX A6000, 49GB) — port 7861
INSTALL_DIR="/home/gregor/pixal3d"
CUDA_HOME="/usr/local/cuda-12.6"

export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
export CUDA_HOME
export CUDA_VISIBLE_DEVICES=GPU-2b2d8950-ac66-d6f7-f309-279d102f38c5
export ATTN_BACKEND=flash_attn
export HF_HOME="/home/gregor/hf_cache"
export TRANSFORMERS_CACHE="/home/gregor/hf_cache"
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
# TRELLIS.2 has no setup.py — add to PYTHONPATH
export PYTHONPATH="$INSTALL_DIR/build_ext/TRELLIS.2:${PYTHONPATH:-}"

cd "$INSTALL_DIR"
source venv/bin/activate

# Kill any existing instance and wait for GPU memory to clear
echo "[run.sh] Stopping any existing pixal3d process..."
pkill -f 'python.*app.py' 2>/dev/null && sleep 4
rm -f pixal3d.pid

echo "[run.sh] Starting Pixal3D on GPU 2 (RTX A6000, 49GB), port 7861..."
echo "[run.sh] Access at http://$(hostname -I | awk '{print $1}'):7861"

nohup python -u app.py > logs/app.log 2>&1 &
PID=$!
echo $PID > pixal3d.pid
echo "[run.sh] PID=$PID  —  tail -f $INSTALL_DIR/logs/app.log"
