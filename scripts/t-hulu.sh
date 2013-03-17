# test for hulu.sh

warn ()
{
  printf '\e[36m%s\e[m\n' "$*"
}

log ()
{
  unset PS4
  coproc yy (set -x; : "$@") 2>&1
  read zz <&$yy
  warn ${zz:2}
  "$@"
}

for aa in {1..10}
do
  printf '\ntry %s\n' $aa
  log sleep 50
  timeout 20 hulu.sh limelight 1000_h264 hulu.com/watch/441271
done
