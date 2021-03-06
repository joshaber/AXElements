require 'mouse'

##
# The module that contains helpers for working with the accessibility APIs.
module Accessibility; end

class << Accessibility

  # @group Debug helpers

  ##
  # Get a list of elements, starting with an element you give, and riding
  # the hierarchy up to the top level object (i.e. the {AX::Application}).
  #
  # @example
  #
  #   element = AX::DOCK.list.application_dock_item
  #   Accessibility.path(element) # => [AX::ApplicationDockItem, AX::List, AX::Application]
  #
  # @param [AX::Element]
  # @return [Array<AX::Element>] the path in ascending order
  def path *elements
    element = elements.last
    return path(elements << element.parent) if element.respond_to? :parent
    return elements
  end

  ##
  # Make a `dot` format graph of the tree, meant for graphing with
  # GraphViz.
  #
  # @return [String]
  def graph root
    dot = Accessibility::Graph.new(root)
    dot.build!
    dot.to_s
  end

  ##
  # Dump a tree to the console, indenting for each level down the
  # tree that we go, and inspecting each element.
  #
  # @example
  #
  #   puts Accessibility.dump(app)
  #
  # @return [String]
  def dump element
    output = element.inspect + "\n"
    enum   = Accessibility::DFEnumerator.new(element)
    enum.each_with_height do |element, depth|
      output << "\t"*depth + element.inspect + "\n"
    end
    output
  end

  # @group Finding an object at a point

  ##
  # Get the current mouse position and return the top most element at
  # that point.
  #
  # @return [AX::Element]
  def element_under_mouse
    element_at_point Mouse.current_position
  end

  ##
  # Get the top most object at an arbitrary point on the screen.
  #
  # @overload element_at_point(x,y)
  #   @param [Float] x
  #   @param [Float] y
  #
  # @overload element_at_point([x,y])
  #   @param [Array(Float,Float)] point
  #
  # @overload element_at_point(CGPoint.new(x,y))
  #   @param [CGPoint] point
  #
  # @return [AX::Element]
  def element_at_point *point
    arg = point.size == 1 ? point.first : point
    AX::Element.process AX.element_at_point(*arg.to_a.flatten)
  end
  alias_method :element_at_position, :element_at_point

  # @group Finding an application object

  ##
  # @todo Find a way for this method to work without sleeping;
  #       consider looping begin/rescue/end until AX starts up
  # @todo This needs to handle bad bundle identifier's gracefully
  #
  # This is the standard way of creating an application object. It will
  # launch the app if it is not already running and then create the
  # accessibility object.
  #
  # However, this method is a HUGE hack in cases where the app is not
  # already running; I've tried to register for notifications, launch
  # synchronously, etc., but there is always a problem with accessibility
  # not being ready. Hopefully this problem will go away on Lion...
  #
  # If this method fails to find an app with the appropriate bundle
  # identifier then it will return nil, eventually.
  #
  # @param [String] bundle a bundle identifier
  # @param [Float] sleep_time how long to wait between polling
  # @return [AX::Application,nil]
  def application_with_bundle_identifier bundle, sleep_time = 2
    sleep_count = 0
    while (apps = NSRunningApplication.runningApplicationsWithBundleIdentifier bundle).empty?
      launch_application bundle
      return if sleep_count > 10
      sleep sleep_time
      sleep_count += 1
    end
    application_with_pid apps.first.processIdentifier
  end

  ##
  # @todo We don't launch apps if they are not running, but we could if
  #       we used `NSWorkspace#launchApplication`, but it will be a headache
  #
  # Get the accessibility object for an application given its localized
  # name. This will not work if the application is not already running.
  #
  # @param [String] name name of the application to launch
  # @return [AX::Application,nil]
  def application_with_name name
    NSRunLoop.currentRunLoop.runUntilDate Time.now
    workspace = NSWorkspace.sharedWorkspace
    app = workspace.runningApplications.find { |app| app.localizedName == name }
    application_with_pid(app.processIdentifier) if app
  end

  ##
  # Get the accessibility object for an application given its PID.
  #
  # @return [AX::Application]
  def application_with_pid pid
    AX::Element.process AX.application_for_pid pid
  end

  # @endgroup


  private

  ##
  # This method uses asynchronous method calls to launch applications.
  #
  # @param [String] bundle the bundle identifier for the app
  # @return [Boolean]
  def launch_application bundle
    NSWorkspace.sharedWorkspace.launchAppWithBundleIdentifier bundle,
                                                     options: NSWorkspaceLaunchAsync,
                              additionalEventParamDescriptor: nil,
                                            launchIdentifier: nil
  end

end


require 'ax_elements/accessibility/enumerators'
require 'ax_elements/accessibility/qualifier'
require 'ax_elements/accessibility/graph'
