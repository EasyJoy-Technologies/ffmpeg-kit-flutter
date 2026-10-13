#!/usr/bin/env bash
# Generates the synthetic part of the test corpus into "$1".
# Needs a full-featured ffmpeg on PATH (Debian 13 ffmpeg 7.1 was used: it has libmp3lame/libopus/
# libvorbis/libspeex/libgsm and many native encoders). Bytes depend on that ffmpeg, which is fine:
# the corpus is only ever compared build-against-build on the same files (see MANIFEST.tsv).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out=$1; mkdir -p "$out"; cd "$out"
F="ffmpeg -nostdin -hide_banner -loglevel error -y"
A="-f lavfi -i sine=frequency=440:sample_rate=44100:duration=6 -f lavfi -i sine=frequency=660:sample_rate=44100:duration=6 -filter_complex [0][1]amerge=inputs=2[a] -map [a]"
A6="-f lavfi -i sine=frequency=220:sample_rate=48000:duration=4 -filter_complex [0]asplit=6[a][b][c][d][e][f];[a][b][c][d][e][f]amerge=inputs=6,aformat=channel_layouts=5.1[o] -map [o]"
V="-f lavfi -i testsrc2=size=320x240:rate=25:duration=6"
AV="-f lavfi -i sine=frequency=440:sample_rate=44100:duration=6 -f lavfi -i sine=frequency=660:sample_rate=44100:duration=6 -filter_complex [1][2]amerge=inputs=2[a] -map 0:v -map [a]"

$F -f lavfi -i testsrc2=size=300x300:duration=0.04 -frames:v 1 cover.jpg

# --- common audio formats ---
$F $A -metadata title="测试 标题 Title" -c:a libmp3lame -b:a 128k a_cbr.mp3
$F $A -c:a libmp3lame -q:a 4 a_vbr.mp3
$F -i a_cbr.mp3 -i cover.jpg -map 0 -map 1 -c copy -id3v2_version 3 -metadata:s:v title=cover -disposition:v attached_pic a_cover.mp3
$F $A -metadata title="中文标题 ID3v2.4" -metadata artist="歌手" -id3v2_version 4 -c:a libmp3lame -b:a 96k a_id3v24_zh.mp3
cp a_cbr.mp3 a_noext
cp a_cbr.mp3 A_UPPER.MP3
$F $A -c:a aac -b:a 128k -metadata title="m4a title" a_aac.m4a
$F -i a_aac.m4a -i cover.jpg -map 0 -map 1 -c copy -disposition:v:0 attached_pic a_cover.m4a
$F $A -c:a aac -f adts a_adts.aac
$F $A -c:a alac a_alac.m4a
$F $A -c:a pcm_s16le a_s16.wav
$F $A -c:a pcm_s24le a_s24.wav
$F $A -c:a pcm_f32le a_f32.wav
$F $A -ac 1 -ar 8000 -c:a pcm_mulaw a_mulaw.wav
$F $A -ac 1 -c:a adpcm_ima_wav a_ima.wav
$F $A -ac 1 -c:a adpcm_ms a_msadpcm.wav
$F $A -ac 1 -ar 8000 -c:a g726 a_g726.wav
$F $A -c:a pcm_s16be a_aiff.aiff
$F $A -c:a pcm_s24be a_aiff24.aif
$F $A -c:a pcm_s16be a_caf.caf
$F $A -c:a adpcm_ima_qt a_imaqt.caf
$F $A -c:a flac a_flac.flac
$F -f lavfi -i "sine=frequency=1000:sample_rate=96000:duration=5" -ac 2 -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 a_flac_24_96.flac
$F -i a_flac.flac -i cover.jpg -map 0 -map 1 -c copy -disposition:v attached_pic a_cover.flac
$F $A -c:a libvorbis a_vorbis.ogg
$F $A6 -c:a libvorbis a_vorbis_51.ogg
$F $A -c:a libopus a_opus.opus
$F $A6 -c:a libopus -mapping_family 1 a_opus_51.opus
$F $A -c:a libopus a_opus.webm
$F $A -c:a libopus a_opus.mka
# Ogg cover art = FLAC picture block in a METADATA_BLOCK_PICTURE comment (the ogg muxer cannot write it)
pic=$(python3 "$here/gen_special.py" --picture-block cover.jpg)
$F -i a_opus.opus -c copy -metadata METADATA_BLOCK_PICTURE="$pic" a_cover.opus
$F -i a_vorbis.ogg -c copy -metadata METADATA_BLOCK_PICTURE="$pic" a_cover.ogg
$F $A -c:a wmav1 a_wma1.wma
$F $A -c:a wmav2 a_wma2.wma
$F $A -c:a ac3 a_ac3.ac3
$F $A -c:a eac3 a_eac3.eac3
$F $A -strict -2 -c:a dca a_dts.dts
$F $A -c:a mp2 a_mp2.mp2
$F $A -c:a tta a_tta.tta
$F $A -c:a wavpack a_wv.wv
$F $A -c:a wavpack -metadata title="APE 标签标题" -metadata artist="歌手" a_wv_apetag_zh.wv
$F $A -c:a mlp -strict -2 a_mlp.mlp
$F -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=6" -ac 2 -c:a truehd -strict -2 a_truehd.thd
$F $A -ac 1 -ar 16000 -c:a g722 a_g722.wav
$F $A -ac 1 -ar 8000 -c:a libgsm a_gsm.gsm
$F $A -ac 1 -c:a libspeex -ar 16000 a_speex.spx
$F $A -c:a pcm_s16be -f au a_au.au
$F $A -ac 1 -ar 8000 -c:a pcm_mulaw -f au a_mulaw.au
$F $A -f s16le -c:a pcm_s16le a_raw.pcm
$F $A -c:a pcm_s16le -f w64 a_w64.w64
$F $A -c:a aac a_3gp.3gp
$F $A -ac 1 -ar 22050 -c:a nellymoser a_nelly.flv
$F $A -ac 1 -ar 22050 -c:a adpcm_swf a_swfadpcm.flv
$F $A -ac 1 -ar 22050 -c:a adpcm_yamaha -f mmf a_yamaha.mmf
$F $A -c:a adpcm_adx a_adx.adx
$F $A -ac 1 -ar 8000 -c:a real_144 a_ra144.ra
$F $A -c:a aptx -f aptx a_aptx.aptx
$F $A -c:a sbc -f sbc a_sbc.sbc
$F $A -ac 1 -ar 48000 -c:a dfpwm -f dfpwm a_dfpwm.dfpwm
$F $A -ac 1 -ar 22050 -c:a pcm_u8 -f voc a_voc.voc
$F $A -c:a s302m -strict -2 -ar 48000 -f mpegts a_s302m.ts

# long file: 2 hours, mono 8 kHz mp3 (duration scan / seek behaviour)
$F -f lavfi -i "sine=frequency=300:sample_rate=8000:duration=7200" -c:a libmp3lame -b:a 8k a_long_2h.mp3

# --- video containers (NiceNote must reject real video; cover art is not video) ---
$F $V $AV -c:v libx264 -preset ultrafast -c:a aac v_h264_aac.mp4
$F $V $AV -c:v libx264 -preset ultrafast -c:a aac v_h264_aac.mov
$F $V $AV -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -c:a libopus v_vp9_opus.mkv
$F $V $AV -c:v libvpx -deadline realtime -cpu-used 8 -c:a libvorbis v_vp8_vorbis.webm
$F $V $AV -c:v mpeg4 -c:a libmp3lame v_mpeg4_mp3.avi
$F $V $AV -c:v libx264 -preset ultrafast -c:a aac v_h264_aac.flv
$F $V $AV -c:v libx264 -preset ultrafast -c:a aac v_h264_aac.ts
$F $V $AV -c:v mpeg2video -c:a mp2 v_mpeg2_mp2.mpg
$F $V $AV -c:v wmv2 -c:a wmav2 v_wmv2_wma.wmv
$F $V $AV -c:v h263 -s 352x288 -ac 1 -ar 8000 -c:a aac v_h263_aac.3gp
$F $V $AV -c:v libx264 -preset ultrafast -c:a ac3 v_h264_ac3.mkv
$F $V -i a_aac.m4a -i a_ac3.ac3 -map 0:v -map 1:a -map 2:a -c:v libx264 -preset ultrafast -c:a copy v_2audio.mp4
$F $V -c:v libx264 -preset ultrafast v_noaudio.mp4

# --- broken / edge files ---
: > e_empty.mp3
head -c 20000 a_aac.m4a > e_trunc_moov_missing.m4a
head -c 30000 a_cbr.mp3 > e_trunc.mp3

# --- non-audio files (what ffprobe says about them must not change) ---
printf 'NiceNote 测试文本\nline 2\n' > n_text.txt
printf '%%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%%%EOF\n' > n_doc.pdf
$F -f lavfi -i testsrc2=size=64x64:duration=0.04 -frames:v 1 n_img.png
cp cover.jpg n_img.jpg
python3 - <<'PY'
import zipfile
with zipfile.ZipFile("n_archive.zip", "w") as z: z.writestr("a.txt", "hello")
PY

python3 "$here/gen_special.py" "$out"
echo GEN_OK
