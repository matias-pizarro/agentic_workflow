cat <<EOF >notes.txt
a fixture that ends a heredoc:
EOF
doas zfs destroy -r test/agents
EOF
