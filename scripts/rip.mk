# Part of rip-dvd - rips DVDs to h264/vorbis|ac3/mkv
# Copyright (C) 2009 Thomas Spurden
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

.SUFFIXES:

MPLAYER := mplayer
MENCODER := mencoder
MKVMERGE := mkvmerge
STATUSBARLEN := 24

DEINTERLACE_FILTER := yadif

# Define a variable called " that expands to " (a crude form of escaping)
" = "

# Build the source definition for mplayer/mencoder
SOURCE = -dvd-device $(CONFIG_SOURCE_DVD) dvd://$($(CFG_PREFIX)TITLE) $(if $(subst 0,,$(CONFIG_SOURCE_CACHE)),-cache $(CONFIG_SOURCE_CACHE)) $(if $(subst $",,$($(CFG_PREFIX)START)),-ss $($(CFG_PREFIX)START)) $(if $(subst $",,$($(CFG_PREFIX)LENGTH)),-endpos $($(CFG_PREFIX)LENGTH)) $(if $(subst $",,$($(CFG_PREFIX)CHAPTERS)),-chapter $($(CFG_PREFIX)CHAPTERS))

FIRST_AUDIO := $(firstword $($(CFG_PREFIX)AUDIOS))

# Sets up the variables for each audio target
define audio_target
ifeq ($$($$(CFG_PREFIX)AUDIO_$(1)_COPY),y)
AUDIO_TARGET_$(1) = audio-$(1).avi
ifeq ($(1),$$(FIRST_AUDIO))
AUDIO_TARGET_$(1)_TRACK = 1
else
AUDIO_TARGET_$(1)_TRACK = 0
endif
else
AUDIO_TARGET_$(1) = audio-$(1).ogg
AUDIO_TARGET_$(1)_TRACK = 0
endif
AUDIO_TARGETS += audio-$(1).lang $$(AUDIO_TARGET_$(1))
endef

AUDIO_TARGETS :=
$(foreach a,$($(CFG_PREFIX)AUDIOS),$(eval $(call audio_target,$(a))))
SUBTITLE_TARGETS = $(foreach s,$($(CFG_PREFIX)SUBTITLES),sub-$(s).idx)

ifeq ($($(CFG_PREFIX)DEINTERLACE),y)
DEINTERLACE := -vf-add $(DEINTERLACE_FILTER)
else
DEINTERLACE :=
endif

all : $(CONFIG_OUTPUT_DIR)/$($(CFG_PREFIX)OUTPUT)

identify.txt :
	@echo "  IDEN  $($(CFG_PREFIX)NAME)"
	@$(MPLAYER) $(SOURCE) -frames 0 -identify 2>&1 | grep '^ID_' > "$@.tmp"
	@mv "$@.tmp" "$@"

chapters.txt :
	@echo "  CHAP  $($(CFG_PREFIX)NAME)"
	@$(MPLAYER) $(SOURCE) -frames 0 -identify 2>&1 | sed -n 's/^CHAPTERS: //p' | \
		awk -F, '{for(i = 1; i != NF; i++) { if(i < 10) { print "CHAPTER0" i "=" $$i ".000"; print "CHAPTER0" i "NAME="; } else { print "CHAPTER" i "=" $$i ".000"; print "CHAPTER" i "NAME="; } }}' > "$@.tmp"
	@mv "$@.tmp" "$@"

autocrop.txt :
	@echo "CROP   $($(CFG_PREFIX)NAME)"
ifeq ($(subst $",,$($(CFG_PREFIX)VIDEO_CROP)),)
	@while :; do echo "seek 300"; sleep 2; done \
		| $(MPLAYER) $(SOURCE) -vf cropdetect -vo null -nosound -slave -benchmark 2>&1 \
		| mclean -n > "$@.tmp"
	@mv "$@.tmp" "$@"
else
	@echo -n $($(CFG_PREFIX)VIDEO_CROP) > "$@"
endif

video.avi : autocrop.txt
	@echo "VIDEO   $($(CFG_PREFIX)NAME)"
	@$(MENCODER) $(SOURCE) -ovc x264 -oac copy $(if $(FIRST_AUDIO),-aid $(FIRST_AUDIO)) \
		-x264encopts crf=$($(CFG_PREFIX)VIDEO_CRF):frameref=6:bframes=4:b_adapt:b_pyramid:direct_pred=auto:partitions=all:8x8dct:me=umh:subq=7:weight_b:trellis=2:threads=$($(CFG_PREFIX)VIDEO_THREADS) \
		$(DEINTERLACE) -vf-add crop=$$(cat $^) -vf-add harddup \
		-o "$@.tmp" 2>&1 \
		| mclean -l $(STATUSBARLEN) -- "$($(CFG_PREFIX)NAME) (video)"
	@mv "$@.tmp" "$@"

audio-$(FIRST_AUDIO).avi :
	@echo "  AID $* link $($(CFG_PREFIX)NAME)"
	@ln -s video.avi "$@"

# Always rip from an avi that has been ripped with both audio & video.  This prevents AV desync due to -ss skipping to
# different places when the video is disabled
# prevent make deleting the avi
.PRECIOUS : audio-%.avi
audio-%.avi :
	@echo "  AID $* copy $($(CFG_PREFIX)NAME)"
# The crop filter greatly reduces the amount of space the avi takes up (have to use raw, copy doesnt get vfs applied)
	@$(MENCODER) $(SOURCE) -oac copy -ovc raw -vf crop=1:1 -aid $* -o "$@.tmp" 2>&1 \
		| mclean -l $(STATUSBARLEN) -- "$($(CFG_PREFIX)NAME) (AID $* copy)"
	@mv "$@.tmp" "$@"

audio-%.lang :
	@awk -F "=" '/ID_AID_$*_LANG/ { printf $$2; }' < "identify.txt" > "$@.tmp"
	@if ! test -s "$@.tmp";then echo 'und' > "$@.tmp";fi
	@mv "$@.tmp" "$@"

audio-%.ogg : audio-%.avi
	@echo "  AID $* (vorbis) $($(CFG_PREFIX)NAME)"
	@rm -f "$@.fifo"
	@mkfifo "$@.fifo"
	@$(OGGENC) -q $($(CFG_PREFIX)AUDIO_$*_QUALITY) -o "$@.tmp" "$@.fifo" 2>&1 \
		| mclean -- "$($(CFG_PREFIX)NAME) (AID $* vorbis)" &
	@$(MPLAYER) "audio-$*.avi" -hardframedrop -quiet -vo null -ao pcm:fast:file="$@.fifo" > "$@.log" 2>&1
	@mv "$@.tmp" "$@"
	@rm "$@.fifo"

# This never seemed to work quite right (A-V desync)
#audio-%.ac3 : audio-%.avi audio-%.lang
#	@echo "  AID $* (ac3) $($(CFG_PREFIX)NAME)"
#	@mencoderwrap "$($(CFG_PREFIX)NAME) (AID $* ac3)" "audio-$*.avi" -oac copy -ovc copy -of rawaudio -o "$@.tmp"
#	@mv "$@.tmp" "$@"

sub-%.idx :
	@echo "   SID $* $($(CFG_PREFIX)NAME)"
	@$(MENCODER) $(SOURCE) -ovc copy -oac copy -o /dev/null \
		-vf harddup -vobsubout "sub-$*.tmp" -sid $* 2>&1 \
		| mclean -l $(STATUSBARLEN) -- "$($(CFG_PREFIX)NAME) (SID $*)"
	@mv "sub-$*.tmp.idx" "sub-$*.idx"
	@mv "sub-$*.tmp.sub" "sub-$*.sub"
	

output.mkv : video.avi identify.txt $(if $(subst $",,$(CFG_PREFIX)GET_CHAPTERS),chapters.txt) $(SUBTITLE_TARGETS) $(AUDIO_TARGETS)
	@echo "  MUX   $($(CFG_PREFIX)NAME)"
# Ignore errors, as the subtitle ripping causes some warnings that will halt make otherwise
	@-$(MKVMERGE) -o "$@.tmp" $(if $(shell test -s chapters.txt && echo y),--chapters chapters.txt) --title "$($(CFG_PREFIX)NAME)" --noaudio video.avi \
		$(foreach aid,$($(CFG_PREFIX)AUDIOS),--language $(AUDIO_TARGET_$(aid)_TRACK):$$(cat "audio-$(aid).lang") --novideo "$(AUDIO_TARGET_$(aid))") \
		$(foreach sid,$($(CFG_PREFIX)SUBTITLES),"sub-$(sid).idx") > mux.log 2>&1
	@mv "$@.tmp" "$@"

$(CONFIG_OUTPUT_DIR)/$($(CFG_PREFIX)OUTPUT) : output.mkv
	@mv -v "$^" "$@"
