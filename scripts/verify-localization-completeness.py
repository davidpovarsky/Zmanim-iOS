#!/usr/bin/env python3
import os
import re
import sys

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    
    he_path = os.path.join(repo_root, "Resources", "he.lproj", "Localizable.strings")
    en_path = os.path.join(repo_root, "Resources", "en.lproj", "Localizable.strings")
    
    if not os.path.exists(he_path) or not os.path.exists(en_path):
        print(f"ERROR: Localizable.strings not found in Resources!", file=sys.stderr)
        sys.exit(1)
        
    key_pattern = re.compile(r'^\s*"([^"]+)"\s*=\s*"')
    
    def extract_keys(path):
        keys = set()
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                m = key_pattern.match(line)
                if m:
                    keys.add(m.group(1))
        return keys
        
    he_keys = extract_keys(he_path)
    en_keys = extract_keys(en_path)
    
    he_minus_en = sorted(list(he_keys - en_keys))
    en_minus_he = sorted(list(en_keys - he_keys))
    
    if he_minus_en:
        print(f"ERROR: Keys in Hebrew but missing in English: {he_minus_en}", file=sys.stderr)
        sys.exit(1)
        
    if en_minus_he:
        print(f"ERROR: Keys in English but missing in Hebrew: {en_minus_he}", file=sys.stderr)
        sys.exit(1)
        
    print(f"[OK] Key sets match perfectly! Total keys: {len(he_keys)}")
    
    # Check for forbidden fallbacks in Sources
    sources_dir = os.path.join(repo_root, "Sources")
    ns_value_pattern = re.compile(r'NSLocalizedString\(\s*"[^"]+"\s*,\s*value:')
    ls_default_pattern = re.compile(r'LocalizedStringResource\(\s*"[^"]+"\s*,\s*defaultValue:\s*"')
    
    code_keys_pattern = re.compile(r'NSLocalizedString\(\s*"([^"]+)"')
    intent_keys_pattern = re.compile(r'LocalizedStringResource\(\s*"([^"]+)"')
    
    missing_keys = set()
    forbidden_fallbacks = []
    
    for root, _, files in os.walk(sources_dir):
        for file in files:
            if not file.endswith(".swift"):
                continue
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                
            if ns_value_pattern.search(content):
                forbidden_fallbacks.append(f"{path}: NSLocalizedString with value:")
            if ls_default_pattern.search(content):
                forbidden_fallbacks.append(f"{path}: LocalizedStringResource with defaultValue:")
                
            for k in code_keys_pattern.findall(content):
                if k not in he_keys:
                    missing_keys.add((k, path))
            for k in intent_keys_pattern.findall(content):
                if k not in he_keys:
                    missing_keys.add((k, path))
                    
    if forbidden_fallbacks:
        print("ERROR: Forbidden fallback literals found in Sources/:", file=sys.stderr)
        for fb in forbidden_fallbacks:
            print(f"  {fb}", file=sys.stderr)
        sys.exit(1)
        
    print("[OK] Zero forbidden fallback literals found in Sources/.")
    
    if missing_keys:
        print("ERROR: Keys referenced in Sources/ are missing from Localizable.strings:", file=sys.stderr)
        for k, p in sorted(missing_keys):
            rel = os.path.relpath(p, repo_root)
            print(f"  '{k}' in {rel}", file=sys.stderr)
        sys.exit(1)
        
    print("[OK] All referenced keys exist in Localizable.strings.")
    print("=== Localization Completeness Verified Successfully ===")

if __name__ == "__main__":
    main()
