git commit -F - <<'MSG'
fix: the fixture ends its <<EOF heredoc twice

It held
EOF
and later
EOF
MSG
