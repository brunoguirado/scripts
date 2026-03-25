#!/bin/bash

# --- Configuration ---
OLD_USER=$1
NEW_USER=$2

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Argument validation
if [ -z "$OLD_USER" ] || [ -z "$NEW_USER" ]; then
  echo "Usage: ./user-rename.sh <old_username> <new_username>"
  exit 1
fi

echo "--- Renaming User from $OLD_USER to $NEW_USER ---"

# 1. Existence Checks
if ! id "$OLD_USER" > /dev/null 2>&1; then
  echo "Error: User $OLD_USER does not exist."
  exit 1
fi

if id "$NEW_USER" > /dev/null 2>&1; then
  echo "Error: User $NEW_USER already exists."
  exit 1
fi

# 2. Check for active processes
if pgrep -u "$OLD_USER" > /dev/null; then
  echo "Warning: User $OLD_USER has active processes. usermod might fail."
  echo "Active PIDs: $(pgrep -u "$OLD_USER" | xargs)"
  # We let usermod try, but it will likely fail if processes are active.
fi

# 3. Rename Login
echo "Renaming login name..."
if usermod -l "$NEW_USER" "$OLD_USER"; then
  echo "Login name updated to $NEW_USER."
else
  echo "Error: Failed to rename login name. Ensure the user is not logged in."
  exit 1
fi

# 4. Rename Primary Group
# Check if a group with the old name exists
if getent group "$OLD_USER" >/dev/null; then
  echo "Renaming primary group..."
  groupmod -n "$NEW_USER" "$OLD_USER"
  echo "Group name updated to $NEW_USER."
fi

# 5. Move Home Directory
# Note: usermod -l đã đổi tên user trong /etc/passwd, nên bây giờ ta dùng NEW_USER
echo "Moving home directory to /home/$NEW_USER..."
if usermod -d "/home/$NEW_USER" -m "$NEW_USER"; then
  echo "Home directory moved and updated in /etc/passwd."
else
  echo "Error: Failed to move home directory."
  exit 1
fi

# 6. Fix Permissions (Ensuring Ownership)
echo "Ensuring correct ownership and permissions..."
chown -R "$NEW_USER":"$NEW_USER" "/home/$NEW_USER"
chmod 755 "/home/$NEW_USER"

echo "--- Renaming Complete ---"
echo "Old user: $OLD_USER (Renamed)"
echo "New user: $NEW_USER"
echo "Home: /home/$NEW_USER"
echo "Login test: ssh $NEW_USER@<ip>"
