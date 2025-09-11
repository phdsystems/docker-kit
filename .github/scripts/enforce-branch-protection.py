#!/usr/bin/env python3
"""
Branch Protection Enforcement Script
This script runs in GitHub Actions to enforce branch protection rules
even without GitHub Pro.
"""

import os
import sys
import json
import subprocess
from datetime import datetime

# Protected branches configuration
PROTECTED_BRANCHES = {
    "main": {"priority": 1, "parent": None},
    "prd": {"priority": 2, "parent": "main"},
    "rc": {"priority": 3, "parent": "prd"},
    "staging": {"priority": 4, "parent": "rc"},
    "int": {"priority": 5, "parent": "staging"},
    "dev": {"priority": 6, "parent": "int"},
}

def run_git_command(cmd):
    """Execute a git command and return output."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")
        return None

def check_branch_exists(branch):
    """Check if a branch exists on remote."""
    result = run_git_command(f"git ls-remote --heads origin {branch}")
    return bool(result)

def get_branch_history(branch, limit=10):
    """Get recent commits from a branch."""
    return run_git_command(f"git log origin/{branch} --oneline -n {limit}")

def find_branch_in_reflog(branch):
    """Try to find deleted branch in reflog."""
    result = run_git_command(f"git reflog show --all | grep 'refs/remotes/origin/{branch}'")
    if result:
        # Extract the commit hash
        return result.split()[0]
    return None

def restore_branch(branch, commit_hash):
    """Restore a deleted branch from a commit."""
    print(f"🔄 Restoring branch '{branch}' from commit {commit_hash}")
    
    # Create a temporary branch from the commit
    run_git_command(f"git checkout -b temp-restore-{branch} {commit_hash}")
    
    # Push it as the protected branch
    result = run_git_command(f"git push origin temp-restore-{branch}:{branch}")
    
    # Clean up
    run_git_command(f"git checkout main")
    run_git_command(f"git branch -D temp-restore-{branch}")
    
    return result is not None

def create_github_issue(title, body):
    """Create a GitHub issue using gh CLI."""
    # This would need GH_TOKEN to be set
    cmd = f'''gh issue create --title "{title}" --body "{body}" --label "security,automated"'''
    return run_git_command(cmd)

def enforce_protection():
    """Main enforcement logic."""
    violations = []
    restored = []
    
    print("🛡️ Enforcing branch protection rules...")
    print(f"📅 Check time: {datetime.now().isoformat()}")
    
    # Check each protected branch
    for branch, config in PROTECTED_BRANCHES.items():
        print(f"\n🔍 Checking branch: {branch}")
        
        if check_branch_exists(branch):
            print(f"  ✅ Branch exists")
            
            # Additional checks could go here (force push detection, etc.)
            
        else:
            print(f"  ❌ Branch is MISSING!")
            violations.append(f"Branch '{branch}' deleted")
            
            # Try to restore from reflog
            last_commit = find_branch_in_reflog(branch)
            if last_commit:
                print(f"  📌 Found last commit: {last_commit}")
                if restore_branch(branch, last_commit):
                    print(f"  ✅ Branch restored successfully!")
                    restored.append(branch)
                else:
                    print(f"  ❌ Failed to restore branch")
            else:
                print(f"  ❌ Could not find branch in reflog")
                
                # Try to restore from parent branch
                if config["parent"] and check_branch_exists(config["parent"]):
                    print(f"  🔄 Attempting to restore from parent '{config['parent']}'")
                    parent_head = run_git_command(f"git rev-parse origin/{config['parent']}")
                    if parent_head and restore_branch(branch, parent_head):
                        print(f"  ✅ Branch restored from parent!")
                        restored.append(branch)
    
    # Report results
    print("\n" + "="*50)
    print("📊 ENFORCEMENT SUMMARY")
    print("="*50)
    
    if violations:
        print(f"❌ Violations found: {len(violations)}")
        for v in violations:
            print(f"  - {v}")
    else:
        print("✅ No violations found")
    
    if restored:
        print(f"🔄 Branches restored: {len(restored)}")
        for r in restored:
            print(f"  - {r}")
    
    # Create issue if there were violations
    if violations:
        issue_title = f"🚨 Branch Protection Violations Detected ({len(violations)})"
        issue_body = f"""
## Branch Protection Report

**Time**: {datetime.now().isoformat()}
**Violations**: {len(violations)}
**Restored**: {len(restored)}

### Violations Detected:
{chr(10).join(f'- {v}' for v in violations)}

### Branches Restored:
{chr(10).join(f'- ✅ {r}' for r in restored) if restored else 'None'}

### Action Required:
1. Review the violations
2. Check user permissions
3. Verify branch integrity
"""
        create_github_issue(issue_title, issue_body)
        
        # Exit with error to fail the workflow
        sys.exit(1)
    
    print("\n✅ All protected branches are intact!")
    return 0

if __name__ == "__main__":
    # Fetch all branches first
    run_git_command("git fetch --all --prune")
    
    # Run enforcement
    sys.exit(enforce_protection())