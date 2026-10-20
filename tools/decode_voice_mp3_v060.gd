extends SceneTree
func _initialize():
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var mp3=AudioStreamMP3.new();mp3.data=FileAccess.get_file_as_bytes(args[0])
	var playback=mp3.instantiate_playback();playback.start()
	var rate=AudioServer.get_mix_rate();var frames=playback.mix_audio(1,ceili((mp3.get_length()+.05)*rate));var bytes=PackedByteArray();bytes.resize(frames.size()*2)
	for i in range(frames.size()):bytes.encode_s16(i*2,roundi(clampf((frames[i].x+frames[i].y)*.5,-1,1)*32767))
	var wave=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=roundi(rate);wave.stereo=false;wave.data=bytes
	var error=wave.save_to_wav(args[1]);print("VOICE_DECODE ",args[1]," ",float(frames.size())/rate," sec");quit(0 if error==OK else 1)
