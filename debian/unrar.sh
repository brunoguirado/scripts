# 1. Create a specific list file for the non-free repository to avoid messing with your main sources
echo "deb http://deb.debian.org/debian bookworm non-free" > /etc/apt/sources.list.d/non-free.list

# 2. Update the package lists to recognize the new proprietary repository
apt update

# 3. Install the official, proprietary unrar package (not unrar-free)
apt install unrar -y

# 4. Extract the file using the official tool (it reads the header natively, ignoring the .zip extension)
unrar e -y FILE.rar ./output