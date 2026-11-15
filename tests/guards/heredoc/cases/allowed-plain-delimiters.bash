cat <<MSG >a.txt
first
MSG
	cat <<-END >b.txt
	second
	END
cat << "DONE_2" >c.txt
third
DONE_2
cat <<'_eof' >d.txt
fourth
_eof
