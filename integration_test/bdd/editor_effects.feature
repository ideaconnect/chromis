Feature: Editor layer effects
  One-tap filters, HDR, vignette, drop shadow, contour and blend mode change a
  layer's look, and the Effects reset takes them all back off.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added
    And I tap the {'Effects'} tool

  Scenario: The Effects panel offers the whole look toolbox
    Then I see {'FILTER'}
    And I see {'HDR'}
    And I see {'VIGNETTE'}
    And I see {'SHADOW'}
    And I see {'BLEND'}
    And no unhandled error occurred

  Scenario: Apply a filter and fade it
    When I tap the {'Noir'} filter
    Then the selected photo has the {'noir'} filter
    When I move the {'Strength'} slider
    Then the selected photo has the {'noir'} filter
    And no unhandled error occurred

  Scenario: A filter can be taken back off
    When I tap the {'Vivid'} filter
    Then the selected photo has the {'vivid'} filter
    When I tap the {'Original'} filter
    Then the selected photo has the {'none'} filter

  Scenario: HDR and vignette
    When I move the {'Tone + detail'} slider
    And I move the {'Amount'} slider
    Then the selected photo has HDR
    And the selected photo has a vignette
    And no unhandled error occurred

  Scenario: A drop shadow with direction, blur and density
    When I move the {'Opacity'} slider
    Then the selected layer has a shadow
    When I move the {'Direction'} slider
    And I move the {'Distance'} slider
    And I move the {'Blur'} slider
    And I move the {'Density'} slider
    Then the selected layer has a shadow
    And no unhandled error occurred

  Scenario: A contour around the layer
    When I move the {'Thickness'} slider
    Then the selected layer has an outline
    And no unhandled error occurred

  Scenario: Blending the layer down
    When I tap {'Multiply'}
    Then the selected layer blends with {'multiply'}
    When I tap {'Screen'}
    Then the selected layer blends with {'screen'}

  Scenario: Reset clears every look at once
    When I tap the {'Punch'} filter
    And I move the {'Tone + detail'} slider
    And I move the {'Thickness'} slider
    And I tap {'Multiply'}
    Then the selected layer blends with {'multiply'}
    When I tap {'Reset'}
    Then the selected photo has no effects
    And no unhandled error occurred

  # No second tap on Effects here: the Background is already on that tool, and
  # adding a layer selects it, so the panel follows. Tapping the active tool
  # would fold the panel away in landscape.
  Scenario: A caption gets a shadow and an outline of its own
    When I add a text layer
    And I move the {'Opacity'} slider
    Then the selected layer has a shadow
    When I move the {'Thickness'} slider
    Then the selected layer has an outline
    And no unhandled error occurred
