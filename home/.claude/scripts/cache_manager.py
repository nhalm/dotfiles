#!/usr/bin/env python3
"""
Library-focused cache manager for docs-researcher agent.
Usage:
  # Check if library docs are cached
  python3 cache_manager.py check-library "/tiangolo/fastapi"
  
  # Cache entire library documentation
  python3 cache_manager.py write-library "/tiangolo/fastapi" < full_docs.md
  
  # Query within cached library docs
  python3 cache_manager.py query "/tiangolo/fastapi" "websocket implementation"
  
  # Legacy query-based caching (for non-Context7 sources)
  python3 cache_manager.py check "some general query"
  python3 cache_manager.py write "some general query" "WebSearch" < docs.txt
"""

import sys
import os
import json
import hashlib
import time
import re
from pathlib import Path

CACHE_ROOT = Path.home() / ".claude" / "docs" / "agent-cache"
LIBRARY_CACHE_ROOT = Path.home() / ".claude" / "docs" / "library-cache"
CACHE_EXPIRY = 7 * 24 * 60 * 60  # 7 days for libraries, they change less frequently

def sanitize_library_id(library_id):
    """Convert library ID to safe filesystem path"""
    # Remove leading slash and replace slashes with underscores
    safe_id = library_id.lstrip('/').replace('/', '_')
    # Keep only alphanumeric, underscore, dash, and dot
    safe_id = re.sub(r'[^a-zA-Z0-9_.-]', '_', safe_id)
    return safe_id

def get_library_cache_path(library_id):
    """Get cache directory path for a library"""
    safe_id = sanitize_library_id(library_id)
    return LIBRARY_CACHE_ROOT / safe_id

def get_legacy_cache_key(query):
    """Generate a short hash for legacy query-based caching"""
    return hashlib.sha256(query.encode()).hexdigest()[:16]

def get_legacy_cache_path(query, source="context7"):
    """Get cache directory path for a query (legacy)"""
    cache_key = get_legacy_cache_key(query)
    query_safe = "".join(c for c in query.lower().replace(" ", "_") if c.isalnum() or c == "_")[:50]
    return CACHE_ROOT / source / query_safe / cache_key

def check_cache(query):
    """Check if cache exists and is valid"""
    cache_dir = get_cache_path(query)
    metadata_file = cache_dir / "metadata.json"
    docs_file = cache_dir / "documentation.md"
    
    if not (metadata_file.exists() and docs_file.exists()):
        print(f"MISS: No cache found at {cache_dir}")
        return False
    
    try:
        with open(metadata_file) as f:
            metadata = json.load(f)
        
        # Check expiry
        if time.time() > metadata.get("expiry", 0):
            print(f"EXPIRED: Cache expired at {cache_dir}")
            # Clean up expired cache
            import shutil
            shutil.rmtree(cache_dir)
            return False
            
        age_hours = (time.time() - metadata["timestamp"]) / 3600
        print(f"HIT: Found cache ({age_hours:.1f}h old) at {cache_dir}")
        
        # Return the cached documentation
        with open(docs_file) as f:
            print(f"SOURCE: {metadata['source']} (Cached)")
            print("---CACHED-CONTENT---")
            print(f.read())
        
        return True
        
    except Exception as e:
        print(f"ERROR: Invalid cache at {cache_dir}: {e}")
        return False

def write_cache(query, source, documentation):
    """Write documentation to cache"""
    cache_dir = get_cache_path(query, source.lower())
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    # Write metadata
    metadata = {
        "timestamp": int(time.time()),
        "expiry": int(time.time() + CACHE_EXPIRY),
        "source": source,
        "query": query,
        "cache_key": get_cache_key(query)
    }
    
    with open(cache_dir / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    # Write documentation
    with open(cache_dir / "documentation.md", "w") as f:
        f.write(documentation)
    
    print(f"✅ Cached at: {cache_dir}")
    return True

def main():
    if len(sys.argv) < 3:
        print("Usage: cache_manager.py [check|write] 'query' ['source']")
        sys.exit(1)
    
    command = sys.argv[1]
    query = sys.argv[2]
    
    if command == "check":
        check_cache(query)
    elif command == "write":
        source = sys.argv[3] if len(sys.argv) > 3 else "Context7"
        documentation = sys.stdin.read().strip()
        if not documentation:
            print("ERROR: No documentation provided via stdin")
            sys.exit(1)
        write_cache(query, source, documentation)
    else:
        print(f"ERROR: Unknown command '{command}'. Use 'check' or 'write'.")
        sys.exit(1)

if __name__ == "__main__":
    main()