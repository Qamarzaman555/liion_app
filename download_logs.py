#!/usr/bin/env python3
"""
Script to download logs from Firestore.
Shows device names (collections) and document names, allows user to select which to download.
Works with public Firestore databases (no authentication required).
"""

import os
import sys
import json
import requests
from typing import List, Dict, Any, Optional
from datetime import datetime
from urllib.parse import quote

# Firebase project configuration
PROJECT_ID = "liion-power-227c6"
BASE_COLLECTION_PATH = "logs/app-logs"

# Firestore REST API base URL
FIRESTORE_REST_API = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

def get_collections_rest() -> List[str]:
    """Get all collection names (device names) using REST API."""
    collections = []
    try:
        print("Fetching device collections...")
        
        # Get the parent document path
        parent_path = f"{FIRESTORE_REST_API}/logs/app-logs"
        
        # List subcollections using REST API
        list_collections_url = f"{parent_path}:listCollectionIds"
        
        response = requests.post(list_collections_url)
        
        if response.status_code == 200:
            data = response.json()
            collections = data.get('collectionIds', [])
            print(f"Found {len(collections)} device collection(s)")
            return collections
        elif response.status_code == 404:
            print("Parent document 'logs/app-logs' not found.")
            print("This might mean:")
            print("1. No logs have been created yet")
            print("2. The collection structure is different")
            print("\nPlease enter device names manually:")
            user_input = input().strip()
            if not user_input:
                sys.exit(0)
            collections = [name.strip() for name in user_input.split(",")]
            return collections
        else:
            print(f"Error fetching collections: {response.status_code}")
            print(f"Response: {response.text}")
            print("\nFalling back to manual input...")
            print("Enter device names (collection names) separated by commas, or press Enter to exit:")
            user_input = input().strip()
            if not user_input:
                sys.exit(0)
            collections = [name.strip() for name in user_input.split(",")]
            return collections
            
    except Exception as e:
        print(f"Error getting collections: {e}")
        print("\nFalling back to manual input...")
        print("Enter device names (collection names) separated by commas, or press Enter to exit:")
        user_input = input().strip()
        if not user_input:
            sys.exit(0)
        collections = [name.strip() for name in user_input.split(",")]
        return collections

def get_documents_rest(device_name: str) -> List[Dict[str, Any]]:
    """Get all documents for a given device collection using REST API."""
    docs = []
    
    try:
        # Access the subcollection: logs/app-logs/{device_name}
        collection_path = f"{FIRESTORE_REST_API}/logs/app-logs/{device_name}"
        
        response = requests.get(collection_path)
        
        if response.status_code == 200:
            data = response.json()
            documents = data.get('documents', [])
            
            for doc in documents:
                # Extract document ID from the name field
                doc_name = doc.get('name', '')
                doc_id = doc_name.split('/')[-1] if '/' in doc_name else doc_name
                
                doc_fields = doc.get('fields', {})
                
                # Parse document data
                doc_data = {}
                for key, value in doc_fields.items():
                    doc_data[key] = parse_firestore_value(value)
                
                docs.append({
                    'id': doc_id,
                    'data': doc_data,
                    'created_at': doc_data.get('createdAt'),
                    'device': doc_data.get('device', device_name),
                    'platform': doc_data.get('platform', 'unknown'),
                    'app_version': doc_data.get('appVersion', 'unknown'),
                    'build_number': doc_data.get('buildNumber', 'unknown'),
                    'logs_count': len(doc_data.get('logs', []))
                })
        elif response.status_code == 404:
            print(f"  No documents found for device: {device_name}")
        else:
            print(f"  Error getting documents: {response.status_code}")
            print(f"  Response: {response.text}")
    
    except Exception as e:
        print(f"Error getting documents for {device_name}: {e}")
        print(f"  Collection path: logs/app-logs/{device_name}")
    
    return docs

def parse_firestore_value(value: Dict[str, Any]) -> Any:
    """Parse a Firestore value from REST API format."""
    if 'stringValue' in value:
        return value['stringValue']
    elif 'integerValue' in value:
        return int(value['integerValue'])
    elif 'doubleValue' in value:
        return float(value['doubleValue'])
    elif 'booleanValue' in value:
        return value['booleanValue']
    elif 'timestampValue' in value:
        # Parse ISO 8601 timestamp
        ts_str = value['timestampValue']
        try:
            # Remove 'Z' and parse
            ts_str = ts_str.replace('Z', '+00:00')
            dt = datetime.fromisoformat(ts_str)
            return {
                'seconds': int(dt.timestamp()),
                'nanoseconds': dt.microsecond * 1000
            }
        except:
            return value['timestampValue']
    elif 'arrayValue' in value:
        array_values = value['arrayValue'].get('values', [])
        return [parse_firestore_value(v) for v in array_values]
    elif 'mapValue' in value:
        map_fields = value['mapValue'].get('fields', {})
        return {k: parse_firestore_value(v) for k, v in map_fields.items()}
    elif 'nullValue' in value:
        return None
    else:
        return value

def format_log_entry(log_entry: Dict[str, Any]) -> str:
    """Format a single log entry for display/saving."""
    timestamp = log_entry.get('ts')
    level = log_entry.get('level', 'UNKNOWN')
    message = log_entry.get('message', '')
    
    # Handle timestamp (could be Timestamp object or dict)
    if timestamp:
        if isinstance(timestamp, dict):
            # Timestamp dict from Firestore REST API
            seconds = timestamp.get('seconds', timestamp.get('_seconds', 0))
            nanoseconds = timestamp.get('nanoseconds', timestamp.get('_nanoseconds', 0))
            dt = datetime.fromtimestamp(seconds + nanoseconds / 1e9)
            ts_str = dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        elif hasattr(timestamp, 'seconds'):
            # Firestore Timestamp object (if using SDK)
            dt = datetime.fromtimestamp(timestamp.seconds + timestamp.nanoseconds / 1e9)
            ts_str = dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        else:
            ts_str = str(timestamp)
    else:
        ts_str = "N/A"
    
    return f"[{ts_str}] [{level}] {message}"

def save_logs_to_file(device_name: str, doc_id: str, doc_data: Dict[str, Any], output_dir: str = "."):
    """Save logs from a document to a .doc file."""
    # Create safe filename (replace invalid characters)
    safe_device = device_name.replace('/', '_').replace('\\', '_').replace(' ', '_')
    safe_doc = doc_id.replace('/', '_').replace('\\', '_').replace(' ', '_')
    filename = f"{safe_device}_{safe_doc}.doc"
    filepath = os.path.join(output_dir, filename)
    
    logs = doc_data.get('logs', [])
    
    with open(filepath, 'w', encoding='utf-8') as f:
        # Write header
        f.write("=" * 80 + "\n")
        f.write(f"Device: {doc_data.get('device', device_name)}\n")
        f.write(f"Document ID: {doc_id}\n")
        f.write(f"Platform: {doc_data.get('platform', 'unknown')}\n")
        f.write(f"App Version: {doc_data.get('appVersion', 'unknown')}\n")
        f.write(f"Build Number: {doc_data.get('buildNumber', 'unknown')}\n")
        
        created_at = doc_data.get('createdAt')
        if created_at:
            if isinstance(created_at, dict):
                seconds = created_at.get('seconds', created_at.get('_seconds', 0))
                nanoseconds = created_at.get('nanoseconds', created_at.get('_nanoseconds', 0))
                dt = datetime.fromtimestamp(seconds + nanoseconds / 1e9)
                f.write(f"Created At: {dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
            elif hasattr(created_at, 'seconds'):
                dt = datetime.fromtimestamp(created_at.seconds + created_at.nanoseconds / 1e9)
                f.write(f"Created At: {dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
            else:
                f.write(f"Created At: {created_at}\n")
        
        f.write(f"Total Log Entries: {len(logs)}\n")
        f.write("=" * 80 + "\n\n")
        
        # Write logs
        for log_entry in logs:
            f.write(format_log_entry(log_entry) + "\n")
    
    print(f"  ✓ Saved {len(logs)} log entries to {filepath}")
    return filepath

def display_devices_menu(devices: List[str]) -> List[str]:
    """Display device menu and return selected devices."""
    if not devices:
        print("No devices found.")
        return []
    
    print("\n" + "=" * 80)
    print("DEVICES (Collections)")
    print("=" * 80)
    for i, device in enumerate(devices, 1):
        print(f"{i}. {device}")
    print("0. Select all devices")
    print("=" * 80)
    
    selection = input("\nEnter device numbers (comma-separated) or 'q' to quit: ").strip()
    
    if selection.lower() == 'q':
        return []
    
    if selection == '0':
        return devices
    
    try:
        indices = [int(x.strip()) - 1 for x in selection.split(',')]
        selected = [devices[i] for i in indices if 0 <= i < len(devices)]
        return selected
    except (ValueError, IndexError):
        print("Invalid selection.")
        return []

def display_documents_menu(device_name: str, documents: List[Dict[str, Any]]) -> List[str]:
    """Display documents menu for a device and return selected document IDs."""
    if not documents:
        print(f"\nNo documents found for device: {device_name}")
        return []
    
    print(f"\n" + "=" * 80)
    print(f"DOCUMENTS for Device: {device_name}")
    print("=" * 80)
    for i, doc in enumerate(documents, 1):
        created_str = "N/A"
        if doc['created_at']:
            if isinstance(doc['created_at'], dict):
                seconds = doc['created_at'].get('seconds', doc['created_at'].get('_seconds', 0))
                nanoseconds = doc['created_at'].get('nanoseconds', doc['created_at'].get('_nanoseconds', 0))
                dt = datetime.fromtimestamp(seconds + nanoseconds / 1e9)
                created_str = dt.strftime('%Y-%m-%d %H:%M:%S')
            elif hasattr(doc['created_at'], 'seconds'):
                dt = datetime.fromtimestamp(doc['created_at'].seconds + doc['created_at'].nanoseconds / 1e9)
                created_str = dt.strftime('%Y-%m-%d %H:%M:%S')
        
        print(f"{i}. Document ID: {doc['id']}")
        print(f"   Created: {created_str} | Logs: {doc['logs_count']} | Version: {doc['app_version']} (Build: {doc['build_number']})")
    print("0. Select all documents")
    print("=" * 80)
    
    selection = input(f"\nEnter document numbers for {device_name} (comma-separated) or 's' to skip: ").strip()
    
    if selection.lower() == 's':
        return []
    
    if selection == '0':
        return [doc['id'] for doc in documents]
    
    try:
        indices = [int(x.strip()) - 1 for x in selection.split(',')]
        selected = [documents[i]['id'] for i in indices if 0 <= i < len(documents)]
        return selected
    except (ValueError, IndexError):
        print("Invalid selection.")
        return []

def main():
    print("=" * 80)
    print("Firestore Log Downloader (Public Access)")
    print("=" * 80)
    print(f"Project: {PROJECT_ID}")
    print(f"Base Path: {BASE_COLLECTION_PATH}")
    print("=" * 80)
    print("Using Firestore REST API (no authentication required)\n")
    
    # Get collections (device names)
    devices = get_collections_rest()
    
    if not devices:
        print("No devices found. Exiting.")
        sys.exit(0)
    
    # Let user select devices
    selected_devices = display_devices_menu(devices)
    
    if not selected_devices:
        print("No devices selected. Exiting.")
        sys.exit(0)
    
    # For each selected device, show documents and let user select
    all_selections = {}  # {device_name: {doc_ids: [...], documents: {...}}}
    
    for device in selected_devices:
        print(f"\nFetching documents for device: {device}...")
        documents = get_documents_rest(device)
        
        if documents:
            selected_docs = display_documents_menu(device, documents)
            if selected_docs:
                all_selections[device] = {
                    'doc_ids': selected_docs,
                    'documents': {doc['id']: doc for doc in documents if doc['id'] in selected_docs}
                }
    
    if not all_selections:
        print("\nNo documents selected. Exiting.")
        sys.exit(0)
    
    # Download selected logs
    print("\n" + "=" * 80)
    print("DOWNLOADING LOGS")
    print("=" * 80)
    
    total_downloaded = 0
    for device, selection_data in all_selections.items():
        print(f"\nDevice: {device}")
        for doc_id in selection_data['doc_ids']:
            doc_info = selection_data['documents'][doc_id]
            save_logs_to_file(device, doc_id, doc_info['data'])
            total_downloaded += 1
    
    print("\n" + "=" * 80)
    print(f"✓ Download complete! {total_downloaded} document(s) downloaded.")
    print("=" * 80)

if __name__ == "__main__":
    main()


