# Imagine, an AI video monitoring framework

Imagine is a crystal lang web platform for AI processing and monitoring video streams.

* takes UDP H.264 video streams as input (needs to be web compatible format)
* runs frames through [TensorFlow Lite](https://tfhub.dev/s?deployment-format=lite) models
* outputs detection data to a websocket and optionally a Redis channel
  * detection coordinates only
  * optionally the PNG image (websocket only)
  * optionally the PNG image with markup applied (websocket only)
* grabs segments from the video stream and makes it available as MPEG-DASH for browser viewing
  * this will be pushed to a local volume for serving
  * and optionally can be pushed to a S3 for serving video at scale

This is intended to run independently of any applications that make use of the output. KISS

## Documentation

Use the provided docker-compose to launch the application.

It's not intended to be public facing as it will not scale (without wasting a lot processing power) but is designed so that it can be used in scalable applications. Obviously works fine as a frontend for your personal Raspberry Pi projects.
