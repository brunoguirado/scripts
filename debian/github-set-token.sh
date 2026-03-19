#!/usr/bin/env bash

# 1. Ask for Name and Email
echo "--------------------------------------------------------"
echo "  GITHUB USER & TOKEN SETUP SCRIPT"
echo "--------------------------------------------------------"
read -p "Enter your Name: " GIT_NAME
read -p "Enter your Email: " GIT_EMAIL

# 2. Configure Git name and email globally
echo "Configuring Git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# 3. Ask for the token (it won't show while you type/paste for security)
read -sp "Paste your GitHub Token and press Enter: " GITHUB_TOKEN
echo -e "\n"

# Check if token was actually provided
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: You didn't paste a token. Run the script again!"
    exit 1
fi

# 4. Identify the current repository owner and name
REMOTE_URL=$(git remote get-url origin)
# Strip username/token part to get a clean URL
CLEAN_URL=$(echo "$REMOTE_URL" | sed 's|https://[^@]*@||' | sed 's|https://||')

# 5. Create the new URL with the token injected
NEW_URL="https://${GITHUB_TOKEN}@${CLEAN_URL}"

# 6. Update the Git remote
git remote set-url origin "$NEW_URL"

# 7. Verify it's actually working
echo "Checking connection... (this might take a second)"
if git ls-remote origin > /dev/null 2>&1; then
    echo "✅ Success! Name, email and token are now stored."
    echo "   You can now run 'git push' without typing anything."
    echo ""
    echo "Current Git Config:"
    git config --global -l | grep -E "user.name|user.email"
else
    echo "❌ Error: Could not connect to GitHub. Please check your token or internet."
    # Reverting to the clean URL if it failed
    git remote set-url origin "https://${CLEAN_URL}"
fi
