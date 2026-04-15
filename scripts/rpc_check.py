import time
import requests
import os
import logging
from prometheus_client import start_http_server, Gauge, Counter

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

# Prometheus Metrics
RPC_UP = Gauge('rpc_up', '1 if the RPC endpoint is responsive, 0 otherwise')
RPC_LATENCY = Gauge('rpc_response_seconds', 'Latency of the RPC request in seconds')
RPC_FAILURES = Counter('rpc_request_failures_total', 'Total number of failed RPC requests')

RPC_URL = os.getenv("RPC_URL", "http://blockchain-node:8545")
CHECK_INTERVAL_SECONDS = int(os.getenv("CHECK_INTERVAL_SECONDS", "5"))

def check_rpc():
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_blockNumber",
        "params": [],
        "id": 1
    }
    
    start_time = time.time()
    try:
        response = requests.post(RPC_URL, json=payload, timeout=2)
        latency = time.time() - start_time
        
        if response.status_code == 200 and 'result' in response.json():
            RPC_UP.set(1)
            RPC_LATENCY.set(latency)
            block_hex = response.json().get('result', '0x0')
            block_num = int(block_hex, 16)
            logging.info(f"RPC check SUCCESS | Latency: {latency:.4f}s | Block: {block_num}")
        else:
            raise Exception(f"Invalid response: {response.text}")
            
    except Exception as e:
        latency = time.time() - start_time
        RPC_UP.set(0)
        RPC_LATENCY.set(0)
        RPC_FAILURES.inc()
        logging.error(f"RPC check FAILED | Latency: {latency:.4f}s | Error: {str(e)}")

if __name__ == '__main__':
    # Start up the server to expose the metrics.
    logging.info("Starting Prometheus metrics server on port 8000")
    start_http_server(8000)
    
    # Generate load and metrics
    logging.info(f"Starting RPC checks against {RPC_URL} every {CHECK_INTERVAL_SECONDS} seconds")
    while True:
        check_rpc()
        time.sleep(CHECK_INTERVAL_SECONDS)
