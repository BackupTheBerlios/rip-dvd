.SUFFIXES:

" = "
SOURCE = -dvd-device $(CONFIG_SOURCE_DVD) dvd://$(CURTITLE) -cache $(CONFIG_SOURCE_CACHE) $(if $(subst $",,$($(CFG_PREFIX)START)),-ss $($(CFG_PREFIX)START)) $(if $(subst $",,$($(CFG_PREFIX)LENGTH)),-endpos $($(CFG_PREFIX)LENGTH))

AUDIO_TARGETS = $(foreach a,$($(CFG_PREFIX)AUDIOS),$(if $($(CFG_PREFIX)AUDIO_$(a)_COPY),audio-$(a).ac3,audio-$(a).ogg))
SUBTITLE_TARGETS = $(foreach s,$($(CFG_PREFIX)SUBTITLES),sub-$(s).idx)

ifeq ($($(CFG_PREFIX)DEINTERLACE),y)
DEINTERLACE := -vf-add pp=lb
else
DEINTERLACE :=
endif

all : $(CONFIG_OUTPUT_DIR)/$($(CFG_PREFIX)OUTPUT)

identify.txt :
	@echo "  IDEN  $($(CFG_PREFIX)NAME)"
	@mplayer $(SOURCE) -frames 0 -identify 2>&1 | grep '^ID_' > "$@.tmp"
	@mv "$@.tmp" "$@"

chapters.txt :
	@echo "  CHAP  $($(CFG_PREFIX)NAME)"
	@mplayer $(SOURCE) -frames 0 -identify 2>&1 | sed -n 's/^CHAPTERS: //p' | \
		awk -F, '{for(i = 1; i != NF; i++) { if(i < 10) { print "CHAPTER0" i "=" $$i ".000"; print "CHAPTER0" i "NAME="; } else { print "CHAPTER" i "=" $$i ".000"; print "CHAPTER" i "NAME="; } }}' > "$@.tmp"
	@mv "$@.tmp" "$@"

autocrop.txt :
	@echo "CROP   $($(CFG_PREFIX)NAME)"
ifeq ($(subst $",,$($(CFG_PREFIX)VIDEO_CROP)),)
	@mkcrop $(SOURCE) > "$@.tmp"
	@mv "$@.tmp" "$@"
else
	@echo -n $($(CFG_PREFIX)VIDEO_CROP) > "$@"
endif

video.avi : autocrop.txt
	@echo "VIDEO   $($(CFG_PREFIX)NAME)"
	@mencoderwrap "$($(CFG_PREFIX)NAME) (video)" $(SOURCE) -ovc x264 -oac copy \
		-x264encopts crf=$($(CFG_PREFIX)VIDEO_CRF):frameref=6:bframes=4:b_adapt:b_pyramid:direct_pred=auto:partitions=all:8x8dct:me=umh:subq=7:weight_b:brdo:bime:trellis=2:threads=$($(CFG_PREFIX)VIDEO_THREADS) \
		-vf-add crop=$$(cat $^) $(DEINTERLACE) \
		-vf-add harddup \
		-o "$@"
audio-%.ogg :
	@echo "  AID $* (vorbis) $($(CFG_PREFIX)NAME)"
	@rm -f "$@.fifo"
	@mkfifo "$@.fifo"
	@awk -F "=" '/ID_AID_$*_LANG/ { printf $$2; }' < "identify.txt" > "audio-$*.lang"
	@oggencwrap "$($(CFG_PREFIX)NAME) (AID $* vorbis)" -q $($(CFG_PREFIX)AUDIO_$*_QUALITY) -o "$@.tmp" "$@.fifo" &
	@mplayer $(SOURCE) -hardframedrop -quiet -aid $* -vo null -ao pcm:fast:file="$@.fifo" > "$@.log" 2>&1
	@mv "$@.tmp" "$@"
	@rm "$@.fifo"

audio-%.ac3 :
	@echo "  AID $* (ac3) $($(CFG_PREFIX)NAME)"
	@mencoderwrap "$($(CFG_PREFIX)NAME) (AID $* ac3)" $(SOURCE) -oac copy -ovc copy -of rawaudio -aid $* -o "$@.tmp"
	@mv "$@.tmp" "$@"

sub-%.idx :
	@echo "   SID $* $($(CFG_PREFIX)NAME)"
	@mencoderwrap "$($(CFG_PREFIX)NAME) (SID $*)" $(SOURCE) -ovc copy -oac copy -o /dev/null \
		-vf harddup -vobsubout "sub-$*.tmp" -sid $*
	@mv "sub-$*.tmp.idx" "sub-$*.idx"
	@mv "sub-$*.tmp.sub" "sub-$*.sub"
	

output.mkv : identify.txt chapters.txt $(SUBTITLE_TARGETS) $(AUDIO_TARGETS) video.avi
	@echo $^
	@echo "  MUX   $($(CFG_PREFIX)NAME)"
	@-mkvmerge -o "$@.tmp" --chapters chapters.txt --title "$($(CFG_PREFIX)NAME)" -A video.avi \
		$(foreach aid,$($(CFG_PREFIX)AUDIOS),--language 0:$$(cat "audio-$(aid).lang") "audio-$(aid).ogg") \
		$(foreach sid,$($(CFG_PREFIX)SUBTITLES),"sub-$(sid).idx") > mux.log 2>&1
	@mv "$@.tmp" "$@"

$(CONFIG_OUTPUT_DIR)/$($(CFG_PREFIX)OUTPUT) : output.mkv
	@mv -v "$^" "$@"
