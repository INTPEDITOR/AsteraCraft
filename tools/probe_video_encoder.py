import bpy
import json
import os

scene = bpy.context.scene
formats = [item.identifier for item in scene.render.image_settings.bl_rna.properties['file_format'].enum_items]
result = {'blender': bpy.app.version_string, 'formats': formats, 'ffmpeg_property': hasattr(scene.render, 'ffmpeg')}
try:
    scene.render.resolution_x = 320
    scene.render.resolution_y = 180
    scene.render.resolution_percentage = 100
    scene.render.fps = 12
    scene.frame_start = 1
    scene.frame_end = 12
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.filepath = os.path.join(os.path.dirname(__file__), '..', 'build', 'video-encoder-probe.mp4')
    scene.render.use_sequencer = True
    sequence = scene.sequence_editor_create()
    strip = sequence.strips.new_effect('encoder_probe', 'COLOR', channel=1, frame_start=1, frame_end=13)
    strip.color = (.06, .15, .22)
    bpy.ops.render.render(animation=True)
    result['encoded'] = os.path.isfile(scene.render.filepath)
    result['size'] = os.path.getsize(scene.render.filepath) if result['encoded'] else 0
except Exception as error:
    result['error'] = repr(error)
print('VIDEO_ENCODER_PROBE ' + json.dumps(result))
