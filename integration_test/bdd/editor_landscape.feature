Feature: Editor in landscape
  Turning the device sideways moves the dock to a rail down the left edge and
  puts the tool panel in a column beside it that folds away on demand, leaving
  the rest of the screen to the picture.

  # The rotation is applied to the test surface rather than the real sensor:
  # driving the device's own orientation from an integration test is racy and
  # tells us nothing the layout itself does not.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added

  Scenario: The dock becomes a vertical rail
    When the device is rotated to landscape
    Then the tool dock is a vertical rail
    And I see {'Effects'}
    And no unhandled error occurred

  Scenario: The tool panel folds away and comes back
    When the device is rotated to landscape
    And I hide the tool panel
    Then the tool panel is hidden
    When I show the tool panel
    Then the tool panel is shown
    And no unhandled error occurred

  # The raw dock-button step, not "I tap the ... tool": that one re-opens the
  # panel afterwards, which is the behaviour under observation here.
  Scenario: Tapping the tool you are already on folds the panel away
    When the device is rotated to landscape
    And I tap the {'Layers'} dock button
    Then the tool panel is shown
    When I tap the {'Layers'} dock button
    Then the tool panel is hidden
    When I tap the {'Layers'} dock button
    Then the tool panel is shown

  Scenario: Tools still work in landscape
    When the device is rotated to landscape
    And I tap the {'Layers'} tool
    And I tap the {'Adjust'} tool
    And I move the {'Brightness'} slider
    Then the selected photo has been adjusted
    And no unhandled error occurred

  Scenario: Back to portrait, the dock is horizontal again
    When the device is rotated to landscape
    Then the tool dock is a vertical rail
    When the device is rotated to portrait
    Then the tool dock is a horizontal bar
    And no unhandled error occurred
