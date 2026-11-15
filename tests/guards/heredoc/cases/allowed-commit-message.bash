git commit -F - <<'EOF'
fix: refuse a heredoc whose delimiter repeats

A body that ends its heredoc early lets bash run the rest as shell.
EOF
