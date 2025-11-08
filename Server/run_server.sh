source /home/alex/Desktop/Tecky\ Server/.venv/bin/activate
# CUDA_VISIBLE_DEVICES=1 vllm serve '/home/alex/Desktop/Tecky Server/Tecky-One-2' --port 6161 --host 0.0.0.0 --dtype bfloat16 --served-model-name Tecky-One --max-model-len 55000
CUDA_VISIBLE_DEVICES=0 vllm serve '/home/alex/Desktop/Tecky Server/Tecky-One-2' --port 6162 --host 0.0.0.0 --dtype bfloat16 --served-model-name Tecky-One