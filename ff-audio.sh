# create high quality video from song and picture

warn ()
{
  printf '\e[36m%s\e[m\n' "$*" >&2
}

log ()
{
  unset PS4
  coproc yy (set -x; : "$@") 2>&1
  read zz <&$yy
  warn ${zz:2}
  "$@"
}

usage ()
{
  echo "Script will search the current directory for JPG file and either FLAC"
  echo "or MP3 files. It will use these files to create high quality videos."
  echo "Finally it will upload videos to YouTube."
  echo "Once you are sure environment is correct run"
  echo "$0 -f"
  exit
}

json ()
{
  read $1 < <(jq -r $2 jq.json)
}

metadata ()
{
  ss=$1
  tt=${ss%.*}.txt
  log fpcalc "$ss" | sed '1d' > fp.sh
  . fp.sh
  rm fp.sh
  set "client=8XaBELgH&duration=${DURATION}&fingerprint=${FINGERPRINT}"
  wget -qO jq.json "api.acoustid.org/v2/lookup?meta=recordings+releaseids&${1}"
  json title '.results[0].recordings[0].title'
  json id '.results[0].recordings[0].releases[0].id'
  if ! [[ $album ]]
  then
    set 'fmt=json&inc=artist-credits+labels'
    log wget -qO jq.json "musicbrainz.org/ws/2/release/${id}?${1}"
    json album '.title'
    json artist '.["artist-credit"][0].name'
    json label '.["label-info"][0].label.name'
    json date '.date'
  fi
  rm -f jq.json "$tt"
  echo "Title: $title" >> "$tt"
  echo "Album: $album" >> "$tt"
  echo "Artist: $artist" >> "$tt"
  echo "Label: $label" >> "$tt"
  echo "Date: $date" >> "$tt"
  cat "$tt"
  warn 'enter "y" if metadata is ok'
  read uu
  [ $uu ] || exit
  titles[$ss]=$title
}

[ $1 ] || usage
if ! read img < <(find -name '*.jpg')
then
  echo no jpg found
  exit
fi

mapfile -t songs < <(find -name '*.flac' -o -name '*.mp3')
declare -A titles

for song in "${songs[@]}"
do
  metadata "$song"
done

for song in "${songs[@]}"
do
  mp3gain -s d "$song"
  video=${song%.*}.mp4
  meta=${song%.*}.txt
  ffprobe -v warning -show_format -print_format flat=s=_ "$song" |
    d2u > pb.sh
  . pb.sh
  rm pb.sh
  # Adding "-preset" would only make small difference in size or speed. Make
  # sure input picture is at least 720. "-shortest" can mess up duration.
  log ffmpeg -loop 1 -r 1 -i "$img" -i "$song" -t $format_duration -qp 0 \
    -c:a aac -strict -2 -b:a 495263 -v warning -stats "$video"
  # category is case sensitive
  log google youtube post -c Music -n "${artist}, ${titles[$song]}" \
    -s "${meta}" -t "${album}, ${artist}" \
    -u svnpenn "${video}"
done