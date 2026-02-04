import boto3
import json
import random
import time
import uuid
from datetime import datetime, timedelta, timezone
from faker import Faker

# ---CONFIGURATION ---
STREAM_NAME = "fraud-detection-v3-stream"
REGION = "ap-southeast-2"  # Change if different
faker = Faker()

# Initialize Kinesis Client
kinesis = boto3.client("kinesis", region_name=REGION)

def get_random_location():
    # Simulate users mostly in Australian cities
    locations = [
        {"city":"Sydney","lat":"-33.8688","long":"151.2093"},
        {"city": "Melbourne", "lat": -37.8136, "long": 144.9631},
        {"city": "Brisbane", "lat": -27.4698, "long": 153.0251},
        {"city": "Perth", "lat": -31.9505, "long": 115.8605}
    ]
    return random.choice(locations)

def generate_transaction():
    """Generates a clean, valid transaction."""
    loc = get_random_location()
    return {
        "transaction_id": str(uuid.uuid4()),
        "user_id": f"user-{random.randint(1,100)}",
        "amount": round(random.uniform(10.0,5000.0),2),
        "currency": "AUD",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "location": loc,
        "merchant": faker.company(),
        "is_chaos": False
    }

def inject_chaos(txn):
    """Applies a 'Chaos Type' to a transaction."""
    chaos_type = random.choice(["DUPLICATE", "LATE_EVENT", "MALFORMED", "POISON"])
    if chaos_type == "DUPLICATE":
        # We will send this txn TWICE in the main loop
        txn['is_chaos'] = True
        txn['chaos_type'] = "DUPLICATE"
        return [txn, txn]
    elif chaos_type == "LATE_EVENT":
        # Set timestamp to 1 hour ago
        txn['timestamp'] = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
        txn['is_chaos'] = True
        txn['chaos_type'] = "LATE_EVENT"
        return [txn]
    elif chaos_type == "MALFORMED":
        # Corrupt the amount (String instead of Float)
        txn['amount'] = "ONE_MILLION_DOLLARS" 
        txn['is_chaos'] = True
        txn['chaos_type'] = "MALFORMED"
        return [txn]
    elif chaos_type == "POISON":
        # DELETE the location key entirely.
        # This forces a KeyError when the Lambda tries to read txn['location']['lat']
        del txn['location']
        txn['is_chaos'] = True
        txn['chaos_type'] = "POISON_PILL"
        return [txn]

def send_record(txn):
    partition_key = txn.get("user_id", "unknown")
    try:
        response = kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(txn),
            PartitionKey=partition_key
        )
        print(f"Sent: {txn['transaction_id']} | Chaos: {txn.get('chaos_type', 'None')}")
    except Exception as e:
        print(f"Error sending: {e}")

def main():
    print(f"Starting Producer... Target Stream: {STREAM_NAME}")
    try:
        for _ in range(100): # Generate 100 events
            txn = generate_transaction()
            
            # 20% Chance of Chaos
            if random.random() < 0.2:
                txns_to_send = inject_chaos(txn)
            else:
                txns_to_send = [txn]

            for t in txns_to_send:
                send_record(t)
                time.sleep(0.1) # Simulate throughput
                
    except KeyboardInterrupt:
        print("Stopping producer...")

if __name__ == "__main__":
    main()