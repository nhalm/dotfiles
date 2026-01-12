#!/usr/bin/env python3
"""
Context7 library cache manager for docs-researcher agent.
Usage:
  # Check if library docs are cached
  python3 context7_cache.py check "/tiangolo/fastapi"
  
  # Cache entire library documentation  
  python3 context7_cache.py write "/tiangolo/fastapi" < full_docs.md
  
  # Query within cached library docs
  python3 context7_cache.py query "/tiangolo/fastapi" "websocket implementation"
"""

import sys
import json
import time
import re
from pathlib import Path

LIBRARY_CACHE_ROOT = Path.home() / ".claude" / "docs" / "context7-cache"
CACHE_EXPIRY = 7 * 24 * 60 * 60  # 7 days for libraries

def sanitize_library_id(library_id):
    """Convert Context7 library ID to safe filesystem path"""
    safe_id = library_id.lstrip('/').replace('/', '_')
    safe_id = re.sub(r'[^a-zA-Z0-9_.-]', '_', safe_id)
    return safe_id

def get_library_cache_path(library_id):
    """Get cache directory path for a Context7 library"""
    safe_id = sanitize_library_id(library_id)
    return LIBRARY_CACHE_ROOT / safe_id

def check_library_cache(library_id):
    """Check if library documentation is cached"""
    cache_dir = get_library_cache_path(library_id)
    metadata_file = cache_dir / "metadata.json"
    docs_file = cache_dir / "documentation.md"
    
    if not (metadata_file.exists() and docs_file.exists()):
        print(f"MISS: No library cache found for {library_id}")
        return False, None
    
    try:
        with open(metadata_file) as f:
            metadata = json.load(f)
        
        # Check expiry
        if time.time() > metadata.get("expiry", 0):
            print(f"EXPIRED: Library cache expired for {library_id}")
            import shutil
            shutil.rmtree(cache_dir)
            return False, None
            
        age_hours = (time.time() - metadata["timestamp"]) / 3600
        print(f"HIT: Found library cache ({age_hours:.1f}h old) for {library_id}")
        
        with open(docs_file) as f:
            docs_content = f.read()
        
        return True, docs_content
        
    except Exception as e:
        print(f"ERROR: Invalid library cache for {library_id}: {e}")
        return False, None

def write_library_cache(library_id, documentation):
    """Cache entire library documentation"""
    cache_dir = get_library_cache_path(library_id)
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    metadata = {
        "timestamp": int(time.time()),
        "expiry": int(time.time() + CACHE_EXPIRY),
        "library_id": library_id,
        "source": "Context7",
        "doc_size": len(documentation)
    }
    
    with open(cache_dir / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    with open(cache_dir / "documentation.md", "w") as f:
        f.write(documentation)
    
    print(f"✅ Cached library {library_id} ({len(documentation)} chars) at: {cache_dir}")
    return True

def query_library_cache(library_id, query):
    """Query within cached library documentation"""
    cached, docs_content = check_library_cache(library_id)
    
    if not cached:
        return False
    
    # Search for query terms within the documentation
    query_terms = query.lower().split()
    lines = docs_content.split('\n')
    
    relevant_sections = []
    context_lines = 3  # Lines before and after a match
    
    for i, line in enumerate(lines):
        line_lower = line.lower()
        # Check if any query terms are in this line
        if any(term in line_lower for term in query_terms):
            start = max(0, i - context_lines)
            end = min(len(lines), i + context_lines + 1)
            section = '\n'.join(lines[start:end])
            if section not in relevant_sections:  # Avoid duplicates
                relevant_sections.append(section)
    
    if relevant_sections:
        print(f"QUERY HIT: Found {len(relevant_sections)} relevant sections in {library_id}")
        print("SOURCE: Context7 (Cached)")
        print("---CACHED-CONTENT---")
        print("\n\n---SECTION---\n".join(relevant_sections))
        return True
    else:
        print(f"QUERY MISS: No relevant content found for '{query}' in {library_id}")
        return False

def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  context7_cache.py check '/library/id'")
        print("  context7_cache.py write '/library/id' < docs.md")
        print("  context7_cache.py query '/library/id' 'search terms'")
        sys.exit(1)
    
    command = sys.argv[1]
    library_id = sys.argv[2]
    
    if command == "check":
        cached, content = check_library_cache(library_id)
        if cached:
            print("SOURCE: Context7 (Cached)")
            print("---CACHED-CONTENT---")
            print(content)
    elif command == "write":
        documentation = sys.stdin.read().strip()
        if not documentation:
            print("ERROR: No documentation provided via stdin")
            sys.exit(1)
        write_library_cache(library_id, documentation)
    elif command == "query":
        if len(sys.argv) < 4:
            print("ERROR: Query command requires search terms")
            sys.exit(1)
        query = sys.argv[3]
        query_library_cache(library_id, query)
    else:
        print(f"ERROR: Unknown command '{command}'. Use 'check', 'write', or 'query'.")
        sys.exit(1)

if __name__ == "__main__":
    main()