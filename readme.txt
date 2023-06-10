Uncompressed* Audio and Video playback on DE10-lite MAX10 FPGA board.
Requires an arduino shield with microSD slot via SPI.
(UIUC ECE385 SP23 final project)

HOW TO USE THIS PROJECT
Compile and run with Quartus Prime Lite 18.1.
Simply open FP-ZUOFU-BASIC.qsf and compile. "player_toplevel" should be top level.
Program the FPGA, no eclipse needed because no NIOS. (Custom I2C module inits the SGTL5000!)

Load in your SDcard and hit reset. Enjoy!

Controls:
- KEY0 is reset/reload. Press this button if you change out the SDcard or switch between audio and video modes (SW9).
   - The FPGA will first buffer half of the SDRAM, and then begin playback. The rest is loaded while playing.
   - While buffering, HEX5:HEX0 will display the address being buffered to. 
- KEY1 is volume adjust. It adjusts volume circularly, and works by writing to the SGTL's registers.
- SW1: set 1 to listen to audio playback, set 0 to listen to audio passthru from line in. 
- SW9: set 1 to play y4m video, set 0 to play wav audio.

Outputs:
- LEDR 9,8 indicate SDcard buffer load status. When both lit, the SDCard has stopped writing to buffer since it's half is done.
    - If only LEDR9 is on, this indicates that the buffer has been overrun, and the video playback will probably loop in a bit.
    - This is because the ping-pong buffer only allows writes to the half that reads are NOT being read from.
- LEDR 7,6 are debug indicators for video playback.

Loading a file to SDCARD
- Make sure you are using an SDHC card.
- Download and install HXD - run it as administrator (following step may fail otherwise)
- Open the SDcard as a RAW DISK (tools, open disk, physical disks - uncheck readonly)

VIDEO: Use the .bat file included. Needs FFMPEG, available online.
- Open the output.y4m in HxD
- CTRL-A the contents of output.y4m, paste it to the SDCard at address 0.
- Copy starting from the first "FRAME" of output.y4m, and paste it starting at address 0x59.
   - "F" of "FRAME" should be at 0x59.
   - Playback will work if you do not do this step (my code is flexible), 
      but the SDRAM ping-pong buffer may run erratically and fail to buffer in time.
      - The SDCARD throughput bottleneck is real!
      - My guess is that the SDcard's delays when moving from one block to the next happen to occur
        at lucky times when starting from 0x59, while starting anywhere else leads to unlucky delay timing 
        that ultimately results in not refilling the buffer in time. 
- Ctrl-S to save to the SDcard - this may take a while.
- Eject the card, put it in the FPGA, set SW9 to 1, hit reset, enjoy.
- Slow SDcards may not be fast enough for video playback even with the 0x59 start. 
- SANDISK EXTREME 32GB were our card of choice, but they were only barely just fast enough.
    - Old SANDISK 32GB ULTRA PLUS was ever so slightly too slow for video, but plenty fast for audio.
HEX0 will show format being detected:
- 4: y4m (YUV420P, 176x144 @ 24fps)
- 1: H.261 (incomplete/inoperable, sadly)
HEX5:HEX1 will show the current leftmost contents of the playback shift-register.

AUDIO: Open your desired file in Audacity, export in one of 3 WAV formats @ 44.1khz:
- 16bit signed PCM
- "U-law" (8bits mapping to 14bits)
- "A-law" (8bits mapping to 13bits)

- Open the file in HxD
- Ctrl-A the contents and paste it to SDCARD at address 0.
(No special offsets needed here - audio bitrate is low and forgiving.)
- Ctrl-S to save the contents to the card. This may take a moment.
- Eject the card, put it in the FPGA, set sw9 to 0, hit reset, enjoy. Plug in VGA for visualizer!
- FPGA auto-detects the playback format. 
HEX0 will show what it's detecting:
- 1: 16-bit signed PCM (stereo)
- 2: U-law (stereo)
- A: A-law (stereo)
HEX5:HEX1 will show what the current playback address[23:4] in memory is.

.VOX VOX ADPCM and MONO IMA-ADPCM in WAV are both experimental and very rough support. 
Playback amplitude erratic but the sound is identifiable.