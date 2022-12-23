# Imagine, an AI video monitoring framework

Imagine is a crystal lang web platform for AI processing and monitoring video streams.

* takes UDP H.264 video streams as input (needs to be web compatible format)
* runs frames through [TensorFlow Lite](https://tfhub.dev/s?deployment-format=lite) models
* outputs detection data to a websocket and optionally a Redis channel or webhook
  * detection coordinates only
  * optionally the PNG image (websocket and webhook)
  * optionally the PNG image with markup applied (websocket and webhook)
* grabs segments from the video stream and makes it available as MPEG-DASH for browser viewing
  * this will be pushed to a local volume for serving
  * and optionally can be pushed to a S3 for serving video at scale

This is intended to run independently of any applications that make use of the output. KISS

## Documentation

Use the provided docker-compose to launch the application.

It's not intended to be public facing as it will not scale (without wasting a lot processing power) but is designed so that it can be used in scalable applications. Obviously works fine as a frontend for your personal Raspberry Pi projects.

### Pre-prepared TF Lite models

These are a bunch of models available that will work with Coral Edge TPUs and the example object detection model

* https://github.com/google-coral/test_data

### Converting TF Models for use

* List of [pre-built detection models](https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/tf2_detection_zoo.md)
* guide for converting these models to [run on TF Lite](https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/running_on_mobile_tf2.md)
  * Download [the tooling](https://github.com/tensorflow/models): `pip3 install tf-models-official`
  * `pip install tensorflow-object-detection-api`
