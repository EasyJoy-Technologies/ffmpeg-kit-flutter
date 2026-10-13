#!/usr/bin/env bash
# Runs NiceNote's exact ffprobe/ffmpeg argument shapes over every corpus file and records results.
#   usage: run_corpus.sh <corpus-dir> <out-dir> <ffmpeg> <ffprobe> [runner...]
#   runner: optional command prefix, e.g. "qemu-aarch64" for Android static binaries.
#   env:    JOBS  files processed in parallel (default 1)
#           SKIP  regex on the corpus path; matching files are recorded as SKIPPED (used to keep the
#                 2-hour file out of the slow qemu runs — the decode path is the same as the short mp3)
# Shapes (lib/audio/probe, lib/utils/ffmpeg_utils.dart):
#   probe  FFprobeKit.getMediaInformation          scan  AudioDurationScan.scanMs
#   wav    16 kHz mono WAV (transcription input)   m4a   AAC 44.1 kHz stereo 128k (conversion)
#   pcm    s16le at source rate (enhance, mp3)     remux ADTS -> m4a (recorder finalise, .aac only)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# one_file <corpus-relative-path>: prints one tab-separated result line.
one_file() {
  local rel=$1 f n o pc probe sc scan wc_ mc dc rc=- rmd5=-
  f="$corpus/$rel"; n=${rel//\//_}; o="$out/files/$n"
  if [[ -n ${SKIP:-} && $rel =~ $SKIP ]]; then printf '%s\tSKIPPED\n' "$n"; return; fi
  # raw PCM: ffmpeg takes -ar/-ac, ffprobe only the demuxer's own option names
  local in=() pin=(); [[ $n == *.pcm ]] && in=(-f s16le -ar 44100 -ac 2) pin=(-f s16le -sample_rate 44100 -ch_layout stereo)
  "${run[@]}" "$FP" -v error -hide_banner -print_format json -show_format -show_streams -show_chapters \
    "${pin[@]}" -i "$f" > "$o.probe.json" 2> "$o.probe.err"; pc=$?
  probe=$(python3 "$here/probe_fields.py" "$o.probe.json")
  "${run[@]}" "$FF" -nostdin -v error -nostats -progress "$o.scan.prog" "${in[@]}" -i "$f" \
    -map 0:a:0 -c copy -f null - 2> "$o.scan.err"; sc=$?
  scan=$(grep -E '^out_time_us=' "$o.scan.prog" 2>/dev/null | tail -1); scan=${scan#out_time_us=}
  local common=(-nostdin -v error -y -protocol_whitelist file "${in[@]}" -i "$f" -map 0:a:0 -vn
                -map_metadata -1 -map_chapters -1)
  "${run[@]}" "$FF" "${common[@]}" -ar 16000 -ac 1 -f wav -c:a pcm_s16le "$o.wav" 2> "$o.wav.err"; wc_=$?
  "${run[@]}" "$FF" "${common[@]}" -ar 44100 -ac 2 -c:a aac -b:a 128k -movflags +faststart "$o.m4a" 2> "$o.m4a.err"; mc=$?
  "${run[@]}" "$FF" "${common[@]}" -f s16le -c:a pcm_s16le "$o.pcm" 2> "$o.pcm.err"; dc=$?
  if [[ $n == *.aac ]]; then
    "${run[@]}" "$FF" -nostdin -v error -y -f aac -i "$f" -vn -c:a copy -bsf:a aac_adtstoasc \
      -movflags +faststart -f ipod "$o.remux.m4a" 2> "$o.remux.err"; rc=$?; rmd5=$(md5 "$o.remux.m4a")
  fi
  printf '%s\tprobe=%s\t%s\tscan=%s\t%s\twav=%s\t%s\tm4a=%s\t%s\tpcm=%s\t%s\tremux=%s\t%s\n' \
    "$n" "$pc" "$probe" "$sc" "${scan:--}" "$wc_" "$(md5 "$o.wav")" "$mc" "$(md5 "$o.m4a")" \
    "$dc" "$(md5 "$o.pcm")" "$rc" "$rmd5"
}
md5() { if [[ -s $1 ]]; then md5sum < "$1" | cut -c1-12; else echo -; fi; }

if [[ ${1:-} == --one ]]; then   # internal: worker invocation from xargs
  shift; corpus=$1 out=$2 FF=$3 FP=$4; shift 4; rel=$1; shift; run=("$@")
  one_file "$rel" > "$out/files/${rel//\//_}.result"
  exit 0
fi

corpus=$1; out=$2; FF=$3; FP=$4; shift 4
rm -rf "$out"; mkdir -p "$out/files"
cut -f1 "$corpus/MANIFEST.tsv" | xargs -P "${JOBS:-1}" -I{} "$0" --one "$corpus" "$out" "$FF" "$FP" {} "$@"
# results.tsv keeps MANIFEST order
cut -f1 "$corpus/MANIFEST.tsv" | while read -r rel; do
  cat "$out/files/${rel//\//_}.result" 2>/dev/null || printf '%s\tMISSING\n' "${rel//\//_}"
done > "$out/results.tsv"
echo "run_corpus: $(grep -vc MISSING "$out/results.tsv") of $(wc -l < "$corpus/MANIFEST.tsv") files -> $out"
