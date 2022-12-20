# provides an API for monitoring events
class Imagine < Application
  base "/imagine/node/v1/"

  SOCKETS = [] of HTTP::WebSocket

  @[AC::Route::WebSocket("/detections")]
  def websocket(socket)

  end
end
