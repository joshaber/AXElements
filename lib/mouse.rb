##
# [Reference](http://developer.apple.com/library/mac/#documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html).
#
# @todo Inertial scrolling
# @todo Bezier paths
# @todo More intelligent default duration
# @todo Point arguments should accept a pair tuple...or should they?
# @todo Refactor to try and reuse the same event for a single action
#       instead of creating new events.
# @todo Pause between down/up clicks
module Mouse; end

class << Mouse

  ##
  # Number of animation steps per second.
  #
  # @return [Number]
  FPS     = 120

  ##
  # @note We keep the number as a rational to try and avoid rounding
  #       error introduced by the way MacRuby deals with floats.
  #
  # Smallest unit of time allowed for an animation step.
  #
  # @return [Number]
  QUANTUM = Rational(1, FPS)

  ##
  # Available constants for the type of units to use when scrolling.
  #
  # @return [Hash{Symbol=>Fixnum}]
  UNIT = {
    line:  KCGScrollEventUnitLine,
    pixel: KCGScrollEventUnitPixel
  }

  ##
  # The coordinates of the mouse using the flipped coordinate system
  # (origin in top left).
  #
  # @return [CGPoint]
  def current_position
    CGEventGetLocation(CGEventCreate(nil))
  end

  ##
  # Move the mouse from the current position to the given point.
  #
  # @param [CGPoint]
  # @param [Float] duration animation duration, in seconds
  def move_to point, duration = 0.2
    animate KCGEventMouseMoved, KCGMouseButtonLeft, current_position, point, duration
  end

  ##
  # Click and drag from the current position to the given point.
  #
  # @param [CGPoint]
  # @param [Float] duration animation duration, in seconds
  def drag_to point, duration = 0.2
    event = CGEventCreateMouseEvent(nil, KCGEventLeftMouseDown, current_position, KCGMouseButtonLeft)
    CGEventPost(KCGHIDEventTap, event)
    animate KCGEventLeftMouseDragged, KCGMouseButtonLeft, current_position, point, duration
    event = CGEventCreateMouseEvent(nil, KCGEventLeftMouseUp, current_position, KCGMouseButtonLeft)
    CGEventPost(KCGHIDEventTap, event)
  end

  ##
  # @todo Need to double check to see if I introduce any inaccuracies.
  #
  # Scroll at the current position the given amount of units.
  #
  # Scrolling too much or too little in a period of time will cause the
  # animation to look weird, possibly causing the app to mess things up.
  #
  # @param [Fixnum] amount number of units to scroll; positive to scroll
  #   up or negative to scroll down
  # @param [Float] duration animation duration, in seconds
  # @param [Fixnum] units `:line` scrolls by line, `:pixel` scrolls by pixel
  def scroll amount, duration = 0.2, units = :line
    units   = UNIT[units] || raise(ArgumentError, "#{units} is not a valid unit")
    steps   = (FPS * duration).floor
    current = 0.0
    steps.times do |step|
      done     = (step+1).to_f / steps
      scroll   = ((done - current)*amount).floor
      # the fixnum arg represents the number of scroll wheels
      # on the mouse we are simulating (up to 3)
      event = CGEventCreateScrollWheelEvent(nil, units, 1, scroll)
      CGEventPost(KCGHIDEventTap, event)
      sleep QUANTUM
      current += scroll.to_f / amount
    end
  end

  ##
  # A standard click. Default position is the current position.
  #
  # @param [CGPoint]
  def click point = current_position
    event = CGEventCreateMouseEvent(nil, KCGEventLeftMouseDown, point, KCGMouseButtonLeft)
    CGEventPost(KCGHIDEventTap, event)
    # @todo Should not set number of sleep frames statically.
    12.times do sleep QUANTUM end
    CGEventSetType(event, KCGEventLeftMouseUp)
    CGEventPost(KCGHIDEventTap, event)
  end

  ##
  # Standard secondary click. Default position is the current position.
  #
  # @param [CGPoint]
  def secondary_click point = current_position
    event = CGEventCreateMouseEvent(nil, KCGEventRightMouseDown, point, KCGMouseButtonRight)
    CGEventPost(KCGHIDEventTap, event)
    CGEventSetType(event, KCGEventRightMouseUp)
    CGEventPost(KCGHIDEventTap, event)
  end
  alias_method :right_click, :secondary_click

  ##
  # A standard double click. Defaults to clicking at the current position.
  #
  # @param [CGPoint]
  def double_click point = current_position
    event = CGEventCreateMouseEvent(nil, KCGEventLeftMouseDown, point, KCGMouseButtonLeft)
    CGEventPost(KCGHIDEventTap, event)
    CGEventSetType(event,       KCGEventLeftMouseUp)
    CGEventPost(KCGHIDEventTap, event)

    CGEventSetIntegerValueField(event, KCGMouseEventClickState, 2)
    CGEventSetType(event,       KCGEventLeftMouseDown)
    CGEventPost(KCGHIDEventTap, event)
    CGEventSetType(event,       KCGEventLeftMouseUp)
    CGEventPost(KCGHIDEventTap, event)
  end

  ##
  # Click with an arbitrary mouse button, using numbers to represent
  # the mouse button. At the time of writing, the documented values are:
  #
  #  - KCGMouseButtonLeft   = 0
  #  - KCGMouseButtonRight  = 1
  #  - KCGMouseButtonCenter = 2
  #
  # And the rest are not documented! Though they should be easy enough
  # to figure out. See the `CGMouseButton` enum in the reference
  # documentation for the most up to date list.
  #
  # @param [CGPoint]
  # @param [Number]
  def arbitrary_click point = current_position, button = KCGMouseButtonCenter
    event = CGEventCreateMouseEvent(nil, KCGEventOtherMouseDown, point, button)
    CGEventPost(KCGHIDEventTap, event)
    CGEventSetType(event, KCGEventOtherMouseUp)
    CGEventPost(KCGHIDEventTap, event)
  end
  alias_method :other_click, :arbitrary_click


  private

  ##
  # Executes a mouse movement animation. It can be a simple cursor
  # move or a drag depending on what is passed to `type`.
  def animate type, button, from, to, duration
    steps = (FPS * duration).floor
    xstep = (to.x - from.x) / steps
    ystep = (to.y - from.y) / steps
    steps.times do
      from.x += xstep
      from.y += ystep
      event = CGEventCreateMouseEvent(nil, type, from, button)
      CGEventPost(KCGHIDEventTap, event)
      sleep QUANTUM
    end
    $stderr.puts 'Not moving anywhere' if from == to
    event = CGEventCreateMouseEvent(nil, type, to, button)
    CGEventPost(KCGHIDEventTap, event)
    sleep QUANTUM
  end

end
