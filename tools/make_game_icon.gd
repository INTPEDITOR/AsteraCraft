extends SceneTree
func _initialize():
	var image=Image.load_from_file("res://assets/game_icon.png")
	var sizes=[16,24,32,48,64,128,256];var images=[]
	for size in sizes:
		var scaled=image.duplicate();scaled.resize(size,size,Image.INTERPOLATE_LANCZOS)
		if size==256:images.append(scaled.save_png_to_buffer());continue
		scaled.convert(Image.FORMAT_RGBA8)
		var rgba=scaled.get_data();var mask_stride=((size+31)/32)*4
		var dib=PackedByteArray();dib.resize(40+size*size*4+mask_stride*size)
		dib.encode_u32(0,40);dib.encode_u32(4,size);dib.encode_u32(8,size*2)
		dib.encode_u16(12,1);dib.encode_u16(14,32);dib.encode_u32(20,size*size*4)
		for y in range(size):
			for x in range(size):
				var source=((size-1-y)*size+x)*4;var dest=40+(y*size+x)*4
				dib[dest]=rgba[source+2];dib[dest+1]=rgba[source+1];dib[dest+2]=rgba[source];dib[dest+3]=rgba[source+3]
				if rgba[source+3]==0:dib[40+size*size*4+y*mask_stride+x/8]|=1<<(7-x%8)
		images.append(dib)
	var file=FileAccess.open("res://assets/game_icon.ico",FileAccess.WRITE)
	file.store_16(0);file.store_16(1);file.store_16(sizes.size())
	var offset=6+16*sizes.size()
	for i in range(sizes.size()):
		file.store_8(sizes[i]%256);file.store_8(sizes[i]%256);file.store_8(0);file.store_8(0)
		file.store_16(1);file.store_16(32);file.store_32(images[i].size());file.store_32(offset)
		offset+=images[i].size()
	for bytes in images:file.store_buffer(bytes)
	file.close();print("ICON_GENERATED 7 sizes; alpha preserved");quit()
