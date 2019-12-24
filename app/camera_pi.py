import io
import time
import picamera
from app.base_camera import BaseCamera


class Camera(BaseCamera):
    @staticmethod
    def frames():
        with picamera.PiCamera() as camera:
            # Configure camera
            camera.vflip = True
            camera.hflip = True

            # Let it warm up
            time.sleep(2)

            stream = io.BytesIO()
            for _ in camera.capture_continuous(
                stream,
                'jpeg',
                use_video_port=True
            ):
                # Return current frame
                stream.seek(0)
                yield stream.read()

                # Reset stream for next frame
                stream.seek(0)
                stream.truncate()
