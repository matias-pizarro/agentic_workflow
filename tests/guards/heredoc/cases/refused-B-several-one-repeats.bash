cat <<'A' >a.txt
first
A
cat <<'B' >b.txt
second
B
zfs create -p test/agents/resources
B
