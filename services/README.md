# Services

Install the service at: `/etc/systemd/system/pi_camera.service`

* `systemctl enable pi_camera`
* `systemctl start pi_camera`
* `systemctl status pi_camera`

This provides a hardware accellerated video stream that can be used with your application.

* `journalctl -u pi_camera` (if there are issues)

## requirements

uses [libcamera](https://libcamera.org/) to provide hardware accellerated h264 conversion

* use `libcamera-vid --list-cameras` to find the most performant resolution / to select mode
