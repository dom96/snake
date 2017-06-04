proc vibrate*(pattern: openarray[int]) =
  # See here for details:
  # https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API
  {.emit: """
    // enable vibration support
    navigator.vibrate = navigator.vibrate || navigator.webkitVibrate ||
                        navigator.mozVibrate || navigator.msVibrate;

    if (navigator.vibrate) {
      // vibration API supported
      navigator.vibrate(`pattern`);
    }
  """.}

proc vibrate*(pattern: int) =
  vibrate(@[pattern])