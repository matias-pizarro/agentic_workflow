git commit -F - <<'EOF'
fix: refuse a heredoc whose delimiter repeats

A body that quotes `<<'EOF'` in prose names the operator but holds no
second delimiter line, so it runs.
EOF
