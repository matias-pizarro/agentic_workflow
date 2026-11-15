python3 - <<'EOF'
import re
p='tests/live/test_on_host.sh'
s=open(p).read()
s=s.replace("""marker /usr/local/etc/doas.conf permit nopass tester
dataset test/agents
""","""marker /usr/local/etc/doas.conf permit nopass tester
host-user guest
marker /usr/local/etc/doas.conf permit nopass guest
dataset test/agents
""",1)
s=s.replace("""file $profile/.pi/agent/auth.json
EOF
""","""file $profile/.pi/agent/auth.json
dataset test/agents/resources
EOF
""",1)
s=s.replace("""permit nopass tester
EOF
prepare-host: creating the dataset test/agents
""","""permit nopass tester
EOF
prepare-host: creating the user guest
pw useradd guest -m -s /bin/sh -c 'live-test guest'
prepare-host: letting guest run doas without a password
tee -a /usr/local/etc/doas.conf >/dev/null <<'EOF'
permit nopass guest
EOF
prepare-host: creating the dataset test/agents
""",1)
s=s.replace("""chmod 600 $p/.pi/agent/auth.json
EXPECTED
""","""chmod 600 $p/.pi/agent/auth.json
prepare-host: creating the dataset test/agents/resources
zfs create -p test/agents/resources
EXPECTED
""",1)
open(p,'w').write(s)
EOF
git diff --stat; lib/test_jail sh tests/live/test_on_host.sh 2>&1 | tail -30"
