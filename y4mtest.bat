ffmpeg -i "input.mp4" -map 0:v -r 23.976 -pix_fmt yuv420p -s qcif output.y4m
pause