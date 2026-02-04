import base64
import json
import boto3
import os
import logging
from math import radians, cos, sin, asin, sqrt
from datetime import datetime, timezone
from decimal import Decimal

# Setup Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
dynamodb = boto3.resource('dynamodb')
table_user_state = dynamodb.Table(os.environ['USER_STATE_TABLE'])
table_alerts = dynamodb.Table(os.environ['ALERTS_TABLE'])

def haversine(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance in kilometers between two points 
    on the earth (specified in decimal degrees)
    """
    # Convert decimal degrees to radians 
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])

    # Haversine formula 
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    r = 6371 # Radius of earth in kilometers
    return c * r

def process_record(record):
    try:
        # 1. Decode Kinesis Data
        payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
        txn = json.loads(payload)
        
        # 2. Schema Validation (Chaos: MALFORMED)
        if not isinstance(txn['amount'], (int, float)):
            logger.warning(f"MALFORMED DATA DETECTED: {txn['transaction_id']}")
            return # In real world: Send to DLQ

        user_id = txn['user_id']
        new_lat = float(txn['location']['lat'])
        new_long = float(txn['location']['long'])
        new_time = datetime.fromisoformat(txn['timestamp'])
        
        # 3. Get Previous State
        response = table_user_state.get_item(Key={'user_id': user_id})
        
        if 'Item' in response:
            last_state = response['Item']
            
            # Idempotency Check (Chaos: DUPLICATE)
            if last_state.get('last_transaction_id') == txn['transaction_id']:
                logger.info(f"DUPLICATE EVENT IGNORED: {txn['transaction_id']}")
                return

            # 4. Calculate Velocity (The Fraud Rule)
            last_lat = float(last_state['last_lat'])
            last_long = float(last_state['last_long'])
            last_time = datetime.fromisoformat(last_state['last_txn_timestamp'])
            
            # Calculate Distance (km)
            dist_km = haversine(last_long, last_lat, new_long, new_lat)
            
            # Calculate Time Diff (hours)
            time_diff_hours = (new_time - last_time).total_seconds() / 3600.0
            
            # Avoid division by zero for instant transactions
            if time_diff_hours > 0:
                speed = dist_km / time_diff_hours
                
                # Rule: Impossible Travel (> 900km/h)
                if speed > 900 and dist_km > 50: # Thresholds
                    logger.error(f"FRAUD DETECTED! User: {user_id}, Speed: {speed:.2f} km/h")
                    
                    # Write to Alerts Table
                    table_alerts.put_item(Item={
                        'transaction_id': txn['transaction_id'],
                        'user_id': user_id,
                        'reason': 'IMPOSSIBLE_TRAVEL',
                        'details': f"Speed: {speed:.2f} km/h, Dist: {dist_km:.2f} km",
                        'timestamp': datetime.now(timezone.utc).isoformat()
                    })

        # 5. Update State (Always update current location)
        table_user_state.put_item(Item={
            'user_id': user_id,
            'last_transaction_id': txn['transaction_id'],
            'last_lat': Decimal(str(new_lat)), # DynamoDB requires Decimal
            'last_long': Decimal(str(new_long)),
            'last_txn_timestamp': txn['timestamp'],
            'ttl': int(datetime.now(timezone.utc).timestamp()) + 86400 # 24h retention
        })

    except Exception as e:
        logger.error(f"Error processing record: {e}")
        # Raise to trigger Kinesis retry (or DLQ if configured)
        raise e

def handler(event, context):
    """
    Kinesis triggers this handler with a batch of records.
    """
    for record in event['Records']:
        process_record(record)
    
    return {"status": "success"}